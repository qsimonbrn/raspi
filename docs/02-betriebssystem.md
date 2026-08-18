# 02 — Betriebssystem

*Erfasst: 18.08.2026*

## Basisdaten

| Merkmal | Wert |
|---|---|
| Distribution | Debian GNU/Linux 12 (bookworm) |
| Architektur | 64-bit (`aarch64`) |
| Kernel | `6.12.96+rpt-rpi-v8` |
| Hostname | `raspberrypi` |
| Zeitzone | Europe/Berlin (CEST) |
| Zeitsynchronisation | `systemd-timesyncd` |
| Uptime | 16 Tage |

Bemerkenswert: Es läuft ein **64-bit-System**. Viele ältere Pi-Installationen sind noch
32-bit, was Docker-Images einschränkt und den RAM-Zugriff pro Prozess begrenzt. Hier ist
das richtig aufgesetzt.

Der Kernel `6.12.x` ist der aktuelle Raspberry-Pi-Foundation-Zweig für Bookworm.

## Paketstand

| | |
|---|---|
| Ausstehende Updates | **0** |
| Fehlgeschlagene systemd-Dienste | **0** |

Das ist ein gutes Zeichen: Das System wird offensichtlich regelmäßig und manuell gepflegt.

## ✅ Automatische Sicherheitsupdates — seit 18.08.2026

Bis dahin hing jedes Sicherheitsupdate davon ab, dass sich jemand einloggt und
`apt upgrade` ausführt. Das funktionierte zuverlässig, war aber ein Prozess ohne
Rückfallebene: zwei Wochen Urlaub, und ein kritischer OpenSSH- oder Samba-Patch bleibt
liegen.

| | |
|---|---|
| Paket | `unattended-upgrades` 2.9.1 |
| Umfang | ausschließlich Sicherheitsquellen — keine Funktionsänderungen |
| Konfiguration | `/etc/apt/apt.conf.d/52unattended-upgrades-lokal` |
| Aktivierung | `/etc/apt/apt.conf.d/20auto-upgrades` |
| Selbsttätiger Neustart | **nein** |
| Meldung bei fälligem Neustart | über ntfy, täglich 08:30 (`pi-reboot-check.timer`) |

**Warum kein automatischer Neustart:** An diesem Gerät hängt der DNS des gesamten
Haushalts, und Paperless-Importe laufen unbeaufsichtigt. Ein unbemerkt fehlgeschlagener
Neustart um drei Uhr nachts bedeutet, dass morgens im ganzen Haus nichts mehr geht.
Stattdessen meldet sich der Pi mit den betroffenen Paketen und wartet auf eine
Entscheidung — höchstens einmal pro Tag, damit die Erinnerung nicht zur Tapete wird.

Details in [07 — Sicherheit](07-sicherheit.md).

## Aktive systemd-Timer

| Timer | Nächster Lauf | Zweck |
|---|---|---|
| `man-db.timer` | täglich | Handbuch-Index |
| `apt-daily.timer` | täglich | Paketlisten aktualisieren |
| `apt-daily-upgrade.timer` | täglich | installiert Sicherheitsupdates (seit 18.08.2026) |
| `dpkg-db-backup.timer` | täglich | Paketdatenbank sichern |
| `logrotate.timer` | täglich | Logrotation |
| `systemd-tmpfiles-clean.timer` | täglich | Temporäre Dateien aufräumen |
| `e2scrub_all.timer` | wöchentlich | ext4-Metadatenprüfung |
| `fstrim.timer` | wöchentlich | TRIM für SSD |
| `pi-reboot-check.timer` | täglich 08:30 | meldet über ntfy, wenn ein Neustart fällig ist |
| `pi-backup.timer` | täglich 03:17 | restic-Backup nach OneDrive |

`fstrim.timer` ist aktiv — das ist für die SSD wichtig und richtig so.

**Früherer Befund, inzwischen erledigt:** `apt-daily-upgrade.timer` lief zwar, fand aber
kein Programm, das etwas hätte installieren können — er lud Pakete nur herunter. Das wird
leicht mit „automatischen Updates" verwechselt. Seit dem 18.08.2026 ist
`unattended-upgrades` installiert, und der Timer tut, was sein Name verspricht.

## Cron

| Quelle | Inhalt |
|---|---|
| `crontab -l` (simon) | leer |
| `sudo crontab -l` (root) | leer |
| `/etc/cron.d/` | `e2scrub_all`, `pihole`, `sysstat` |

Alle drei Einträge in `/etc/cron.d/` stammen aus Paketinstallationen, keiner ist
selbst angelegt.

**Konsequenz:** Es existiert **kein einziger selbst eingerichteter geplanter Job** — also
insbesondere kein Backup-Job. Siehe [06 — Daten & Speicher](06-daten-und-speicher.md).

## Laufende Systemdienste

```
avahi-daemon      mDNS/Bonjour — macht "raspberrypi.local" auflösbar
containerd        Container-Runtime unter Docker
cron              Zeitgesteuerte Jobs
dbus              Systemweite Interprozesskommunikation
dhcpcd            DHCP-Client
docker            Container-Verwaltung
getty@tty1        Lokale Konsole
ModemManager      Mobilfunk-Modem-Verwaltung
NetworkManager    Netzwerkkonfiguration
nmbd              NetBIOS-Namensdienst (Samba)
pihole-FTL        Pi-hole DNS-Engine
polkit            Rechteverwaltung
smbd              Samba-Dateifreigabe
ssh               SSH-Server
systemd-journald  Logging
systemd-logind    Sitzungsverwaltung
systemd-timesyncd Zeitsynchronisation
systemd-udevd     Geräteverwaltung
triggerhappy      Tastatur-Hotkey-Daemon
unbound           Rekursiver DNS-Resolver
user@1000         Benutzersitzung simon
wpa_supplicant    WLAN-Authentifizierung
```

## ⚠️ Befund: Zwei konkurrierende Netzwerk-Manager

Sowohl **`dhcpcd`** als auch **`NetworkManager`** laufen und wollen beide `eth0`
verwalten. Das erzeugt im Journal stündlich:

```
dhcpcd[483]: eth0: invalid prefix in RA
```

Diese Meldung erscheint bei jedem Router-Advertisement der FRITZ!Box, also etwa 15-mal
pro Tag. Funktional passiert nichts Schlimmes — die Netzwerkverbindung steht seit 16
Tagen stabil. Aber:

- Das Journal wird mit Fehlern gefüllt, die keine sind. Echte Probleme gehen darin unter.
- Zwei Netzwerk-Manager auf einer Schnittstelle sind eine klassische Quelle für Fehler,
  die erst nach einem Neustart auftreten und dann schwer zu diagnostizieren sind.

**Empfehlung:** Einen von beiden deaktivieren. Auf Bookworm ist `NetworkManager` der
Standard — `dhcpcd` kann in der Regel abgeschaltet werden. Vorsicht: Das sollte nur mit
gesichertem Zugang geschehen (lokale Tastatur oder zweiter Zugangsweg), da ein Fehler die
Netzwerkverbindung kappt.

## ⚠️ Befund: Ungenutzte Dienste

| Dienst | Warum überflüssig |
|---|---|
| `ModemManager` | Kein Mobilfunk-Modem am System |
| `triggerhappy` | Reagiert auf Tastatur-Events — der Pi läuft headless |
| `wpa_supplicant` | `wlan0` ist DOWN, es wird ausschließlich Ethernet genutzt |

Der Ressourcenverbrauch ist gering, aber jeder laufende Dienst ist Angriffsfläche und
potenzieller Fehlerherd. Abschalten kostet drei Befehle.
