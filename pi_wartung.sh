#!/bin/bash
set -euo pipefail

DOCKER_PRUNE="${DOCKER_PRUNE:-0}"   # 1 = aufräumen, 0 = nicht

echo "== 1) Paketlisten & Updates =="
apt update
apt full-upgrade -y
apt autoremove -y
apt clean

echo "== 2) Pi-hole Updates =="
pihole -up
pihole -g

echo "== 3) Docker Checks =="
if systemctl is-active --quiet docker; then
  echo "[OK] Docker läuft"
  sudo docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"
  sudo docker system df
else
  echo "[WARN] Docker läuft nicht"
fi

echo "== 4) Docker Compose Stacks updaten (optional) =="
for d in /opt/stacks/*; do
  if [ -f "$d/compose.yml" ] || [ -f "$d/docker-compose.yml" ]; then
    echo "==> Updating $d"
    (cd "$d" && sudo docker compose pull && sudo docker compose up -d)
  fi
done

echo "== 5) Docker Cleanup (optional) =="
if [ "$DOCKER_PRUNE" = "1" ]; then
  sudo docker image prune -f
  sudo docker system prune -f
fi

echo "== 6) Logs aufräumen (letzte 7 Tage) =="
journalctl --vacuum-time=7d

echo "== 7) Reboot-Check =="
[ -f /var/run/reboot-required ] && echo "[INFO] Reboot erforderlich."