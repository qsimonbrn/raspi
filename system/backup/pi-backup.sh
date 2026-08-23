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
#  docs/12-backup.md
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
mkdir -p "$STAGE"/{paperless,vaultwarden,pihole,etc,system}
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

# --- 2. Vaultwarden: konsistenter Datenbankabzug ------------------------------
# Ein bytweises Kopieren der laufenden SQLite-Datei kann sie zerrissen
# erwischen: WAL-Journal und Hauptdatei geraten auseinander, und das faellt
# erst beim Wiederherstellen auf. ".backup" nimmt stattdessen die
# Sicherungs-API von SQLite und liefert einen in sich stimmigen Stand, auch
# waehrend geschrieben wird. Die Live-Datei ist deshalb aus der
# restic-Sicherung ausgeschlossen -- gesichert wird ausschliesslich dieser
# Abzug. Attachments, Sends und der JWT-Schluessel liegen daneben im
# Datenverzeichnis und werden direkt gesichert.
VW_DB=/mnt/usb-hdd/vaultwarden/db.sqlite3
if docker ps --format '{{.Names}}' | grep -qx vaultwarden; then
  if [ -r "$VW_DB" ]; then
    log "Vaultwarden: Datenbankabzug"
    if sqlite3 "$VW_DB" ".backup '$STAGE/vaultwarden/db.sqlite3'" 2>/dev/null \
         && [ -s "$STAGE/vaultwarden/db.sqlite3" ]; then
      # Gegenprobe: Ein Abzug, der sich nicht lesen laesst, ist kein Backup.
      # integrity_check meldet bei einem heilen Stand genau "ok" -- jede andere
      # Ausgabe, auch eine leere, ist ein Fehler.
      PRUEF=$(sqlite3 "$STAGE/vaultwarden/db.sqlite3" 'PRAGMA integrity_check;' 2>&1 | head -1)
      if [ "$PRUEF" = "ok" ]; then
        # integrity_check allein genuegt NICHT. Nachgemessen am 23.08.2026 an
        # absichtlich beschaedigten Kopien: Strukturschaden, Abschneiden und
        # ein zerstoerter Kopf werden zuverlaessig erkannt -- eine voellig
        # LEERE Datei besteht die Pruefung dagegen mit "ok". Ein Abzug kann
        # also formal heil und trotzdem wertlos sein. Erst die Abfrage einer
        # echten Tabelle zeigt, ob ueberhaupt ein Tresor drinsteht.
        KONTEN=$(sqlite3 "$STAGE/vaultwarden/db.sqlite3" 'SELECT count(*) FROM users;' 2>/dev/null)
        case "${KONTEN:-leer}" in
          *[!0-9]*|leer)
            warn "Vaultwarden: Abzug ohne lesbare Benutzertabelle -- kein brauchbares Backup" ;;
          0)
            warn "Vaultwarden: Abzug enthaelt kein einziges Konto -- kein brauchbares Backup" ;;
          *)
            # Die Zahl der Eintraege steht zur Information im Protokoll: Ein
            # ploetzlicher Rueckgang faellt beim Durchsehen auf.
            ANZ=$(sqlite3 "$STAGE/vaultwarden/db.sqlite3" 'SELECT count(*) FROM ciphers;' 2>/dev/null)
            log "Vaultwarden: Datenbank gesichert ($(du -h "$STAGE/vaultwarden/db.sqlite3" | cut -f1), $KONTEN Konto/Konten, ${ANZ:-?} Eintraege)" ;;
        esac
      else
        warn "Vaultwarden: Abzug beschaedigt -- integrity_check meldet: ${PRUEF:-keine Ausgabe}"
      fi
    else
      warn "Vaultwarden: sqlite3 .backup fehlgeschlagen"
    fi
  else
    warn "Vaultwarden: $VW_DB nicht lesbar"
  fi
else
  warn "Vaultwarden-Container laeuft nicht -- uebersprungen"
fi

# --- 3. Pi-hole: Teleporter-Export -------------------------------------------
# Enthaelt Einstellungen, lokale DNS-Eintraege und Blocklisten-Quellen --
# wenige hundert Kilobyte statt 424 MB Query-Datenbank.
log "Pi-hole: Teleporter-Export"
if (cd "$STAGE/pihole" && pihole-FTL --teleporter >/dev/null 2>&1); then
  log "Pi-hole: Export erfolgreich ($(ls "$STAGE/pihole" | head -1))"
else
  warn "Pi-hole: Teleporter-Export fehlgeschlagen"
fi

# --- 4. Systemkonfiguration ---------------------------------------------------
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

# --- 5. Systemzustand fuer den Wiederaufbau ----------------------------------
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

# --- 6. Sicherung ------------------------------------------------------------
log "restic: Sicherung laeuft"
restic backup \
  --tag automatisch \
  --host raspberrypi \
  --exclude-caches \
  --exclude '*/tmp/*' \
  --exclude '*/logs/*' \
  --exclude '*.lock' \
  --exclude '/mnt/usb-hdd/vaultwarden/db.sqlite3*' \
  --exclude '/mnt/usb-hdd/vaultwarden/icon_cache' \
  "$STAGE" \
  /mnt/usb-hdd/bichon \
  /mnt/usb-hdd/ntfy \
  /mnt/usb-hdd/paperless/export \
  /mnt/usb-hdd/paperless/media \
  /mnt/usb-hdd/vaultwarden \
  /var/lib/docker/volumes/portainer_portainer_data/_data \
  /mnt/usb-hdd/claude-skills \
  /home/simon/raspi
RC=$?

if [ $RC -ne 0 ]; then
  echo "FEHLER: restic backup endete mit Code $RC"
  notify "Backup fehlgeschlagen" \
         "restic endete mit Code $RC. Details: journalctl -u pi-backup.service" \
         "urgent" "rotating_light"
  rm -rf "$STAGE"
  exit $RC
fi

# --- 7. Aufbewahrung ---------------------------------------------------------
# 7 taegliche, 4 woechentliche, 6 monatliche Staende. Aeltere werden entfernt
# und der freiwerdende Platz wird zurueckgegeben (--prune).
log "restic: alte Staende aufraeumen"
restic forget \
  --tag automatisch \
  --keep-daily 7 --keep-weekly 4 --keep-monthly 6 \
  --prune >/dev/null 2>&1 || warn "Aufraeumen fehlgeschlagen"

# --- 8. Aufraeumen und Bericht ------------------------------------------------
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
