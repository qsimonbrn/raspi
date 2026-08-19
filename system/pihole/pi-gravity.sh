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

vorher=$(pihole-FTL sqlite3 /etc/pihole/gravity.db \
           "select count(*) from vw_gravity;" </dev/null 2>/dev/null || echo 0)

PATH="$PATH:/usr/sbin:/usr/local/bin"
if ! pihole updateGravity >"$LOG" 2>&1; then
  logger -t pi-gravity "updateGravity fehlgeschlagen, siehe $LOG"
  notify "Pi-hole: Blocklisten NICHT aktualisiert" \
         "$(tail -n 15 "$LOG")" high "shield,warning"
  exit 1
fi

nachher=$(pihole-FTL sqlite3 /etc/pihole/gravity.db \
            "select count(*) from vw_gravity;" </dev/null 2>/dev/null || echo 0)

logger -t pi-gravity "Blocklisten aktualisiert: $vorher -> $nachher Domains"

# Ein Einbruch um mehr als ein Viertel bedeutet fast immer, dass eine Quelle
# nicht erreichbar war oder ihr Format geaendert hat. Pi-hole meldet das nicht
# von sich aus -- die Sperren fallen einfach leise weg.
if [ "$vorher" -gt 0 ] && [ "$nachher" -lt $((vorher * 3 / 4)) ]; then
  notify "Pi-hole: Blocklisten deutlich geschrumpft" \
         "Von $vorher auf $nachher Domains. Vermutlich war eine Quelle nicht erreichbar. Pruefen: sudo pihole -g" \
         high "shield,warning"
fi

exit 0
