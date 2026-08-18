#!/usr/bin/env bash
# =============================================================================
#  pi-abgleich — haelt Repository und installierte Fassungen deckungsgleich
#
#  Hintergrund: Ein Teil der Dateien laeuft NICHT aus dem Repository, sondern
#  aus /etc, /usr/local/bin, /usr/local/sbin oder /boot. Eine Aenderung nur im
#  Repository ist dort wirkungslos. Am 18.08.2026 ist genau das aufgefallen:
#  pi_wartung.sh war im Repository auf "sudo docker" umgestellt, die
#  installierte Fassung /usr/local/sbin/pi-maintenance.sh nicht.
#
#  Dieses Skript KOPIERT NIE VON SELBST. Der Timer ruft ausschliesslich
#  "check" auf und meldet Abweichungen ueber ntfy. Kopiert wird nur auf
#  ausdrueckliche Anweisung -- damit das Repository weiter festhaelt, was
#  entschieden wurde, und nicht bloss, was zufaellig der Fall ist.
#
#  Aufruf:
#    pi-abgleich.sh list                 Alle Paare mit Zustand
#    pi-abgleich.sh check [--melden]     Nur pruefen; Exit 1 bei Abweichung
#    pi-abgleich.sh diff [Muster]        Unterschiede im Klartext
#    pi-abgleich.sh install [Muster]     Repository -> System
#    pi-abgleich.sh pull    [Muster]     System -> Repository
#
#  "Muster" filtert auf den Repo-Pfad, z. B. "backup" oder "pi_wartung".
#  Ohne Nachfrage laeuft install/pull nur mit --ja (noetig ohne Terminal).
#
#  Dokumentation: docs/17-wo-was-liegt.md
# =============================================================================

set -uo pipefail

REPO="${ABGLEICH_REPO:-/home/simon/raspi}"
MANIFEST="$REPO/system/abgleich/manifest.tsv"

[ -r "$MANIFEST" ] || { echo "FEHLER: Manifest nicht lesbar: $MANIFEST" >&2; exit 2; }

# --- ntfy (gleiche Anbindung wie das Backup) ---------------------------------
notify() {  # $1=Titel  $2=Text  $3=Prioritaet  $4=Tags
  local cfg=/etc/pi-backup.env
  [ -r "$cfg" ] || return 0
  set -a; . "$cfg"; set +a
  [ -n "${NTFY_URL:-}" ] || return 0
  [ -r "${NTFY_TOKEN_FILE:-/nonexistent}" ] || return 0
  curl -s -m 20 -o /dev/null \
    -H "Authorization: Bearer $(cat "$NTFY_TOKEN_FILE")" \
    -H "Title: $1" -H "Priority: ${3:-default}" -H "Tags: ${4:-open_file_folder}" \
    -d "$2" "$NTFY_URL/${NTFY_TOPIC:-raspberrypi}" || true
}

# --- Manifest einlesen -------------------------------------------------------
# Liefert Zeilen:  repo_pfad \t system_pfad \t besitzer \t modus \t nachlauf
zeilen() {
  grep -vE '^\s*(#|$)' "$MANIFEST" | while IFS=$'\t' read -r r s o m n; do
    [ -n "${1:-}" ] && [[ "$r" != *"$1"* ]] && continue
    printf '%s\t%s\t%s\t%s\t%s\n' "$r" "$s" "$o" "$m" "$n"
  done
}

# Zustand eines Paares: identisch | abweichend | repo-fehlt | system-fehlt
zustand() {  # $1=repo_pfad $2=system_pfad
  [ -e "$REPO/$1" ] || { echo "repo-fehlt"; return; }
  [ -e "$2" ]       || { echo "system-fehlt"; return; }
  if diff -q "$REPO/$1" "$2" >/dev/null 2>&1; then echo "identisch"; else echo "abweichend"; fi
}

rechte_ok() {  # $1=system_pfad $2=besitzer $3=modus
  [ -e "$1" ] || return 1
  local ist
  ist="$(stat -c '%U:%G %a' "$1" 2>/dev/null)"
  [ "$ist" = "$2 $3" ]
}

nachlauf() {  # $1=art
  case "$1" in
    systemd) systemctl daemon-reload && echo "    systemctl daemon-reload ausgefuehrt" ;;
    sudoers) visudo -c -q -f /etc/sudoers && echo "    visudo -c: Regeln gueltig" \
             || echo "    ACHTUNG: visudo meldet einen Fehler in den sudo-Regeln" ;;
  esac
}

bestaetigen() {  # $1=Frage
  [ "${JA:-0}" = "1" ] && return 0
  [ -t 0 ] || { echo "Kein Terminal -- fuer unbeaufsichtigten Lauf --ja angeben."; return 1; }
  local a; read -r -p "$1 [j/N] " a; [ "$a" = "j" ] || [ "$a" = "J" ]
}

# --- Unterbefehle ------------------------------------------------------------
cmd_list() {
  printf '%-40s %-48s %-13s %s\n' "REPOSITORY" "INSTALLIERT" "INHALT" "RECHTE"
  printf -- '-%.0s' {1..120}; echo
  zeilen "${1:-}" | while IFS=$'\t' read -r r s o m n; do
    local z rr
    z="$(zustand "$r" "$s")"
    rechte_ok "$s" "$o" "$m" && rr="ok" || rr="abweichend ($(stat -c '%U:%G %a' "$s" 2>/dev/null || echo 'nicht da'))"
    printf '%-40s %-48s %-13s %s\n' "$r" "$s" "$z" "$rr"
  done
}

cmd_check() {
  local melden=0 abw=0 liste=""
  [ "${1:-}" = "--melden" ] && melden=1
  while IFS=$'\t' read -r r s o m n; do
    local z; z="$(zustand "$r" "$s")"
    if [ "$z" != "identisch" ]; then
      abw=$((abw+1)); liste="${liste}${r} (${z})\n"
    elif ! rechte_ok "$s" "$o" "$m"; then
      abw=$((abw+1)); liste="${liste}${r} (Rechte weichen ab)\n"
    fi
  done < <(zeilen)

  if [ "$abw" -eq 0 ]; then
    echo "Abgleich in Ordnung: alle $(zeilen | wc -l) Paare identisch."
    return 0
  fi
  echo "$abw von $(zeilen | wc -l) Paaren weichen ab:"
  printf "%b" "$liste" | sed 's/^/  /'
  [ "$melden" -eq 1 ] && notify "Abgleich: $abw Abweichung(en)" \
    "$(printf "%b" "$liste")"$'\n'"Pruefen mit: sudo pi-abgleich.sh diff" "high" "warning"
  return 1
}

cmd_diff() {
  zeilen "${1:-}" | while IFS=$'\t' read -r r s o m n; do
    [ "$(zustand "$r" "$s")" = "abweichend" ] || continue
    echo "===== $r  <->  $s"
    echo "      < Repository   > installiert"
    diff "$REPO/$r" "$s" | sed 's/^/      /'
    echo
  done
}

cmd_kopieren() {  # $1=install|pull  $2=Muster
  local richtung="$1" muster="${2:-}" n=0
  zeilen "$muster" | while IFS=$'\t' read -r r s o m nl; do
    local z; z="$(zustand "$r" "$s")"
    [ "$z" = "identisch" ] && rechte_ok "$s" "$o" "$m" && continue
    echo "===== $r  <->  $s   ($z)"
    if [ "$z" = "abweichend" ]; then diff "$REPO/$r" "$s" | sed 's/^/      /'; fi
    if [ "$richtung" = "install" ]; then
      [ -e "$REPO/$r" ] || { echo "      uebersprungen: Datei fehlt im Repository"; continue; }
      bestaetigen "  Repository -> System uebernehmen?" || { echo "      uebersprungen"; continue; }
      install -o "${o%%:*}" -g "${o##*:}" -m "$m" "$REPO/$r" "$s" \
        && echo "    installiert nach $s" || { echo "    FEHLGESCHLAGEN"; continue; }
      nachlauf "$nl"
    else
      [ -e "$s" ] || { echo "      uebersprungen: installierte Fassung fehlt"; continue; }
      bestaetigen "  System -> Repository uebernehmen?" || { echo "      uebersprungen"; continue; }
      mkdir -p "$(dirname "$REPO/$r")"
      cp -a "$s" "$REPO/$r" && chmod 664 "$REPO/$r" \
        && echo "    ins Repository uebernommen -- bitte mit einer Begruendung committen" \
        || echo "    FEHLGESCHLAGEN"
    fi
  done
}

# --- Aufruf ------------------------------------------------------------------
JA=0
ARGS=()
for a in "$@"; do [ "$a" = "--ja" ] && JA=1 || ARGS+=("$a"); done
if [ ${#ARGS[@]} -eq 0 ]; then set --; else set -- "${ARGS[@]}"; fi

case "${1:-check}" in
  list)    cmd_list "${2:-}" ;;
  check)   cmd_check "${2:-}" ;;
  diff)    cmd_diff "${2:-}" ;;
  install) cmd_kopieren install "${2:-}" ;;
  pull)    cmd_kopieren pull "${2:-}" ;;
  *) sed -n '/^#  Aufruf:/,/^#  Doku/p' "$0" | sed 's/^#\s\?//'; exit 2 ;;
esac
