#!/bin/bash
# =============================================================================
#  pi-probealarm.sh -- bewusster Probealarm auf allen drei Meldewegen
#
#  Warum es das gibt: Vom 11. bis 18.09.2026 kam auf dem iPhone keine einzige
#  Meldung an, weil Tailscale dort nicht lief. Der Server nahm weiter an, das
#  Backup meldete weiter Erfolg -- nur las es niemand. Die stille
#  Erfolgsmeldung des Backups ist als Lebenszeichen gedacht, aber ihr Fehlen
#  faellt nicht auf, wenn man nicht taeglich nachsieht.
#
#  Dieses Skript kann die Zustellung NICHT pruefen -- das kann kein Skript, die
#  Anzeige auf dem Geraet sieht nur ein Mensch. Es sorgt nur dafuer, dass ein
#  Ausfall sichtbar wird: Jede Meldung traegt eine fortlaufende Nummer. Fehlt
#  eine Nummer oder ist die letzte aelter als ein paar Tage, stimmt etwas
#  nicht.
#
#  Drei Wege, weil sie unabhaengig voneinander ausfallen:
#    1. eigener Server, Thema raspberrypi  -- braucht Tailscale auf dem Handy
#    2. eigener Server, Thema workbench    -- dito, eigenes Abo
#    3. ntfy.sh (Notruf)                   -- braucht KEIN Tailscale
#  Weg 3 ist der, der im September 2026 als einziger durchkam.
#
#  Dokumentation: docs/14-benachrichtigungen.md
# =============================================================================
set -u

CONFIG=/etc/pi-backup.env
[ -r "$CONFIG" ] || { logger -t pi-probealarm "FEHLER: $CONFIG nicht lesbar"; exit 1; }
set -a; . "$CONFIG"; set +a

ZAEHLERDATEI=/var/lib/pi-probealarm.zaehler
NR=$(( $(cat "$ZAEHLERDATEI" 2>/dev/null || echo 0) + 1 ))
echo "$NR" > "$ZAEHLERDATEI"

DATUM="$(date '+%d.%m.%Y %H:%M')"
TEXT="Probealarm Nr. $NR vom $DATUM. Keine Aktion noetig.
Fehlt eine Nummer oder ist die letzte aelter als vier Tage, kommt nichts mehr an."

FEHLER=0
sende() {  # $1 = Beschreibung, $2... = curl-Argumente
  local was="$1"; shift
  local code
  code="$(curl -s -o /dev/null -w '%{http_code}' -m 20 "$@" || echo 000)"
  if [ "$code" = "200" ]; then
    logger -t pi-probealarm "$was: ok (200)"
  else
    logger -t pi-probealarm "$was: FEHLGESCHLAGEN (HTTP $code)"
    FEHLER=$((FEHLER + 1))
  fi
}

# --- Weg 1 und 2: eigener Server ---------------------------------------------
if [ -n "${NTFY_URL:-}" ] && [ -r "${NTFY_CURL_CONF:-/nonexistent}" ]; then
  for THEMA in "${NTFY_TOPIC:-raspberrypi}" workbench; do
    sende "eigener Server/$THEMA" \
      --config "$NTFY_CURL_CONF" \
      -H "Title: Probealarm $NR -- $THEMA" \
      -H "Priority: default" -H "Tags: bell" \
      -d "$TEXT" \
      "$NTFY_URL/$THEMA"
  done
else
  logger -t pi-probealarm "eigener Server: uebersprungen, NTFY_URL oder NTFY_CURL_CONF fehlt"
  FEHLER=$((FEHLER + 1))
fi

# --- Weg 3: Notruf ueber ntfy.sh ---------------------------------------------
# Bewusst "default" statt "high": Ein Probealarm soll nicht klingeln wie ein
# echter. Der Punkt ist, dass er ankommt, nicht dass er weckt.
if [ -r "${NTFY_NOTRUF_CONF:-/nonexistent}" ]; then
  sende "Notruf/ntfy.sh" \
    --config "$NTFY_NOTRUF_CONF" \
    -H "Title: Probealarm $NR -- Notrufweg" \
    -H "Priority: default" -H "Tags: bell" \
    -d "$TEXT"
else
  logger -t pi-probealarm "Notruf: uebersprungen, NTFY_NOTRUF_CONF fehlt"
  FEHLER=$((FEHLER + 1))
fi

if [ "$FEHLER" -gt 0 ]; then
  logger -t pi-probealarm "Probealarm $NR: $FEHLER von 3 Wegen fehlgeschlagen"
  exit 1
fi
logger -t pi-probealarm "Probealarm $NR: alle drei Wege mit 200 angenommen"
exit 0
