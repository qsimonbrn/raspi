# Änderungsverlauf der Dokumentation

Dieser Verlauf dokumentiert Änderungen an der **Dokumentation**, nicht am System selbst.
Systemänderungen werden in den jeweiligen Kapiteln vermerkt.

Format: [Keep a Changelog](https://keepachangelog.com/de/1.1.0/) ·
Datumsformat: JJJJ-MM-TT

---

## [1.3.0] — 2026-08-13

### Geändert am System

- **Paperless-ngx vollständig konfiguriert**: OCR auf `deu+eng`, Zeitzone
  Europe/Berlin, Ablageschema `Jahr/Korrespondent/Datum_Titel`, Deskew und
  Seitendrehung aktiv, `OCR_MODE: skip` für bereits durchsuchbare PDFs,
  Worker-Zahl auf den Pi 4 abgestimmt.
- **Samba-Freigabe `scans`** angelegt, zeigt auf den Consume-Ordner. macOS-Beiwerk
  (`._*`, `.DS_Store`) wird über `veto files` ausgesperrt.
- **Polling statt inotify** für den Einwurf-Ordner — verhindert, dass halb
  übertragene Dateien eingelesen werden.
- **Zugangsdaten bereinigt**: PostgreSQL-Passwort und Secret-Key zufällig erzeugt,
  in `.env` ausgelagert, über `.gitignore` ausgeschlossen. Das alte Passwort wurde
  per `ALTER USER` in der laufenden Datenbank ersetzt.
- Container-Abhängigkeiten über `condition: service_healthy` statt blossem
  `depends_on`; Healthchecks für Paperless und PostgreSQL ergänzt.

### Hinzugefügt zur Doku

- **[13 — Paperless-ngx](docs/13-paperless.md)** — Einwurfwege, Konfiguration mit
  Begründung, automatische Zuordnung, Einordnung von KI-Erweiterungen, Betrieb
  und Fehlersuche.

### Korrigiert

- **Sachfehler in `docs/05-docker.md`**: Die Behauptung, `postgres:15` könne
  unbeabsichtigt auf PostgreSQL 16 springen, war falsch — der Tag ist an die
  Major-Version gebunden. Auch in `docs/09` entsprechend richtiggestellt.

### Geprüft

- Vollständiger Durchlauf mit Testdokument: Erkennung nach 15 s, OCR korrekt,
  Ablage nach Schema, Einwurf-Ordner geleert, 62 s für eine Seite. Testdokument
  anschließend entfernt.

---

## [1.2.0] — 2026-08-13

### Geändert am System

- **Automatisiertes Backup eingerichtet**: restic über rclone nach OneDrive,
  täglich 03:17 Uhr per systemd-Timer, verschlüsselt und versioniert
  (7 Tage / 4 Wochen / 6 Monate).
- Paperless wird über `document_exporter` plus `pg_dump` gesichert, Pi-hole über
  `pihole-FTL --teleporter`, dazu `/etc/wireguard`, `/etc/samba`,
  `passdb.tdb`, SSH-Konfiguration und Paketlisten.
- Skript und Unit-Dateien liegen versioniert unter `docker-stacks/backup/`.
- `RESTIC_PACK_SIZE=32` und rclone-Drosselung (`TPSLIMIT`, erhöhte Wiederholungen)
  gegen die OneDrive-Antworten `resourceLocked` / HTTP 500 unter Last.

### Hinzugefügt zur Doku

- **[12 — Backup](docs/12-backup.md)** — Umfang, Ausschlüsse mit Begründung,
  Zeitplan, Wiederherstellung Schritt für Schritt, Überwachung, Grenzen der
  5-GB-Freeversion.

### Korrigiert

- **Paperless enthält 0 Dokumente.** Die erste Fassung nahm ein gefülltes
  Dokumentenarchiv an und stufte das Risiko entsprechend hoch ein. Die Messung
  ergab ein leeres Medienverzeichnis und 0 Datensätze in der Datenbank. Das
  Bichon-Archiv umfasst 45 E-Mails (689 MB). Betroffen: `docs/06`, `README.md`.

### Behoben

- Empfehlung 1.1 (automatisiertes Backup) abgeschlossen.
- `docs/11-disaster-recovery.md`: 6 von 7 Bausteinen gesichert statt 1 von 7.

### Neue Befunde

- **Schwache Standardpasswörter bei Paperless** — `PAPERLESS_ADMIN_PASSWORD`
  steht auf `***ENTFERNT-20260820***`, `POSTGRES_PASSWORD` auf ***ENTFERNT-20260820***, beides im
  Git-Repository. Aufgenommen in `docs/07-sicherheit.md`.
- **222 GB unter `SSD_Müll` sind ungesichert** — darunter 2.971 Bilddateien und
  ein vollständiges Windows-Benutzerprofil. Passt nicht in 5 GB.
- **86 GB unter `rclone_bak`** sind Sicherungskopien auf derselben Festplatte,
  die sie schützen sollen — keine wirksame Sicherung.

---

## [1.1.0] — 2026-08-13

### Geändert am System

- **Homepage als Dashboard installiert** (Port 3000), Stack unter
  `docker-stacks/homepage/`. Konfiguration als Volume eingebunden und im Git
  versioniert.
- **Socket-Proxy** (`tecnativa/docker-socket-proxy`) ergänzt: Homepage erhält
  Container-Status und Ressourcendaten über eine Allowlist statt über einen
  direkt eingebundenen Docker-Socket. Schreibende Anfragen werden mit `403`
  abgewiesen — verifiziert.
- SSD unter `/mnt/usb-hdd` schreibgeschützt in den Homepage-Container
  eingebunden, damit das Speicher-Widget die Belegung anzeigen kann.
- Dashy läuft unverändert weiter (Port 8080), zunächst zum Vergleich.

### Behoben

- **Dashy-Konfiguration nicht persistent** — der Nachfolger Homepage hat die
  Konfiguration als Volume. Siehe [05 — Docker](docs/05-docker.md).
- Empfehlung 3.1 (Dashboard) abgeschlossen.

### Aktualisiert

- `docs/03-netzwerk.md` — Port 3000 in der Portliste
- `docs/05-docker.md` — Containerzahl 7 → 9, Stacks 5 → 6, neue Einträge
- `docs/09-empfehlungen.md` — 3.1 als erledigt markiert
- `docs/10-zugriff.md` — Homepage in Übersicht und Zugriffsmatrix
- `README.md` — Dashboard-Link

### Offen

- Push zu GitHub steht aus: SSH-Schlüssel des Pi ist auf dem Konto nicht
  hinterlegt, und die OAuth-Freigabe des GitHub-Connectors umfasst keinen
  Repository-Zugriff (`403 Resource not accessible by integration`).

---

## [1.0.0] — 2026-08-13

Erste vollständige Bestandsaufnahme.

### Hinzugefügt

- Vollständige Dokumentation in elf Kapiteln
- `inventar/collect.sh` — rein lesendes Skript zur Bestandsaufnahme
- Skill `raspi-doku` zur automatisierten Pflege dieser Dokumentation

### Erfasster Systemzustand

| | |
|---|---|
| Hardware | Raspberry Pi 4 Model B Rev 1.1, 4 GB RAM |
| Betriebssystem | Debian 12 (bookworm), 64-bit, Kernel 6.12.96 |
| Uptime | 16 Tage |
| Container | 7 (Dashy, Paperless + DB + Redis, Filebrowser, Bichon, Portainer) |
| Systemdienste | Pi-hole v6.4.3, unbound, WireGuard, Samba, SSH |
| Speicher | SD 235 G (5 % belegt), SSD 916 G (36 % belegt) |

### Festgestellte Befunde

**Kritisch**

- Keine automatisierten Backups — letzter rclone-Lauf am 12.12.2025
- Wurzeldateisystem auf SD-Karte von 02/2023 bei hoher Schreiblast

**Wichtig**

- Keine Firewall auf dem Host (`iptables` policy ACCEPT, kein `ufw`)
- SSH-Passwortanmeldung aktiv, kein `fail2ban`
- Container-Images 8 bis 17 Monate ohne Update
- Öffentliche IPv6-Adresse ohne lokale Firewall als zweite Schicht
- `unattended-upgrades` nicht aktiv

**Aufräumen**

- Dashy-Konfiguration nicht persistent (Volume auskommentiert)
- `dhcpcd` und `NetworkManager` laufen parallel — stündliche Journal-Fehler
- Ungenutzte Dienste: `ModemManager`, `triggerhappy`, `wpa_supplicant`
- 1,18 GB verwaiste Docker-Images
- Pfad-Drift beim Paperless-Stack (Label verweist auf gelöschtes Verzeichnis)
- Verwaistes Verzeichnis `/mnt/usb-hdd/filebrowser.db/`
- Nicht committete Änderungen im `docker-stacks`-Repository
- `smartmontools` fehlt — keine SSD-Gesundheitsdaten verfügbar

---

## Vorlage für künftige Einträge

```markdown
## [X.Y.Z] — JJJJ-MM-TT

### Geändert am System
- Was am Pi tatsächlich verändert wurde

### Hinzugefügt zur Doku
- Neue Kapitel oder Abschnitte

### Aktualisiert
- Kapitel, deren Werte sich geändert haben

### Behoben
- Befunde, die erledigt sind (mit Verweis auf das Kapitel)
```

### Versionierung

| Stelle | Wann erhöhen |
|---|---|
| **Major** (X) | Grundlegender Umbau der Infrastruktur oder der Dokumentationsstruktur |
| **Minor** (Y) | Neuer Dienst, neues Kapitel, neuer Befund |
| **Patch** (Z) | Aktualisierte Messwerte, Korrekturen, erledigte Befunde |
