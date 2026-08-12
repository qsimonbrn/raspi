# Änderungsverlauf der Dokumentation

Dieser Verlauf dokumentiert Änderungen an der **Dokumentation**, nicht am System selbst.
Systemänderungen werden in den jeweiligen Kapiteln vermerkt.

Format: [Keep a Changelog](https://keepachangelog.com/de/1.1.0/) ·
Datumsformat: JJJJ-MM-TT

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
