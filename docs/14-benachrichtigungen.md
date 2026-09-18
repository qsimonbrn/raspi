# 14 — Benachrichtigungen (ntfy)

*Eingerichtet: 13.08.2026 · Zugangsdaten ausgelagert: 23.08.2026 ·
Zustellung auf die Tailnet-Adresse umgestellt und zweiter Alarmweg ergänzt: 06.09.2026 ·
Zugangsdaten aus der Kommandozeile entfernt und Token rotiert: 18.09.2026*

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
| Weboberfläche im Heimnetz | `http://192.168.178.80:2586` |
| Adresse für die Handy-App | `https://raspberrypi.tailf372ec.ts.net:8444` — **die App muss diese verwenden**, siehe Abschnitt 4 |
| Benutzer | `simon` (Rolle `admin`) |
| Thema | `raspberrypi` |
| Passwort | im Vaultwarden-Tresor, Eintrag „ntfy" — **nicht mehr in der `.env`** |
| Passwort neu setzen | `sudo docker exec -it ntfy ntfy user change-pass simon` |

> **Seit dem 23.08.2026 stehen Benutzer, Passwort und Token nicht mehr in
> `stacks/ntfy/.env`.** Der Container hat kein `env_file` und liest die Datei gar
> nicht — die Benutzer liegen in `/mnt/usb-hdd/ntfy/lib/user.db`. Die Zeilen waren
> eine Zweitschrift, die niemand pflegt: Beim Passwortwechsel am 23.08.2026 wurde
> sie noch am selben Tag still falsch. Seit dem 18.09.2026 liegt der Token nicht
> mehr als nackter Wert in `/root/.ntfy-token`, sondern als fertige
> curl-Konfigurationsdatei in `/root/.ntfy-curl.conf` (root, Modus 600) —
> siehe Abschnitt 9.

---

## 3. Einrichtung auf dem Handy

> **Ohne diesen Schritt kommt nichts an.** Der Server läuft, aber er hat noch kein
> Gerät, an das er ausliefern könnte.

1. App installieren: **ntfy** aus dem App Store bzw. Play Store
   (Entwickler: *Philipp C. Heckel*, kostenlos, quelloffen)
2. In der App: *Einstellungen → Allgemein → **Standard-Server*** auf
   `https://raspberrypi.tailf372ec.ts.net:8444` setzen
3. *Einstellungen → Benutzerkonten → **Konto hinzufügen***
   Server `https://raspberrypi.tailf372ec.ts.net:8444`, Benutzer `simon`,
   Passwort aus dem Tresor
4. Zurück zur Übersicht → **+** → Thema `raspberrypi` abonnieren,
   dabei „Andere Server verwenden" wählen und dieselbe Adresse eintragen
5. Zusätzlich das Notruf-Thema abonnieren — Server `ntfy.sh`, siehe Abschnitt 4

> **Die LAN-Adresse `192.168.178.80:2586` darf in der App nicht mehr stehen.** Sie
> ist der Grund, aus dem unterwegs leere Meldungen ankamen. Ein altes Abo auf diese
> Adresse **löschen**, nicht nur ein neues danebenlegen — die App leitet aus der
> Serveradresse das Upstream-Thema ab, ein altes Abo wartet also auf einem Thema,
> das niemand mehr bespielt.

Schritt 3 ist zwingend: Der Server steht auf `auth-default-access: deny-all` — ohne
Anmeldung liefert er nichts aus und nimmt nichts an.

### Testen

```bash
sudo curl --config /root/.ntfy-curl.conf -H "Title: Test" \
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
Inhalt**. Die `base-url` bestimmt zweierlei: wo die App den Text abholt, und
**welches Upstream-Thema beide Seiten berechnen**. Sie ist deshalb keine Kosmetik —
ändert sie sich, muss das Abo in der App neu angelegt werden, sonst warten App und
Server auf verschiedenen Themen.

Seit dem 06.09.2026 lautet sie `https://raspberrypi.tailf372ec.ts.net:8444`.

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

### Leere Meldungen — Befund vom 06.09.2026

**Fehlerbild:** In der Mitteilungszentrale des iPhones erschien gelegentlich ein
Eintrag mit App-Namen, aber **ohne Text**; in der App stand unter dem Thema
„0 notifications“.

**Das ist die Bauart, nicht ein Fehler im Server.** Der Apple-Push trägt nur die
Kennung. Erreicht die App den eigenen Server in der kurzen Zeitspanne nicht, die iOS
ihr zum Nachladen gibt, bleibt die Hülle stehen — leer, und ohne Eintrag im Verlauf,
weil es nichts zu speichern gab. Ein `HTTP 200` beim Absenden sagt darüber nichts.

**Was geändert wurde.** Die App holte den Text bis dahin von
`http://192.168.178.80:2586` — einer Adresse, die nur im Heimnetz gilt und von
unterwegs eine freigegebene Tailscale-Subnetzroute voraussetzt. Diese Kette hat mehr
Glieder als nötig. Seit dem 06.09.2026 hängt ntfy zusätzlich unter seinem
Tailnet-Namen:

```bash
sudo tailscale serve --bg --https=8444 http://127.0.0.1:2586
```

Damit spricht die App den Pi direkt an, mit gültigem Zertifikat, ohne Subnetzroute
und ohne Unterschied zwischen zu Hause und unterwegs. Die Regel liegt in der
tailscaled-Konfiguration und überlebt einen Neustart — wie die seit dem 23.08.2026
bestehende Regel für Vaultwarden auf 8443.

| Messung vom 06.09.2026 | Ergebnis |
|---|---|
| `/v1/health` über 8444, Zertifikat geprüft (ohne `-k`) | `{"healthy":true}` |
| Negativkontrolle: derselbe Aufruf auf Port 8445 | Verbindung abgelehnt |
| Negativkontrolle: derselbe Port unter falschem Hostnamen | Zertifikatsfehler |
| Meldung auf dem iPhone nach Neuanlage des Abos | **mit Text angekommen** (Simon bestätigt) |

**Welches Glied genau riss, ist nicht gemessen** — in Frage kommen die Subnetzroute,
ein kalter WireGuard-Handschlag und das Zeitbudget der Mitteilungserweiterung.
Nachgewiesen ist die Wirkung, nicht die Ursache: Die Abhängigkeit von der LAN-Adresse
ist weg, und die Meldungen kommen an. Was bleibt, ist die Abhängigkeit von Tailscale
auf dem Handy — und genau dafür gibt es seit demselben Tag den zweiten Weg.

Nebenbei erledigt: Der Verkehr zur App ist nicht mehr unverschlüsselt. Der Port 2586
bleibt im Heimnetz offen und unverschlüsselt, wird von der App aber nicht mehr
benutzt.

### Zweiter Alarmweg: Notruf über ntfy.sh

*Ergänzt am 06.09.2026. Der erste Weg hat einen einzigen Punkt, an dem er reißt:
Läuft Tailscale auf dem iPhone nicht, kommt kein Text an — und ein ausbleibender
Alarm sieht aus wie „alles in Ordnung“.*

Bei Priorität `high` oder `urgent` schickt `notify()` zusätzlich eine Meldung an ein
zufällig benanntes Thema auf **ntfy.sh**. Dort ist die Zustellung sofort und
vollständig — ohne Nachladen, ohne VPN.

| | Weg 1 — eigener Server | Weg 2 — Notruf |
|---|---|---|
| Zustellung | Anstoß über ntfy.sh, Text vom Pi | ntfy.sh direkt, Text kommt mit |
| Braucht Tailscale | ja | nein |
| Inhalt | vollständig | ein Satz ohne Details, dazu `Alarm B` bzw. `Alarm A` |
| Auslöser | jede Meldung, auch der Erfolg | nur `high` und `urgent` |

**Der Preis ist bewusst gewählt.** Bei einem fremden Server wird sichtbar, *dass* auf
irgendeinem Rechner etwas fehlschlug — nicht was, nicht wo, nicht bei wem. Kein
Hostname, kein Dienstname, keine Fehlermeldung. `B` steht für Backup, `A` für
Abgleich; den Schlüssel kennt nur Simon.

**Der Themenname ist das Geheimnis.** Wer ihn kennt, liest die Alarme mit und kann
welche einschleusen. Er steht in `/etc/pi-notruf.url` (Modus 600, root) und
**nicht im Git**; seit dem 18.09.2026 lesen die Skripte ihn nicht mehr von dort,
sondern aus der curl-Konfigurationsdatei `/root/.ntfy-notruf.conf` (Abschnitt 9).
Auslesen: `sudo cat /etc/pi-notruf.url`. Ersetzen: Datei neu
schreiben und das Abo auf dem Handy neu anlegen — sonst nichts.

| Messung vom 06.09.2026 | Ergebnis |
|---|---|
| Ausgangsstand des Themas auf ntfy.sh | 0 Meldungen |
| `notify` mit Priorität `min` (Negativkontrolle) | weiterhin **0** — nicht durchgereicht |
| `notify` mit Priorität `urgent` | **1** — angekommen |

Gemessen wurde am ausgelieferten Skript `/usr/local/bin/pi-backup.sh`, nicht an einer
Nachbildung: Die Funktion wurde aus der Datei herausgeschnitten und unverändert
aufgerufen. Und gezählt wurde, was **auf ntfy.sh liegt** (`/json?poll=1`), nicht der
Rückgabecode des Absendens — der hat in dieser Einrichtung schon zweimal
Zuverlässigkeit vorgetäuscht.

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

### Wer außer dem Backup noch sendet

Seit dem 25.08.2026 gibt es ein **zweites Absenderkonto**: `diun`. Es ist bewusst kein
zweiter Token des Admin-Kontos, sondern ein eigener Benutzer mit dem kleinstmöglichen
Recht.

| | `simon` | `diun` |
|---|---|---|
| Rolle | `admin` | `user` |
| Rechte | alles | **nur schreiben**, nur auf `raspberrypi` |
| Token | `/root/.ntfy-curl.conf` (fertige curl-Konfiguration) | `/etc/diun/ntfy-token` |
| Wer benutzt ihn | `pi-backup.sh`, `pi-abgleich.sh`, Handbetrieb | ausschließlich der Diun-Container |

Am 25.08.2026 gegen alle drei Fälle gemessen: schreiben auf `raspberrypi` → `200`,
schreiben auf ein anderes Thema → `403`, lesen → `403`. Ein verfälschter Token → `401`.

**Der Nutzen ist die getrennte Widerrufbarkeit.** Wird der Diun-Container einmal
kompromittiert, kostet das Sperren dieses Kontos nichts — der Backup-Alarm läuft
weiter. Mit einem gemeinsamen Token hätte man die Wahl zwischen „alles sperren" und
„nichts tun".

## 5. Was das Backup meldet

Im Skript `pi-backup.sh` steckt eine Funktion `notify()`. Drei Fälle:

| Fall | Priorität | Verhalten auf dem Handy |
|---|---|---|
| **Backup fehlgeschlagen** | `urgent` | Ton und Vibration, auch bei Nicht-Stören |
| **Mit Warnungen abgeschlossen** | `high` | Normale Benachrichtigung mit Ton |
| **Erfolgreich** | `min` | Stiller Eintrag im Verlauf, keine Störung |

Seit dem 06.09.2026 lösen die beiden oberen Fälle zusätzlich den Notruf über
ntfy.sh aus. Der Erfolgsfall bewusst nicht: Ein täglicher Eintrag bei einem fremden
Server wäre ein Anwesenheitsprotokoll des Haushalts, und dafür taugt das Ausbleiben
der stillen Meldung auf dem eigenen Server genauso gut.

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
sudo curl --config /root/.ntfy-curl.conf \
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
| Zugang für die Systemskripte | `/root/.ntfy-curl.conf` (Modus 600, root) |
| Adresse des Notruf-Themas | `/etc/pi-notruf.url` und `/root/.ntfy-notruf.conf` (beide Modus 600, root) |

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
sudo curl --config /root/.ntfy-curl.conf \
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

## 9. Zugangsdaten stehen nicht mehr in der Kommandozeile

*Befund vom 14.09.2026, behoben am 18.09.2026.*

Simon fiel der Token beim Hinsehen in die Prozessliste auf, ungewollt. Die Skripte
bauten den Kopfzeilenwert im Aufruf zusammen:

```bash
curl -s -m 20 -o /dev/null -H "Authorization: Bearer $(cat "$NTFY_TOKEN_FILE")" ...
```

Die Datei war korrekt geschützt (root, Modus 600) — aber die Ersetzung geschieht in
der Shell, **bevor** `curl` startet. Der Klartext landet damit in den Argumenten des
Prozesses, und die liest unter Linux jeder lokale Benutzer mit. `/proc` ist ohne
`hidepid` eingehängt, und es gibt fünf Konten mit Anmeldeshell.

**Betroffen waren vier Skripte, nicht eins:** `pi-backup.sh`, `pi-abgleich.sh`,
`pi-gravity.sh` und `pi-reboot-check.sh` — dazu `inventar/collect.sh`. Dieselbe
Schwäche hatte der zweite Alarmweg: die Notruf-Adresse stand als
`"$(cat /etc/pi-notruf.url)"` im Aufruf, und bei ntfy.sh **ist der Themenname das
Geheimnis**.

### Was jetzt geschieht

`curl` liest Kopfzeile und Adresse aus Konfigurationsdateien, die es selbst öffnet.
Damit steht im Aufruf nur noch ein Dateiname.

| Datei | Inhalt | Rechte |
|---|---|---|
| `/root/.ntfy-curl.conf` | `header = "Authorization: Bearer …"` | root:root, 600 |
| `/root/.ntfy-notruf.conf` | `url = "https://ntfy.sh/…"` | root:root, 600 |

Die Pfade stehen als `NTFY_CURL_CONF` und `NTFY_NOTRUF_CONF` in
`/etc/pi-backup.env`. `NTFY_TOKEN_FILE` gibt es nicht mehr, `/root/.ntfy-token`
wurde gelöscht.

> **Warum keine Umgebungsvariable.** `/proc/<pid>/environ` liest nur der Eigentümer,
> das klingt zunächst besser. Ein `-H "Authorization: Bearer $VAR"` würde die
> Variable aber genauso in die Argumente expandieren — der Gewinn wäre nur
> scheinbar. Der Unterschied liegt nicht am Speicherort, sondern daran, wer die
> Zeichenkette zusammensetzt: die Shell oder `curl`.

### Messung vom 18.09.2026

Gemessen am ausgelieferten `/usr/local/bin/pi-backup.sh`: die `notify()`-Funktion
wurde herausgeschnitten und unverändert aufgerufen, gegen eine tote Adresse, damit
`curl` in sein `-m 20` läuft und lange genug in der Prozessliste steht. Gelesen
wurde als Konto `claude`, **ohne** `sudo`.

| Fassung | Prozessliste enthält den Token | Positivkontrolle: curl läuft |
|---|---|---|
| vorher (aus der Sicherung) | **ja** | ja |
| nachher (`curl --config`) | **nein** | ja |

Die Positivkontrolle ist der Punkt: Ohne sie hätte „kein Treffer" auch bedeuten
können, dass der Testaufruf gar nicht lief.

| Weitere Prüfung | Ergebnis |
|---|---|
| Versand mit der neuen Konfigurationsdatei | `200` |
| Negativkontrolle: verfälschter Token in derselben Datei | `401` |
| Negativkontrolle: gar keine Anmeldung | `403` |
| Notruf über `/root/.ntfy-notruf.conf` | `200` |
| `notify()` aus allen drei Skripten mit Funktion, Meldung bei ntfy nachgezählt | **3 von 3 angekommen** |
| `pi-reboot-check.sh` vollständig ausgeführt (Neustartbedarf vorgetäuscht) | Meldung angekommen |
| Vollständiger Backup-Lauf über `systemctl start pi-backup.service` | 4 min 31 s, `Backup erfolgreich` angekommen |

### Der Token wurde dabei rotiert

Der alte Token war seit dem 23.08.2026 in Betrieb und stand in dieser Zeit bei jedem
Lauf in der Prozessliste; wer ihn gesehen hat, lässt sich nicht mehr feststellen.
Er wurde deshalb widerrufen (`ntfy token remove`) und durch einen neuen ersetzt
(Bezeichnung `pi-skripte (rotiert 18.09.2026)`). Gegenprobe: der alte Token
antwortet seitdem mit `401`, der neue mit `200`.

> **Am selben Abend ein zweites Mal rotiert, aus demselben Grund in neuer Gestalt.**
> Bei der Fehlersuche am Abo gab `GET /v1/account` die vollständige Tokenliste im
> Klartext aus — nicht als Kommandozeile, sondern als API-Antwort. **Der Filter, der seit
> der ersten Rotation vor jeder `ps`-Ausgabe steht, greift bei JSON nicht.** Der Token
> wurde erneut gewechselt (`pi-skripte (rotiert 18.09.2026, 22:00)`), der vorherige
> widerrufen, Gegenprobe alt `401` / neu `200`, danach die `notify()`-Funktion aus
> `pi-backup.sh` gegengeprüft. **Regel daraus: Nicht die Ausgabeart filtern, sondern
> jede Ausgabe, die ein Geheimnis enthalten kann** — `/v1/account`, `ntfy token list`,
> `docker inspect`, `env`.

**Das Abo auf dem Handy war davon nicht betroffen** — die App meldet sich mit
Benutzername und Passwort an, nicht mit diesem Token. Der Notruf-Themenname wurde
aus demselben Grund **nicht** gewechselt: Das hätte ein neues Abo auf dem Handy
erfordert, und der Themenname war nie öffentlich, sondern nur lokal lesbar.

---

---

## 10. Probealarm: der Weg wird regelmäßig benutzt

*Eingerichtet am 18.09.2026.*

**Anlass.** Vom **11. bis 18.09.2026** kam auf dem iPhone keine einzige Meldung an —
Tailscale lief dort seit sieben Tagen nicht (`tailscale status`: *offline, last seen 7d
ago*). Der Server nahm die ganze Zeit an, das Backup meldete jede Nacht Erfolg, und
niemand las es. Aufgefallen ist es erst nebenbei, beim Einrichten eines anderen Abos.

**Das ist der Bruch im eigentlichen Sicherungsgedanken.** Der Erfolgsfall wird
absichtlich gemeldet, damit sein *Ausbleiben* auffällt (siehe Abschnitt 8). Genau das hat
nicht funktioniert: Eine Woche ohne Lebenszeichen fiel nicht auf. **Ein Lebenszeichen,
dessen Fehlen niemand bemerkt, ist keins.**

### Was der Probealarm tut

| | |
|---|---|
| Skript | `/usr/local/sbin/pi-probealarm.sh` (root:root, 750) |
| Timer | `pi-probealarm.timer` — **Montag und Donnerstag 10:05**, `Persistent=true` |
| Wege | eigener Server `raspberrypi` · eigener Server `workbench` · **Notruf über ntfy.sh** |
| Zähler | `/var/lib/pi-probealarm.zaehler`, fortlaufende Nummer in jeder Meldung |
| Protokoll | `journalctl -t pi-probealarm` |

**Feste Wochentage statt „alle drei Tage"**, weil ein wiederkehrender Termin beim
Ausbleiben eher auffällt als ein wandernder. `Persistent=true`, damit nach einem Ausfall
nachgeholt wird — sonst fällt ausgerechnet der Alarm aus, der auf ein Problem
hingewiesen hätte.

**Die fortlaufende Nummer ist der eigentliche Mechanismus.** Das Skript kann die
Zustellung **nicht** prüfen — das kann kein Skript, die Anzeige auf dem Gerät sieht nur
ein Mensch. Es sorgt nur dafür, dass eine Lücke sichtbar wird: Fehlt eine Nummer, oder ist
die letzte älter als vier Tage, kommt nichts mehr an.

**Der dritte Weg ist der wichtige.** Er läuft über ntfy.sh und braucht **kein** Tailscale
— er war im September 2026 der einzige, der durchkam. Bewusst mit Priorität `default`
statt `high`: Ein Probealarm soll ankommen, nicht wecken.

**Der Preis, benannt:** Zweimal pro Woche erfährt ntfy.sh, dass dieser Haushalt einen
Rechner betreibt, der lebt. Das ist ein Anwesenheitssignal — ohne Hostnamen, ohne
Dienstnamen, ohne Fehlermeldung, aber es ist eins. Die Alternative wäre ein Notrufweg, der
monatelang ungeprüft bleibt; dann ist er im Ernstfall genauso gut wie keiner.

### Nachweis vom 18.09.2026

| Messung | Ergebnis |
|---|---|
| Lauf über `systemctl start pi-probealarm.service` | `Result=success`, alle drei Wege **200** |
| **Negativkontrolle:** dasselbe Skript mit `NTFY_NOTRUF_CONF=/gibtsnicht` | „Notruf: uebersprungen", **Exitcode 1**, zwei von drei Wegen ok |
| Abgleich Repository ↔ System nach dem Installieren | 28 von 28 Paaren identisch |
| **Anzeige auf dem iPhone, alle drei Wege** | **angekommen — von Simon am 18.09.2026 um 22:15 bestätigt** |

Die Negativkontrolle ist hier der Punkt: Ein fehlender Weg wird **gemeldet und färbt den
Exitcode**, statt still übersprungen zu werden. Genau das hat die alte `notify()` nicht
getan — sie kehrt bei fehlender Konfigurationsdatei wortlos zurück, weil eine kaputte
Benachrichtigung kein Backup verhindern darf. Für einen Probealarm gilt das Gegenteil.

---

## 11. Was noch zu tun ist

- [x] ntfy-App auf dem Handy installieren
- [x] Konto und Abo auf `https://raspberrypi.tailf372ec.ts.net:8444` umgestellt (06.09.2026)
- [x] Thema `raspberrypi` abonniert, Meldung mit Text nachgewiesen
- [x] Notruf-Thema auf **ntfy.sh** abonniert (18.09.2026 im Abo-Bestand bestätigt)
- [x] Thema `workbench` abonnieren
- [ ] **Tailscale auf dem iPhone im Blick behalten** — war vom 11. bis 18.09.2026 aus, und
      damit der eigene Meldeweg tot. Der Probealarm (Abschnitt 10) macht das künftig
      sichtbar
- [ ] Am nächsten Morgen nachsehen, ob die stille Erfolgsmeldung des nächtlichen
      Backups im Verlauf steht
