# 14 — Benachrichtigungen (ntfy)

*Eingerichtet: 13.08.2026 · Zugangsdaten ausgelagert: 23.08.2026*

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
| Passwort | im Vaultwarden-Tresor, Eintrag „ntfy" — **nicht mehr in der `.env`** |
| Passwort neu setzen | `sudo docker exec -it ntfy ntfy user change-pass simon` |

> **Seit dem 23.08.2026 stehen Benutzer, Passwort und Token nicht mehr in
> `stacks/ntfy/.env`.** Der Container hat kein `env_file` und liest die Datei gar
> nicht — die Benutzer liegen in `/mnt/usb-hdd/ntfy/lib/user.db`. Die Zeilen waren
> eine Zweitschrift, die niemand pflegt: Beim Passwortwechsel am 23.08.2026 wurde
> sie noch am selben Tag still falsch. Der Token liegt weiterhin in
> `/root/.ntfy-token`, weil die Skripte ihn von dort lesen.

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

## 4. Zustellung aufs iPhone

*Gemessen am 25.08.2026.*

ntfy läuft **ausschließlich lokal**. Es gibt keine Portfreigabe nach außen, und das
soll auch so bleiben. Die Zustellung an das iPhone läuft trotzdem — über einen Umweg,
den iOS erzwingt.

### Wie es funktioniert

iOS erlaubt Apps keine dauerhafte Hintergrundverbindung. Die ntfy-App empfängt von
einem *selbst gehosteten* Server im Hintergrund deshalb nur dann, wenn dieser einen
Anstoß über `ntfy.sh` schickt, der per Apple-Push zugestellt wird. Den Inhalt holt
die App danach direkt beim eigenen Server ab. Dafür sorgt eine einzige Zeile in
`stacks/ntfy/server.yml`:

```yaml
upstream-base-url: "https://ntfy.sh"
```

An `ntfy.sh` geht dabei die Nachrichten-Kennung mit gehashtem Thema, **nicht der
Inhalt**. Die `base-url` bleibt `http://192.168.178.80:2586`; erreichbar ist sie
für das Handy auch von unterwegs, weil der Pi die Route `192.168.178.0/24` ins
Tailnet anbietet und diese freigegeben ist (`PrimaryRoutes`, gemessen 25.08.2026).

### Nachweis vom 25.08.2026

| Messung | Ergebnis |
|---|---|
| Versand über den Pfad von `pi-backup.sh` (gleiche URL, Thema `raspberrypi`, gleicher Token) | `http=200` |
| Pakete des ntfy-Containers an `ntfy.sh` (iptables-Zählregel `172.24.0.2 → 159.203.148.75:443`) | **13** |
| Negativkontrolle: dieselbe Zählregel auf eine unbeteiligte Adresse | **0** |
| Anzeige auf dem gesperrten iPhone, App vorher geschlossen | **erschienen** (Simon bestätigt) |

**Damit ist die Kette, deretwegen ntfy existiert, zum ersten Mal geschlossen.** Der
Versand aus `pi-backup.sh` nimmt keinen anderen Weg als der Test — gleicher Server,
gleiches Thema, gleicher Token, gleiche URL.

Die App musste **nicht** neu eingerichtet werden: Sie berechnet das Upstream-Thema
selbst und war nach der Serveränderung sofort erreichbar.

### Was die Änderung nicht leistet

- **Ohne Tailscale auf dem iPhone kommt unterwegs nichts an.** Der Apple-Push trägt
  nur die Kennung; den Text holt die App beim Pi, und dorthin führt von außerhalb
  des WLAN nur das Tailnet. Die Meldung bleibt bis zu 24 Stunden im Cache
  (`cache-duration: 24h`) und wird nachgeholt.
- **Der Verkehr im WLAN ist unverschlüsselt** (`http`, Port 2586). Wer das ändern
  will, legt ntfy wie Vaultwarden hinter `tailscale serve` auf einen eigenen Port;
  am 25.08.2026 bewusst nicht getan, weil es dieselbe Abhängigkeit von Tailscale
  hat und nur den Transport im Heimnetz betrifft.

### Vorgeschichte — warum es zwei Wochen lang still ausfiel

<details>
<summary>Befund vom 23.08.2026 (behoben am 25.08.2026)</summary>

Bis zum 23.08.2026 stand hier, das Handy erhalte Nachrichten, solange es im
heimischen WLAN ist. Das war nachweislich falsch. Simon hat an diesem Tag **keine
einzige** Meldung erhalten, obwohl der Server 32 Nachrichten angenommen hatte.

| | |
|---|---|
| `subscribers` über den Abend | **0** in allen 287 Stichproben |
| `upstream-base-url` in `server.yml` | **nicht gesetzt** |
| Versand vom Pi aus | `http=200` — der Server nimmt an |

**Die Kette war seit dem 13.08.2026 nie geschlossen.** Ein fehlgeschlagenes Backup
hätte niemanden erreicht.

**Dass es so lange unbemerkt blieb, hat einen Grund:** Geprüft wurde immer nur, ob
der Server die Nachricht *annimmt*. Ein `http=200` beweist die Annahme, nicht die
Zustellung. Am 23.08.2026 wurde dieser Fehler ein zweites Mal gemacht — der offene
Punkt galt nach einem `200` kurzzeitig als erledigt und musste zurückgenommen
werden.

Daraus folgt die Prüfung, die `inventar/collect.sh` seit dem 25.08.2026 zusätzlich
fährt: Sie misst nicht die Zustellung — das kann kein Skript —, sondern ob die
Voraussetzung dafür überhaupt noch vorhanden ist.

</details>

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
| Passwort für Handy und Browser | `stacks/ntfy/.env` (Modus 600, nicht im Git) |
| Token für das Backup-Skript | `/root/.ntfy-token` (Modus 600) |

Das Token steht bewusst **nicht** in `/etc/pi-backup.env`, sondern in einer eigenen
Datei — dieselbe Systematik wie beim restic-Repository-Passwort. So bleibt die
Konfigurationsdatei lesbar und teilbar, ohne Geheimnisse zu enthalten.

`enable-signup: false` — es kann sich niemand selbst ein Konto anlegen.

---

## 8. Betrieb

```bash
# Läuft der Dienst?
sudo docker ps --filter name=ntfy

# Gesundheitsprüfung
curl http://192.168.178.80:2586/v1/health

# Letzte Nachrichten ansehen
TOKEN=$(sudo cat /root/.ntfy-token)
curl -H "Authorization: Bearer $TOKEN" \
     "http://192.168.178.80:2586/raspberrypi/json?poll=1"

# Benutzer und Token verwalten
sudo docker exec ntfy ntfy user list
sudo docker exec ntfy ntfy token list simon

# Protokoll
sudo docker logs ntfy
```

### Aufbau

| | |
|---|---|
| Container | `ntfy` (`binwiederhier/ntfy`) |
| Port | 2586 → 80 im Container |
| Konfiguration | `stacks/ntfy/server.yml` |
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
