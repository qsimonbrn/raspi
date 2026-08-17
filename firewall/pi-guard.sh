#!/bin/bash
# pi-guard — begrenzt den Zugriff auf Verwaltungsoberflaechen auf Tailscale und den Pi selbst.
#
# Hintergrund: Docker schreibt eigene iptables-Regeln, die eine gewoehnliche Firewall
# (ufw) umgehen. Der vom Hersteller vorgesehene Einhaengepunkt ist die Kette
# DOCKER-USER, die vor allen Docker-Regeln ausgewertet wird.
#
# Zwei Wege muessen abgedeckt werden:
#   FORWARD/DOCKER-USER — Verkehr, den Docker per DNAT direkt an den Container leitet
#   INPUT               — Verkehr, den der userland-proxy auf dem Host annimmt (v.a. IPv6)
#
# Das Skript ist idempotent: mehrfaches Ausfuehren aendert nichts.

set -u

LAN_IF="eth0"
TS_IF="tailscale0"

# Ports, die aus dem LAN nicht erreichbar sein sollen
GESPERRT="9000,9443,15630,8000"
# 9000/9443 Portainer — Vollzugriff auf den Docker-Socket
# 15630      Bichon    — E-Mail-Archiv, altes Image
# 8000       Paperless — Dokumentenarchiv
#
# Bewusst NICHT gesperrt (Entscheidung vom 18.08.2026):
#   22        SSH       — Rettungsanker, falls Tailscale ausfaellt; nur Schluesselanmeldung
#   53        DNS       — das ganze Haus haengt daran
#   80/443    Pi-hole   — vorerst im LAN, hat eigenes Passwort
#   139/445   Samba     — Dateizugriff im Heimnetz, eigene Anmeldung
#   2586      ntfy      — mit auth-default-access deny-all abgesichert
#   3000      Homepage  — reines Linkverzeichnis, Socket-Proxy nur lesend

regeln_setzen() {
  local ipt="$1"

  # --- Kette fuer weitergeleiteten Container-Verkehr ---
  $ipt -N PI-GUARD 2>/dev/null || $ipt -F PI-GUARD
  $ipt -A PI-GUARD -i "$TS_IF" -j RETURN
  $ipt -A PI-GUARD -i lo -j RETURN
  $ipt -A PI-GUARD -i "$LAN_IF" -p tcp -m multiport --dports "$GESPERRT" \
       -m comment --comment "pi-guard: Verwaltung nicht aus dem LAN" -j DROP
  $ipt -C DOCKER-USER -j PI-GUARD 2>/dev/null || $ipt -I DOCKER-USER 1 -j PI-GUARD

  # --- Kette fuer Verkehr an den Host selbst (userland-proxy) ---
  $ipt -N PI-GUARD-IN 2>/dev/null || $ipt -F PI-GUARD-IN
  $ipt -A PI-GUARD-IN -i "$TS_IF" -j RETURN
  $ipt -A PI-GUARD-IN -i lo -j RETURN
  $ipt -A PI-GUARD-IN -i "$LAN_IF" -p tcp -m multiport --dports "$GESPERRT" \
       -m comment --comment "pi-guard: Verwaltung nicht aus dem LAN" -j DROP
  $ipt -C INPUT -j PI-GUARD-IN 2>/dev/null || $ipt -I INPUT 1 -j PI-GUARD-IN
}

case "${1:-start}" in
  start)
    # DOCKER-USER anlegen, falls Docker noch nicht so weit ist
    iptables  -N DOCKER-USER 2>/dev/null || true
    ip6tables -N DOCKER-USER 2>/dev/null || true
    regeln_setzen iptables
    regeln_setzen ip6tables
    echo "pi-guard aktiv — gesperrt aus dem LAN: $GESPERRT"
    ;;
  stop)
    for ipt in iptables ip6tables; do
      $ipt -D DOCKER-USER -j PI-GUARD    2>/dev/null || true
      $ipt -D INPUT       -j PI-GUARD-IN 2>/dev/null || true
      $ipt -F PI-GUARD    2>/dev/null || true
      $ipt -F PI-GUARD-IN 2>/dev/null || true
      $ipt -X PI-GUARD    2>/dev/null || true
      $ipt -X PI-GUARD-IN 2>/dev/null || true
    done
    echo "pi-guard entfernt"
    ;;
  status)
    echo "=== IPv4 PI-GUARD (weitergeleitet) ==="; iptables  -L PI-GUARD    -n -v 2>/dev/null || echo "nicht vorhanden"
    echo "=== IPv4 PI-GUARD-IN (an den Host) ==="; iptables  -L PI-GUARD-IN -n -v 2>/dev/null || echo "nicht vorhanden"
    echo "=== IPv6 PI-GUARD ===";                  ip6tables -L PI-GUARD    -n -v 2>/dev/null || echo "nicht vorhanden"
    echo "=== IPv6 PI-GUARD-IN ===";               ip6tables -L PI-GUARD-IN -n -v 2>/dev/null || echo "nicht vorhanden"
    ;;
  *)
    echo "Aufruf: $0 {start|stop|status}" >&2; exit 1 ;;
esac
