# 06 — Daten & Speicher

*Erfasst: 13.08.2026*

> **Dies ist das wichtigste Kapitel dieser Dokumentation.** Alle anderen Befunde sind
> Optimierungen. Dieser hier betrifft möglichen dauerhaften Datenverlust.

---

## Speicherlandschaft

| Ort | Größe | Belegt | Inhalt |
|---|---|---|---|
| `/` (SD-Karte) | 235 G | 8,9 G | Betriebssystem, Docker-Layer, Logs |
| `/mnt/usb-hdd` (SSD) | 916 G | **310 G** | Alle Nutzdaten |

Die Trennung ist grundsätzlich richtig: Nutzdaten liegen auf der SSD, nicht auf der
SD-Karte. Zum Risiko des Systemdatenträgers siehe [01 — Hardware](01-hardware.md).

## Verzeichnisse auf der SSD

| Verzeichnis | Inhalt | Kritikalität |
|---|---|---|
| `paperless/` | **Dokumentenarchiv**, Thumbnails, Datenbankdaten | 🔴 sehr hoch |
| `bichon/` | **E-Mail-Archiv** | 🔴 sehr hoch |
| `filebrowser-data/` | Filebrowser-Datenbank (Benutzer, Einstellungen) | 🟡 mittel |
| `rclone_bak/` | Backup-Ablage Dropbox + OneDrive | 🟡 mittel |
| `trainings_bilder/` | Bilddatensätze | 🟢 ersetzbar |
| `Abschlussprojekt_DeepLearning/` | Projektdaten | 🟡 mittel |
| `SSD_Müll/` | vermutlich Ablage | 🟢 niedrig |
| `60 gb/`, `Leo Gartenfest/` | gemischt | ? |
| Diverse Einzeldateien | PNGs, `.DS_Store`, `._*`-Dateien von macOS | 🟢 niedrig |

Die zahlreichen `._*`-Dateien und `.DS_Store` stammen von macOS-Zugriffen über Samba.
Harmlos, aber sie lassen sich mit einer Samba-Option (`veto files`) künftig vermeiden.

### Verwaistes Verzeichnis

`/mnt/usb-hdd/filebrowser.db/` — ein **leeres Verzeichnis**, das `root` gehört.

Entstanden durch einen klassischen Docker-Fehler: In einer früheren Compose-Version war
`filebrowser.db` als Bind-Mount für eine *Datei* angegeben. Existierte die Datei auf dem
Host nicht, legt Docker stattdessen ein Verzeichnis an. Der Git-Commit
`9c4c0d0 Fix Filebrowser volumes: use proper database directory` hat das bereits
korrigiert — die aktuelle Konfiguration nutzt `filebrowser-data/`. Das alte Verzeichnis
ist nur noch ein Rückstand und kann entfernt werden.

---

## 🔴 Befund: Es existieren keine automatisierten Backups

### Was vorhanden ist

| Werkzeug | Status |
|---|---|
| `rsync` | installiert |
| `rclone` | installiert, Remotes **`onedrive:`** und **`dropbox:`** eingerichtet |
| `borg` / `borgmatic` | nicht installiert |
| `restic` | nicht installiert |
| `duplicity` | nicht installiert |
| `timeshift` | nicht installiert |

### Was fehlt

**Kein Cronjob. Kein systemd-Timer. Nichts.**

```
crontab -l (simon)   → leer
sudo crontab -l      → leer
/etc/cron.d/         → nur Paket-Einträge (e2scrub_all, pihole, sysstat)
```

Das Log `/mnt/usb-hdd/rclone_bak/rclone-onedrive.log` ist 8,4 MB groß und endet am
**12.12.2025**. Seitdem — seit rund **acht Monaten** — wurde kein Backup mehr erstellt.

### Was das konkret bedeutet

Die Einrichtung war da. Jemand hat sich die Mühe gemacht, rclone zu konfigurieren, zwei
Cloud-Ziele einzurichten und einen Lauf durchzuführen. Was fehlt, ist der eine Schritt,
der daraus einen Prozess macht: die Automatisierung.

Betroffen sind unter anderem:

- **Paperless-Dokumente** — eingescannte Papierunterlagen. Bei einem Dokumentenarchiv
  ist die typische Nutzung, das Papieroriginal nach dem Scannen wegzuwerfen. Ein Verlust
  wäre damit endgültig.
- **Bichon-E-Mail-Archiv** — laut Compose-Datei mit dem Hinweis versehen, dass das
  Master-Passwort später nicht änderbar ist, „ohne das Archiv zu zerstören". Ein Archiv,
  das so aufgebaut ist, sollte gesichert sein.
- **310 GB Nutzdaten** insgesamt.

Ein Ausfall der SSD, ein versehentliches `rm -rf` oder ein fehlgeschlagenes
Container-Update wären derzeit nicht rückgängig zu machen.

### Der Sonderfall Paperless

Paperless-ngx speichert nicht nur Dateien, sondern auch **Metadaten in PostgreSQL**:
Tags, Korrespondenten, Dokumenttypen, OCR-Text, Zuordnungen. Ein reines Kopieren des
Datenverzeichnisses ergibt **kein wiederherstellbares Archiv** — die Dokumente wären da,
aber die gesamte Ordnungsstruktur wäre weg.

Zwei saubere Wege:

1. **`document_exporter`** — das mitgelieferte Werkzeug von Paperless. Exportiert
   Dokumente *und* Metadaten in ein selbsttragendes Verzeichnis, das sich in eine neue
   Instanz importieren lässt. Der empfohlene Weg.
   ```
   docker compose exec -T webserver document_exporter ../export
   ```
2. **`pg_dump`** der Datenbank plus Kopie des Medienverzeichnisses. Funktioniert, ist
   aber enger an die Paperless-Version gekoppelt.

Wichtig in beiden Fällen: Der Export muss **vor** dem Kopieren laufen, und die Datenbank
sollte dabei nicht mitten in einem Import stehen.

---

## Empfohlene Backup-Strategie

### Zielbild

| Ebene | Was | Wohin | Häufigkeit |
|---|---|---|---|
| 1 | Paperless-Export + Bichon + Konfigurationen | lokal auf der SSD | täglich |
| 2 | Ebene 1, verschlüsselt und dedupliziert | OneDrive via rclone | täglich |
| 3 | Systemkonfiguration (`/etc/wireguard`, `/etc/samba`, Pi-hole-Export) | mit Ebene 1 | wöchentlich |

### Werkzeugempfehlung: `restic`

`restic` passt hier besser als reines `rclone sync`, weil es drei Dinge mitbringt, die
eine Spiegelung nicht leisten kann:

- **Versionierung.** Eine Datei, die vor drei Wochen versehentlich überschrieben wurde,
  ist bei einer Spiegelung längst überall kaputt. Mit Snapshots ist sie wiederherstellbar.
- **Verschlüsselung.** Die Dokumente landen bei einem Cloud-Anbieter. Sie sollten
  verschlüsselt sein, bevor sie das Haus verlassen.
- **Deduplizierung.** Bei täglichen Läufen über 310 GB spart das erheblich Bandbreite und
  Cloud-Speicher.

`restic` kann rclone direkt als Backend nutzen — die vorhandene OneDrive-Konfiguration
wird also weiterverwendet, nicht ersetzt.

### Alternative

Wenn es einfach bleiben soll: ein systemd-Timer mit `rclone sync` und aktivierter
`--backup-dir`-Option. Das ist deutlich schwächer als restic (keine Verschlüsselung,
gröbere Versionierung), aber ungleich besser als der aktuelle Zustand.

**Der entscheidende Punkt ist nicht das Werkzeug, sondern dass überhaupt etwas läuft.**

### Und dann: den Rückweg testen

Ein Backup, aus dem noch nie etwas zurückgespielt wurde, ist eine Vermutung. Der
sinnvollste erste Test: einen Paperless-Export in eine leere Testinstanz importieren und
prüfen, ob Tags und Zuordnungen vollständig sind.

---

## Verwandte Kapitel

- [01 — Hardware](01-hardware.md): SD-Karte als Ausfallrisiko
- [05 — Docker](05-docker.md): Warum Container-Updates ohne Backup riskant sind
- [11 — Notfallwiederherstellung](11-disaster-recovery.md): Was für einen Wiederaufbau fehlt
