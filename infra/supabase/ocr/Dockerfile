# The family's own text recognition for photographed timetables (specs/24 "Scanning",
# docs/server/extras.md "Texterkennung"). Optional: the stack runs without it, and the app
# then offers the paste import only. Started with `docker compose --profile ocr up -d` once
# OCR_URL=http://ocr:9003/ocr is in the stack's .env.
#
# Engine: RapidOCR (Apache-2.0) running PaddleOCR's PP-OCR models on ONNX Runtime, CPU only,
# the same stack Immich's machine-learning container uses for its OCR. The Latin-script
# recognition model covers German, French and Spanish with their accents. The models are
# fetched at build time, so the running container needs no internet and reads nothing but
# the pictures the Edge Function sends it (server.py).
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PIP_NO_CACHE_DIR=1

RUN pip install --no-cache-dir \
      "rapidocr==3.10.0" \
      "onnxruntime==1.23.2" \
      "fastapi==0.120.4" \
      "uvicorn==0.38.0" \
      "python-multipart==0.0.20" \
      "pillow==12.0.0" \
      "pillow-heif==1.1.0" \
      "pypdfium2==5.0.0" \
      "numpy==2.3.4"

WORKDIR /app
COPY server.py /app/server.py

# Fetch every model once, at build time, by reading one drawn line; a failure here fails
# the build, never a scan. The running container (an unprivileged user, no internet) only
# reads what this step put into the image.
RUN python -c "import server; n = server.warm_up(); print('warm-up read', n, 'lines'); assert n > 0"

EXPOSE 9003
USER nobody
CMD ["uvicorn", "server:app", "--host", "0.0.0.0", "--port", "9003"]
