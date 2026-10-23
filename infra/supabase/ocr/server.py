"""The OCR service behind the timetable scan (specs/24 "Scanning").

One endpoint: POST /ocr with a multipart field ``image`` (JPEG, PNG, WebP or HEIC, or a PDF,
at most 6 MB) answers ``{"width", "height", "lines": [{"text", "box", "score"}], "source"}``.
``box`` is the text's quadrilateral as eight pixel coordinates (x1 y1 x2 y2 x3 y3 x4 y4). The
Edge Function ``timetable-scan`` turns the lines into the grid; this process only reads the
file.

A PDF a school made on a computer carries its text: that text layer is read with its
positions and no OCR at all (``source: "text"``), which is exact. A PDF that is only a scan
has no text layer; its first page is rendered and read like a photo (``source: "ocr"``).

Engine: RapidOCR with PaddleOCR's PP-OCRv5 Latin-script models on ONNX Runtime (CPU). The
models are loaded once and kept; the first request after a start takes a few seconds.
Nothing is written to disk and nothing is logged but the request line.
"""

from __future__ import annotations

import io
import threading
from typing import Any

import numpy as np
import pypdfium2 as pdfium
from fastapi import FastAPI, File, HTTPException, UploadFile
from PIL import Image, ImageOps
from pillow_heif import register_heif_opener

register_heif_opener()

MAX_BYTES = 6 * 1024 * 1024
MAX_SIDE = 2400
# A PDF page is rendered at this scale (1 = 72 dpi): A4 landscape becomes about 1300 px wide.
PDF_SCALE = 110 / 72
# Fewer text pieces than this on a PDF page means a scan without a text layer.
MIN_TEXT_PIECES = 8

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


def _recognise(pixels: np.ndarray) -> list[dict[str, Any]]:
    result = engine()(pixels)
    lines: list[dict[str, Any]] = []
    boxes = getattr(result, "boxes", None)
    texts = getattr(result, "txts", None)
    scores = getattr(result, "scores", None)
    if boxes is None or texts is None:
        return lines
    for i, text in enumerate(texts):
        box = np.asarray(boxes[i], dtype=float).reshape(-1)[:8]
        if box.size < 8 or not str(text).strip():
            continue
        lines.append({
            "text": str(text),
            "box": [float(v) for v in box],
            "score": float(scores[i]) if scores is not None else None,
        })
    return lines


def _pdf_text(page: Any, scale: float) -> list[dict[str, Any]]:
    """The first page's text layer as lines with boxes in the rendered page's pixel space:
    PDF points from the bottom-left corner become pixels from the top-left one. The library
    hands out one rectangle per character or short run; neighbours on one baseline are
    joined into the words and phrases the grid parser expects, as the OCR would see them."""
    width, height = page.get_size()
    textpage = page.get_textpage()
    pieces: list[tuple[float, float, float, float, str]] = []
    for i in range(textpage.count_rects()):
        left, bottom, right, top = textpage.get_rect(i)
        text = textpage.get_text_bounded(left=left, bottom=bottom, right=right, top=top)
        if not text or not text.strip() or right <= left or top <= bottom:
            continue
        pieces.append((left * scale, (height - top) * scale, right * scale, (height - bottom) * scale, text))
    # Capitals, lowercase letters and dots come as rectangles of different heights that share
    # a baseline (the bottom edge, descenders aside). Pieces are read along that baseline.
    if not pieces:
        return []
    typical = sorted(p[3] - p[1] for p in pieces)[len(pieces) // 2] or 1.0
    # Lines: pieces whose centres chain within half a text height. Then, left to right along
    # each line, neighbours closer than a text height become one word or phrase.
    pieces.sort(key=lambda p: (p[1] + p[3]) / 2)
    lines: list[list[tuple[float, float, float, float, str]]] = []
    for piece in pieces:
        cy = (piece[1] + piece[3]) / 2
        if lines and cy - (lines[-1][-1][1] + lines[-1][-1][3]) / 2 <= 0.45 * typical:
            lines[-1].append(piece)
        else:
            lines.append([piece])
    merged: list[list[Any]] = []
    for line in lines:
        line.sort(key=lambda p: p[0])
        current: list[Any] | None = None
        for x0, y0, x1, y1, text in line:
            size = max(typical, y1 - y0, (current[3] - current[1]) if current else 0.0)
            gap = x0 - current[2] if current else None
            if current is not None and gap is not None and -0.3 * size <= gap <= 0.9 * size:
                space = gap > 0.2 * size and not current[4].endswith(" ") and not text.startswith(" ")
                current[4] += (" " if space else "") + text
                current[2] = max(current[2], x1)
                current[1], current[3] = min(current[1], y0), max(current[3], y1)
            else:
                current = [x0, y0, x1, y1, text]
                merged.append(current)
    out: list[dict[str, Any]] = []
    for x0, y0, x1, y1, text in merged:
        clean = " ".join(text.split())
        if clean:
            out.append({"text": clean, "box": [x0, y0, x1, y0, x1, y1, x0, y1], "score": 1.0})
    return out


def _read_pdf(data: bytes) -> dict[str, Any]:
    try:
        pdf = pdfium.PdfDocument(data)
        if len(pdf) < 1:
            raise ValueError("no pages")
        page = pdf[0]
    except Exception as err:  # noqa: BLE001
        raise HTTPException(status_code=400, detail="image_invalid") from err
    width, height = page.get_size()
    scale = PDF_SCALE
    if max(width, height) * scale > MAX_SIDE:
        scale = MAX_SIDE / max(width, height)
    lines = _pdf_text(page, scale)
    if len(lines) >= MIN_TEXT_PIECES:
        return {"width": int(width * scale), "height": int(height * scale), "lines": lines, "source": "text"}
    # A scan: no text layer worth the name. Render the page and read it like a photo.
    bitmap = page.render(scale=scale)
    pixels = np.asarray(bitmap.to_pil().convert("RGB"))
    h, w = pixels.shape[:2]
    return {"width": int(w), "height": int(h), "lines": _recognise(pixels), "source": "ocr"}


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
    if data[:5] == b"%PDF-" or (image.content_type or "") == "application/pdf":
        return _read_pdf(data)
    pixels = _load(data)
    height, width = pixels.shape[:2]
    return {"width": int(width), "height": int(height), "lines": _recognise(pixels), "source": "ocr"}
