#!/usr/bin/env bash
# Taegliche Aktualisierung der Pi-hole-Blocklisten.
#
# Warum nicht der mitgelieferte Cronjob? /etc/cron.d/pihole gehoert Pi-hole und
# wird bei jedem Core-Update neu geschrieben. Die am 20.08.2026 dort von Hand
# eingetragene taegliche Ausfuehrung waere beim naechsten "pihole -up" still auf
# woechentlich zurueckgefallen -- und niemand haette es gemerkt. systemd-Units
# unter /etc/systemd/system fasst Pi-hole nicht an.
#
# Installiert als /usr/local/sbin/pi-gravity.sh, Quelle in
# system/pihole/pi-gravity.sh des Repositories qsimonbrn/raspi.

set -uo pipefail

LOG=/var/log/pihole/pihole_updateGravity.log
# Ueberschreibbar, damit die Statuspruefung gegen eine Kopie der Datenbank
# getestet werden kann, ohne die echte anzufassen.
GDB="${GDB:-/etc/pihole/gravity.db}"

gsql() { pihole-FTL sqlite3 "$GDB" "$1" </dev/null 2>/dev/null; }

# --- ntfy (gleiche Anbindung wie Backup und Abgleich) ------------------------
notify() {  # $1=Titel  $2=Text  $3=Prioritaet  $4=Tags
  local cfg=/etc/pi-backup.env
  [ -r "$cfg" ] || return 0
  set -a; . "$cfg"; set +a
  [ -n "${NTFY_URL:-}" ] || return 0
  [ -r "${NTFY_TOKEN_FILE:-/nonexistent}" ] || return 0
  curl -s -m 20 -o /dev/null \
    -H "Authorization: Bearer $(cat "$NTFY_TOKEN_FILE")" \
    -H "Title: $1" -H "Priority: ${3:-default}" -H "Tags: ${4:-shield}" \
    -d "$2" "$NTFY_URL/${NTFY_TOPIC:-raspberrypi}" || true
}

vorher=$(gsql "select count(*) from vw_gravity;" || echo 0)

PATH="$PATH:/usr/sbin:/usr/local/bin"
if ! pihole updateGravity >"$LOG" 2>&1; then
  logger -t pi-gravity "updateGravity fehlgeschlagen, siehe $LOG"
  notify "Pi-hole: Blocklisten NICHT aktualisiert" \
         "$(tail -n 15 "$LOG")" high "shield,warning"
  exit 1
fi

nachher=$(gsql "select count(*) from vw_gravity;" || echo 0)

logger -t pi-gravity "Blocklisten aktualisiert: $vorher -> $nachher Domains"

# Ein Einbruch um mehr als ein Viertel bedeutet fast immer, dass eine Quelle
# nicht erreichbar war oder ihr Format geaendert hat. Pi-hole meldet das nicht
# von sich aus -- die Sperren fallen einfach leise weg.
if [ "$vorher" -gt 0 ] && [ "$nachher" -lt $((vorher * 3 / 4)) ]; then
  notify "Pi-hole: Blocklisten deutlich geschrumpft" \
         "Von $vorher auf $nachher Domains. Vermutlich war eine Quelle nicht erreichbar. Pruefen: sudo pihole -g" \
         high "shield,warning"
fi

# --- Status je Liste (seit 07.09.2026) --------------------------------------
# Die Gesamtzahl deckt nur den groben Fall ab. Faellt EINE von sechs Listen aus,
# aendert sich die Summe kaum: Pi-hole faellt still auf seinen Cache zurueck und
# die Zahl bleibt fast gleich -- die Liste ist aber veraltet und friert ein.
#   status 1 = aktualisiert · 2 = Cache benutzt, harmlos
#   status 3 = Download fehlgeschlagen, Cache benutzt  <- der bedenkliche Fall
#   status 4 = fehlgeschlagen, kein Cache
#
# Der Fall, in dem diese Pruefung durchlaufen koennte, ohne etwas gemessen zu
# haben: die Abfrage selbst scheitert (Datenbank gesperrt, Pfad falsch, Aufruf
# ohne Rechte) und liefert eine leere Zeichenkette -- die sich von "keine
# Fehler" nicht unterscheidet. Deshalb wird zuerst die Zahl der aktiven Listen
# geholt und auf eine Ziffer groesser null geprueft. Erst danach zaehlt ein
# leeres Ergebnis als Entwarnung.
aktiv=$(gsql "select count(*) from adlist where enabled=1;")
if ! printf '%s' "${aktiv:-}" | grep -qE '^[1-9][0-9]*$'; then
  logger -t pi-gravity "Statusabfrage der Blocklisten nicht moeglich"
  notify "Pi-hole: Listenstatus nicht pruefbar" \
         "Die Abfrage von adlist in $GDB lieferte kein brauchbares Ergebnis. Die Zahl der Domains sagt darueber nichts. Pruefen: sudo pihole-FTL sqlite3 $GDB 'select id,status,address from adlist where enabled=1;'" \
         high "shield,warning"
else
  fehl=$(gsql "select group_concat(status || ' ' || address, ' | ') from adlist where enabled=1 and status>=3;")
  if [ -n "${fehl:-}" ]; then
    logger -t pi-gravity "Blocklisten mit Fehlstatus: $fehl"
    notify "Pi-hole: Blockliste nicht geladen" \
           "Von $aktiv aktiven Listen sind welche fehlgeschlagen (3 = Cache benutzt, 4 = kein Cache): $fehl -- Pruefen: sudo pihole -g" \
           high "shield,warning"
  else
    logger -t pi-gravity "Listenstatus: $aktiv aktive Listen, keine mit status>=3"
  fi
fi

exit 0
