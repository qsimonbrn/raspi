# Raspberry Pi — Infrastruktur-Dokumentation

Vollständige Dokumentation des Heimservers `raspberrypi` (`192.168.178.80`).

> **Stand:** 16.08.2026 · **Erfasst durch:** automatisierte Bestandsaufnahme via SSH
> **Nächste Prüfung empfohlen:** bei jeder Änderung am Setup, mindestens quartalsweise

---

## Was ist das hier?

Ein Raspberry Pi 4B als Heimserver mit drei Rollen:

| Rolle | Umgesetzt durch |
|---|---|
| **Netzwerk-DNS & Werbeblocker** | Pi-hole + unbound (eigener rekursiver Resolver) |
| **Dokumentenarchiv** | Paperless-ngx mit OCR, PostgreSQL, Redis |
| **Dateiablage** | Samba auf einer 1-TB-SSD |

Dazu Tailscale für den Fernzugriff, Portainer zur Container-Verwaltung und Homepage als
Einstiegsseite. Acht Docker-Container in fünf Stacks, Compose-Dateien versioniert in
einem separaten Repository — seit dem 16.08.2026 durchgängig auf feste Image-Versionen
gepinnt.

---

## Navigation

| Kapitel | Inhalt |
|---|---|
| [01 — Hardware](docs/01-hardware.md) | Modell, CPU, RAM, Temperatur, Datenträger |
| [02 — Betriebssystem](docs/02-betriebssystem.md) | Debian-Version, Kernel, Updates, Timer |
| [03 — Netzwerk](docs/03-netzwerk.md) | IP-Adressen, IPv6, Routing, Docker-Bridges |
| [04 — Systemdienste](docs/04-dienste-system.md) | Pi-hole, unbound, Tailscale, Samba, SSH |
| [05 — Docker](docs/05-docker.md) | Container, Images, Volumes, Netze, Compose |
| [06 — Daten & Speicher](docs/06-daten-und-speicher.md) | SSD-Belegung, Verzeichnisse, Backup-Lage |
| [07 — Sicherheit](docs/07-sicherheit.md) | Firewall, SSH-Härtung, Angriffsfläche |
| [08 — Bewertung](docs/08-bewertung.md) | Was gut läuft, was fehlt |
| [09 — Empfehlungen](docs/09-empfehlungen.md) | Priorisierte Maßnahmen |
| [10 — Zugriff](docs/10-zugriff.md) | Alle URLs, Ports und Zugangswege |
| [11 — Notfallwiederherstellung](docs/11-disaster-recovery.md) | Wiederaufbau von Null |
| [12 — Backup](docs/12-backup.md) | Strategie, Umfang, Wiederherstellung, Grenzen |
| [13 — Paperless-ngx](docs/13-paperless.md) | Dokumentenarchiv: Einwurf, OCR, Zuordnung, KI-Optionen |
| [14 — Benachrichtigungen](docs/14-benachrichtigungen.md) | ntfy: Push aufs Handy, Anbindung ans Backup |
| [15 — Änderungshistorie](docs/15-aenderungshistorie.md) | Betriebstagebuch: was wann am System geändert wurde und warum |
| [16 — Konten und Rechte](docs/16-konten-und-rechte.md) | Wer darf was, Sitzungsaufzeichnung, Überwachungsbefehle, Notausschalter |

Änderungen an der Dokumentation: [CHANGELOG.md](CHANGELOG.md)

---

## Zustand auf einen Blick

| | |
|---|---|
| Uptime | 6 Minuten (Neustart am 18.08.2026 für den Speicher-Cgroup) |
| Load (1/5/15 min) | 0,47 / 0,22 / 0,15 bei 4 Kernen |
| Temperatur | 52,5 °C — nie gedrosselt (`throttled=0x0`) |
| RAM verfügbar | 2,4 von 3,7 GiB — Container zusammen rund 1,4 GiB (38 %) |
| Systemdatenträger | 4 % belegt (7,8 G von 235 G) — 5 GB durch Image-Aufräumen frei |
| Datenspeicher SSD | 36 % belegt (310 G von 916 G) |
| Ausstehende OS-Updates | 0 |
| Fehlgeschlagene Dienste | 0 |
| Container-Images | **alle auf feste Versionen oder Digests gepinnt** — vollständig seit 18.08.2026 |
| Container | **8**, alle mit Logrotation und `no-new-privileges` (18.08.2026) |
| Fernzugriff | **Tailscale**, nachweislich in Betrieb (18.08.2026) |
| Verwaltungsoberflächen | **nicht aus dem Heimnetz erreichbar** — nur über Tailscale (`pi-guard`, 18.08.2026) |
| Automatisierung | eigenes Konto `claude` mit vollständiger Sitzungsaufzeichnung (18.08.2026) |
| Speicher-Limits | seit dem 18.08.2026 technisch möglich (`cgroup_enable=memory`), Messung läuft, noch keine gesetzt |

**Dashboard:** [Homepage](http://192.168.178.80:3000) ist der Einstieg zu allen Diensten.

### Die drei wichtigsten offenen Punkte

1. **222 GB unter `SSD_Müll` sind ungesichert** — darunter 2.971 Bilddateien und ein
   vollständiges Windows-Benutzerprofil. In die 5 GB der OneDrive-Freeversion passt das
   nicht. → [Kapitel 12](docs/12-backup.md)
2. **Wurzeldateisystem liegt auf einer SD-Karte von 02/2023.** Ausfallrisiko nach
   3,5 Jahren Dauerbetrieb, während eine SSD zu 64 % leer danebenliegt. → [Kapitel 01](docs/01-hardware.md)
3. **SSH-Passwortanmeldung ist weiterhin möglich.** Am 18.08.2026 vorbereitet,
   erfolgreich getestet und auf Wunsch zurückgenommen — soll gemeinsam mit Vorlauf
   erfolgen. `AllowUsers` muss dabei **beide** Konten nennen (`simon claude`), sonst ist
   die Automatisierung ausgesperrt. → [Kapitel 07](docs/07-sicherheit.md)

Ebenfalls offen: **Speicher-Limits je Container** — seit dem Neustart am 18.08.2026
technisch möglich, eine 24-Stunden-Messung läuft. → [Kapitel 05](docs/05-docker.md)

Am 18.08.2026 erledigt: Verwaltungsoberflächen aus dem Heimnetz genommen, Filebrowser
(CVE ohne Patch) und Dashy abgeschaltet, Automatisierung auf ein eigenes, aufgezeichnetes
Konto umgestellt, `simon` aus der Gruppe `docker` entfernt, automatische
Sicherheitsupdates eingerichtet. Nachmittags dazu: Logrotation wirksam gemacht, alle
Images gepinnt, Bichon-Geheimnis aus dem Git-Verlauf entfernt, Backup-Lücken
geschlossen, Speicher-Cgroup aktiviert. → [Kapitel 15](docs/15-aenderungshistorie.md)

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
