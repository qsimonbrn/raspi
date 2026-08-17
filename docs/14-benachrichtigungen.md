# 14 — Benachrichtigungen (ntfy)

*Eingerichtet: 13.08.2026*

Push-Nachrichten aufs Handy, ohne Umweg über einen fremden Dienst.

---

## 1. Warum

Das tägliche Backup lief bis dahin still. Schlug es fehl, landete der Dienst in
`systemctl --failed` — einer Stelle, in die niemand freiwillig schaut. Ein Backup,
dessen Ausfall unbemerkt bleibt, ist so gut wie keins: Man merkt es erst, wenn man
wiederherstellen will.

ntfy schließt diese Lücke. Es ist ein sehr schlanker Server (rund 30 MB
Arbeitsspeicher), der Nachrichten entgegennimmt und an Apps ausliefert.

---

## 2. Zugang

| | |
|---|---|
| Weboberfläche | `http://192.168.178.80:2586` |
| Benutzer | `simon` (Rolle `admin`) |
| Thema | `raspberrypi` |
| Passwort ausgeben | `grep NTFY_PASSWORD ~/docker-stacks/ntfy/.env` |

---

## 3. Einrichtung auf dem Handy

> **Ohne diesen Schritt kommt nichts an.** Der Server läuft, aber er hat noch kein
> Gerät, an das er ausliefern könnte.

1. App installieren: **ntfy** aus dem App Store bzw. Play Store
   (Entwickler: *Philipp C. Heckel*, kostenlos, quelloffen)
2. In der App: *Einstellungen → Allgemein → **Standard-Server*** auf
   `http://192.168.178.80:2586` setzen
3. *Einstellungen → Benutzerkonten → **Konto hinzufügen***
   Server `http://192.168.178.80:2586`, Benutzer `simon`, Passwort aus der `.env`
4. Zurück zur Übersicht → **+** → Thema `raspberrypi` abonnieren,
   dabei „Andere Server verwenden" wählen und dieselbe Adresse eintragen

Schritt 3 ist zwingend: Der Server steht auf `auth-default-access: deny-all` — ohne
Anmeldung liefert er nichts aus und nimmt nichts an.

### Testen

```bash
TOKEN=$(sudo cat /root/.ntfy-token)
curl -H "Authorization: Bearer $TOKEN" -H "Title: Test" \
     -d "Wenn das ankommt, ist alles richtig eingerichtet." \
     http://192.168.178.80:2586/raspberrypi
```

### Auch im Browser

`http://192.168.178.80:2586` im Browser öffnen, anmelden, Thema abonnieren — dann
erscheinen Nachrichten auch auf dem Rechner. Praktisch als Verlauf, wenn man wissen
will, ob das Backup letzte Woche durchlief.

---

## 4. ⚠️ Wichtige Einschränkung: nur im Heimnetz

ntfy läuft **ausschließlich lokal**. Es gibt keine Portfreigabe nach außen, und das
soll auch so bleiben.

**Was das bedeutet:** Das Handy erhält Nachrichten, solange es im WLAN zu Hause ist
oder Tailscale aktiv ist. Unterwegs ohne VPN kommt nichts an — die
Nachricht wird aber nachgeliefert, sobald das Gerät wieder erreichbar ist
(`cache-duration: 24h`).

Für den Zweck reicht das: Das Backup läuft um 03:17 Uhr nachts, das Handy liegt
üblicherweise im heimischen WLAN.

**Wer Benachrichtigungen zuverlässig auch unterwegs will**, hat drei Möglichkeiten:

| Weg | Abwägung |
|---|---|
| Tailscale dauerhaft aktiv | Kein zusätzlicher Dienst, kostet etwas Akku. Seit dem 18.08.2026 auch tatsächlich von unterwegs nutzbar |
| Öffentliches `ntfy.sh` als Relay | Funktioniert überall, aber die Meldungen laufen über einen fremden Server. Bei „Backup fehlgeschlagen" ist der Inhalt unkritisch — Metadaten fallen trotzdem an |
| Reverse Proxy mit HTTPS und Portfreigabe | Volle Funktion, öffnet aber einen weiteren Weg von außen ins Heimnetz |

Solange nur das Backup meldet, ist die erste Variante die richtige: nichts tun.

---

## 5. Was das Backup meldet

Im Skript `pi-backup.sh` steckt eine Funktion `notify()`. Drei Fälle:

| Fall | Priorität | Verhalten auf dem Handy |
|---|---|---|
| **Backup fehlgeschlagen** | `urgent` | Ton und Vibration, auch bei Nicht-Stören |
| **Mit Warnungen abgeschlossen** | `high` | Normale Benachrichtigung mit Ton |
| **Erfolgreich** | `min` | Stiller Eintrag im Verlauf, keine Störung |

Der Erfolgsfall wird **absichtlich** gemeldet, wenn auch lautlos. Sonst hätte man
wieder das Ausgangsproblem: Bleibt eine Meldung aus, weil der Timer gar nicht mehr
läuft, fällt das bei „nur bei Fehlern melden" niemandem auf. Ein täglicher stiller
Eintrag ist ein Lebenszeichen — sein Fehlen ist die eigentliche Information.

Schlägt der Versand der Nachricht selbst fehl, läuft das Backup trotzdem weiter. Eine
kaputte Benachrichtigung darf keine Sicherung verhindern.

---

## 6. Eigene Nachrichten schicken

Von jedem Skript auf dem Pi:

```bash
TOKEN=$(sudo cat /root/.ntfy-token)
curl -H "Authorization: Bearer $TOKEN" \
     -H "Title: Titel der Nachricht" \
     -H "Priority: default" \
     -H "Tags: warning" \
     -d "Text der Nachricht" \
     http://192.168.178.80:2586/raspberrypi
```

| Feld | Werte |
|---|---|
| `Priority` | `min`, `low`, `default`, `high`, `urgent` |
| `Tags` | Emoji-Kürzel wie `warning`, `white_check_mark`, `rotating_light`, `floppy_disk` |
| Thema | frei wählbar — ein neues Thema entsteht durch Benutzung und muss in der App abonniert werden |

**Naheliegende Erweiterungen:** Meldung bei fehlgeschlagenen SSH-Anmeldungen, bei
Temperaturen über 70 °C, bei knappem Speicherplatz, oder wenn ein Container
unerwartet neu startet.

---

## 7. Zugriffsschutz

`auth-default-access: deny-all` in `server.yml` — ohne Anmeldung geht nichts, weder
Lesen noch Schreiben. Ohne diese Zeile könnte jedes Gerät im Heimnetz mitlesen und
Nachrichten einschleusen.

| Zugangsdaten | Ablage |
|---|---|
| Passwort für Handy und Browser | `docker-stacks/ntfy/.env` (Modus 600, nicht im Git) |
| Token für das Backup-Skript | `/root/.ntfy-token` (Modus 600) |

Das Token steht bewusst **nicht** in `/etc/pi-backup.env`, sondern in einer eigenen
Datei — dieselbe Systematik wie beim restic-Repository-Passwort. So bleibt die
Konfigurationsdatei lesbar und teilbar, ohne Geheimnisse zu enthalten.

`enable-signup: false` — es kann sich niemand selbst ein Konto anlegen.

---

## 8. Betrieb

```bash
# Läuft der Dienst?
docker ps --filter name=ntfy

# Gesundheitsprüfung
curl http://192.168.178.80:2586/v1/health

# Letzte Nachrichten ansehen
TOKEN=$(sudo cat /root/.ntfy-token)
curl -H "Authorization: Bearer $TOKEN" \
     "http://192.168.178.80:2586/raspberrypi/json?poll=1"

# Benutzer und Token verwalten
docker exec ntfy ntfy user list
docker exec ntfy ntfy token list simon

# Protokoll
docker logs ntfy
```

### Aufbau

| | |
|---|---|
| Container | `ntfy` (`binwiederhier/ntfy`) |
| Port | 2586 → 80 im Container |
| Konfiguration | `docker-stacks/ntfy/server.yml` |
| Daten | `/mnt/usb-hdd/ntfy/` (Nachrichten-Zwischenspeicher, Benutzerdatenbank) |

Der Nachrichten-Zwischenspeicher wird **nicht** gesichert — er enthält nur
Meldungen der letzten 24 Stunden. Die Benutzerdatenbank ist ebenfalls schnell neu
angelegt; wichtiger ist, dass `server.yml` und die Compose-Datei im Git liegen.

---

## 9. Was noch zu tun ist

- [ ] ntfy-App auf dem Handy installieren
- [ ] Standard-Server und Konto in der App eintragen (Abschnitt 3)
- [ ] Thema `raspberrypi` abonnieren
- [ ] Mit dem `curl`-Befehl aus Abschnitt 3 prüfen, ob eine Nachricht ankommt
- [ ] Am nächsten Morgen nachsehen, ob die stille Erfolgsmeldung des nächtlichen
      Backups im Verlauf steht
