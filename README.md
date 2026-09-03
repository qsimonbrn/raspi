# Raspberry Pi — Infrastruktur-Dokumentation

Vollständige Dokumentation des Heimservers `raspberrypi` (`192.168.178.80`).

> **Stand:** 04.09.2026 · **Erfasst durch:** automatisierte Bestandsaufnahme via SSH
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
Einstiegsseite. Acht Docker-Container in fünf Stacks; die Compose-Dateien liegen seit dem
18.08.2026 in **diesem** Repository unter `stacks/` und laufen direkt von dort — seit dem
16.08.2026 durchgängig auf feste Image-Versionen gepinnt.

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
| [17 — Wo was liegt](docs/17-wo-was-liegt.md) | Welche Datei ist Original, welche Kopie — Repositories, installierte Fassungen, Rechte |
| [18 — Vaultwarden](docs/18-vaultwarden.md) | Passwort-Tresor: Aufbau, Absicherung, Sicherung der Tresor-Datenbank, Wiederherstellung |

Änderungen an der Dokumentation: [CHANGELOG.md](CHANGELOG.md)

---

## Zustand auf einen Blick

| | |
|---|---|
| Uptime | 1 Woche, 4 Tage (04.09.2026) |
| Load (1/5/15 min) | 0,65 / 0,32 / 0,22 bei 4 Kernen |
| Temperatur | 47,2 °C — nie gedrosselt (`throttled=0x0`) |
| RAM verfügbar | 2,0 von 3,7 GiB (04.09.2026) |
| Systemdatenträger | 4 % belegt (8,5 G von 235 G) |
| Datenspeicher SSD | 36 % belegt (311 G von 916 G) |
| Ausstehende OS-Updates | **2** (04.09.2026) — `tailscale` wird von `unattended-upgrades` nie erfasst (Fremd-Repository), zuletzt am 20.08.2026 von Hand auf 1.102.3 gezogen |
| Fehlgeschlagene Dienste | 0 |
| Backup | täglich, 21 Snapshots (04.09.2026); zuletzt am 23.08.2026 als **wiederherstellbar nachgewiesen** (Tresor-Datenbank zurückgeholt und gelesen) |
| Container-Images | **alle auf feste Versionen oder Digests gepinnt** — vollständig seit 18.08.2026 |
| Container | **12**, alle mit Logrotation und `no-new-privileges` (04.09.2026) |
| Fernzugriff | **Tailscale**, nachweislich in Betrieb (18.08.2026) |
| Verwaltungsoberflächen | **nicht aus dem Heimnetz erreichbar** — nur über Tailscale (`pi-guard`, 18.08.2026) |
| Automatisierung | eigenes Konto `claude` mit vollständiger Sitzungsaufzeichnung (18.08.2026) |
| Speicher-Limits | **seit 20.08.2026 gesetzt** für alle neun Container, Summe 3.360 von 3.796 MiB — nicht überbucht |
| Passwort-Tresor | **Vaultwarden 1.37.2** seit 23.08.2026, nur über Tailscale auf Port 8443 ([18](docs/18-vaultwarden.md)) |
| Benachrichtigungen | **ntfy stellt seit 25.08.2026 nachweislich aufs iPhone zu** — Alarmkette erstmals geschlossen ([14](docs/14-benachrichtigungen.md)) |
| Update-Meldungen | **Diun 4.33.0** seit 25.08.2026, täglich 06:15, überwacht 11 Images ([05](docs/05-docker.md)) |

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

Am 25.08.2026 erledigt: **Die Alarmkette trägt.** ntfy stellt nachweislich aufs
gesperrte iPhone zu; ein fehlgeschlagenes Backup erreicht seitdem jemanden.
→ [Kapitel 14](docs/14-benachrichtigungen.md) · Darauf aufbauend **Diun**: meldet
täglich neue Image-Versionen, aktualisiert nichts.
→ [Kapitel 05](docs/05-docker.md)

Am 23.08.2026 erledigt: **Passwort-Tresor Vaultwarden** aufgesetzt, ausschließlich über
Tailscale erreichbar, mit konsistenter Sicherung der Tresor-Datenbank.
→ [Kapitel 18](docs/18-vaultwarden.md)

Am 20.08.2026 erledigt: **Speicher-Limits je Container** stehen für alle acht, auf
Grundlage einer Messung über zwei Tage und bewusst großzügig — sie sollen einen
ausgerissenen Dienst abfangen, nicht den normalen Betrieb begrenzen.
→ [Kapitel 05](docs/05-docker.md)

Am 18.08.2026 erledigt: Verwaltungsoberflächen aus dem Heimnetz genommen, Filebrowser
(CVE ohne Patch) und Dashy abgeschaltet, Automatisierung auf ein eigenes, aufgezeichnetes
Konto umgestellt, `simon` aus der Gruppe `docker` entfernt, automatische
Sicherheitsupdates eingerichtet. Nachmittags dazu: Logrotation wirksam gemacht, alle
Images gepinnt, Bichon-Geheimnis aus dem Git-Verlauf entfernt, Backup-Lücken
geschlossen, Speicher-Cgroup aktiviert. → [Kapitel 15](docs/15-aenderungshistorie.md)

Das automatisierte Backup der unersetzlichen Daten läuft seit dem 13.08.2026 täglich.
Am 20.08.2026 wurde es erstmals **als wiederherstellbar nachgewiesen**: `restic check`
über alle 10 Snapshots ohne Fehler, Stichprobe zurückgeholt und byte-identisch. Bis dahin
war nur bekannt, dass gesichert wird — nicht, dass es sich zurückholen lässt.
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

Konfiguration und Dokumentation lagen bis zum 18.08.2026 in zwei getrennten
Repositories. Seither hier zusammen, damit eine Systemänderung und ihre
Dokumentation in **einem** Commit liegen und nicht auseinanderlaufen können.

```
raspi/
├── README.md              Diese Seite — Einstieg und Überblick
├── CHANGELOG.md           Was wann an der Dokumentation geändert wurde
├── docs/                  Die Kapitel, thematisch getrennt
├── inventar/
│   ├── collect.sh         Sammelskript (nur lesend)
│   └── snapshots/         Momentaufnahmen des Ist-Zustands mit Zeitstempel
├── stacks/                Compose-Dateien je Dienst — laufen DIREKT von hier
│   ├── bichon/  homepage/  ntfy/  paperless/  portainer/
│   └── _archiviert/       abgeschaltete Dienste, Konfiguration bleibt nachvollziehbar
└── system/                Systemkonfiguration — läuft NICHT von hier, siehe docs/17
    ├── abgleich/          prüft täglich, ob Repository und System übereinstimmen
    ├── backup/            restic nach OneDrive
    ├── firewall/          pi-guard
    ├── messung/           befristete Speichermessung
    ├── sudoers/           Regeln für das Konto claude
    ├── updates/           unattended-upgrades, daemon.json, cmdline.txt
    └── wartung/           Wartungslauf und Aliase
```

> **Der Unterschied zwischen `stacks/` und `system/` ist wichtig.** Was unter
> `stacks/` liegt, wird direkt von hier gelesen — eine Änderung wirkt sofort. Was
> unter `system/` liegt, ist nur eine **Kopie**; die laufende Fassung steht in `/etc`,
> `/usr/local/bin`, `/usr/local/sbin` oder `/boot`. Eine Änderung nur hier ist dort
> wirkungslos. `sudo pi-abgleich.sh check` prüft das, täglich automatisch.

---

## Konventionen

- **Jedes Kapitel ist eigenständig lesbar.** Querverweise statt Wiederholung.
- **Fakten mit Datum.** Werte wie Uptime oder Belegung stehen immer mit Erfassungsdatum,
  weil sie altern.
- **Bewertungen sind als solche gekennzeichnet.** Messwerte und Einschätzungen werden
  nicht vermischt.
- **Keine Geheimnisse im Repo.** Öffentliche Schlüssel ja, private Schlüssel, Passwörter
  und Tokens nie — auch nicht in Snapshots.
