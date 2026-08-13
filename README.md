# Raspberry Pi — Infrastruktur-Dokumentation

Vollständige Dokumentation des Heimservers `raspberrypi` (`192.168.178.80`).

> **Stand:** 13.08.2026 · **Erfasst durch:** automatisierte Bestandsaufnahme via SSH
> **Nächste Prüfung empfohlen:** bei jeder Änderung am Setup, mindestens quartalsweise

---

## Was ist das hier?

Ein Raspberry Pi 4B als Heimserver mit drei Rollen:

| Rolle | Umgesetzt durch |
|---|---|
| **Netzwerk-DNS & Werbeblocker** | Pi-hole + unbound (eigener rekursiver Resolver) |
| **Dokumentenarchiv** | Paperless-ngx mit OCR, PostgreSQL, Redis |
| **Dateiablage** | Samba + Filebrowser auf einer 1-TB-SSD |

Dazu WireGuard für den Fernzugriff, Portainer zur Container-Verwaltung und Dashy als
Einstiegsseite. Sieben Docker-Container, Compose-Dateien versioniert in einem
separaten Repository.

---

## Navigation

| Kapitel | Inhalt |
|---|---|
| [01 — Hardware](docs/01-hardware.md) | Modell, CPU, RAM, Temperatur, Datenträger |
| [02 — Betriebssystem](docs/02-betriebssystem.md) | Debian-Version, Kernel, Updates, Timer |
| [03 — Netzwerk](docs/03-netzwerk.md) | IP-Adressen, IPv6, Routing, Docker-Bridges |
| [04 — Systemdienste](docs/04-dienste-system.md) | Pi-hole, unbound, WireGuard, Samba, SSH |
| [05 — Docker](docs/05-docker.md) | Container, Images, Volumes, Netze, Compose |
| [06 — Daten & Speicher](docs/06-daten-und-speicher.md) | SSD-Belegung, Verzeichnisse, Backup-Lage |
| [07 — Sicherheit](docs/07-sicherheit.md) | Firewall, SSH-Härtung, Angriffsfläche |
| [08 — Bewertung](docs/08-bewertung.md) | Was gut läuft, was fehlt |
| [09 — Empfehlungen](docs/09-empfehlungen.md) | Priorisierte Maßnahmen |
| [10 — Zugriff](docs/10-zugriff.md) | Alle URLs, Ports und Zugangswege |
| [11 — Notfallwiederherstellung](docs/11-disaster-recovery.md) | Wiederaufbau von Null |
| [12 — Backup](docs/12-backup.md) | Strategie, Umfang, Wiederherstellung, Grenzen |
| [13 — Paperless-ngx](docs/13-paperless.md) | Dokumentenarchiv: Einwurf, OCR, Zuordnung, KI-Optionen |

Änderungen an der Dokumentation: [CHANGELOG.md](CHANGELOG.md)

---

## Zustand auf einen Blick

| | |
|---|---|
| Uptime | 16 Tage |
| Load (1/5/15 min) | 0,05 / 0,14 / 0,15 bei 4 Kernen |
| Temperatur | 47,7 °C — nie gedrosselt (`throttled=0x0`) |
| RAM verfügbar | 2,4 von 3,7 GiB |
| Systemdatenträger | 5 % belegt (8,9 G von 235 G) |
| Datenspeicher SSD | 36 % belegt (310 G von 916 G) |
| Ausstehende OS-Updates | 0 |
| Fehlgeschlagene Dienste | 0 |

**Dashboard:** [Homepage](http://192.168.178.80:3000) ist der Einstieg zu allen Diensten.

### Die drei wichtigsten offenen Punkte

1. **222 GB unter `SSD_Müll` sind ungesichert** — darunter 2.971 Bilddateien und ein
   vollständiges Windows-Benutzerprofil. In die 5 GB der OneDrive-Freeversion passt das
   nicht. → [Kapitel 12](docs/12-backup.md)
2. **Wurzeldateisystem liegt auf einer SD-Karte von 02/2023.** Ausfallrisiko nach
   3,5 Jahren Dauerbetrieb, während eine SSD zu 64 % leer danebenliegt. → [Kapitel 01](docs/01-hardware.md)
3. **Keine Firewall, SSH-Passwortlogin aktiv, schwache Standardpasswörter bei
   Paperless.** → [Kapitel 07](docs/07-sicherheit.md)

Das automatisierte Backup der unersetzlichen Daten läuft seit dem 13.08.2026 täglich.
→ [Kapitel 12](docs/12-backup.md)

---

## Bestandsaufnahme neu erzeugen

Das Skript unter [`inventar/collect.sh`](inventar/collect.sh) sammelt den kompletten
Ist-Zustand ein. Es ist **rein lesend** und verändert nichts am System.

```bash
bash inventar/collect.sh
```

Ergebnis landet unter `inventar/snapshots/`. Der Vergleich eines neuen Snapshots mit
der bestehenden Dokumentation ist die Grundlage jeder Aktualisierung.

---

## Aufbau dieses Repositories

```
raspi-doku/
├── README.md              Diese Seite — Einstieg und Überblick
├── CHANGELOG.md           Was wann an der Doku geändert wurde
├── docs/                  Die eigentliche Dokumentation, thematisch getrennt
├── inventar/
│   ├── collect.sh         Sammelskript (read-only)
│   └── snapshots/         Zeitstempel-Momentaufnahmen des Ist-Zustands
└── .claude/skills/        Skill zur automatisierten Pflege dieser Doku
```

---

## Konventionen

- **Jedes Kapitel ist eigenständig lesbar.** Querverweise statt Wiederholung.
- **Fakten mit Datum.** Werte wie Uptime oder Belegung stehen immer mit Erfassungsdatum,
  weil sie altern.
- **Bewertungen sind als solche gekennzeichnet.** Messwerte und Einschätzungen werden
  nicht vermischt.
- **Keine Geheimnisse im Repo.** Öffentliche Schlüssel ja, private Schlüssel, Passwörter
  und Tokens nie — auch nicht in Snapshots.
