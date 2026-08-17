# 12 — Backup

*Eingerichtet: 13.08.2026*

Vollständige Beschreibung der Sicherungsstrategie: was gesichert wird, was
bewusst nicht, wie wiederhergestellt wird — und wo die Lücken bleiben.

---

## 1. Ausgangslage

Vor dieser Einrichtung existierte **kein automatisiertes Backup**. `rclone` war mit
OneDrive und Dropbox konfiguriert, der letzte Lauf lag am **12.12.2025** — rund acht
Monate zurück. Kein Cronjob, kein Timer.

### Korrektur einer Annahme aus der ersten Bestandsaufnahme

Die erste Fassung dieser Dokumentation ging davon aus, dass in Paperless eingescannte
Papierunterlagen liegen, deren Originale möglicherweise entsorgt wurden — und stufte den
fehlenden Schutz entsprechend dramatisch ein.

Die Messung ergab etwas anderes:

| Erwartet | Tatsächlich |
|---|---|
| Gefülltes Dokumentenarchiv | **0 Dokumente** in der Datenbank, Medienverzeichnis leer |
| Umfangreiches E-Mail-Archiv | **45 E-Mails**, 689 MB (überwiegend Anhänge) |

Paperless ist eine leere, lauffähige Installation. Das entschärft die ursprüngliche
Einschätzung deutlich — der Schutz ist trotzdem sinnvoll, weil das Archiv wachsen soll
und ein Backup ab dem ersten Dokument greifen muss, nicht erst wenn jemand daran denkt.

---

## 2. Wie viel Platz steht zur Verfügung?

| Ziel | Kontingent | Belegt (Stand 13.08.2026) |
|---|---|---|
| **OneDrive (Free)** | 5 GiB | 0 B vor der Einrichtung |
| Dropbox (Free) | 2 GiB | 270 KiB |

5 GiB klingen wenig gegenüber 310 GB auf der SSD. Die entscheidende Frage ist aber nicht,
wie viel Daten vorhanden sind, sondern **wie viel davon unwiederbringlich** ist:

| Datenbestand | Größe | Wiederbeschaffbar? |
|---|---|---|
| Bichon E-Mail-Archiv | 689 MB | ❌ nein |
| Paperless (Export + Datenbank) | ~25 MB | ❌ nein |
| Systemkonfiguration (Tailscale, Samba, Pi-hole, SSH) | ~5 MB | ❌ nein — nur mit erheblichem Aufwand |
| Filebrowser-Datenbank | 44 KB | ❌ nein |
| Compose-Dateien und Doku | ~1 MB | ✅ liegt auch auf GitHub |
| Docker-Images | 3,8 GB | ✅ jederzeit neu ladbar |
| Pi-hole Query-Datenbank | 424 MB | ✅ reine Statistik |
| Pi-hole Blocklisten (`gravity.db`) | 29 MB | ✅ werden neu erzeugt |
| Trainingsbilder | 1,6 GB | ✅ reproduzierbar |

**Summe des Unersetzlichen: rund 720 MB.** Das passt bequem in 5 GiB — mit Reserve für
mehrere Monate Versionsstände, da restic dedupliziert und komprimiert.

Die Free-Version reicht also. Für den Teil, für den sie *nicht* reicht, siehe
[Abschnitt 8](#8-was-dieses-backup-nicht-abdeckt).

---

## 3. Technischer Aufbau

| Baustein | Wahl |
|---|---|
| Sicherungswerkzeug | **restic 0.14** (Debian-Paket) |
| Transport | **rclone** über das vorhandene OneDrive-Remote |
| Repository | `rclone:onedrive:Backups/raspberrypi-restic` |
| Repository-Format | Version 2 — mit Kompression |
| Auslöser | systemd-Timer, täglich 03:17 Uhr |
| Ausführung als | `root` (nötig für `/var/lib/tailscale`, `passdb.tdb`, Docker-Socket) |

### Warum restic und nicht `rclone sync`

Eine Spiegelung war der naheliegende Weg — die rclone-Konfiguration existierte ja
bereits. Drei Eigenschaften fehlen ihr aber:

- **Versionierung.** Eine Datei, die vor drei Wochen versehentlich überschrieben wurde,
  ist bei einer Spiegelung längst auch in der Cloud kaputt. Ein Ransomware-Verschlüsseler
  würde sauber mitsynchronisiert. restic legt Momentaufnahmen an; jeder alte Stand
  bleibt abrufbar.
- **Verschlüsselung.** Die Daten liegen bei einem Cloud-Anbieter. Mit restic sind sie
  bereits vor dem Upload verschlüsselt — Microsoft sieht nur Blöcke ohne Struktur.
- **Deduplizierung.** Bei täglichen Läufen über 700 MB überträgt restic nur die
  tatsächlich veränderten Blöcke. Der zweite Lauf ist typischerweise wenige Megabyte groß.

rclone wird dabei nicht ersetzt, sondern weiterverwendet: restic nutzt es als Transport
und damit auch die bestehende OneDrive-Anmeldung.

### Beteiligte Dateien

| Datei | Zweck |
|---|---|
| `/usr/local/bin/pi-backup.sh` | Das Backup-Skript |
| `/etc/systemd/system/pi-backup.service` | Dienstdefinition |
| `/etc/systemd/system/pi-backup.timer` | Zeitplan |
| `/etc/pi-backup.env` | Konfiguration (enthält **keine** Geheimnisse) |
| `/root/.restic-password` | Repository-Passwort, Modus 600 |
| `/mnt/usb-hdd/backup-stage` | Temporäre Ablage, wird nach jedem Lauf gelöscht |

Skript und Unit-Dateien liegen versioniert unter `docker-stacks/backup/` und werden von
dort nach `/usr/local/bin` bzw. `/etc/systemd/system` installiert. Die Kopien im System
sind also reproduzierbar.

---

## 4. Was gesichert wird

### Ablauf eines Laufs

**Schritt 1 — Paperless exportieren.** Nicht das Datenverzeichnis wird kopiert, sondern
`document_exporter` ausgeführt. Grund: Paperless speichert Tags, Korrespondenten,
Dokumenttypen und OCR-Text in PostgreSQL, nicht in den Dateien. Eine reine Dateikopie
ergäbe ein Archiv ohne jede Ordnungsstruktur. Zusätzlich wird ein `pg_dump` der
Datenbank abgelegt.

**Schritt 2 — Pi-hole exportieren.** Über `pihole-FTL --teleporter` entsteht ein Archiv
mit Einstellungen, lokalen DNS-Einträgen und den Quellen der Blocklisten — wenige hundert
Kilobyte statt 424 MB Query-Datenbank.

**Schritt 3 — Systemkonfiguration einsammeln:**

| Quelle | Warum |
|---|---|
| `/var/lib/tailscale/` | Node-Schlüssel. Verlust ist verkraftbar — eine Neuanmeldung stellt denselben Zustand her, ohne Client-Geräte anzufassen |
| `/etc/samba/` | Freigaben und Berechtigungen |
| `/var/lib/samba/private/passdb.tdb` | Samba-Passwort-Hashes |
| `/etc/ssh/sshd_config*` | SSH-Härtung |
| `/etc/fstab`, `/etc/hosts` | Einbindungen und Namensauflösung |
| `/etc/unbound/` | Resolver-Konfiguration |

**Schritt 4 — Systemzustand dokumentieren.** Paketlisten (`apt-mark showmanual`,
`dpkg -l`), Container- und Image-Übersicht, Datenträgerlayout, Netzwerkkonfiguration,
aktive Dienste. Das ist keine Datensicherung, sondern eine Bauanleitung für den
Wiederaufbau.

**Schritt 5 — restic-Lauf** über die Zwischenablage plus:

```
/mnt/usb-hdd/bichon              E-Mail-Archiv
/mnt/usb-hdd/paperless/export    Dokumentenexport
/mnt/usb-hdd/paperless/media     Originaldateien
/mnt/usb-hdd/filebrowser-data    Benutzer und Einstellungen
/home/simon/docker-stacks        Compose-Dateien
/home/simon/raspi-doku           diese Dokumentation
```

Ausgeschlossen: `*/tmp/*`, `*/logs/*`, `*.lock`, Cache-Verzeichnisse.

**Schritt 6 — Aufräumen.** Alte Stände werden nach den Regeln aus Abschnitt 5 entfernt
und der Speicher freigegeben (`--prune`).

---

## 5. Aufbewahrung

```
--keep-daily   7      die letzten 7 Tage
--keep-weekly  4      die letzten 4 Wochen
--keep-monthly 6      die letzten 6 Monate
```

Ein Fehler, der heute passiert, ist damit bis zu sechs Monate rückgängig zu machen. Die
Staffelung kostet kaum Platz, weil sich zwischen zwei Ständen nur wenige Blöcke ändern.

---

## 6. Zeitplan und Ausführung

| | |
|---|---|
| Zeitpunkt | täglich 03:17 Uhr |
| Streuung | bis zu 20 Minuten zufällig |
| Nachholen | ja (`Persistent=true`) — ein verpasster Lauf wird nach dem Einschalten nachgeholt |
| Priorität | `Nice=10`, I/O-Klasse `idle` — stört den laufenden Betrieb nicht |
| Zeitlimit | 4 Stunden, danach Abbruch |

03:17 statt 03:00 ist bewusst gewählt: Zur vollen Stunde laufen `apt-daily` und
`logrotate`.

Nur ein Lauf gleichzeitig — abgesichert über `flock`.

---

## 7. Wiederherstellung

> **Der wichtigste Abschnitt dieses Kapitels.** Ein Backup, aus dem noch nie etwas
> zurückgeholt wurde, ist eine Vermutung.

### Vorbereitung

```bash
set -a; . /etc/pi-backup.env; set +a
```

Danach stehen `RESTIC_REPOSITORY` und `RESTIC_PASSWORD_FILE` bereit, alle folgenden
Befehle laufen mit `sudo -E`.

### Verfügbare Stände ansehen

```bash
sudo -E restic snapshots
```

### Einzelne Datei zurückholen

```bash
# Suchen, in welchen Ständen die Datei vorkommt
sudo -E restic find "*smb.conf*"

# Aus einem bestimmten Stand in ein Zielverzeichnis holen
sudo -E restic restore <snapshot-id> \
     --include "*/etc/samba/smb.conf" --target /tmp/wiederherstellung
```

### Kompletten Stand zurückholen

```bash
sudo -E restic restore latest --target /tmp/wiederherstellung
```

Immer erst in ein **Zielverzeichnis** zurückholen, nie direkt über die produktiven Pfade.

### Paperless wiederherstellen

```bash
# 1. Export aus dem Backup holen
sudo -E restic restore latest --include "*/paperless/export/*" --target /tmp/wh

# 2. In das Importverzeichnis legen
sudo cp -a /tmp/wh/mnt/usb-hdd/paperless/export/* /mnt/usb-hdd/paperless/export/

# 3. In eine laufende (leere) Paperless-Instanz importieren
docker exec paperless document_importer /usr/src/paperless/export
```

Der Importer stellt Dokumente **und** Metadaten wieder her. Der `pg_dump` aus dem Backup
ist die Rückfallebene, falls der Import scheitert.

### Pi-hole wiederherstellen

Weboberfläche → *Settings → Teleporter → Restore*, dort die ZIP-Datei aus dem Backup
hochladen. Blocklisten anschließend mit `pihole -g` neu aufbauen.

### Tailscale wiederherstellen

```bash
sudo -E restic restore latest --include "*/var/lib/tailscale/*" --target /tmp/wh
sudo systemctl stop tailscaled
sudo cp -a /tmp/wh/.../var/lib/tailscale/* /var/lib/tailscale/
sudo systemctl start tailscaled

# Einfacher und meist ausreichend: gar nicht zurückspielen, sondern neu anmelden
sudo tailscale up --advertise-routes=192.168.178.0/24 --advertise-exit-node --accept-dns=false
```

Client-Geräte müssen in **keinem** der beiden Fälle neu eingerichtet werden. Das ist der
Unterschied zum früheren WireGuard-Aufbau: Dort hätte der Verlust der Serverschlüssel
bedeutet, jedes Endgerät von Hand neu zu konfigurieren.

### Vollständiger Neuaufbau

Reihenfolge siehe [11 — Notfallwiederherstellung](11-disaster-recovery.md). Der
Unterschied zu vorher: Die Punkte 2 bis 6 der dortigen Tabelle sind jetzt abgedeckt.

---

## 8. Was dieses Backup nicht abdeckt

Ehrlichkeit an dieser Stelle ist wichtiger als ein grünes Häkchen.

### 222 GB unter `/mnt/usb-hdd/SSD_Müll`

Der Verzeichnisname legt Wegwerfmaterial nahe. Der Inhalt sieht anders aus:

| Verzeichnis | Größe | Einschätzung |
|---|---|---|
| `pi_bak` | 136 GB | vermutlich altes System-Abbild |
| `Ralf und Manuela` | 38 GB | vollständiges Windows-Benutzerprofil |
| `BackupMacbook0320224` | 14 GB | Macbook-Sicherung von 2024 |
| `Pictures` | 13 GB | **2.971 Bilddateien** |
| `NAS_Backup_Sortiert` | 12 GB | NAS-Sicherung |

Besonders `Pictures` und `Ralf und Manuela` können unwiederbringliche Daten enthalten.
In 5 GiB passt davon nichts.

### 86 GB unter `/mnt/usb-hdd/rclone_bak`

Alte Sicherungskopien aus Dropbox und OneDrive — abgelegt auf **derselben Festplatte**,
die sie schützen sollen. Fällt die SSD aus, sind Original und Kopie gleichzeitig weg.
Das ist keine Sicherung, sondern eine Kopie.

### Empfehlung für diesen Teil

1. **Sichten und aussortieren.** Ein 136 GB großes Systemabbild von 2024 und eine
   Macbook-Sicherung von 2022 sind vermutlich verzichtbar. Danach bleibt eine deutlich
   kleinere, klarer umrissene Menge übrig.
2. **Externe USB-Festplatte** für den Rest. Einmalig rund 60 Euro, monatlich rechnet sich
   das gegen jeden Cloud-Tarif. Kann mit demselben restic-Repository-Format arbeiten.
3. **Nur wenn es außer Haus liegen soll:** OneDrive 100 GB (Microsoft 365 Basic) oder ein
   anderer Anbieter. Für 13 GB Fotos plus Konfigurationen genügt das.

Fotos gehören idealerweise an **zwei** Orte — die externe Platte allein schützt nicht
gegen Feuer oder Diebstahl.

---

## 9. Überwachung

Ein Backup, dessen Ausfall niemand bemerkt, ist keins.

```bash
# Läuft der Timer, und wann kommt der nächste Lauf?
systemctl list-timers pi-backup.timer

# Wie ist der letzte Lauf ausgegangen?
systemctl status pi-backup.service

# Protokoll des letzten Laufs
sudo journalctl -u pi-backup.service -n 50

# Vorhandene Stände und Belegung
sudo -E restic snapshots
sudo -E restic stats --mode raw-data
```

### Push-Benachrichtigung (seit 13.08.2026)

Jeder Lauf meldet sich per **ntfy** aufs Handy — siehe
[14 — Benachrichtigungen](14-benachrichtigungen.md):

| Fall | Priorität | Verhalten |
|---|---|---|
| Fehlgeschlagen | `urgent` | Ton und Vibration |
| Mit Warnungen | `high` | normale Benachrichtigung |
| Erfolgreich | `min` | stiller Eintrag im Verlauf |

Der Erfolgsfall wird absichtlich mitgemeldet, wenn auch lautlos: Bleibt die tägliche
Meldung aus — etwa weil der Timer gar nicht mehr läuft —, ist genau das die
Information. Bei „nur bei Fehlern melden" wäre dieser Fall unsichtbar.

Zusätzlich endet ein fehlgeschlagener Lauf mit Fehlerstatus und erscheint dauerhaft in
`systemctl --failed` — dieselbe Stelle, die `inventar/collect.sh` bei jeder
Bestandsaufnahme abfragt.

---

## 10. Das Repository-Passwort

> **Ohne dieses Passwort sind alle Sicherungen wertlos.** Es gibt keine Hintertür,
> keinen Zurücksetzen-Link und keinen Support, der helfen könnte. Das ist der Preis der
> Verschlüsselung.

Das Passwort wurde bei der Einrichtung zufällig erzeugt (32 Byte) und liegt unter
`/root/.restic-password` mit Modus 600.

**Es liegt damit ausschließlich auf dem Pi** — also auf genau dem Gerät, dessen Ausfall
das Backup abfangen soll. Diese Kopie muss an einen zweiten Ort:

```bash
sudo cat /root/.restic-password
```

Ausgabe in den Passwortmanager übernehmen, Eintrag z. B. „restic Raspberry Pi
Backup-Repository". Das ist kein optionaler Schritt.

### Prüffrage

*Der Pi ist weg. Kommst du an das Passwort?* Lautet die Antwort nein, ist das Backup
wirkungslos.

---

## 11. Zusammenfassung

| Frage | Antwort |
|---|---|
| Was ist geschützt? | E-Mail-Archiv, Paperless, alle Systemkonfigurationen, Compose-Dateien, Doku |
| Wovor? | Ausfall der SD-Karte oder SSD, versehentliches Löschen, misslungene Updates, Ransomware |
| Wovor nicht? | Verlust der 222 GB unter `SSD_Müll` — dafür fehlt der Speicherplatz |
| Wie oft? | täglich, 03:17 Uhr |
| Wie weit zurück? | 7 Tage, 4 Wochen, 6 Monate |
| Wo? | OneDrive, verschlüsselt vor dem Upload |
| Was ist zu tun? | Repository-Passwort in den Passwortmanager übertragen |
