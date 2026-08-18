#!/usr/bin/env bash
# =============================================================================
#  pi-wartung — Wartungslauf von Hand
#
#  Aufruf:   wartung            (Alias, siehe /etc/profile.d/pi-aliase.sh)
#            sudo /usr/local/sbin/pi-wartung.sh
#
#  Schalter (Standard jeweils aus, weil sie ueber ein reines Aufraeumen
#  hinausgehen und eine Entscheidung sind):
#            PIHOLE_UPDATE=1    Pi-hole auf eine neue Version heben
#            DOCKER_PRUNE=1     ungenutzte Images, Netze, Build-Cache entfernen
#
#  Beispiel: sudo PIHOLE_UPDATE=1 DOCKER_PRUNE=1 /usr/local/sbin/pi-wartung.sh
#
#  Was dieses Skript BEWUSST NICHT tut:
#    * Container aktualisieren. Alle Images sind auf feste Versionen oder
#      Digests gepinnt; ein Update ist eine Entscheidung mit vorherigem Backup
#      und laeuft ueber den Skill "docker-updates". Der Vorgaenger versuchte das
#      ueber /opt/stacks/* -- ein Verzeichnis, das es auf diesem Pi nie gab.
#    * Neustarten. Am Pi haengt der DNS des ganzen Haushalts.
#
#  Hervorgegangen aus pi-maintenance.sh (12/2025), ueberarbeitet am 18.08.2026.
#  Dokumentation: raspi-doku/docs/02-betriebssystem.md
# =============================================================================

set -uo pipefail

[ "$(id -u)" -eq 0 ] || { echo "Bitte mit sudo ausfuehren."; exit 2; }

PIHOLE_UPDATE="${PIHOLE_UPDATE:-0}"
DOCKER_PRUNE="${DOCKER_PRUNE:-0}"
FEHLER=0
HINWEIS=0

log()     { printf '\n\033[1m== %s\033[0m\n' "$*"; }
zeile()   { printf '   %s\n' "$*"; }
warn()    { printf '   \033[33mWARNUNG:\033[0m %s\n' "$*"; FEHLER=$((FEHLER+1)); }
merke()   { printf '   \033[36mHINWEIS:\033[0m %s\n' "$*"; HINWEIS=$((HINWEIS+1)); }

# Nur ein Lauf gleichzeitig -- apt vertraegt nichts anderes.
exec 9>/var/lock/pi-wartung.lock
flock -n 9 || { echo "Ein Wartungslauf laeuft bereits -- Abbruch."; exit 0; }

START=$(date +%s)
printf '\033[1mWartungslauf %s\033[0m\n' "$(date '+%d.%m.%Y %H:%M')"

# --- 1. Zustand vorher -------------------------------------------------------
log "1) Zustand"
zeile "Laufzeit:    $(uptime -p | sed 's/^up //')"
zeile "Temperatur:  $(vcgencmd measure_temp 2>/dev/null | cut -d= -f2)"
TH=$(vcgencmd get_throttled 2>/dev/null | cut -d= -f2)
if [ "$TH" = "0x0" ]; then zeile "Drosselung:  nie ($TH)"; else warn "Drosselung aufgetreten: $TH"; fi
zeile "Wurzel:      $(df -h / | awk 'NR==2{print $3" von "$2" ("$5")"}')"
zeile "SSD:         $(df -h /mnt/usb-hdd 2>/dev/null | awk 'NR==2{print $3" von "$2" ("$5")"}')"
zeile "Speicher:    $(free -h | awk '/^Mem:/{print $7" von "$2" verfuegbar"}')"

# --- 2. Systemupdate ---------------------------------------------------------
log "2) Systemupdate"
if apt-get update -qq 2>/dev/null; then
  N=$(apt list --upgradable 2>/dev/null | tail -n +2 | grep -c .)
  if [ "$N" -eq 0 ]; then
    zeile "Keine Aktualisierungen ausstehend."
  else
    zeile "$N Pakete werden aktualisiert:"
    apt list --upgradable 2>/dev/null | tail -n +2 | cut -d/ -f1 | sed 's/^/     /'
    # Ohne DEBIAN_FRONTEND und Umleitung besteht die Ausgabe zu neun Zehnteln
    # aus debconf-Klagen ueber das fehlende Terminal und aus
    # "Reading database ... 95%". Fehler werden weiter gezeigt.
    PROT=$(mktemp)
    if DEBIAN_FRONTEND=noninteractive apt-get full-upgrade -y -qq >"$PROT" 2>&1; then
      zeile "Aktualisierung durchgelaufen."
    else
      warn "full-upgrade meldete einen Fehler:"
      tail -20 "$PROT" | sed 's/^/     /'
    fi
    grep -iE '^(E:|dpkg: error)' "$PROT" | sed 's/^/     /'
    rm -f "$PROT"
    DEBIAN_FRONTEND=noninteractive apt-get autoremove -y -qq >/dev/null 2>&1 || warn "autoremove meldete einen Fehler"
    apt-get clean
    # Ein Sprung bei docker-compose-plugin ist harmlos, aber merkenswert:
    # er wechselt das Werkzeug unter den Stacks aus.
    zeile "docker compose: $(sudo docker compose version --short 2>/dev/null)"
  fi
else
  warn "apt-get update fehlgeschlagen -- kein Netz?"
fi

# --- 3. Pi-hole --------------------------------------------------------------
log "3) Pi-hole"
if command -v pihole >/dev/null 2>&1; then
  if pihole -g >/dev/null 2>&1; then
    zeile "Blocklisten erneuert (gravity)."
  else
    warn "gravity-Lauf fehlgeschlagen"
  fi
  if [ "$PIHOLE_UPDATE" = "1" ]; then
    zeile "Versionsaktualisierung laeuft (PIHOLE_UPDATE=1) ..."
    pihole -up || warn "pihole -up meldete einen Fehler"
  else
    merke "Versionsstand nicht angetastet. Fuer ein Update: PIHOLE_UPDATE=1"
  fi
else
  warn "pihole nicht gefunden"
fi

# --- 4. Docker ---------------------------------------------------------------
# Bewusst nur schauen, nicht anfassen. "sudo docker", nie "docker": das Konto
# claude ist absichtlich nicht in der Gruppe docker, damit jeder Aufruf im
# sudo-Protokoll steht. Ohne sudo scheitern die Befehle -- und zwar still.
log "4) Docker"
if systemctl is-active --quiet docker; then
  LAEUFT=$(sudo docker ps -q | grep -c .)
  GESAMT=$(sudo docker ps -aq | grep -c .)
  zeile "$LAEUFT von $GESAMT Containern laufen."
  UNGESUND=$(sudo docker ps --filter health=unhealthy --format '{{.Names}}' | tr '\n' ' ')
  [ -n "${UNGESUND// /}" ] && warn "ungesund: $UNGESUND"
  GESTOPPT=$(sudo docker ps -a --filter status=exited --format '{{.Names}}' | tr '\n' ' ')
  [ -n "${GESTOPPT// /}" ] && merke "gestoppt: $GESTOPPT"
  sudo docker system df --format 'table {{.Type}}\t{{.TotalCount}}\t{{.Size}}\t{{.Reclaimable}}' 2>/dev/null | sed 's/^/     /'
  # Ungedrehte Logdateien wuerden bedeuten, dass die Rotation wieder fehlt.
  GROSS=$(find /var/lib/docker/containers -name '*-json.log' -size +12M 2>/dev/null | wc -l)
  [ "$GROSS" -gt 0 ] && warn "$GROSS Logdatei(en) ueber 12 MB -- Logrotation pruefen (docs/05-docker.md)"
else
  warn "Docker laeuft nicht"
fi

# --- 5. Abgleich Repository <-> System ---------------------------------------
log "5) Abgleich Repository und installierte Fassungen"
if [ -x /usr/local/sbin/pi-abgleich.sh ]; then
  /usr/local/sbin/pi-abgleich.sh check | sed 's/^/   /' || merke "Abweichungen -- siehe: sudo pi-abgleich.sh diff"
else
  merke "pi-abgleich.sh nicht installiert"
fi

# --- 6. Backup ---------------------------------------------------------------
log "6) Backup"
# Die Eigenschaften des oneshot-Dienstes werden von jedem daemon-reload
# geleert. Der Timer merkt sich den letzten Start dagegen zuverlaessig.
LETZTER=$(systemctl show pi-backup.timer -p LastTriggerUSec --value)
if [ -n "$LETZTER" ]; then
  ALTER=$(( ( $(date +%s) - $(date -d "$LETZTER" +%s) ) / 3600 ))
  if [ "$ALTER" -le 30 ]; then zeile "Letzter Lauf vor ${ALTER} h ($LETZTER)."
  else warn "Letzter Lauf liegt ${ALTER} h zurueck -- taeglich waere erwartbar"; fi
else
  merke "Kein Zeitpunkt eines Backuplaufs ermittelbar."
fi
systemctl is-enabled pi-backup.timer >/dev/null 2>&1 || warn "pi-backup.timer ist nicht aktiviert"

# --- 7. Aufraeumen -----------------------------------------------------------
log "7) Aufraeumen"
VOR=$(journalctl --disk-usage 2>/dev/null | grep -oE '[0-9.]+[MG]' | head -1)
journalctl --vacuum-time=7d >/dev/null 2>&1
zeile "Journal: $VOR -> $(journalctl --disk-usage 2>/dev/null | grep -oE '[0-9.]+[MG]' | head -1) (aelter als 7 Tage entfernt)"
if [ "$DOCKER_PRUNE" = "1" ]; then
  sudo docker image prune -f  >/dev/null 2>&1 && zeile "Ungenutzte Images entfernt."
  sudo docker system prune -f >/dev/null 2>&1 && zeile "Ungenutzte Netze und Build-Cache entfernt."
else
  merke "Docker nicht aufgeraeumt. Dafuer: DOCKER_PRUNE=1"
fi

# --- 8. Neustart ------------------------------------------------------------
# Der Vorgaenger endete hier mit "[ -f … ] && echo …" als letzter Zeile. Unter
# set -e lieferte das Skript dadurch IMMER Exit 1, wenn kein Neustart faellig
# war -- ein Fehlschlag, der keiner ist.
log "8) Neustart"
if [ -f /var/run/reboot-required ]; then
  merke "Ein Neustart ist faellig: $(cat /var/run/reboot-required.pkgs 2>/dev/null | tr '\n' ' ')"
else
  zeile "Kein Neustart noetig."
fi

# --- Zusammenfassung ---------------------------------------------------------
DAUER=$(( $(date +%s) - START ))
printf '\n\033[1m== Ergebnis\033[0m\n'
zeile "Dauer: ${DAUER}s, $FEHLER Warnung(en), $HINWEIS Hinweis(e)"
if [ "$FEHLER" -gt 0 ]; then
  printf '   \033[33mMit Warnungen beendet.\033[0m\n'
  exit 1
fi
printf '   \033[32mOhne Warnungen beendet.\033[0m\n'
exit 0
