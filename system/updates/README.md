# Automatische Sicherheitsupdates und Neustart-Meldung

Eingerichtet am 18.08.2026.

| Datei | Installiert unter | Zweck |
|---|---|---|
| `52unattended-upgrades-lokal` | `/etc/apt/apt.conf.d/` | Nur Sicherheitsquellen, **kein** selbsttätiger Neustart |
| `pi-reboot-check.sh` | `/usr/local/sbin/` | Meldet über ntfy, wenn ein Neustart fällig ist |
| `pi-reboot-check.service` | `/etc/systemd/system/` | Aufruf des Skripts |
| `pi-reboot-check.timer` | `/etc/systemd/system/` | Täglich 08:30, mit Streuung |
| `docker-daemon.json` | `/etc/docker/daemon.json` | Log-Rotation 10 MB × 3, `live-restore` |

## Warum kein automatischer Neustart

An diesem Gerät hängt der DNS des gesamten Haushalts. Ein unbemerkt fehlgeschlagener
Neustart um drei Uhr nachts bedeutet, dass morgens im ganzen Haus nichts mehr geht.
Stattdessen meldet sich der Pi mit den betroffenen Paketen und wartet auf eine
Entscheidung — höchstens einmal pro Tag, damit die Erinnerung nicht zur Tapete wird.

## ⚠️ Installierte Fassung und Repository auseinanderhalten

Die Dateien hier sind **Kopien**. Der Dienst führt die Fassung unter `/usr/local/`
bzw. `/etc/` aus. Eine Änderung nur im Repository wird **nicht wirksam**.

Genau das passierte am 18.08.2026 mit `backup/pi-backup.sh`: Die Umstellung von
`/etc/wireguard` auf `/var/lib/tailscale` wurde nur versioniert, nicht installiert. Das
nächste Backup hätte den Tailscale-Zustand nicht gesichert und über ein Verzeichnis
gewarnt, das es nicht mehr gibt.

Nach jeder Änderung also beides tun:

```bash
sudo install -o root -g root -m 750 backup/pi-backup.sh /usr/local/bin/pi-backup.sh
sudo diff -q /usr/local/bin/pi-backup.sh backup/pi-backup.sh   # muss still bleiben
```
