# 20 — yt-werk: Beschaffungsdienst für die Workbench

Stand: 12.09.2026

## Wozu

n8n verwandelt Videos aus der YouTube-Playlist „Project Ideas" in Projekt­fahrpläne
im Obsidian-Vault. Zwei Dinge kann n8n dabei nicht selbst:

1. **Transkripte beschaffen.** Die YouTube Data API v3 liefert *keine* Untertitel
   fremder Videos — `captions.download` funktioniert nur als Eigentümer des Kanals.
   Ein API-Schlüssel hätte also gemeldet, dass ein neues Video da ist, aber keinen
   Inhalt geliefert.
2. **yt-dlp ausführen.** Das n8n-Image bringt weder Python noch yt-dlp mit.

Deshalb gibt es `yt-werk`: ein kleiner FastAPI-Dienst mit yt-dlp, der beides
übernimmt. n8n orchestriert nur noch.

**Kein Google-API-Schlüssel im Einsatz.** Er wurde geprüft und verworfen: yt-dlp
listet die Playlist ohnehin mit auf, und wenn yt-dlp einmal bricht, nützt eine
funktionierende Playlist-Abfrage nichts, weil dann auch das Transkript fehlt. Der
Schlüssel hätte ein Google-Cloud-Projekt und ein weiteres Geheimnis gekostet, ohne
dass etwas häufiger funktioniert. Bei Playlists mit vielen tausend Videos wäre die
Rechnung eine andere.

## Wo es läuft

| Sache | Wert |
|---|---|
| Stack | `/home/simon/raspi/stacks/yt-werk/` |
| Image | `yt-werk:1.0.0`, selbst gebaut aus `python:3.12.8-slim-bookworm` |
| Benutzer | 1000:1000 — dieselbe UID wie n8n, damit beide dieselben Dateien anfassen können |
| Speicherlimit | 256 MB (gemessen im Leerlauf: rund 43 MB) |
| Netz | `werkbank` (extern angelegt), gemeinsam mit n8n |
| Port | **keiner veröffentlicht** — nur `http://yt-werk:8722` innerhalb des Netzes |
| Ablage | `/mnt/usb-hdd/second-brain/eingang:/eingang` |

Weil kein Port auf dem Host erscheint, ist **pi-guard hier nicht beteiligt**. Das
ist der Unterschied zu n8n, wo die Abschottung an einer einzigen Firewall-Regel
hängt, die Docker bei jedem `up -d` neu schreibt.

Das Netz `werkbank` wird bewusst **außerhalb** beider Stacks angelegt:

```bash
docker network create werkbank
```

Läge es in einem der beiden Compose-Dateien, würde ein `docker compose down` es
dem jeweils anderen Stack unter den Füßen wegziehen.

## Schnittstelle

| Weg | Was er tut |
|---|---|
| `GET /health` | Zustand und yt-dlp-Version |
| `GET /playlist/<id>` | listet eine Playlist auf, ohne Videos zu laden |
| `POST /holen` | `{video_id}` → legt `eingang/<id>/` mit Metadaten und Transkript an |
| `GET /offen` | alle abgelegten Videos, die noch nicht ausgearbeitet sind |
| `GET /video/<id>` | Metadaten plus Transkript in einem Rutsch |
| `POST /ablegen` | schreibt eine fertige Notiz in den Ordner des Videos |
| `GET /verarbeitet` | Liste der erledigten Video-IDs |
| `POST /verarbeitet` | trägt eine Video-ID ein — erst nach erfolgreicher Ablage |

`/holen` ist idempotent: liegt der Ordner schon, antwortet es mit
`uebersprungen: true`. Damit braucht Workflow A keine eigene Duplikatprüfung.

Alles Schreibende arbeitet über eine Zwischendatei und hängt sie erst am Ende um.
Ein abgebrochener Lauf hinterlässt so keinen halben Ordner, den n8n für fertig hält.
`.verarbeitet` wird unter Dateisperre fortgeschrieben.

## Zwei Fallen, die beim Bauen zugeschnappt sind

**HTTP 429.** Lässt man yt-dlp die Untertitel selbst herunterladen und gibt ein
Sprachmuster wie `de.*` an, fragt es dutzende automatisch übersetzte Fächer
nacheinander an — YouTube antwortet mit „Too Many Requests". Der Dienst holt
deshalb zuerst die Metadaten, wählt daraus *eine* Untertitelspur und lädt genau
diese eine Datei über ihre URL.

**Übersetzung statt Original.** YouTube bietet zu einem englischen Video rund 150
übersetzte Untertitelfächer an, darunter ein deutsches. Nimmt man das, verarbeitet
das Modell die Maschinenübersetzung einer Maschinentranskription; Namen und
Fachbegriffe leiden sichtbar. Der Dienst bevorzugt deshalb die unübersetzte Spur
(`<sprache>-orig`) und überlässt das Übersetzen dem Modell, das den Fahrplan
ohnehin auf Deutsch schreibt.

## Wenn das Holen ausfällt

yt-dlp muss YouTube hinterherlaufen und bricht deshalb gelegentlich für ein paar
Tage. Das Zeichen dafür: `POST /holen` antwortet mit 502, im Log steht ein
Extraktionsfehler. Maßnahme:

```bash
# Version in stacks/yt-werk/Dockerfile hochziehen, dann
cd /home/simon/raspi/stacks/yt-werk
sudo docker compose build && sudo docker compose up -d
sudo docker exec yt-werk python -c "import urllib.request;print(urllib.request.urlopen('http://127.0.0.1:8722/health').read())"
```

Nichts geht dabei verloren: Was nicht geholt wurde, steht weiter in der Playlist
und wird beim nächsten Takt erneut versucht.

**Bekannte Warnung:** `No supported JavaScript runtime could be found`. yt-dlp
hätte für manche Formate gern Deno. Für Metadaten und Untertitel — mehr holen wir
nicht — ist es ohne Belang. Sollte YouTube das erzwingen, käme Deno ins Image;
das kostet rund 100 MB.

## Was der Dienst NICHT tut

- Kein Ton, kein Bild, keine Videodatei. Deshalb auch kein ffmpeg im Image
  (spart rund 250 MB).
- Keine Einsortierung in den Vault. Der Dienst schreibt ausschließlich nach
  `eingang/`; das Verteilen auf `10_Projekte/`, `40_Quellen/` und `_anhaenge/`
  macht der Mac beim abendlichen Sync anhand der `ablage.json`.

## Verwandt

- `docs/19-n8n.md` — die Workflows, die diesen Dienst aufrufen
- `docs/12-backup.md` — `eingang/` ist seit dem 12.09.2026 in der Sicherung
