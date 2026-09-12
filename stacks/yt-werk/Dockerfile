# yt-werk -- Beschaffungsdienst fuer n8n.
#
# Bewusst ein eigenes Image statt yt-dlp ins n8n-Image zu backen: n8n bleibt
# damit unveraendert auf seinem gepinnten Stand, und yt-dlp -- das YouTube
# hinterherlaufen muss und deshalb oft aktualisiert wird -- laesst sich davon
# unabhaengig neu bauen.

FROM python:3.12.8-slim-bookworm

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    EINGANG=/eingang

WORKDIR /app

# yt-dlp ist ausdruecklich gepinnt. Wenn YouTube etwas aendert und das Holen
# ausfaellt, ist die Massnahme: Version hier hochziehen und neu bauen --
# siehe docs/20-yt-werk.md. Kein "latest", damit ein Neubau nicht still
# etwas anderes installiert als das, was zuletzt lief.
RUN pip install --no-cache-dir \
      "yt-dlp==2026.8.19" \
      "fastapi==0.141.1" \
      "uvicorn[standard]==0.52.4"

COPY app/ /app/

# Kein ffmpeg im Image: wir laden ausschliesslich Untertitel und Metadaten,
# nie Ton oder Bild. Das spart rund 250 MB.

EXPOSE 8722
USER 1000:1000
CMD ["python", "app.py"]
