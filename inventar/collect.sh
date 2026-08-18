#!/usr/bin/env bash
# ============================================================================
#  Bestandsaufnahme des Raspberry Pi  --  READ ONLY
#
#  Veraendert nichts am System. Sammelt den Ist-Zustand in zwei Dateien:
#
#    snapshots/<zeitstempel>-voll.txt    Vollstaendige Rohausgabe
#    snapshots/<zeitstempel>-fakten.md   Kompakte Kennzahlen zum Abgleich
#    snapshots/aktuell-fakten.md         Kopie der letzten Fakten (fuer Diffs)
#
#  Aufruf:  bash inventar/collect.sh
#
#  Geheimnisse werden bewusst ausgelassen: Container-Umgebungsvariablen
#  erscheinen nur mit Namen, private Schluessel nie.
# ============================================================================

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SNAP_DIR="$SCRIPT_DIR/snapshots"
TS="$(date +%Y-%m-%d-%H%M)"
FULL="$SNAP_DIR/${TS}-voll.txt"
FACTS="$SNAP_DIR/${TS}-fakten.md"

mkdir -p "$SNAP_DIR"

s() { printf '\n\n=================== %s ===================\n' "$1"; }
r() { echo "--- \$ $* ---"; eval "$@" 2>&1 | head -n "${LIMIT:-200}"; echo; }

# ---------------------------------------------------------------------------
#  Teil 1 -- Vollstaendige Rohausgabe
# ---------------------------------------------------------------------------
{
echo "Bestandsaufnahme Raspberry Pi"
echo "Zeitpunkt: $(date -Is)"
echo "Host: $(hostname)"

s "HARDWARE"
r "tr -d '\0' < /proc/device-tree/model"
r "nproc"
r "sudo vcgencmd measure_temp"
r "sudo vcgencmd get_throttled"
r "cat /sys/block/mmcblk0/device/name"
r "cat /sys/block/mmcblk0/device/date"

s "BETRIEBSSYSTEM"
r "grep -E 'PRETTY_NAME|VERSION_ID' /etc/os-release"
r "uname -rm"
r "getconf LONG_BIT"
r "uptime"
r "cat /proc/loadavg"
r "timedatectl | head -5"

s "SPEICHER"
r "free -h"
r "df -hT | grep -vE 'tmpfs|udev'"
r "lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,MODEL"
r "cat /etc/fstab"
r "ps aux --sort=-%mem | head -12"

s "NETZWERK"
r "ip -brief addr"
r "ip route | head -8"
r "hostname -f"

s "OFFENE PORTS"
LIMIT=60 r "sudo ss -tulpn | grep LISTEN"

s "SYSTEMD"
LIMIT=80 r "systemctl list-units --type=service --state=running --no-pager --no-legend"
r "systemctl --failed --no-pager"
LIMIT=20 r "systemctl list-timers --no-pager --no-legend"

s "DOCKER"
r "sudo docker --version"
LIMIT=60 r "sudo docker ps -a --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'"
LIMIT=60 r "sudo docker images --format 'table {{.Repository}}:{{.Tag}}\t{{.Size}}\t{{.CreatedSince}}'"
r "sudo docker volume ls"
r "sudo docker network ls"
r "sudo docker system df"
r "sudo docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}'"

echo "--- Container-Details (ENV nur mit Namen, ohne Werte) ---"
for c in $(sudo docker ps -a --format '{{.Names}}' 2>/dev/null); do
  echo ""
  echo ">>> $c"
  sudo docker inspect "$c" --format '  Image: {{.Config.Image}}
  Status: {{.State.Status}} (Restarts: {{.RestartCount}})
  RestartPolicy: {{.HostConfig.RestartPolicy.Name}}
  Privileged: {{.HostConfig.Privileged}}
  NetworkMode: {{.HostConfig.NetworkMode}}
  Compose: {{index .Config.Labels "com.docker.compose.project"}} | {{index .Config.Labels "com.docker.compose.project.config_files"}}' 2>&1
  echo "  Mounts:"
  sudo docker inspect "$c" --format '{{range .Mounts}}    {{.Source}} => {{.Destination}}
{{end}}' 2>&1
  echo "  ENV (nur Namen):"
  sudo docker inspect "$c" --format '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null | cut -d= -f1 | sed 's/^/    /'
done

s "DIENSTE"
r "pihole -v 2>/dev/null | head -5"
r "sudo wg show 2>/dev/null | grep -v private"
r "sudo testparm -s 2>/dev/null | grep -A8 usb-share"
r "sudo sshd -T 2>/dev/null | grep -E '^(passwordauthentication|permitrootlogin|pubkeyauthentication|port )'"

s "SICHERHEIT"
r "sudo ufw status verbose 2>/dev/null || echo 'ufw nicht installiert'"
r "sudo iptables -L INPUT -n | head -10"
r "sudo fail2ban-client status 2>/dev/null || echo 'fail2ban nicht installiert'"
r "systemctl is-enabled unattended-upgrades 2>/dev/null || echo 'unattended-upgrades nicht aktiv'"
r "apt list --upgradable 2>/dev/null | tail -n +2 | head -20"

s "BACKUP"
r "for t in rsync borg borgmatic restic duplicity rclone; do if command -v \$t >/dev/null; then echo \"\$t: installiert\"; else echo \"\$t: -\"; fi; done"
r "rclone listremotes 2>/dev/null"
r "crontab -l 2>/dev/null || echo 'keine'"
r "sudo crontab -l 2>/dev/null || echo 'keine'"
r "ls /etc/cron.d/"
r "ls -la /mnt/usb-hdd/rclone_bak/ 2>/dev/null | head"

s "COMPOSE-REPO"
r "ls -la /home/simon/raspi/"
r "cd /home/simon/raspi && git status -sb"
r "cd /home/simon/raspi && git log --oneline -5"

s "LOGS"
LIMIT=30 r "sudo journalctl -p err -b --no-pager | tail -30"
r "journalctl --disk-usage"

echo ""
echo "=================== ENDE ==================="
} > "$FULL" 2>&1

# ---------------------------------------------------------------------------
#  Teil 2 -- Kompakte Kennzahlen (fuer den Abgleich mit der Doku)
# ---------------------------------------------------------------------------
{
echo "# Kennzahlen -- $(date +%d.%m.%Y)"
echo ""
echo "Erzeugt von \`inventar/collect.sh\`. Diese Datei ist die Grundlage fuer den"
echo "Abgleich mit der bestehenden Dokumentation."
echo ""
echo "## System"
echo ""
echo "| Kennzahl | Wert |"
echo "|---|---|"
echo "| Modell | $(tr -d '\0' < /proc/device-tree/model) |"
echo "| OS | $(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2) |"
echo "| Kernel | $(uname -r) |"
echo "| Uptime | $(uptime -p) |"
echo "| Load | $(cut -d' ' -f1-3 /proc/loadavg) |"
echo "| Temperatur | $(sudo vcgencmd measure_temp 2>/dev/null | cut -d= -f2) |"
echo "| Throttled | $(sudo vcgencmd get_throttled 2>/dev/null | cut -d= -f2) |"
echo "| RAM verfuegbar | $(free -h | awk '/^Mem:/{print $7}') von $(free -h | awk '/^Mem:/{print $2}') |"
echo "| Root belegt | $(df -h / | awk 'NR==2{print $3" von "$2" ("$5")"}') |"
echo "| SSD belegt | $(df -h /mnt/usb-hdd 2>/dev/null | awk 'NR==2{print $3" von "$2" ("$5")"}') |"
echo "| Ausstehende Updates | $(apt list --upgradable 2>/dev/null | tail -n +2 | wc -l) |"
echo "| Fehlgeschlagene Dienste | $(systemctl --failed --no-legend --no-pager | wc -l) |"
echo ""
echo "## Container"
echo ""
echo "| Name | Image | Status | Ports |"
echo "|---|---|---|---|"
sudo docker ps -a --format '| {{.Names}} | {{.Image}} | {{.Status}} | {{.Ports}} |' 2>/dev/null
echo ""
echo "## Image-Alter"
echo ""
echo "| Image | Alter |"
echo "|---|---|"
sudo docker images --format '| {{.Repository}}:{{.Tag}} | {{.CreatedSince}} |' 2>/dev/null
echo ""
echo "## Offene Ports"
echo ""
echo '```'
sudo ss -tulpn 2>/dev/null | grep LISTEN | awk '{print $5, $7}' | sed 's/users:((//;s/))//' | sort -u
echo '```'
echo ""
echo "## Sicherheitslage"
echo ""
echo "| Pruefpunkt | Zustand |"
echo "|---|---|"
if command -v ufw >/dev/null; then UFW="$(sudo ufw status | head -1)"; else UFW="nicht installiert"; fi
if command -v fail2ban-client >/dev/null; then F2B="installiert"; else F2B="nicht installiert"; fi
echo "| ufw | $UFW |"
echo "| fail2ban | $F2B |"
echo "| SSH Passwortlogin | $(sudo sshd -T 2>/dev/null | grep '^passwordauthentication' | awk '{print $2}') |"
echo "| unattended-upgrades | $(systemctl is-enabled unattended-upgrades 2>/dev/null || echo 'nicht aktiv') |"
echo "| iptables INPUT policy | $(sudo iptables -L INPUT -n 2>/dev/null | head -1 | grep -o 'policy [A-Z]*') |"
echo ""
echo "## Backup-Lage"
echo ""
echo "| Pruefpunkt | Zustand |"
echo "|---|---|"
echo "| Cronjobs (simon) | $(crontab -l 2>/dev/null | grep -vc '^#') |"
echo "| Cronjobs (root) | $(sudo crontab -l 2>/dev/null | grep -vc '^#') |"
if command -v restic >/dev/null; then RES="installiert"; else RES="nicht installiert"; fi
echo "| restic | $RES |"
echo "| rclone-Remotes | $(rclone listremotes 2>/dev/null | tr '\n' ' ') |"
echo "| Letzter rclone-Log-Eintrag | $(ls -la --time-style=+%d.%m.%Y /mnt/usb-hdd/rclone_bak/*.log 2>/dev/null | awk '{print $6}' | tail -1) |"
echo ""
echo "## Compose-Repository"
echo ""
echo '```'
cd /home/simon/raspi 2>/dev/null && git status -sb 2>/dev/null
echo '```'
} > "$FACTS" 2>&1

cp "$FACTS" "$SNAP_DIR/aktuell-fakten.md"

echo ""
echo "  Bestandsaufnahme abgeschlossen."
echo ""
echo "    Vollausgabe : $FULL  ($(du -h "$FULL" | cut -f1))"
echo "    Kennzahlen  : $FACTS"
echo "    Kopie       : $SNAP_DIR/aktuell-fakten.md"
echo ""
