# yt-werk

Beschaffungsdienst für die Workbench: holt Playlist-Einträge, Metadaten und
Transkripte von YouTube und legt sie unter `/mnt/usb-hdd/second-brain/eingang/`
ab. Wird ausschließlich von n8n aufgerufen.

Vollständige Dokumentation: `docs/20-yt-werk.md`

## Handgriffe

```bash
# Zustand
sudo docker exec yt-werk python -c \
  "import urllib.request;print(urllib.request.urlopen('http://127.0.0.1:8722/health').read().decode())"

# Ein Video von Hand holen
sudo docker exec yt-werk python -c \
  "import urllib.request,json;r=urllib.request.Request('http://127.0.0.1:8722/holen',\
data=json.dumps({'video_id':'XXXXXXXXXXX'}).encode(),\
headers={'Content-Type':'application/json'},method='POST');\
print(urllib.request.urlopen(r,timeout=170).read().decode())"

# Nach einer Änderung an app.py oder am Dockerfile
sudo docker compose build && sudo docker compose up -d

# Modellvergleich an einem echten Transkript wiederholen
sudo docker cp vergleich.py yt-werk:/app/vergleich.py
sudo docker exec yt-werk python /app/vergleich.py <video_id>
```

## Voraussetzung

Das Netz `werkbank` muss existieren, sonst startet weder dieser Stack noch n8n:

```bash
docker network create werkbank
```
