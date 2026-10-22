"""The OCR service behind the timetable scan (specs/24 "Scanning").

One endpoint: POST /ocr with a multipart field ``image`` (JPEG, PNG or WebP, at most 6 MB)
answers ``{"width", "height", "lines": [{"text", "box", "score"}]}``. ``box`` is the text's
quadrilateral as eight pixel coordinates (x1 y1 x2 y2 x3 y3 x4 y4). The Edge Function
``timetable-scan`` turns the lines into the grid; this process only reads the picture.

Engine: RapidOCR with PaddleOCR's PP-OCRv5 Latin-script models on ONNX Runtime (CPU). The
models are loaded once and kept; the first request after a start takes a few seconds.
Nothing is written to disk and nothing is logged but the request line.
"""

from __future__ import annotations

import io
import threading
from typing import Any

import numpy as np
from fastapi import FastAPI, File, HTTPException, UploadFile
from PIL import Image, ImageOps

MAX_BYTES = 6 * 1024 * 1024
MAX_SIDE = 2400

app = FastAPI(title="WuselWall OCR", docs_url=None, redoc_url=None)
_engine: Any = None
_lock = threading.Lock()


def engine() -> Any:
    """The RapidOCR engine, built on first use. Latin-script PP-OCRv5 when the installed
    version knows the language switch; the default (Chinese and English, which reads Latin
    letters too) otherwise, so an older or newer rapidocr still serves."""
    global _engine
    with _lock:
        if _engine is None:
            from rapidocr import RapidOCR  # type: ignore

            params: dict[str, Any] = {}
            try:
                from rapidocr import LangRec, ModelType, OCRVersion  # type: ignore

                params = {
                    "Rec.lang_type": LangRec.LATIN,
                    "Rec.model_type": ModelType.MOBILE,
                    "Rec.ocr_version": OCRVersion.PPOCRV5,
                }
            except ImportError:
                params = {}
            _engine = RapidOCR(params=params) if params else RapidOCR()
    return _engine


def warm_up() -> int:
    """Runs one recognition on a drawn line, so every model (detection, orientation,
    recognition) is fetched now. Called at build time by the Dockerfile; the running
    container, as an unprivileged user without internet, could not fetch them."""
    from PIL import ImageDraw, ImageFont

    image = Image.new("RGB", (640, 120), "white")
    ImageDraw.Draw(image).text((20, 30), "Mo Di Mi 08:00 Ma", fill="black",
                               font=ImageFont.load_default(size=40))
    result = engine()(np.asarray(image))
    return len(getattr(result, "txts", None) or [])


def _load(data: bytes) -> np.ndarray:
    try:
        image = Image.open(io.BytesIO(data))
        image = ImageOps.exif_transpose(image)  # phones store the rotation as a tag
        image = image.convert("RGB")
    except Exception as err:  # noqa: BLE001 - any decoding problem is the same answer
        raise HTTPException(status_code=400, detail="image_invalid") from err
    if max(image.size) > MAX_SIDE:
        image.thumbnail((MAX_SIDE, MAX_SIDE))
    return np.asarray(image)


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/ocr")
async def ocr(image: UploadFile = File(...)) -> dict[str, Any]:
    data = await image.read()
    if len(data) == 0:
        raise HTTPException(status_code=400, detail="image_invalid")
    if len(data) > MAX_BYTES:
        raise HTTPException(status_code=413, detail="image_too_large")
    pixels = _load(data)
    height, width = pixels.shape[:2]
    result = engine()(pixels)
    lines: list[dict[str, Any]] = []
    boxes = getattr(result, "boxes", None)
    texts = getattr(result, "txts", None)
    scores = getattr(result, "scores", None)
    if boxes is not None and texts is not None:
        for i, text in enumerate(texts):
            box = np.asarray(boxes[i], dtype=float).reshape(-1)[:8]
            if box.size < 8 or not str(text).strip():
                continue
            lines.append({
                "text": str(text),
                "box": [float(v) for v in box],
                "score": float(scores[i]) if scores is not None else None,
            })
    return {"width": int(width), "height": int(height), "lines": lines}
