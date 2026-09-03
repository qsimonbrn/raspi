# insta-triage

Sichten und Sortieren der eigenen Instagram-Abos. Die App **hat keinen Zugang zu
Instagram**: Sie liest vorbereitete JSON-Dateien ein, zeigt sie an und führt Listen.
Entfolgt und gefolgt wird von Hand — die App sagt nur, was als Nächstes dran ist.

Erreichbar unter <http://100.108.219.87:8080> — nur über Tailscale.

## Warum keine Automatisierung

Die offizielle Meta Graph API kennt weder die Following-Liste noch Follow oder
Unfollow. Alles, was das trotzdem kann, arbeitet über die inoffizielle Private API
oder Browser-Automation und riskiert den Account. Instagram lässt 2026 etwa
100–150 Unfollows pro Tag und 15–20 pro Stunde durchgehen; ausschlaggebend ist die
Geschwindigkeit, nicht die Tagessumme. Schneller als von Hand wäre eine
Automatisierung also ohnehin nicht — sie wäre nur riskanter.

## Ablauf

1. **Daten einlesen** — im Reiter *Daten* die JSON-Dateien hochladen:
   - aus dem Instagram-Datenexport (Format JSON, Auswahl „Follower und Follows"):
     `following.json`, `followers_1.json`, `close_friends.json`
   - aus der Browser-Abfrage: `following_profile.json` (Klarnamen, Profilbilder,
     privat/verifiziert)

   Mehrfaches Einlesen ist unschädlich: Entscheidungen und Kategorien bleiben stehen,
   nur Stammdaten werden aufgefrischt.

2. **Bilder holen** — einmalig, ebenfalls im Reiter *Daten*. Nötig, weil die
   CDN-URLs signiert sind und nach Stunden ablaufen.

3. **Sichten** — Reiter *Sichten*. Je Account eine von vier Entscheidungen:

   | Entscheidung | Bedeutung |
   |---|---|
   | offen | noch nicht entschieden |
   | behalten | bleibt auf dem Hauptaccount |
   | entfolgen | wird auf dem Hauptaccount entfernt |
   | migrieren | Hauptaccount entfolgt, Zweitaccount folgt |

   Tastatur: `j`/`k` bewegen, `1` behalten, `2` entfolgen, `3` migrieren, `0`
   zurücksetzen, `Leertaste` auswählen. Mehrfachauswahl unten in der Leiste.

4. **Abarbeiten** — Reiter *Arbeitsliste Hauptaccount* und *Zweitaccount*. Jede Zeile
   verlinkt das Profil; Häkchen setzen, sobald erledigt. Höchstens 100–150 Aktionen
   am Tag, mit Pausen.

## Aufbau

| | |
|---|---|
| Anwendung | FastAPI + SQLite, eine Datei (`app/app.py`), Oberfläche in `app/static/` |
| Daten | `/mnt/usb-hdd/insta-triage/` — `triage.db`, `pics/`, `import/` |
| Port | 8080, gebunden an die Tailscale-Adresse |
| Speicher | Limit 256 MB |

Der Port ist ausdrücklich an `100.108.219.87` gebunden statt an `0.0.0.0`. Damit hängt
die Abschottung nicht an der Portliste in `system/firewall/pi-guard.sh`, die sonst hätte
erweitert werden müssen. **Ändert sich die Tailscale-Adresse des Pi, startet der
Container nicht mehr** — dann die Adresse in `docker-compose.yml` nachziehen.

## Befehle

```bash
cd /home/simon/raspi/stacks/insta-triage
sudo docker compose build && sudo docker compose up -d
sudo docker logs -f insta-triage

# ohne Weboberflaeche, direkt im Container:
sudo docker exec insta-triage python app.py import   # /data/import/*.json einlesen
sudo docker exec insta-triage python app.py pics     # Profilbilder holen
sudo docker exec insta-triage python app.py stand    # Kurzstand
```

## Sicherung

`/mnt/usb-hdd/insta-triage/` liegt auf der SSD. Ob das Verzeichnis ins restic-Backup
gehört, ist noch nicht entschieden — die Entscheidungen darin sind mühsam erarbeitet,
die Bilder dagegen jederzeit nachladbar. Siehe `docs/12-backup.md`.
