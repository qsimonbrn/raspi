#!/bin/bash
# Meldet ueber ntfy, wenn nach automatischen Updates ein Neustart faellig ist.
#
# Hintergrund: unattended-upgrades spielt Sicherheitsupdates ein, startet den Pi
# aber bewusst nie selbst neu (Automatic-Reboot "false"). An diesem Geraet haengt
# der DNS des gesamten Haushalts. Ein fehlgeschlagener Neustart um drei Uhr
# nachts faellt sonst erst auf, wenn morgens im ganzen Haus nichts mehr geht.
#
# Statt automatisch neu zu starten, meldet sich der Pi und wartet auf eine
# Entscheidung.

set -u
[ -r /etc/pi-backup.env ] && . /etc/pi-backup.env

# Kein Neustart faellig -> nichts zu tun.
[ -f /var/run/reboot-required ] || exit 0

# Hoechstens eine Meldung pro Tag, damit die Erinnerung nicht zur Tapete wird.
MARKE="/var/lib/pi-reboot-check.gemeldet"
HEUTE="$(date +%F)"
[ "$(cat "$MARKE" 2>/dev/null)" = "$HEUTE" ] && exit 0

PAKETE="$(tr '\n' ' ' < /var/run/reboot-required.pkgs 2>/dev/null | sed 's/ $//')"
[ -n "$PAKETE" ] || PAKETE="(keine Paketliste vorhanden)"
LAUFZEIT="$(uptime -p)"

TEXT="Automatische Sicherheitsupdates wurden eingespielt. Ein Neustart ist faellig.

Betroffene Pakete: ${PAKETE}
Laufzeit bisher: ${LAUFZEIT}

Neustart von Hand:  sudo reboot
Waehrend des Neustarts faellt der DNS fuers ganze Haus kurz aus."

if [ -n "${NTFY_URL:-}" ] && [ -r "${NTFY_TOKEN_FILE:-/nonexistent}" ]; then
  curl -s -m 20 -o /dev/null \
    -H "Authorization: Bearer $(cat "$NTFY_TOKEN_FILE")" \
    -H "Title: Raspberry Pi: Neustart faellig" \
    -H "Priority: default" \
    -H "Tags: arrows_counterclockwise,package" \
    -d "$TEXT" \
    "$NTFY_URL/${NTFY_TOPIC:-raspberrypi}" && echo "$HEUTE" > "$MARKE"
else
  logger -t pi-reboot-check "Neustart faellig, aber ntfy ist nicht konfiguriert"
fi
