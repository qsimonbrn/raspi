#!/usr/bin/env bash
# =============================================================================
#  Backup des Raspberry Pi nach OneDrive (restic ueber rclone)
#
#  Aufruf ueber systemd: pi-backup.service / pi-backup.timer
#  Manuell:              sudo /usr/local/bin/pi-backup.sh
#
#  Gesichert werden ausschliesslich Daten, die sich NICHT wiederbeschaffen
#  lassen. Bewusst NICHT gesichert: Docker-Images, Pi-hole-Query-Datenbank,
#  Blocklisten, Trainingsdaten, alte Backup-Kopien. Begruendung siehe
#  raspi-doku/docs/12-backup.md
# =============================================================================

set -uo pipefail

CONFIG=/etc/pi-backup.env
[ -r "$CONFIG" ] || { echo "FEHLER: $CONFIG nicht lesbar"; exit 1; }
set -a; . "$CONFIG"; set +a

STAGE="${STAGE_DIR:-/mnt/usb-hdd/backup-stage}"
FEHLER=0

log()  { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }
warn() { printf '[%s] WARNUNG: %s\n' "$(date +%H:%M:%S)" "$*"; FEHLER=$((FEHLER+1)); }

# Push-Benachrichtigung ueber ntfy. Schlaegt der Versand fehl, laeuft das
# Backup trotzdem weiter -- eine fehlende Meldung darf keine Sicherung verhindern.
notify() {  # $1=Titel  $2=Text  $3=Prioritaet  $4=Tags
  [ -n "${NTFY_URL:-}" ] || return 0
  [ -r "${NTFY_TOKEN_FILE:-/nonexistent}" ] || return 0
  curl -s -m 20 -o /dev/null \
    -H "Authorization: Bearer $(cat "$NTFY_TOKEN_FILE")" \
    -H "Title: $1" \
    -H "Priority: ${3:-default}" \
    -H "Tags: ${4:-floppy_disk}" \
    -d "$2" \
    "$NTFY_URL/${NTFY_TOPIC:-raspberrypi}" || true
}

# --- Nur eine Instanz gleichzeitig -------------------------------------------
exec 9>/var/lock/pi-backup.lock
if ! flock -n 9; then
  echo "Ein Backup laeuft bereits -- Abbruch."
  exit 0
fi

log "=== Backup gestartet ==="

# --- Zwischenablage vorbereiten ----------------------------------------------
rm -rf "$STAGE"
mkdir -p "$STAGE"/{paperless,pihole,etc,system}
chmod 700 "$STAGE"

# --- 1. Paperless: Export inklusive Metadaten --------------------------------
# Ein reines Kopieren des Datenverzeichnisses ergaebe KEIN wiederherstellbares
# Archiv -- Tags, Korrespondenten und OCR-Zuordnungen liegen in PostgreSQL.
if docker ps --format '{{.Names}}' | grep -qx paperless; then
  log "Paperless: Dokumentenexport"
  if docker exec paperless document_exporter /usr/src/paperless/export \
       --delete --no-progress-bar >/dev/null 2>&1; then
    log "Paperless: Export erfolgreich"
  else
    warn "Paperless: document_exporter fehlgeschlagen"
  fi

  log "Paperless: Datenbankabzug"
  if docker exec paperless-paperless-db-1 pg_dump -U paperless -d paperless \
       > "$STAGE/paperless/datenbank.sql" 2>/dev/null; then
    log "Paperless: Datenbank gesichert ($(du -h "$STAGE/paperless/datenbank.sql" | cut -f1))"
  else
    warn "Paperless: pg_dump fehlgeschlagen"
  fi
else
  warn "Paperless-Container laeuft nicht -- uebersprungen"
fi

# --- 2. Pi-hole: Teleporter-Export -------------------------------------------
# Enthaelt Einstellungen, lokale DNS-Eintraege und Blocklisten-Quellen --
# wenige hundert Kilobyte statt 424 MB Query-Datenbank.
log "Pi-hole: Teleporter-Export"
if (cd "$STAGE/pihole" && pihole-FTL --teleporter >/dev/null 2>&1); then
  log "Pi-hole: Export erfolgreich ($(ls "$STAGE/pihole" | head -1))"
else
  warn "Pi-hole: Teleporter-Export fehlgeschlagen"
fi

# --- 3. Systemkonfiguration ---------------------------------------------------
log "Systemkonfiguration einsammeln"
cp -a /var/lib/tailscale      "$STAGE/etc/"       2>/dev/null || warn "Tailscale-Zustand fehlt"
cp -a /etc/samba              "$STAGE/etc/"       2>/dev/null || warn "Samba-Konfiguration fehlt"
cp -a /etc/ssh/sshd_config    "$STAGE/etc/"       2>/dev/null
cp -a /etc/ssh/sshd_config.d  "$STAGE/etc/"       2>/dev/null
cp -a /etc/fstab              "$STAGE/etc/"       2>/dev/null
cp -a /etc/hosts              "$STAGE/etc/"       2>/dev/null
cp -a /etc/unbound            "$STAGE/etc/"       2>/dev/null
cp -a /etc/pi-backup.env      "$STAGE/etc/"       2>/dev/null
# Samba-Benutzerdatenbank (Passwort-Hashes) -- ohne sie muessen alle
# Samba-Zugaenge neu angelegt werden.
cp -a /var/lib/samba/private/passdb.tdb "$STAGE/etc/" 2>/dev/null

# --- Konten, Rechte und Protokolle (seit 18.08.2026) --------------------------
# Schluessel und sudo-Regeln des Automatisierungskontos "claude". Die Schluessel
# waeren im Notfall in Minuten neu erzeugt -- entscheidend sind die
# Sitzungsaufzeichnungen: Protokolle, die nur auf dem betroffenen System liegen,
# sind wertlos, weil ein Angreifer sie zuerst loescht.
mkdir -p "$STAGE/konten"
cp -a /home/claude/.ssh       "$STAGE/konten/claude-ssh"  2>/dev/null || warn "Schluessel des Kontos claude fehlen"
cp -a /etc/sudoers.d          "$STAGE/konten/"            2>/dev/null || warn "sudo-Regeln fehlen"
cp -a /var/log/sudo-io        "$STAGE/konten/"            2>/dev/null || warn "Sitzungsaufzeichnungen fehlen"
cp -a /var/log/sudo-claude.log "$STAGE/konten/"           2>/dev/null

# --- 4. Systemzustand fuer den Wiederaufbau ----------------------------------
log "Systemzustand dokumentieren"
apt-mark showmanual                    > "$STAGE/system/pakete-manuell.txt"   2>/dev/null
dpkg -l                                > "$STAGE/system/pakete-alle.txt"      2>/dev/null
docker ps -a --format '{{.Names}}\t{{.Image}}\t{{.Status}}' \
                                       > "$STAGE/system/container.txt"        2>/dev/null
docker images --format '{{.Repository}}:{{.Tag}}\t{{.ID}}' \
                                       > "$STAGE/system/images.txt"           2>/dev/null
lsblk -f                               > "$STAGE/system/datentraeger.txt"     2>/dev/null
ip -brief addr                         > "$STAGE/system/netzwerk.txt"         2>/dev/null
crontab -l -u simon                    > "$STAGE/system/crontab-simon.txt"    2>/dev/null
systemctl list-unit-files --state=enabled --no-pager --no-legend \
                                       > "$STAGE/system/dienste-aktiv.txt"    2>/dev/null

# --- 5. Sicherung ------------------------------------------------------------
log "restic: Sicherung laeuft"
restic backup \
  --tag automatisch \
  --host raspberrypi \
  --exclude-caches \
  --exclude '*/tmp/*' \
  --exclude '*/logs/*' \
  --exclude '*.lock' \
  "$STAGE" \
  /mnt/usb-hdd/bichon \
  /mnt/usb-hdd/ntfy \
  /mnt/usb-hdd/paperless/export \
  /mnt/usb-hdd/paperless/media \
  /var/lib/docker/volumes/portainer_portainer_data/_data \
  /home/simon/docker-stacks \
  /home/simon/raspi-doku
RC=$?

if [ $RC -ne 0 ]; then
  echo "FEHLER: restic backup endete mit Code $RC"
  notify "Backup fehlgeschlagen" \
         "restic endete mit Code $RC. Details: journalctl -u pi-backup.service" \
         "urgent" "rotating_light"
  rm -rf "$STAGE"
  exit $RC
fi

# --- 6. Aufbewahrung ---------------------------------------------------------
# 7 taegliche, 4 woechentliche, 6 monatliche Staende. Aeltere werden entfernt
# und der freiwerdende Platz wird zurueckgegeben (--prune).
log "restic: alte Staende aufraeumen"
restic forget \
  --tag automatisch \
  --keep-daily 7 --keep-weekly 4 --keep-monthly 6 \
  --prune >/dev/null 2>&1 || warn "Aufraeumen fehlgeschlagen"

# --- 7. Aufraeumen und Bericht ------------------------------------------------
rm -rf "$STAGE"

log "Belegung im Repository:"
restic stats --mode raw-data 2>/dev/null | sed 's/^/    /'

GROESSE=$(restic stats --mode raw-data 2>/dev/null | awk '/Total Size/{print $3" "$4}')

if [ "$FEHLER" -gt 0 ]; then
  echo "=== Backup abgeschlossen, aber mit $FEHLER Warnung(en) ==="
  notify "Backup mit Warnungen" \
         "$FEHLER Warnung(en). Repository: ${GROESSE:-unbekannt}. Details: journalctl -u pi-backup.service" \
         "high" "warning"
  exit 1
fi

# Erfolg wird mit niedrigster Prioritaet gemeldet: keine Toene, kein Vibrieren,
# aber ein sichtbarer Eintrag im Verlauf. So faellt auf, wenn er ausbleibt.
notify "Backup erfolgreich" \
       "Repository: ${GROESSE:-unbekannt}" \
       "min" "white_check_mark"

log "=== Backup erfolgreich abgeschlossen ==="
exit 0
