# 22 — SnapOtter: Werkzeugkasten für Dateien

Stand: 14.09.2026

## Wozu

Bild, Video, Audio, PDF und Dokumente umwandeln, komprimieren, zuschneiden — über eine
Oberfläche, eine REST-Schnittstelle und Pipelines. Die REST-Schnittstelle ist der
eigentliche Grund für die Wahl gegenüber Einzelwerkzeugen: n8n kann sie ansprechen.

**Was SnapOtter hier NICHT leisten soll:** die eingebauten KI-Werkzeuge — Transkription
mit faster-whisper, Hochskalierung, Freisteller, Kolorierung. Sie laufen auf einem Pi 4
ohne GPU bestenfalls zäh. Dokumenten-OCR macht Paperless, Transkription und Bild-KI
gehören auf den Mac.

**Auslagern geht nicht.** SnapOtter kennt keine Konfiguration für einen externen
Endpunkt; der Quelltext wurde am 13.09.2026 nach `OLLAMA`, `OPENAI_BASE_URL`,
`AI_ENDPOINT` und `REMOTE_WORKER` durchsucht — kein Treffer. `faster-whisper` läuft fest
im Container. Ollama wäre ohnehin der falsche Server dafür: es bedient Sprachmodelle,
nicht Whisper oder Bildmodelle.

## Wo es läuft

| Sache | Wert |
|---|---|
| Stack | `/home/simon/raspi/stacks/snapotter/` |
| Container | `snapotter`, `snapotter-postgres`, `snapotter-redis` |
| Images | `snapotter/snapotter:2.2.0`, `postgres:17-alpine`, `redis:8-alpine` |
| Adresse | `http://192.168.178.80:1349` — **aus dem LAN**, nicht nur über Tailscale |
| Anmeldung | Benutzer `admin`, Passwort in `stacks/snapotter/.env` |
| Daten | `/mnt/usb-hdd/snapotter/{data,pgdata,redis,workspace}` |
| Belegung | Image **5,44 GB** ausgepackt auf der SD-Karte, Daten 357 MB |

**1349 steht bewusst NICHT in der Sperrliste von `pi-guard`.** Entscheidung vom
13.09.2026. Wer die Liste erweitert, darf 1349 nicht mit aufnehmen.

Postgres und Redis veröffentlichen **keinen** Port. Nachgeprüft: 5432 und 6379 sind auf
dem Host nicht gebunden. Das ist wichtig, weil `pi-guard` sie nicht abfangen würde —
die beiden Ports stehen nicht in seiner Liste.

## Drei Container, nicht einer

Seit Version 2.0 hält SnapOtter seinen Bestand in PostgreSQL statt in SQLite und braucht
Redis als Auftragswarteschlange. Es gibt einen Einzelcontainer-Modus mit eingebauter
Datenbank, der setzt aber Root im Container voraus. Deshalb der Compose-Weg.

## Abweichung von der Hersteller-Vorlage

Die Referenz-Compose des Herstellers verlangt Werte, die auf diesem Pi nicht darstellbar
sind. Der Pi hat 3.796 MiB **insgesamt**.

| | Hersteller | hier |
|---|---|---|
| Anwendung | 6 GB | 1024 MiB |
| Postgres | 1 GB | 256 MiB |
| Redis | 1 GB, `maxmemory 512mb` | 192 MiB, `maxmemory 128mb` |
| `shm_size` | 2 GB | 256 MiB |

Gemessen im Ruhezustand: Anwendung **393 MiB**, Postgres 43 MiB, Redis 11 MiB.

Zwei Werte weichen aus einem Grund ab, der nicht auf der Hand liegt:

- **`maxmemory 128mb` statt 512mb.** Redis würde sonst bis 512 MiB wachsen wollen und
  vorher am 192-MiB-Containerlimit sterben. `noeviction` bleibt: Aufträge dürfen nicht
  still verschwinden, lieber ein Fehler beim Einstellen.
- **`TRUST_PROXY` auf `loopback,linklocal,uniquelocal` statt `true`.** Die Vorlage steht
  auf `true` und würde damit jedem Aufrufer erlauben, seine Client-IP per
  `X-Forwarded-For` selbst zu behaupten — die Ratenbegrenzung wäre wirkungslos. Hier
  steht kein Reverse Proxy davor.

## Der Fallstrick beim ersten Start: DAC_OVERRIDE

Die Fähigkeitenliste der Hersteller-Vorlage wurde beim Aufbau um `DAC_OVERRIDE` gekürzt,
mit der Begründung, die Datenverzeichnisse gehörten dem Container ohnehin. **Diese
Begründung war falsch**, und der Start ist daran gescheitert:

```
mkdir: cannot create directory '/data/ai': Permission denied
```

in einer Neustartschleife. Das Image startet als **root** (`Config.User` ist leer) und
wechselt erst im `entrypoint.sh` auf `PUID`/`PGID`. In diesem ersten Moment gehören ihm
die Verzeichnisse eben nicht — sie gehören `1000:1000` mit Modus 755, und root ohne
`DAC_OVERRIDE` darf dort nicht schreiben.

**Merksatz:** Wer die Fähigkeitenliste kürzt, muss prüfen, als *welcher* Benutzer das
Image **startet**, nicht als welcher es später läuft.

## PUID 1000 statt 999

Die Vorgabe des Images ist 999. Auf diesem Host gehört UID 999 dem nativen Benutzer
`pihole` und GID 999 der Gruppe `systemd-journal` — die SnapOtter-Daten hätten damit dem
Pi-hole-Benutzer gehört. Gesetzt ist deshalb 1000 (`simon`), wie bei n8n.

## Was im Backup landet

Seit 14.09.2026 in `pi-backup.sh`, Abschnitt 2c:

- **`pg_dump` der Datenbank** in die Zwischenablage. Das Datenverzeichnis `pgdata` steht
  **nicht** in der restic-Pfadliste: ein laufendes Postgres-Verzeichnis bytweise zu
  kopieren ergibt keinen wiederherstellbaren Stand.
- **`data/files`** — die Nutzdateien.

**Nicht gesichert: `data/ai`.** Dort liegen nachgeladene KI-Modelle, laut Hersteller bis
zu 35 GB. Sie sind jederzeit neu ladbar und würden das OneDrive-Kontingent von 5 GB im
Alleingang sprengen.

Die Prüfung des Abzugs ist gegen beide Fehlerbilder abgesichert und am 14.09.2026 mit
Negativkontrollen belegt:

| Prüfung | fängt ab | Nachweis |
|---|---|---|
| Schlussmarke `PostgreSQL database dump complete` in den letzten Zeilen | abgeschnittener Abzug | abgeschnittene Kopie wurde erkannt |
| `CREATE TABLE` mindestens einmal | Abzug einer leeren Datenbank | Abzug einer eigens angelegten Leerdatenbank: Schlussmarke **vorhanden**, Tabellen **0** |

Der zweite Fall ist der wichtige: Ein Abzug einer leeren Datenbank ist syntaktisch
vollständig und trägt die Schlussmarke. Die Schlussmarke allein hätte ihn durchgewinkt —
derselbe Fehler, den `integrity_check` bei Vaultwarden am 23.08.2026 gemacht hat.

Der echte Abzug: 20 KB, **12 Tabellen**.

## Telemetrie — offen, nicht geklärt

Das offizielle Image ist mit `SNAPOTTER_ANALYTICS=on` gebaut. Eine Laufzeitvariable, die
das abschaltet, gibt es nicht — nur einen Build-Parameter.

**Ob der Dienst tatsächlich nach außen funkt, konnte am 14.09.2026 nicht festgestellt
werden.** Drei Methoden wurden versucht, alle drei sind an ihrer eigenen Negativkontrolle
gescheitert:

| Methode | warum untauglich |
|---|---|
| `ss` im Netzwerk-Namensraum des Containers | zeigte nichts — aber auch bei `diun`, das nachweislich nach draußen spricht, nichts. Eine Momentaufnahme sieht keine kurzen Aufrufe. |
| Pi-hole-Abfrageprotokoll | ein eigens erzeugter Testname, im Container aufgelöst, tauchte im Protokoll **nicht** auf. DNS aus dem Container läuft nicht über Pi-hole. |
| `/proc/net/nf_conntrack` | Datei existiert auf diesem Kernel nicht, obwohl die Module geladen sind. |

Der Fund `app-analytics-services.com` im Pi-hole-Protokoll (108 Anfragen) stammt
nachweislich von **192.168.178.164 und .179**, also Geräten im LAN, nicht vom Pi.

**Weg beim nächsten Anlauf:** `tcpdump` nachinstallieren und 10 Minuten auf der Brücke
`br-7dced95a724d` mitschneiden, gegen eine erzwungene Verbindung als Kontrolle. Alternativ
eine zählende `nftables`-Regel für ausgehenden Verkehr aus `172.29.0.0/16` an öffentliche
Adressen — dann steht die Antwort als Zähler da, ohne Mitschnitt.

Bis dahin gilt: **unbekannt**, nicht „tut es nicht".

## Drosselung

`CONCURRENT_JOBS=1`, `MAX_WORKER_THREADS=2`, `PROCESSING_TIMEOUT_S=1800`,
`MAX_UPLOAD_SIZE_MB=200`. Vier Kerne, aber nur 1024 MiB für alles zusammen — ohne
Drosselung reißt ein einzelner Auftrag den Pi mit.

## Erster Start

Der erste Start legt eine Python-Umgebung unter `/data` an („First run: bootstrapping AI
venv from base image"). Das dauert und schreibt einige hundert MB auf die USB-HDD.
Danach: `Workers started: image(1), media(1), ai(1), docs(1), system(1)`.

Die Meldung `Module 'mediapipe' not available` ist erwartet und betrifft nur die
Gesichtserkennung.
