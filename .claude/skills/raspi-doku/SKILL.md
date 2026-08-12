---
name: raspi-doku
description: Pflegt die Infrastruktur-Dokumentation des Raspberry Pi (192.168.178.80) im Repository raspi-doku. Nimmt den Ist-Zustand per SSH auf, gleicht ihn mit der bestehenden Doku ab, aktualisiert nur die tatsächlich veränderten Stellen, pflegt den CHANGELOG und committet. Verwenden bei - Doku aktualisieren, Raspi-Doku, Pi-Dokumentation, Infrastruktur dokumentieren, Bestandsaufnahme Pi, was läuft auf dem Pi, neuer Dienst auf dem Pi dokumentieren, Doku abgleichen, Pi-Inventar.
---

# Raspberry Pi — Infrastruktur-Dokumentation pflegen

Diese Skill hält das Repository `raspi-doku` deckungsgleich mit dem tatsächlichen
Zustand des Raspberry Pi. Sie ist auf **inkrementelle Aktualisierung** ausgelegt:
Nicht neu schreiben, sondern abgleichen und gezielt ändern.

---

## Voraussetzungen prüfen

Der Zugriff läuft über den lokalen MCP-Server `pi-ssh`, der auf Simons Mac läuft
(Claude Desktop brückt ihn in Cowork-Sessions).

Tools laden:

```
ToolSearch: select:mcp__remote-devices__pi-ssh__ssh_exec,mcp__remote-devices__pi-ssh__ssh_read_file,mcp__remote-devices__pi-ssh__ssh_write_file,mcp__remote-devices__pi-ssh__ssh_status
```

Dann `ssh_status` aufrufen. Erwartete Antwort: `Verbindung OK`, Hostname `raspberrypi`,
sudo ohne Passwort `ja`.

**Wenn die Tools fehlen:** Claude Desktop läuft nicht oder wurde nach einer
Konfigurationsänderung nicht neu gestartet. Den Nutzer bitten, die App mit `Cmd+Q`
komplett zu beenden und neu zu öffnen. Nicht auf andere Wege ausweichen — aus der
Cloud-Session gibt es keinen direkten Netzzugang zum Heimnetz.

**Wenn die Verbindung mitten in der Arbeit abreißt:** Das kommt vor. Bereits
geschriebene Dateien bleiben erhalten. Weiterarbeiten, sobald die Tools wieder
verfügbar sind; Zwischenergebnisse notfalls lokal zwischenspeichern und später
übertragen.

---

## Ablauf

### 1. Bestandsaufnahme erzeugen

```bash
cd ~/raspi-doku && git pull --rebase 2>/dev/null; bash inventar/collect.sh
```

Das Skript ist **rein lesend**. Es erzeugt:

| Datei | Zweck |
|---|---|
| `inventar/snapshots/<ts>-voll.txt` | Vollständige Rohausgabe (nicht versioniert) |
| `inventar/snapshots/<ts>-fakten.md` | Kompakte Kennzahlen (versioniert) |
| `inventar/snapshots/aktuell-fakten.md` | Kopie der letzten Kennzahlen |

### 2. Abgleich statt Neuaufnahme

Die neue `aktuell-fakten.md` mit der vorherigen Version vergleichen:

```bash
cd ~/raspi-doku && git diff -- inventar/snapshots/aktuell-fakten.md
```

**Das ist der zentrale Schritt.** Der Diff zeigt genau, was sich geändert hat. Nur
Kapitel anfassen, die davon betroffen sind. Ein unveränderter Wert braucht keine
Bearbeitung.

Bei sehr großen Änderungen die Vollausgabe gezielt lesen — mit `ssh_read_file`
oder per `grep` über `ssh_exec`, nicht die ganze Datei in den Kontext ziehen.

### 3. Betroffene Kapitel aktualisieren

Zuordnung Änderung → Kapitel:

| Was sich geändert hat | Zu aktualisieren |
|---|---|
| Modell, RAM, Temperatur, Datenträger, Belegung | `docs/01-hardware.md` |
| Debian-/Kernel-Version, Updates, Dienste, Timer | `docs/02-betriebssystem.md` |
| IP-Adressen, Ports, Docker-Netze, IPv6 | `docs/03-netzwerk.md` |
| Pi-hole, unbound, WireGuard, Samba, SSH | `docs/04-dienste-system.md` |
| Container, Images, Volumes, Compose-Dateien | `docs/05-docker.md` |
| SSD-Belegung, Verzeichnisse, Backup-Werkzeuge, Cronjobs | `docs/06-daten-und-speicher.md` |
| ufw, fail2ban, SSH-Härtung, unattended-upgrades | `docs/07-sicherheit.md` |
| Neue oder erledigte Befunde | `docs/08-bewertung.md` |
| Erledigte Maßnahmen, neue Empfehlungen | `docs/09-empfehlungen.md` |
| Neue oder entfallene Dienste, geänderte Ports | `docs/10-zugriff.md` |
| Backup-Lage, gesicherte Bausteine | `docs/11-disaster-recovery.md` |

**Immer mitziehen**, wenn sich Kennzahlen geändert haben:

- Der Kasten „Zustand auf einen Blick" in `README.md`
- Die Liste „Die drei wichtigsten offenen Punkte" in `README.md`, falls sich die
  Prioritäten verschoben haben
- Das Erfassungsdatum (`*Erfasst: TT.MM.JJJJ*`) in jedem berührten Kapitel

### 4. Befunde konsistent halten

Wenn ein Befund **erledigt** ist (z. B. Backups laufen jetzt):

1. Im Fachkapitel die Warnung durch die Beschreibung des neuen Zustands ersetzen
2. In `docs/08-bewertung.md` aus der Mängelliste entfernen und — falls zutreffend —
   unter „Was gut gelöst ist" aufnehmen
3. In `docs/09-empfehlungen.md` die Maßnahme streichen
4. Im `CHANGELOG.md` unter „Behoben" vermerken
5. `docs/11-disaster-recovery.md` prüfen — ändert sich die Tabelle „gesichert?"

Ein Befund, der an einer Stelle als erledigt und an anderer noch als offen steht,
macht die ganze Dokumentation unglaubwürdig. Diese fünf Stellen gehören zusammen.

### 5. CHANGELOG pflegen

Neuen Eintrag oben einfügen, Format siehe Vorlage am Ende der Datei.

| Änderungsart | Versionssprung |
|---|---|
| Nur aktualisierte Messwerte | Patch (1.0.0 → 1.0.1) |
| Neuer Dienst, neues Kapitel, neuer Befund | Minor (1.0.0 → 1.1.0) |
| Grundlegender Umbau | Major (1.0.0 → 2.0.0) |

### 6. Committen

```bash
cd ~/raspi-doku
git add -A
git commit -m "doku: <knappe Beschreibung der Änderung>"
git push
```

Commit-Präfixe: `doku:` für Inhalt, `inventar:` für das Sammelskript, `skill:` für
diese Skill, `chore:` für Aufräumarbeiten.

**Wenn `git push` mit `Permission denied (publickey)` scheitert:** Der SSH-Schlüssel
des Pi ist bei GitHub nicht (mehr) hinterlegt. Den öffentlichen Schlüssel ausgeben
(`cat ~/.ssh/id_ed25519.pub`) und den Nutzer bitten, ihn unter
github.com/settings/keys einzutragen. Lokal committen ist trotzdem sinnvoll — der
Push kann nachgeholt werden.

---

## Schreibregeln

Diese Dokumentation soll auch in einem Jahr noch nützlich sein. Dafür gelten
Konventionen, die beim Ergänzen einzuhalten sind:

**Messwert und Bewertung trennen.** Erst die Zahl, dann die Einordnung — nicht
vermischt. Der Leser soll erkennen können, was gemessen und was eingeschätzt ist.

**Jeder Befund erklärt die Konsequenz.** Nicht „kein fail2ban installiert", sondern
warum das in *diesem* Setup zählt. Ein Befund ohne Begründung ist eine Behauptung.

**Werte mit Datum versehen.** Uptime, Belegung, Image-Alter — alles altert. Ohne
Erfassungsdatum ist ein Wert später wertlos.

**Querverweisen statt wiederholen.** Jedes Kapitel ist eigenständig lesbar, aber
Details stehen genau einmal. Verweise als relative Links: `[06](06-daten-und-speicher.md)`.

**Keine Geheimnisse.** Öffentliche Schlüssel, Adressen, Ports und Benutzernamen ja.
Private Schlüssel, Passwörter, Tokens und Container-Umgebungswerte nie — auch nicht
in Snapshots.

**Ampel-Konvention beibehalten:** 🔴 kritisch (Datenverlust droht) · 🟠 wichtig
(Sicherheit) · 🟡 Aufräumen · 🟢 optional.

**Auf Deutsch, in ganzen Sätzen.** Tabellen für Fakten, Fließtext für Begründungen.

---

## Häufige Anlässe

### Neuer Dienst wurde installiert

1. Bestandsaufnahme laufen lassen
2. `docs/05-docker.md` (Container) oder `docs/04-dienste-system.md` (nativ) ergänzen
3. `docs/03-netzwerk.md` — Portliste erweitern
4. `docs/10-zugriff.md` — URL und Zugriffsmatrix ergänzen
5. `docs/11-disaster-recovery.md` — braucht der Dienst ein Backup? Dann in die Tabelle
6. Falls ein Dashboard existiert: Eintrag dort nachziehen
7. CHANGELOG: Minor-Sprung

### Nur turnusmäßige Aktualisierung

1. Bestandsaufnahme laufen lassen
2. Diff der Kennzahlen ansehen
3. Geänderte Werte in den betroffenen Kapiteln nachziehen
4. Image-Alter in `docs/05-docker.md` prüfen — es wächst immer weiter und ist ein
   wiederkehrender Befund
5. CHANGELOG: Patch-Sprung

### Nur eine bestimmte Frage beantworten

Nicht die vollständige Bestandsaufnahme fahren. Gezielt per `ssh_exec` abfragen und
die Antwort geben. Die Doku nur anfassen, wenn sich dabei herausstellt, dass sie von
der Realität abweicht.

---

## Referenz — nützliche Abfragen

```bash
# Container mit Ports und Status
docker ps -a --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'

# Image-Alter
docker images --format 'table {{.Repository}}:{{.Tag}}\t{{.CreatedSince}}'

# Compose-Zuordnung je Container
docker ps -a --format '{{.Names}}' | while read c; do \
  echo "$c -> $(docker inspect $c --format '{{index .Config.Labels "com.docker.compose.project.config_files"}}')"; done

# Offene Ports mit Prozess
sudo ss -tulpn | grep LISTEN

# Sicherheitslage kompakt
sudo sshd -T | grep -E '^(passwordauthentication|permitrootlogin)'; \
  sudo ufw status 2>/dev/null || echo 'kein ufw'; \
  systemctl is-enabled unattended-upgrades 2>/dev/null || echo 'keine Auto-Updates'

# Backup-Lage
crontab -l; sudo crontab -l; ls -la /mnt/usb-hdd/rclone_bak/

# Temperatur und Drosselung (0x0 = nie gedrosselt)
sudo vcgencmd measure_temp; sudo vcgencmd get_throttled
```

## Referenz — feste Pfade

| Was | Wo |
|---|---|
| Doku-Repository | `/home/simon/raspi-doku` |
| Compose-Stacks | `/home/simon/docker-stacks` (eigenes Repo) |
| Nutzdaten | `/mnt/usb-hdd` |
| Pi-hole-Konfiguration | `/etc/pihole/` |
| WireGuard | `/etc/wireguard/` |
| Samba | `/etc/samba/smb.conf` |
