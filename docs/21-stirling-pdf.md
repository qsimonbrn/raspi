# 21 — Stirling PDF: Werkzeugkasten für PDF-Arbeiten

Stand: 14.09.2026

> **Der Dienst ist eingerichtet, aber angehalten.** Er läuft nicht, und das ist Absicht —
> siehe [Warum angehalten](#warum-angehalten). Starten mit
> `cd /home/simon/raspi/stacks/stirling-pdf && sudo docker compose start`.

## Wozu

Wiederkehrende Kleinarbeit an PDFs: zusammenfügen, teilen, drehen, komprimieren,
Formate wandeln, Wasserzeichen, Formulare. Kein Ersatz für Paperless — Paperless ist
das Archiv, Stirling die Werkbank daneben.

## Wo es läuft

| Sache | Wert |
|---|---|
| Stack | `/home/simon/raspi/stacks/stirling-pdf/` |
| Image | `stirlingtools/stirling-pdf:2.14.3`, arm64 nachgeprüft |
| Container | **`stirlingpdf`** — ohne Bindestrich, siehe unten |
| Adresse | `http://192.168.178.80:8090` — **aus dem LAN**, nicht nur über Tailscale |
| Anmeldung | Benutzer `admin`, Passwort in `stacks/stirling-pdf/.env` |
| Daten | `/mnt/usb-hdd/stirling-pdf/{configs,logs,pipeline}` |
| Belegung | Image 2,20 GB auf der SD-Karte, Daten 176 KB |

Port **8090** statt der Vorgabe 8080, weil 8080 belegt ist: `insta-triage` bindet dort
auf `100.108.219.87`. Eine zweite Bindung auf `0.0.0.0:8080` schlösse diese Adresse ein
und scheiterte mit `EADDRINUSE`.

**8090 steht bewusst NICHT in der Sperrliste von `pi-guard`.** Entscheidung vom
14.09.2026. Wer die Liste erweitert, darf 8090 nicht „der Vollständigkeit halber"
mit aufnehmen.

## Warum angehalten

Am 14.09.2026 liefen Stirling PDF, SnapOtter und der nächtliche `restic`-Lauf zum
ersten Mal gleichzeitig. Gemessen im Gipfel:

| Größe | Wert |
|---|---|
| Arbeitsspeicher belegt | 3.360 von 3.796 MiB |
| Swap | **511 von 511 MiB — vollständig aufgebraucht** |
| Load average | 25,4 bei vier Kernen |
| SSH | mehrfach „Connection timed out during banner exchange" |

Nach dem Anhalten von Stirling: 1.390 MiB verfügbar, Load 1,6.

Im Ruhezustand belegt Stirling **819 MiB** und ist damit der größte Einzelverbraucher
auf dem Pi — mehr als Paperless (395), n8n (352) oder bichon (414). Mit ihm bleiben
604 MiB verfügbar, ohne ihn 1.390 MiB.

Das genügt im Leerlauf, aber nicht mit Reserve, und die Sicherung um 03:18 ist kein
Sonderfall, sondern jede Nacht. Deshalb steht der Dienst still, bis entschieden ist,
wo der Platz herkommt. Möglichkeiten, grob nach Aufwand:

1. **SnapOtter oder Stirling — einer von beiden.** Kein Aufwand, sofort wirksam.
2. **Stirling nur bei Bedarf starten.** `compose start` / `compose stop`. Kostet
   sechs Minuten Anlaufzeit je Nutzung.
3. **Limits anderswo senken.** bichon (768) und paperless (1.250) sind die nächsten
   großen Posten; beide bräuchten vorher eine Messreihe.
4. **Wurzeldateisystem auf die SSD.** Ändert am RAM nichts, nimmt aber den
   IO-Druck von der SD-Karte, der den Gipfel mitverursacht hat.

Ein manuell angehaltener Container bleibt trotz `restart: unless-stopped` auch nach
einem Daemon-Neustart und nach einem Reboot aus. Das ist so gewollt.

## Der Containername

Der Container heißt `stirlingpdf`, nicht `stirling-pdf`. Beim ersten Anlegen brach die
Cowork-Brücke den `compose up` nach 60 Sekunden ab; Docker rollte die halb angelegte
Instanz zurück, ließ den Namen aber im Namensregister des Daemons stehen. Nachgemessen:

- `docker ps -a` zeigt keinen solchen Container
- `docker inspect <ID>` meldet „no such object"
- `/var/lib/docker/containers/<ID>` existiert nicht
- `docker rm -f`, `docker container prune` greifen nicht
- ein Wegwerf-Container mit demselben Namen scheitert weiterhin am Konflikt

Nur ein Neustart des Docker-Daemons baut das Register neu auf. Dafür 18 laufende
Container durchzustarten stand in keinem Verhältnis. **Nach dem nächsten Reboot ist
der Name frei und kann in `docker-compose.yml` und in
`stacks/homepage/config/services.yaml` zurückgeändert werden.**

## Speicher der JVM — der Fallstrick

`JAVA_TOOL_OPTIONS` ist hier **wirkungslos**. `/scripts/init-without-ocr.sh` setzt die
Variable selbst und überschreibt jeden Wert von außen. Im Log erscheint zwar

```
Picked up JAVA_TOOL_OPTIONS: -Xms256m -Xmx512m
```

— diese Zeile stammt aber von einem kurzlebigen Versions-Aufruf beim Start, **nicht von
der Anwendung**. Wer sie für den Beweis hält, dass die Einstellung wirkt, irrt.

Der vorgesehene Weg ist `JAVA_BASE_OPTS`. Das Skript prüft, ob darin bereits
`MaxRAMPercentage` vorkommt: wenn ja, übernimmt es die Werte unverändert und protokolliert
`JAVA_BASE_OPTS already contains memory flags; keeping user values`. Diese Zeile ist der
Nachweis, dass die eigenen Werte greifen.

**Warum das nötig war.** Ohne eigene Werte staffelt das Skript nach `mem_limit`:

| Containerlimit | Heap | Metaspace |
|---|---|---|
| bis 512 MiB | 55 % | 96 m |
| bis 1024 MiB | 60 % | **128 m** |
| bis 2048 MiB | 65 % | 192 m |
| bis 4096 MiB | 70 % | 256 m |

Bei den geplanten 1024 MiB ergab das 128 MiB Metaspace — und mit eingeschalteter
Anmeldung (Spring-Profil `security`) lädt Stirling mehr Klassen, als dort hineinpassen.
Der erste Lauf endete nach rund vier Minuten mit

```
java.lang.OutOfMemoryError: Metaspace
Terminating due to java.lang.OutOfMemoryError: Metaspace
```

Wegen `-XX:+ExitOnOutOfMemoryError` mit **Exitcode 0**. In `docker ps` sah das aus wie
ein normaler Neustart; `OOMKilled` stand auf `false`, und im Kernelprotokoll stand nichts.
Ohne den Blick ins Containerprotokoll wäre das als „startet halt neu" durchgegangen.

Bloßes Anheben von `mem_limit` hilft nur scheinbar, weil der Heap prozentual mitwächst.
Gesetzt ist deshalb: Limit 1280 MiB, Heap 30 %, Metaspace 256 m — kleiner Heap, großer
Metaspace. **`mem_limit` ist dabei eine Obergrenze, keine Reservierung**; gespart wird
nur, wo der Heap tatsächlich kleiner wird.

## Healthcheck

Geprüft wird `/api/v1/info/status`. Gemessen, welche Pfade ohne Anmeldung antworten:

| Pfad | ohne Anmeldung |
|---|---|
| `/` | **401** |
| `/login` | 200 |
| `/actuator/health` | 200 |
| `/api/v1/info/status` | 200 |

Die Startseite taugt also nicht als Prüfziel — sie stünde dauerhaft auf Rot.

`start_period` liegt bei **420 s**. Die ursprünglichen 180 s waren zu kurz: der erste
Start brauchte gemessen rund sechs Minuten, und der Dienst stand zwischenzeitlich als
`unhealthy` da, obwohl er einwandfrei lief. Eine Anzeige, die im Normalbetrieb falschen
Alarm schlägt, wird nach dem dritten Mal ignoriert.

## Was im Backup landet

`/mnt/usb-hdd/stirling-pdf/configs` — darin `settings.yml`, `custom_settings.yml`, die
H2-Datenbank mit den Benutzerkonten und Stirlings eigene Sicherungen unter `backup/`.

Ausgeschlossen: `configs/cache` und `configs/heap_dumps`.

**Warum `heap_dumps` ausgeschlossen ist:** Der Metaspace-Absturz oben hat dort einen
Speicherabzug von **236 MB** hinterlassen — in einem Verzeichnis, das ins Backup geht,
bei 5 GB OneDrive-Kontingent. Der Abzug wurde gelöscht und `HeapDumpPath` auf `/tmp`
umgelegt; die Ausschlussregel bleibt als zweite Sicherung stehen.

**Offener Punkt:** Die H2-Datenbank wird als laufende Datei kopiert, nicht als Abzug.
Bei einem einzelnen Benutzerkonto ist der Schaden im Fehlerfall gering, aber es ist
kein sauberes Backup im Sinne von Vaultwarden oder n8n.

## Was NICHT eingehängt ist

`/usr/share/tessdata` bleibt bewusst unangetastet. Ein leeres Host-Verzeichnis darüber
würde die mitgelieferten Sprachdateien verdecken und OCR still unbrauchbar machen.

**Offener Punkt:** Damit gibt es OCR vorerst nur in der mitgelieferten Sprachauswahl.
Deutsche Texterkennung liefert ohnehin Paperless.

## Fehlende Zusatzwerkzeuge

Im Protokoll stehen beim Start zwei Meldungen, die erwartet sind und keine Maßnahme
brauchen:

- `Missing dependency: rar` — betrifft nur „PDF To Cbr"
- `WeasyPrint version could not be determined` — betrifft HTML-nach-PDF

Beide kämen mit der Image-Variante `-fat`, die deutlich größer ist.
