#!/usr/bin/env bash
# ============================================================================
#  Bestandsaufnahme des Raspberry Pi  --  READ ONLY
#
#  Veraendert nichts am System. Sammelt den Ist-Zustand in vier Dateien:
#
#    snapshots/<zeitstempel>-voll.txt    Vollstaendige Rohausgabe
#    snapshots/<zeitstempel>-fakten.md   Kennzahlen und Behauptungspruefung
#    snapshots/aktuell-fakten.md         Kopie der letzten Fakten (fuer Diffs)
#    snapshots/aktuell-werte.tsv         Maschinenlesbare Zahlen (fuer Wachstum)
#
#  Aufruf:  bash inventar/collect.sh [--ohne-tiefpruefung]
#
#    --ohne-tiefpruefung   laesst die restic-Pruefungen aus (spart rund 100 s).
#                          Die betroffenen Zeilen melden dann ausdruecklich
#                          "uebersprungen" -- nie "ok".
#
#  Laufzeit: rund 2,5 Minuten vollstaendig, rund 40 Sekunden mit
#  --ohne-tiefpruefung. Ueber die Cowork-Bruecke deshalb IMMER als Job starten
#  (ssh_job_start / ssh_job_wait), die bricht nach 60 Sekunden ab.
#
#  Geheimnisse werden bewusst ausgelassen: Container-Umgebungsvariablen
#  erscheinen nur mit Namen, private Schluessel und Tokens nie.
#
#  ---------------------------------------------------------------------------
#  ZWEI REGELN, an denen dieses Skript frueher gescheitert ist
#  ---------------------------------------------------------------------------
#
#  1. IMMER "sudo docker", nie "docker". Das Konto claude ist bewusst nicht in
#     der Gruppe docker. Ohne sudo scheitern die Aufrufe STILL: das Skript
#     laeuft scheinbar durch und liefert leere Ergebnisse.
#
#  2. Eine Pruefung, die nicht laufen konnte, muss das SAGEN -- nicht leer
#     bleiben. Eine leere Zelle liest sich wie "nichts vorhanden" und ist damit
#     schlimmer als gar keine Pruefung. Dafuer gibt es die Funktion w() und die
#     Marke "?" in der Behauptungspruefung.
#
#  Ein dritter Fallstrick, gemessen am 20.08.2026: In einer while-read-Schleife
#  verschluckt "sudo docker" die Eingabe der Pipe, die Schleife bricht nach dem
#  ersten Durchlauf ab. Deshalb hier ueberall for-Schleifen und zusaetzlich
#  </dev/null an den docker-Aufrufen.
# ============================================================================

set -u

TIEF=1
for arg in "$@"; do
  case "$arg" in
    --ohne-tiefpruefung|--schnell) TIEF=0 ;;
    -h|--help) sed -n '2,30p' "$0"; exit 0 ;;
    *) echo "Unbekannte Option: $arg" >&2; exit 2 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SNAP_DIR="$SCRIPT_DIR/snapshots"
TS="$(date +%Y-%m-%d-%H%M)"
FULL="$SNAP_DIR/${TS}-voll.txt"
FACTS="$SNAP_DIR/${TS}-fakten.md"
WERTE="$SNAP_DIR/aktuell-werte.tsv"
VOR_WERTE="$(mktemp)"

mkdir -p "$SNAP_DIR"

# Die Werte des vorigen Laufs beiseitelegen, BEVOR sie ueberschrieben werden --
# ohne sie ist Pruefung 11 (Wachstum) nicht moeglich.
[ -f "$WERTE" ] && cp "$WERTE" "$VOR_WERTE"

trap 'rm -f "$VOR_WERTE"' EXIT

# ---------------------------------------------------------------------------
#  Werkzeuge
# ---------------------------------------------------------------------------

s() { printf '\n\n=================== %s ===================\n' "$1"; }
r() { echo "--- \$ $* ---"; eval "$@" </dev/null 2>&1 | head -n "${LIMIT:-200}"; echo; }

# w <shell-ausdruck>  --  liefert den Wert oder eine Fehlermarke, aber NIE leer.
# Das ist der Kern von Regel 2: "konnte nicht ermittelt werden" muss sich von
# "geprueft und in Ordnung" unterscheiden lassen.
w() {
  local out rc
  out="$(eval "$1" </dev/null 2>/dev/null)"; rc=$?
  if [ "$rc" -ne 0 ] && [ -z "${out//[[:space:]]/}" ]; then
    printf '? nicht ermittelbar (Code %d)' "$rc"; return 0
  fi
  if [ -z "${out//[[:space:]]/}" ]; then
    printf '? leere Antwort'; return 0
  fi
  printf '%s' "$out"
}

# restic_ <argumente>  --  restic mit der Konfiguration des Backups.
# /etc/pi-backup.env gehoert root und enthaelt Repo-Adresse und Passwortdatei,
# deshalb der Umweg ueber sudo bash -c.
restic_() {
  sudo -n bash -c 'set -a; . /etc/pi-backup.env 2>/dev/null; set +a; exec restic "$@"' _ "$@"
}

# Zaehler und Ausgabe der Behauptungspruefung.
GEPRUEFT=0; ABWEICHUNG=0; UNGEPRUEFT=0
pruef() {  # $1=Was geprueft wurde  $2=ok|ACHTUNG|?  $3=Befund
  case "$2" in
    ok)      GEPRUEFT=$((GEPRUEFT+1)) ;;
    ACHTUNG) ABWEICHUNG=$((ABWEICHUNG+1)) ;;
    *)       UNGEPRUEFT=$((UNGEPRUEFT+1)) ;;
  esac
  printf '| %s | %s | %s |\n' "$1" "$2" "$3"
}

# wert <schluessel> <zahl>  --  maschinenlesbar fuer den Wachstumsvergleich.
wert() { printf '%s\t%s\n' "$1" "$2" >> "$WERTE"; }
vorwert() { awk -F'\t' -v k="$1" '$1==k{print $2; f=1} END{if(!f) print ""}' "$VOR_WERTE" 2>/dev/null; }

# ---------------------------------------------------------------------------
#  Vorab: die teuren Abfragen genau einmal
# ---------------------------------------------------------------------------
# restic spricht ueber rclone mit OneDrive. Ein Aufruf dauert 20 bis 40
# Sekunden; die Antwort wird deshalb hier einmal geholt und mehrfach benutzt.

SNAP_ZEIT="";  SNAP_ID="";  SNAP_ANZAHL="";  SNAP_PFADE="";  SNAP_EPOCH=0
RESTIC_FEHLER=""
if ! command -v restic >/dev/null 2>&1; then
  RESTIC_FEHLER="restic nicht installiert"
elif [ "$TIEF" -eq 0 ]; then
  RESTIC_FEHLER="uebersprungen (--ohne-tiefpruefung)"
else
  SNAP_JSON="$(restic_ snapshots --json --no-lock 2>/dev/null)"
  if [ -z "$SNAP_JSON" ]; then
    RESTIC_FEHLER="Repository nicht erreichbar oder keine Snapshots"
  else
    # ACHTUNG, gemessen am 20.08.2026: "restic snapshots --latest 1" liefert
    # NICHT den neuesten Snapshot, sondern den neuesten JE PFAD-GRUPPE. Nach
    # einer Aenderung der gesicherten Pfade kommt dadurch ein tagealter
    # Snapshot zurueck und das Backup sieht still stehend aus. Deshalb wird
    # hier ueber alle Snapshots nach Zeit sortiert.
    eval "$(printf '%s' "$SNAP_JSON" | python3 -c '
import json,sys,datetime
try:
    d=json.load(sys.stdin)
except Exception:
    sys.exit(0)
if not d: sys.exit(0)
s=sorted(d,key=lambda x:x["time"])[-1]
t=datetime.datetime.fromisoformat(s["time"])
print("SNAP_ZEIT=%s" % t.strftime("%d.%m.%Y-%H:%M"))
print("SNAP_ID=%s" % s["short_id"])
print("SNAP_ANZAHL=%d" % len(d))
print("SNAP_PFADE=%d" % len(s["paths"]))
print("SNAP_EPOCH=%d" % int(t.timestamp()))
' 2>/dev/null)"
    [ -n "$SNAP_ZEIT" ] || RESTIC_FEHLER="Antwort von restic nicht auswertbar"
  fi
fi

# ---------------------------------------------------------------------------
#  Teil 1 -- Vollstaendige Rohausgabe
# ---------------------------------------------------------------------------
{
echo "Bestandsaufnahme Raspberry Pi"
echo "Zeitpunkt: $(date -Is)"
echo "Host: $(hostname)"
echo "Tiefpruefung: $([ "$TIEF" -eq 1 ] && echo ja || echo 'nein (--ohne-tiefpruefung)')"

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
r "cat /boot/firmware/cmdline.txt"

s "SPEICHER"
r "free -h"
r "df -hT | grep -vE 'tmpfs|udev'"
r "lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,MODEL"
r "cat /etc/fstab"
r "ps aux --sort=-%mem | head -12"
r "cat /sys/fs/cgroup/cgroup.controllers"

s "NETZWERK"
r "ip -brief addr"
r "ip route | head -8"
r "hostname -f"
r "tailscale status 2>/dev/null | head -10"

s "OFFENE PORTS"
LIMIT=60 r "sudo ss -tulpn | grep LISTEN"

s "SYSTEMD"
LIMIT=80 r "systemctl list-units --type=service --state=running --no-pager --no-legend"
r "systemctl --failed --no-pager"
LIMIT=20 r "systemctl list-timers --all --no-pager --no-legend"

echo "--- Ergebnis der eigenen Dienste (nicht nur der naechste Lauf) ---"
for u in pi-backup pi-abgleich pi-reboot-check pi-gravity docker-stats-messung; do
  [ -f "/etc/systemd/system/$u.service" ] || continue
  echo ">>> $u"
  systemctl show "$u.service" -p Result -p ExecMainStatus -p ExecMainExitTimestamp \
    -p ActiveState 2>/dev/null | sed 's/^/    /'
done
echo

s "DOCKER"
r "sudo docker --version"
LIMIT=60 r "sudo docker ps -a --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'"
LIMIT=60 r "sudo docker images --format 'table {{.Repository}}:{{.Tag}}\t{{.Size}}\t{{.CreatedSince}}'"
r "sudo docker volume ls"
r "sudo docker network ls"
r "sudo docker system df"
r "sudo docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}'"

echo "--- Container-Details (ENV nur mit Namen, ohne Werte) ---"
for c in $(sudo docker ps -a --format '{{.Names}}' </dev/null 2>/dev/null); do
  echo ""
  echo ">>> $c"
  sudo docker inspect "$c" --format '  Image: {{.Config.Image}}
  Status: {{.State.Status}} (Restarts: {{.RestartCount}})
  RestartPolicy: {{.HostConfig.RestartPolicy.Name}}
  Privileged: {{.HostConfig.Privileged}}
  SecurityOpt: {{.HostConfig.SecurityOpt}}
  Speicherlimit: {{.HostConfig.Memory}}
  Logrotation: {{.HostConfig.LogConfig.Type}} max-size={{index .HostConfig.LogConfig.Config "max-size"}} max-file={{index .HostConfig.LogConfig.Config "max-file"}}
  NetworkMode: {{.HostConfig.NetworkMode}}
  Compose: {{index .Config.Labels "com.docker.compose.project"}} | {{index .Config.Labels "com.docker.compose.project.config_files"}}' </dev/null 2>&1
  echo "  Mounts:"
  sudo docker inspect "$c" --format '{{range .Mounts}}    {{.Source}} => {{.Destination}}
{{end}}' </dev/null 2>&1
  echo "  ENV (nur Namen):"
  sudo docker inspect "$c" --format '{{range .Config.Env}}{{println .}}{{end}}' </dev/null 2>/dev/null | cut -d= -f1 | sed 's/^/    /'
done

s "DIENSTE"
r "pihole -v 2>/dev/null | head -5"
r "pihole-FTL sqlite3 /etc/pihole/gravity.db 'select count(*) from vw_gravity;'"
r "pihole-FTL sqlite3 /etc/pihole/gravity.db 'select id, enabled, substr(address,1,70) from adlist order by id;'"
r "sudo testparm -s 2>/dev/null | grep -A8 usb-share"
r "sudo sshd -T 2>/dev/null | grep -E '^(passwordauthentication|permitrootlogin|pubkeyauthentication|allowusers|port )'"

s "SICHERHEIT"
echo "--- pi-guard: ufw ist bewusst NICHT installiert, Docker umgeht es ---"
r "sudo iptables -L PI-GUARD -n -v"
r "sudo iptables -L PI-GUARD-IN -n -v"
r "sudo ip6tables -L PI-GUARD-IN -n -v"
r "systemctl is-enabled pi-guard.service"
r "sudo iptables -L INPUT -n | head -10"
r "sudo fail2ban-client status 2>/dev/null || echo 'fail2ban nicht installiert (offener Punkt, siehe docs/09)'"
r "systemctl is-enabled unattended-upgrades 2>/dev/null || echo 'unattended-upgrades nicht aktiv'"
r "apt list --upgradable 2>/dev/null | tail -n +2 | head -20"
r "sudo ls -l /etc/sudoers.d/"

s "BACKUP"
r "for t in restic rclone borg rsync; do if command -v \$t >/dev/null; then echo \"\$t: \$(\$t version 2>/dev/null | head -1)\"; else echo \"\$t: nicht installiert\"; fi; done"
r "sudo grep -oE '^[A-Za-z_]+' /etc/pi-backup.env | sort | tr '\n' ' '"
if [ -n "$RESTIC_FEHLER" ]; then
  echo "--- restic snapshots ---"; echo "    $RESTIC_FEHLER"; echo
else
  echo "--- restic: neuester Snapshot $SNAP_ID vom $SNAP_ZEIT, $SNAP_ANZAHL Snapshots insgesamt ---"
  printf '%s' "$SNAP_JSON" | python3 -c '
import json,sys
d=json.load(sys.stdin)
for s in sorted(d,key=lambda x:x["time"]):
    print("   ", s["time"][:19], s["short_id"], "%2d Pfade" % len(s["paths"]), ",".join(s.get("tags",[])))
print("    Pfade des neuesten Snapshots:")
for p in sorted(d,key=lambda x:x["time"])[-1]["paths"]:
    print("      ", p)
' 2>&1
  echo
fi
LIMIT=25 r "sudo journalctl -u pi-backup.service -n 25 --no-pager -o cat"

s "SYSTEMDATEIEN UND REPOSITORY"
r "ls -la /home/simon/raspi/"
r "cd /home/simon/raspi && git status -sb"
r "cd /home/simon/raspi && git log --oneline -5"
r "cd /home/simon/raspi && git rev-list --left-right --count HEAD...@{u} 2>/dev/null || echo 'kein upstream gesetzt'"
r "sudo /usr/local/sbin/pi-abgleich.sh check 2>&1 | tail -20"

s "LOGS"
LIMIT=30 r "sudo journalctl -p err -b --no-pager | tail -30"
r "journalctl --disk-usage"
LIMIT=15 r "sudo dmesg -T | grep -iE 'i/o error|EXT4-fs error|mmc.*error|voltage' | tail -15"

echo ""
echo "=================== ENDE ==================="
} > "$FULL" 2>&1

# ---------------------------------------------------------------------------
#  Teil 2 -- Kompakte Kennzahlen (fuer den Abgleich mit der Doku)
# ---------------------------------------------------------------------------

: > "$WERTE"

{
echo "# Kennzahlen -- $(date +%d.%m.%Y)"
echo ""
echo "Erzeugt von \`inventar/collect.sh\`. Diese Datei ist die Grundlage fuer den"
echo "Abgleich mit der bestehenden Dokumentation. Ein Wert, der mit \`?\` beginnt,"
echo "konnte **nicht ermittelt** werden -- das ist keine Aussage ueber den Zustand."
echo ""
echo "## System"
echo ""
echo "| Kennzahl | Wert |"
echo "|---|---|"
echo "| Modell | $(w "tr -d '\0' < /proc/device-tree/model") |"
echo "| OS | $(w "grep PRETTY_NAME /etc/os-release | cut -d'\"' -f2") |"
echo "| Kernel | $(w "uname -r") |"
echo "| Uptime | $(w "uptime -p") |"
echo "| Load | $(w "cut -d' ' -f1-3 /proc/loadavg") |"
echo "| Temperatur | $(w "sudo vcgencmd measure_temp | cut -d= -f2") |"
echo "| Throttled | $(w "sudo vcgencmd get_throttled | cut -d= -f2") |"
echo "| RAM verfuegbar | $(w "free -h | awk '/^Mem:/{print \$7\" von \"\$2}'") |"
echo "| Root belegt | $(w "df -h / | awk 'NR==2{print \$3\" von \"\$2\" (\"\$5\")\"}'") |"
echo "| SSD belegt | $(w "df -h /mnt/usb-hdd | awk 'NR==2{print \$3\" von \"\$2\" (\"\$5\")\"}'") |"
echo "| Speicher-Cgroup | $(w "grep -qw memory /sys/fs/cgroup/cgroup.controllers && echo 'aktiv (Limits je Container moeglich)' || echo 'FEHLT -- Limits wirken nicht'") |"
echo "| Ausstehende Updates | $(w "apt list --upgradable 2>/dev/null | tail -n +2 | wc -l") |"
echo "| Fehlgeschlagene Dienste | $(w "systemctl --failed --no-legend --no-pager | wc -l") |"
echo "| Journal belegt | $(w "journalctl --disk-usage | grep -oE '[0-9.]+[MG]' | head -1") |"
echo ""

wert root_used_mb   "$(df -BM --output=used / 2>/dev/null | tail -1 | tr -dc '0-9')"
wert ssd_used_mb    "$(df -BM --output=used /mnt/usb-hdd 2>/dev/null | tail -1 | tr -dc '0-9')"
wert journal_kb     "$(journalctl --disk-usage 2>/dev/null | grep -oE '[0-9.]+[KMG]' | head -1 | awk '/G/{sub("G","");print $1*1048576} /M/{sub("M","");print $1*1024} /K/{sub("K","");print $1}')"

echo "## Zeitgesteuerte Dienste"
echo ""
echo "Ersetzt die frueheren Cronjob-Zeilen: seit dem 18.08.2026 laeuft alles ueber"
echo "systemd-Timer. \`crontab -l\` ist hier leer und war es auch damals schon --"
echo "die Null sagte nichts ueber die tatsaechliche Automatisierung aus."
echo ""
echo "| Timer | Zeitplan | Letzter Lauf | Ergebnis |"
echo "|---|---|---|---|"
for u in $(systemctl list-timers --all --no-pager --no-legend 2>/dev/null | awk '{print $NF}' | grep -E '^(pi-|docker-stats)' | sort -u); do
  sv="${u%.service}"
  plan="$(w "systemctl cat ${sv}.timer 2>/dev/null | grep -m1 -E 'OnCalendar|OnUnitActiveSec|OnBootSec' | sed 's/^[[:space:]]*//'")"
  lauf="$(w "systemctl show ${sv}.service -p ExecMainExitTimestamp --value | cut -d' ' -f2,3")"
  res="$(w "systemctl show ${sv}.service -p Result --value")"
  code="$(w "systemctl show ${sv}.service -p ExecMainStatus --value")"
  echo "| $sv | $plan | $lauf | $res (Code $code) |"
done
echo ""
echo "| Cron-Ablage | Eintraege |"
echo "|---|---|"
echo "| crontab des Kontos simon | $(crontab -l 2>/dev/null | grep -c '^[^#]') |"
echo "| crontab von root | $(sudo crontab -l 2>/dev/null | grep -c '^[^#]') |"
echo "| Dateien in /etc/cron.d | $(w "ls /etc/cron.d/ | tr '\n' ' '") |"
echo ""

echo "## Container"
echo ""
echo "| Name | Image | Status | Ports |"
echo "|---|---|---|---|"
sudo docker ps -a --format '| {{.Names}} | {{.Image}} | {{.Status}} | {{.Ports}} |' </dev/null 2>/dev/null \
  || echo "| ? | Abfrage scheiterte -- laeuft sie ohne sudo? | | |"
echo ""
wert container_laufend "$(sudo docker ps -q </dev/null 2>/dev/null | wc -l)"
wert container_gesamt  "$(sudo docker ps -aq </dev/null 2>/dev/null | wc -l)"

echo "## Container -- Haertung und Verbrauch"
echo ""
echo "Speicherlimit \`0\` heisst: kein Limit gesetzt. Alle acht zusammen belegten"
echo "am 18.08.2026 rund 38 % des Arbeitsspeichers, Paperless allein 25 %."
echo ""
echo "| Container | Logrotation | no-new-privileges | Speicherlimit | RAM jetzt |"
echo "|---|---|---|---|---|"
STATS="$(sudo docker stats --no-stream --format '{{.Name}}\t{{.MemUsage}}\t{{.MemPerc}}' </dev/null 2>/dev/null)"
for c in $(sudo docker ps --format '{{.Names}}' </dev/null 2>/dev/null); do
  logt="$(w "sudo docker inspect -f '{{.HostConfig.LogConfig.Type}} {{index .HostConfig.LogConfig.Config \"max-size\"}}x{{index .HostConfig.LogConfig.Config \"max-file\"}}' $c")"
  nnp="$(w "sudo docker inspect -f '{{.HostConfig.SecurityOpt}}' $c | grep -q no-new-privileges && echo ja || echo NEIN")"
  mem="$(w "sudo docker inspect -f '{{.HostConfig.Memory}}' $c | awk '{ if (\$1==0) print \"kein Limit\"; else printf \"%d MB\", \$1/1048576 }'")"
  ram="$(printf '%b' "$STATS" | awk -F'\t' -v n="$c" '$1==n{print $2" ("$3")"}')"
  echo "| $c | $logt | $nnp | $mem | ${ram:-? nicht ermittelbar} |"
done
echo ""

echo "## Image-Alter"
echo ""
echo "| Image | Alter | Groesse |"
echo "|---|---|---|"
sudo docker images --format '| {{.Repository}}:{{.Tag}} | {{.CreatedSince}} | {{.Size}} |' </dev/null 2>/dev/null \
  || echo "| ? | Abfrage scheiterte | |"
echo ""
wert images_anzahl "$(sudo docker images -q </dev/null 2>/dev/null | sort -u | wc -l)"
wert images_mb "$(sudo docker system df --format '{{.Type}} {{.Size}}' </dev/null 2>/dev/null | awk '/^Images/{v=$2; if (v ~ /GB/) {sub("GB","",v); print int(v*1024)} else if (v ~ /MB/) {sub("MB","",v); print int(v)} else print 0}')"

echo "## Offene Ports"
echo ""
echo '```'
w "sudo ss -tulpn | grep LISTEN | awk '{print \$5, \$7}' | sed 's/users:((//;s/))//' | sort -u"
echo ""
echo '```'
echo ""

echo "## Sicherheitslage"
echo ""
echo "\`ufw\` fehlt hier bewusst: Docker schreibt eigene iptables-Regeln, an denen"
echo "ufw vorbeigeht. Die Absicherung leistet \`pi-guard\` in den Ketten PI-GUARD"
echo "und PI-GUARD-IN. Die Trefferzaehler stehen darunter."
echo ""
echo "| Pruefpunkt | Zustand |"
echo "|---|---|"
echo "| pi-guard aktiv | $(w "sudo iptables -L PI-GUARD-IN -n >/dev/null 2>&1 && echo 'ja, Ketten vorhanden' || echo 'NEIN -- Ketten fehlen'") |"
echo "| pi-guard Dienst | $(w "systemctl is-enabled pi-guard.service") |"
echo "| Gesperrte Ports aus dem LAN | $(w "sudo iptables -L PI-GUARD-IN -n | grep -m1 -oE 'dports [0-9,]+' | cut -d' ' -f2") |"
echo "| Treffer der DROP-Regel (v4, an den Host) | $(w "sudo iptables -L PI-GUARD-IN -n -v | awk '/DROP/{print \$1\" Pakete\"; exit}'") |"
echo "| Treffer der DROP-Regel (v4, weitergeleitet) | $(w "sudo iptables -L PI-GUARD -n -v | awk '/DROP/{print \$1\" Pakete\"; exit}'") |"
echo "| SSH Passwortlogin | $(w "sudo sshd -T | grep '^passwordauthentication' | awk '{print \$2}'") |"
echo "| SSH AllowUsers | $(w "sudo sshd -T 2>/dev/null | grep -m1 '^allowusers' | cut -d' ' -f2- | grep . || echo 'nicht gesetzt -- jedes Konto darf sich anmelden'") |"
echo "| SSH root-Login | $(w "sudo sshd -T | grep '^permitrootlogin' | awk '{print \$2}'") |"
echo "| unattended-upgrades | $(w "systemctl is-enabled unattended-upgrades") |"
echo "| fail2ban | $(w "command -v fail2ban-client >/dev/null && echo installiert || echo 'nicht installiert (bewusst offen, siehe docs/09)'") |"
echo "| iptables INPUT policy | $(w "sudo iptables -L INPUT -n | head -1 | grep -o 'policy [A-Z]*'") |"
echo "| Gruppe docker | $(w "getent group docker | cut -d: -f4 | grep -q . && getent group docker | cut -d: -f4 || echo 'leer (so gewollt)'") |"
echo ""

echo "## Pi-hole"
echo ""
echo "| Kennzahl | Wert |"
echo "|---|---|"
echo "| Domains in gravity | $(w "pihole-FTL sqlite3 /etc/pihole/gravity.db 'select count(*) from vw_gravity;'") |"
echo "| Blocklisten aktiv | $(w "pihole-FTL sqlite3 /etc/pihole/gravity.db 'select count(*) from adlist where enabled=1;'") |"
echo "| Blocklisten abgeschaltet | $(w "pihole-FTL sqlite3 /etc/pihole/gravity.db 'select count(*) from adlist where enabled=0;'") |"
echo "| Letztes Gravity-Update | $(w "systemctl show pi-gravity.service -p ExecMainExitTimestamp --value | cut -d' ' -f2,3") |"
echo "| Speicher pihole-FTL | $(w "ps -o rss= -C pihole-FTL | awk '{printf \"%d MB\", \$1/1024}'") |"
echo ""
wert gravity_domains "$(pihole-FTL sqlite3 /etc/pihole/gravity.db 'select count(*) from vw_gravity;' </dev/null 2>/dev/null)"

echo "## Backup-Lage"
echo ""
echo "| Pruefpunkt | Zustand |"
echo "|---|---|"
echo "| Werkzeug | $(w "restic version 2>/dev/null | head -1 || echo 'restic nicht installiert'") |"
if [ -n "$RESTIC_FEHLER" ]; then
  echo "| Neuester Snapshot | ? $RESTIC_FEHLER |"
  echo "| Snapshots gesamt | ? $RESTIC_FEHLER |"
else
  echo "| Neuester Snapshot | $SNAP_ZEIT (\`$SNAP_ID\`), $SNAP_PFADE Pfade |"
  echo "| Snapshots gesamt | $SNAP_ANZAHL |"
fi
echo "| Backup-Dienst zuletzt | $(w "systemctl show pi-backup.service -p ExecMainExitTimestamp --value | cut -d' ' -f2,3") -- $(w "systemctl show pi-backup.service -p Result --value") |"
echo "| Naechster Lauf | $(w "systemctl list-timers pi-backup.timer --no-pager --no-legend | awk '{print \$1\" \"\$2\" \"\$3}'") |"
echo "| Groesse laut letztem Lauf | $(w "sudo journalctl -u pi-backup.service -n 200 --no-pager -o cat | grep -iE 'gesamt|Total Size' | tail -1 | sed 's/^[[:space:]]*//; s/[[:space:]][[:space:]]*/ /g'") |"
echo "| Rueckfallebene ausserhalb restic | $(w "ls -1 /mnt/usb-hdd/backups-manuell/ 2>/dev/null | tr '\n' ' ' || echo 'keine'") |"
echo ""

echo "## Repository und Systemdateien"
echo ""
echo "| Pruefpunkt | Zustand |"
echo "|---|---|"
echo "| Arbeitsverzeichnis | $(w "cd /home/simon/raspi && git status --porcelain | wc -l | awk '{if (\$1==0) print \"sauber\"; else print \$1\" geaenderte Dateien\"}'") |"
echo "| Letzter Commit | $(w "cd /home/simon/raspi && git log --oneline -1") |"
echo "| Gegenueber origin | $(w "cd /home/simon/raspi && git rev-list --left-right --count HEAD...@{u} 2>/dev/null | awk '{print \$1\" nur lokal, \"\$2\" nur remote\"}'") |"
echo "| Abgleich Repo <-> System | $(w "sudo /usr/local/sbin/pi-abgleich.sh check 2>&1 | grep -E 'in Ordnung|weichen ab' | head -1") |"
echo ""

echo "## Behauptungspruefung"
echo ""
echo "Die Tabelle prueft nicht, was leicht zu messen ist, sondern was **still**"
echo "scheitert, was **oft angefasst** wird und was wir **ungeprueft hinnehmen**."
echo ""
echo "Marken: \`ok\` geprueft und in Ordnung · \`ACHTUNG\` geprueft und abweichend ·"
echo "\`?\` **konnte nicht geprueft werden** -- sagt nichts ueber den Zustand aus."
echo ""
echo "| Pruefung | Marke | Befund |"
echo "|---|---|---|"

# --- 1. Ist das Backup wiederherstellbar? -----------------------------------
# Der Pfad wurde bis zum 20.08.2026 NIE zurueckgespielt. Ein Repository, das
# sich sichern laesst, ist damit noch nicht wiederherstellbar.
PROBE="/home/simon/raspi/README.md"
if [ -n "$RESTIC_FEHLER" ]; then
  pruef "Backup wiederherstellbar" "?" "$RESTIC_FEHLER"
else
  CHK="$(restic_ check --no-lock 2>&1 | tail -2 | tr '\n' ' ')"
  if printf '%s' "$CHK" | grep -q "no errors were found"; then
    TMPF="$(mktemp)"
    if restic_ dump latest "$PROBE" > "$TMPF" 2>/dev/null && [ -s "$TMPF" ]; then
      if cmp -s "$TMPF" "$PROBE"; then
        pruef "Backup wiederherstellbar" "ok" "check ohne Fehler, Stichprobe \`$(basename "$PROBE")\` aus \`$SNAP_ID\` zurueckgeholt und byte-identisch"
      elif [ "$(stat -c %Y "$PROBE" 2>/dev/null || echo 0)" -gt "$SNAP_EPOCH" ]; then
        pruef "Backup wiederherstellbar" "ok" "check ohne Fehler, Stichprobe zurueckgeholt; weicht ab, weil das Original nach dem Snapshot geaendert wurde"
      else
        pruef "Backup wiederherstellbar" "ACHTUNG" "Stichprobe weicht vom Original ab, obwohl dieses seit dem Snapshot unveraendert ist"
      fi
    else
      pruef "Backup wiederherstellbar" "ACHTUNG" "check ohne Fehler, aber \`restic dump\` lieferte die Stichprobe nicht"
    fi
    rm -f "$TMPF"
  else
    pruef "Backup wiederherstellbar" "ACHTUNG" "restic check meldet: $CHK"
  fi
fi

# --- 2. Kommt eine ntfy-Meldung tatsaechlich an? ----------------------------
# Belegt die Annahme durch den Server. Dass das Handy sie anzeigt, kann ein
# Skript nicht wissen -- deshalb wird hier genau das gesagt und nichts mehr.
NT="$(sudo -n bash -c '
  set -a; . /etc/pi-backup.env 2>/dev/null; set +a
  [ -n "${NTFY_URL:-}" ] || { echo "KEINEURL"; exit 0; }
  [ -r "${NTFY_TOKEN_FILE:-/nonexistent}" ] || { echo "KEINTOKEN"; exit 0; }
  curl -s -m 20 -o /dev/null -w "%{http_code}" \
    -H "Authorization: Bearer $(cat "$NTFY_TOKEN_FILE")" \
    -H "Title: Bestandsaufnahme" -H "Priority: min" -H "Tags: mag" \
    -d "Testversand aus collect.sh -- keine Aktion noetig." \
    "$NTFY_URL/${NTFY_TOPIC:-raspberrypi}"
' 2>/dev/null)"
case "$NT" in
  200) pruef "ntfy nimmt Meldungen an" "ok" "HTTP 200 vom ntfy-Server (Zustellung ans Geraet kann ein Skript nicht pruefen)" ;;
  KEINEURL)   pruef "ntfy nimmt Meldungen an" "ACHTUNG" "NTFY_URL ist in /etc/pi-backup.env nicht gesetzt -- alle Alarme laufen ins Leere" ;;
  KEINTOKEN)  pruef "ntfy nimmt Meldungen an" "ACHTUNG" "Token-Datei nicht lesbar -- alle Alarme laufen ins Leere" ;;
  "")  pruef "ntfy nimmt Meldungen an" "?" "Testversand lieferte keine Antwort" ;;
  *)   pruef "ntfy nimmt Meldungen an" "ACHTUNG" "ntfy antwortete mit HTTP $NT" ;;
esac

# --- 3. Endet jeder Timer-Dienst erfolgreich? -------------------------------
# list-timers zeigt nur den naechsten Lauf. Der Backup-Dienst endete tagelang
# mit Code 1, ohne dass es auffiel.
TFEHLER=""; TGEPRUEFT=0
for u in pi-backup pi-abgleich pi-reboot-check pi-gravity docker-stats-messung; do
  [ -f "/etc/systemd/system/$u.service" ] || continue
  st="$(systemctl show "$u.service" -p Result --value 2>/dev/null)"
  co="$(systemctl show "$u.service" -p ExecMainStatus --value 2>/dev/null)"
  TGEPRUEFT=$((TGEPRUEFT+1))
  [ "$st" = "success" ] && [ "$co" = "0" ] || TFEHLER="$TFEHLER $u($st/$co)"
done
if [ "$TGEPRUEFT" -eq 0 ]; then
  pruef "Timer-Dienste enden erfolgreich" "?" "keine eigenen Dienste gefunden -- Namen im Skript pruefen"
elif [ -z "$TFEHLER" ]; then
  pruef "Timer-Dienste enden erfolgreich" "ok" "$TGEPRUEFT von $TGEPRUEFT zuletzt mit Code 0 beendet"
else
  pruef "Timer-Dienste enden erfolgreich" "ACHTUNG" "nicht erfolgreich:$TFEHLER"
fi

# --- 4. Ist jede .env vorhanden, die eine Compose-Datei erwartet? -----------
# Fehlt sie, startet der Stack mit leeren Werten. Bei Paperless bedeutet das
# laut dessen eigener Compose-Doku einen stillen Rueckfall auf SQLite -- die
# Oberflaeche laeuft, das Archiv ist leer.
ENVFEHLT=""; ENVGEPRUEFT=0
for f in /home/simon/raspi/stacks/*/docker-compose.yml; do
  [ -f "$f" ] || continue
  d="$(dirname "$f")"
  grep -q 'env_file' "$f" || grep -q '\${' "$f" || continue
  ENVGEPRUEFT=$((ENVGEPRUEFT+1))
  if [ ! -f "$d/.env" ]; then
    ENVFEHLT="$ENVFEHLT $(basename "$d")(fehlt)"
  elif [ ! -s "$d/.env" ]; then
    ENVFEHLT="$ENVFEHLT $(basename "$d")(leer)"
  fi
done
if [ "$ENVGEPRUEFT" -eq 0 ]; then
  pruef ".env je Stack vorhanden" "?" "keine Compose-Datei mit env_file gefunden"
elif [ -z "$ENVFEHLT" ]; then
  pruef ".env je Stack vorhanden" "ok" "$ENVGEPRUEFT Stacks erwarten eine .env, alle vorhanden und nicht leer"
else
  pruef ".env je Stack vorhanden" "ACHTUNG" "fehlt oder leer:$ENVFEHLT"
fi

# --- 5. Bleibt etwas im Paperless-Einwurfordner liegen? --------------------
CONS="/mnt/usb-hdd/paperless/consume"
if [ ! -d "$CONS" ]; then
  pruef "Paperless-Einwurf leert sich" "?" "Verzeichnis $CONS nicht vorhanden"
else
  ALT="$(find "$CONS" -maxdepth 1 -type f -mmin +15 2>/dev/null | wc -l)"
  NEU="$(find "$CONS" -maxdepth 1 -type f 2>/dev/null | wc -l)"
  if [ "$ALT" -gt 0 ]; then
    pruef "Paperless-Einwurf leert sich" "ACHTUNG" "$ALT Datei(en) liegen laenger als 15 Minuten in consume/ -- der Import hakt"
  else
    pruef "Paperless-Einwurf leert sich" "ok" "$NEU Datei(en) im Ordner, keine aelter als 15 Minuten"
  fi
fi

# --- 6. Zeigt jedes Compose-Label auf eine Datei im Repository? ------------
# Pfad-Drift ist hier zweimal unbemerkt aufgetreten, zuletzt bei der
# Zusammenlegung der Repositories am 18.08.2026.
LDRIFT=""; LGEPRUEFT=0
for c in $(sudo docker ps -a --format '{{.Names}}' </dev/null 2>/dev/null); do
  f="$(sudo docker inspect -f '{{index .Config.Labels "com.docker.compose.project.config_files"}}' "$c" </dev/null 2>/dev/null)"
  [ -n "$f" ] || continue
  LGEPRUEFT=$((LGEPRUEFT+1))
  [ -e "$f" ] || LDRIFT="$LDRIFT $c($f)"
  case "$f" in /home/simon/raspi/*) ;; *) LDRIFT="$LDRIFT $c(ausserhalb des Repos: $f)" ;; esac
done
if [ "$LGEPRUEFT" -eq 0 ]; then
  pruef "Compose-Pfade zeigen ins Repository" "?" "kein Container lieferte ein Compose-Label -- lief die Abfrage ohne sudo?"
elif [ -z "$LDRIFT" ]; then
  pruef "Compose-Pfade zeigen ins Repository" "ok" "$LGEPRUEFT Container, alle Pfade vorhanden und unterhalb von /home/simon/raspi"
else
  pruef "Compose-Pfade zeigen ins Repository" "ACHTUNG" "abweichend:$LDRIFT"
fi

# --- 7. Steht ein Geheimnis im Git-Verlauf? --------------------------------
# Wichtig: Kommentarzeilen und Platzhalter ausschliessen. Eine Pruefung, die
# jedes Mal denselben Fehlalarm liefert (hier: die auskommentierte
# Beispielkonfiguration in stacks/homepage/config/proxmox.yaml), wird nach dem
# zweiten Mal ignoriert -- und taugt dann nichts mehr.
GITTREFFER="$(cd /home/simon/raspi 2>/dev/null && git grep -I -h -inE \
  '^[^#/]*(password|passwd|secret|token|api[_-]?key)[[:space:]]*[=:][[:space:]]*[^[:space:]"'"'"'<${#]{8,}' \
  $(git rev-list --all 2>/dev/null) -- 2>/dev/null \
  | grep -viE 'changeme|beispiel|example|your[_-]|xxx+|placeholder|MASKIERT|<.*>' \
  | sort -u | wc -l)"
if [ -z "$GITTREFFER" ]; then
  pruef "Keine Geheimnisse im Git-Verlauf" "?" "Suche lief nicht -- Repository lesbar?"
elif [ "$GITTREFFER" -eq 0 ]; then
  pruef "Keine Geheimnisse im Git-Verlauf" "ok" "alle $(cd /home/simon/raspi && git rev-list --all | wc -l) Commits durchsucht, kein Treffer ausserhalb von Kommentaren und Platzhaltern"
else
  pruef "Keine Geheimnisse im Git-Verlauf" "ACHTUNG" "$GITTREFFER verdaechtige Zeile(n) im Verlauf -- pruefen mit \`git grep -inE '(password|secret|token)' \$(git rev-list --all)\`"
fi

# --- 8. Hat pi-guard Treffer? ----------------------------------------------
# Zaehler 0 ist zweideutig: entweder wirkt die Regel abschreckend, oder sie
# wird nie erreicht. Beides wird hier benannt statt bewertet.
if ! sudo iptables -L PI-GUARD-IN -n >/dev/null 2>&1; then
  pruef "pi-guard sperrt aus dem LAN" "ACHTUNG" "Kette PI-GUARD-IN fehlt -- die Verwaltungsoberflaechen sind aus dem LAN erreichbar"
else
  TR="$(sudo iptables -L PI-GUARD-IN -n -v 2>/dev/null | awk '/DROP/{print $1; exit}')"
  DU="$(sudo iptables -L PI-GUARD-IN -n -v 2>/dev/null | awk '/tailscale0/{print $1; exit}')"
  if [ "${TR:-0}" -gt 0 ] 2>/dev/null; then
    pruef "pi-guard sperrt aus dem LAN" "ok" "Kette aktiv, ${TR} Pakete verworfen, ${DU:-0} ueber Tailscale durchgelassen"
  else
    pruef "pi-guard sperrt aus dem LAN" "ok" "Kette aktiv, bisher 0 Verwerfungen, ${DU:-0} Pakete ueber Tailscale -- die 0 belegt nur, dass niemand aus dem LAN angeklopft hat"
  fi
fi

# --- 9. Blockt und loest Pi-hole tatsaechlich auf? -------------------------
if ! command -v dig >/dev/null 2>&1; then
  pruef "Pi-hole blockt und loest auf" "?" "dig nicht installiert (Paket dnsutils)"
else
  GESPERRT="$(dig +short +time=2 +tries=1 doubleclick.net @127.0.0.1 2>/dev/null | head -1)"
  ERLAUBT="$(dig +short +time=2 +tries=1 example.com @127.0.0.1 2>/dev/null | grep -cE '^[0-9]+\.')"
  if [ "$GESPERRT" = "0.0.0.0" ] && [ "${ERLAUBT:-0}" -gt 0 ]; then
    pruef "Pi-hole blockt und loest auf" "ok" "doubleclick.net -> 0.0.0.0, example.com loest normal auf"
  elif [ -z "$GESPERRT" ] && [ "${ERLAUBT:-0}" -eq 0 ]; then
    pruef "Pi-hole blockt und loest auf" "ACHTUNG" "keine Antwort auf beide Testabfragen -- laeuft der Resolver?"
  elif [ "$GESPERRT" != "0.0.0.0" ]; then
    pruef "Pi-hole blockt und loest auf" "ACHTUNG" "doubleclick.net antwortet mit '${GESPERRT:-nichts}' statt 0.0.0.0 -- die Sperre greift nicht"
  else
    pruef "Pi-hole blockt und loest auf" "ACHTUNG" "example.com loest nicht auf -- Pi-hole sperrt zu viel oder der Upstream fehlt"
  fi
fi

# --- 10. Meldet die SD-Karte Fehler? ---------------------------------------
# Sie ist das wahrscheinlichste Ausfallteil dieses Aufbaus.
IOFEHLER="$(sudo dmesg -T 2>/dev/null | grep -icE 'i/o error|EXT4-fs error|mmc[0-9]+: error|Buffer I/O error')"
SPANNUNG="$(sudo dmesg -T 2>/dev/null | grep -icE 'under-voltage|voltage normalised')"
if [ -z "$IOFEHLER" ]; then
  pruef "SD-Karte ohne Fehler" "?" "dmesg nicht lesbar"
elif [ "$IOFEHLER" -eq 0 ] && [ "${SPANNUNG:-0}" -eq 0 ]; then
  pruef "SD-Karte ohne Fehler" "ok" "seit dem letzten Start keine I/O- oder Dateisystemfehler, keine Unterspannung"
elif [ "$IOFEHLER" -gt 0 ]; then
  pruef "SD-Karte ohne Fehler" "ACHTUNG" "$IOFEHLER Fehlermeldung(en) im Kernel-Log -- \`sudo dmesg -T | grep -i error\`"
else
  pruef "SD-Karte ohne Fehler" "ACHTUNG" "$SPANNUNG Meldung(en) zu Unterspannung -- Netzteil pruefen"
fi

# --- 11. Waechst etwas ungewoehnlich? --------------------------------------
# Verglichen wird gegen den vorigen Lauf, nicht gegen einen absoluten Wert:
# 14 MB Journal sagen nichts, eine Verdopplung seit gestern schon.
if [ ! -s "$VOR_WERTE" ]; then
  pruef "Kein ungewoehnliches Wachstum" "?" "kein vorheriger Lauf zum Vergleich (aktuell-werte.tsv fehlte)"
else
  GEWACHSEN=""; VGEPRUEFT=0
  for k in root_used_mb ssd_used_mb journal_kb images_mb; do
    alt="$(vorwert "$k")"; neu="$(awk -F'\t' -v k="$k" '$1==k{print $2}' "$WERTE" 2>/dev/null)"
    case "$alt$neu" in *[!0-9]*|"") continue ;; esac
    [ "${alt:-0}" -gt 0 ] || continue
    VGEPRUEFT=$((VGEPRUEFT+1))
    proz=$(( (neu - alt) * 100 / alt ))
    [ "$proz" -ge 20 ] && GEWACHSEN="$GEWACHSEN $k(+${proz}%: $alt->$neu)"
  done
  if [ "$VGEPRUEFT" -eq 0 ]; then
    pruef "Kein ungewoehnliches Wachstum" "?" "keine vergleichbaren Zahlen im vorigen Lauf"
  elif [ -z "$GEWACHSEN" ]; then
    pruef "Kein ungewoehnliches Wachstum" "ok" "$VGEPRUEFT Groessen verglichen, keine um mehr als 20 % gewachsen"
  else
    pruef "Kein ungewoehnliches Wachstum" "ACHTUNG" "gewachsen:$GEWACHSEN"
  fi
fi

echo ""
echo "**$GEPRUEFT geprueft und in Ordnung · $ABWEICHUNG abweichend · $UNGEPRUEFT nicht pruefbar.**"
if [ "$UNGEPRUEFT" -gt 0 ]; then
  echo ""
  echo "Die mit \`?\` markierten Zeilen sind **keine** Entwarnung. Wer sie als"
  echo "unauffaellig liest, dokumentiert einen Zustand, den niemand gemessen hat."
fi
echo ""
} > "$FACTS" 2>&1

cp "$FACTS" "$SNAP_DIR/aktuell-fakten.md"

echo ""
echo "  Bestandsaufnahme abgeschlossen$([ "$TIEF" -eq 0 ] && echo ' (ohne Tiefpruefung)')."
echo ""
echo "    Vollausgabe : $FULL  ($(du -h "$FULL" | cut -f1))"
echo "    Kennzahlen  : $FACTS"
echo "    Kopie       : $SNAP_DIR/aktuell-fakten.md"
echo "    Zahlen      : $WERTE"
echo ""
echo "  Behauptungspruefung: $GEPRUEFT ok · $ABWEICHUNG abweichend · $UNGEPRUEFT nicht pruefbar"
echo ""
[ "$ABWEICHUNG" -gt 0 ] && sed -n '/^| .* | ACHTUNG | /p' "$FACTS" | sed 's/^/    /'
echo ""
