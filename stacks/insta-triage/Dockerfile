FROM python:3.12.8-slim-bookworm

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    DATA_DIR=/data

WORKDIR /app

RUN pip install --no-cache-dir \
      "fastapi==0.115.6" \
      "uvicorn[standard]==0.34.0" \
      "httpx==0.28.1" \
      "python-multipart==0.0.20"

COPY app/ /app/

EXPOSE 8080
USER 1000:1000
CMD ["python", "app.py", "serve"]
