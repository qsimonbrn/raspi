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

## Wartung von Hand: `wartung`

Neben den Timern gibt es einen Wartungslauf, den du selbst anstößt:

```bash
wartung                                    # Alias fuer sudo /usr/local/sbin/pi-wartung.sh
sudo PIHOLE_UPDATE=1 DOCKER_PRUNE=1 /usr/local/sbin/pi-wartung.sh
```

Das Skript stammt aus dem Dezember 2025 und wurde am 18.08.2026 überarbeitet.
Es läuft in acht Abschnitten und braucht rund 20 Sekunden, wenn nichts zu tun ist:

| # | Abschnitt | Was passiert |
|---|---|---|
| 1 | Zustand | Laufzeit, Temperatur, Drosselung, Belegung, freier Speicher |
| 2 | Systemupdate | `apt full-upgrade`, listet vorher die betroffenen Pakete auf |
| 3 | Pi-hole | Blocklisten immer; **Versionssprung nur mit `PIHOLE_UPDATE=1`** |
| 4 | Docker | Nur schauen: laufende Container, ungesunde, Belegung, **Kontrolle auf ungedrehte Logdateien über 12 MB** |
| 5 | Abgleich | ruft `pi-abgleich.sh check`, siehe [17](17-wo-was-liegt.md) |
| 6 | Backup | wie lange der letzte Lauf zurückliegt, ob der Timer aktiv ist |
| 7 | Aufräumen | Journal auf 7 Tage kürzen; **Docker nur mit `DOCKER_PRUNE=1`** |
| 8 | Neustart | meldet, ob einer fällig ist — startet nicht |

**Was es bewusst nicht tut:** Container aktualisieren und neu starten. Alle Images sind
gepinnt; ein Update ist eine Entscheidung mit vorherigem Backup und läuft über den Skill
`docker-updates`. Und am Pi hängt der DNS des ganzen Haushalts.

Warnungen und Hinweise sind getrennt: Ein Hinweis („Docker nicht aufgeräumt") ist eine
Information, eine Warnung („Drosselung aufgetreten") ein Befund. Der Exitcode ist nur bei
mindestens einer Warnung ungleich 0.

### Was dabei am 18.08.2026 herauskam

Der Vorgänger `pi-maintenance.sh` hatte vier Defekte, gegen die der bekannte
`sudo`-Unterschied harmlos war:

| Befund | Folge |
|---|---|
| Abschnitt „Compose-Stacks aktualisieren" lief über `/opt/stacks/*` | Dieses Verzeichnis gab es auf dem Pi **nie** — es ist der Standardpfad von Dockge, einem hier nie eingesetzten Compose-Verwalter. Der Abschnitt tat seit jeher nichts, sah aber so aus, als täte er etwas |
| Letzte Zeile `[ -f /var/run/reboot-required ] && echo …` | Unter `set -e` endete das Skript **immer** mit Exit 1, wenn kein Neustart fällig war. Dieselbe Falle wie beim Backup am selben Tag |
| `apt full-upgrade -y` und `pihole -up` bedingungslos | Hebelt die Entscheidung aus, dass `unattended-upgrades` bewusst nur Sicherheitsquellen einspielt |
| Ausgabe | zu neun Zehnteln debconf-Klagen über das fehlende Terminal und `Reading database … 95%` |

**Aliase.** `wartung`, `abgleich`, `temp`, `throttled` und `bootcheck` standen von Hand
in `/etc/bash.bashrc` und waren damit unversioniert und beim Wiederaufbau nicht
auffindbar. Sie liegen jetzt in `system/wartung/pi-aliase.sh`, installiert nach
`/etc/profile.d/pi-aliase.sh`. Weil `/etc/profile.d` **nur von Login-Shells** gelesen
wird, lädt `/etc/bash.bashrc` dieselbe Datei zusätzlich nach — sonst fehlten die Aliase
in interaktiven Nicht-Login-Shells. Nachgemessen in beiden Shell-Arten und für beide
Konten.

---

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
