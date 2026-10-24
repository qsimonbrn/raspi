# Pi-hole — was hier liegt

Zwei Dinge, die Pi-hole sonst bei jedem Core-Update ueberschreibt.

| Datei | Installiert als | Zweck |
|---|---|---|
| `pi-gravity.sh` | `/usr/local/sbin/pi-gravity.sh` | Aktualisiert die Blocklisten, meldet Fehlschlaege und Einbrueche ueber ntfy |
| `pi-gravity.service` / `.timer` | `/etc/systemd/system/` | Taeglich 03:02 |
| `cron.d-pihole` | `/etc/cron.d/pihole` | Pi-holes eigener Cronjob, `updateGravity`-Zeile auskommentiert |

## Warum ein eigener Timer

Der Zeitplan fuer `updateGravity` stand bis zum 20.08.2026 in `/etc/cron.d/pihole`
und lief woechentlich sonntags. Auf taeglich umgestellt haette die Aenderung nur bis
zum naechsten `pihole -up` gehalten: Diese Datei gehoert Pi-hole und wird bei einem
Core-Update neu geschrieben. Der Rueckfall waere **still** erfolgt — die Blocklisten
waeren wieder eine Woche alt geworden, ohne dass etwas gemeldet haette.

`/etc/systemd/system/` fasst Pi-hole nicht an. Deshalb liegt der Zeitplan dort, und
die Zeile im Cronjob ist auskommentiert.

## Zwei Sicherungen gegen den stillen Rueckfall

**1. Der Abgleich meldet es.** `/etc/cron.d/pihole` steht im `manifest.tsv` des
Abgleichs, seit 25.10.2026 mit der Sonderregel `ohne-aktiv:updateGravity`: Gemeldet
wird nur, wenn eine **aktive** `updateGravity`-Zeile in der Datei steht. Bis dahin
wurde exakt verglichen -- und weil Pi-hole bei jedem Update auch die Uhrzeit des
`updatechecker` neu wuerfelt, schlug der Abgleich vom 02. bis 24.10.2026 taeglich an,
samt Notruf ueber ntfy.sh. Ein Alarm, der drei Wochen lang jeden Tag kommt, liest
niemand mehr. Wenn er jetzt kommt, dann:

```bash
sudo pi-abgleich.sh diff cron.d-pihole        # zeigt die aktive Zeile
sudo sed -i -E 's|^([^#].*updateGravity.*)$|#\1|' /etc/cron.d/pihole   # auskommentieren
sudo cp /etc/cron.d/pihole /home/simon/raspi/system/pihole/cron.d-pihole  # Stand festhalten
```

`install` ist fuer dieses Paar bewusst gesperrt: Es wuerde Pi-holes neue Fassung mit
einer alten ueberschreiben.

Ein doppelter Lauf waere uebrigens harmlos: Kaeme die Cron-Zeile zurueck, liefe
`updateGravity` sonntags zweimal. Das kostet 15 Sekunden, nichts weiter. Gefaehrlich
ist nur der umgekehrte Fall — dass **gar nichts** mehr taeglich laeuft.

**2. Das Skript meldet, wenn die Listen schrumpfen.** Faellt die Zahl der Eintraege
gegenueber dem Vortag um mehr als ein Viertel, kommt eine ntfy-Meldung. Das ist der
uebliche Verlauf, wenn eine Quelle nicht mehr erreichbar ist oder ihr Format aendert:
`pihole -g` laeuft mit Exit 0 durch, und die Sperren fallen leise weg.

## Pruefen

```bash
systemctl list-timers pi-gravity.timer     # wann lief er, wann laeuft er wieder
sudo systemctl start pi-gravity.service    # von Hand ausloesen
journalctl -t pi-gravity -n 5              # Ergebnis der letzten Laeufe
```
