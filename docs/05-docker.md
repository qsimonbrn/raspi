# 05 — Docker

*Erfasst: 18.08.2026 · Verbrauchswerte nachgemessen: 20.08.2026*

## Überblick

| | |
|---|---|
| Docker-Version | 29.7.2 (build a7dcaa6) |
| Laufende Container | 11 von 11 (25.08.2026) |
| Compose-Stacks | 6 aktiv, 2 archiviert |
| Images gesamt | **11 (3,94 GB)** — zuletzt aufgeräumt am 18.08.2026 |
| Alle Images | auf feste Versionen bzw. Digests gepinnt (vollständig seit 18.08.2026) |
| Logrotation | 10 MB je Datei, 3 Dateien — in jeder Compose-Datei gesetzt |
| Speicher-Limits | **gesetzt für alle elf Container** — die acht vom 20.08.2026 auf Grundlage einer Zweitagesmessung, Vaultwarden (23.08.) und die beiden Diun-Container (25.08.) als Erstanhaltspunkt |

## Container

| Container | Image | Port (Host) | Zweck | Restart-Policy |
|---|---|---|---|---|
| **paperless** | `…/paperless-ngx:3.0.5` | 8000 🔒 | Dokumentenarchiv mit OCR | `always` |
| paperless-paperless-db-1 | `postgres:15.19` | — (intern) | Datenbank für Paperless | `always` |
| paperless-paperless-redis-1 | `redis:7.4` | — (intern) | Task-Queue für Paperless | `always` |
| **bichon** | `rustmailer/bichon@sha256:5766707…` | 15630 🔒 | E-Mail-Archivierung | `unless-stopped` |
| **portainer** | `portainer/portainer-ce:2.39.6` | 9000, 9443 🔒 | Docker-Verwaltung | `always` |
| **homepage** | `…/gethomepage/homepage:v1.13.2` | 3000 | Dashboard mit Live-Status | `unless-stopped` |
| **ntfy** | `binwiederhier/ntfy:v2.27.0` | 2586 | Push-Benachrichtigungen | `unless-stopped` |
| homepage-dockerproxy | `…/docker-socket-proxy:v0.5.0` | — (intern) | Gefilterter, nur lesender Docker-Zugriff für Homepage | `unless-stopped` |
| **vaultwarden** | `vaultwarden/server:1.37.2` | 8222 nur auf `127.0.0.1` 🔒 | Passwort-Tresor, siehe [18](18-vaultwarden.md) | `unless-stopped` |
| **diun** | `crazymax/diun:4.33.0` | — (keiner) | Meldet neue Image-Versionen, aktualisiert nicht | `unless-stopped` |
| diun-dockerproxy | `…/docker-socket-proxy:v0.5.0` | — (intern) | Gefilterter, nur lesender Docker-Zugriff für Diun | `unless-stopped` |

**Elf Container** (seit 25.08.2026). 🔒 markiert Dienste, die seit dem 18.08.2026 nur
noch über Tailscale erreichbar sind — siehe [07 — Sicherheit](07-sicherheit.md).

Kein Container läuft mit `privileged`, kein Container nutzt `network_mode: host`,
alle elf laufen mit `no-new-privileges`.

**Vaultwarden ist der einzige Container, der ausdrücklich an `127.0.0.1` gebunden ist.**
Bei allen übrigen sorgt `pi-guard` für die Abschottung; bei einem Passwort-Tresor soll
sie nicht an einer einzigen Regelkette hängen, die Docker beim Erzeugen eines Containers
neu schreibt.

### Abgeschaltet am 18.08.2026

| Dienst | Grund |
|---|---|
| **filebrowser** | Lief in Version 2.51.2 und ist von **CVE-2026-32759** betroffen — Remote Code Execution über den TUS-Upload, **kein Patch verfügbar**. Das Projekt wird zum 01.09.2026 archiviert. Erschwerend: Der Container hatte die gesamte SSD unter `/srv` eingebunden. Ein Nachfolger wird gesucht; aktiv gepflegt wird der Fork **FileBrowser Quantum** (`gtsteffaniak/filebrowser`) |
| **Dashy** | Durch Homepage abgelöst, Image neun Monate alt auf `:latest` |

Die Compose-Dateien liegen weiterhin versioniert unter `stacks/_archiviert/`
samt Begründung. Sie haben bewusst **keinen** Logrotations-Anker bekommen — eine
Einstellung in einer Datei zu pflegen, die nichts startet, würde den Eindruck
erwecken, der Dienst sei betriebsbereit.

Die Reste sind am 18.08.2026 weggeräumt: `/mnt/usb-hdd/filebrowser-data` (44 KB,
nur `filebrowser.db` mit den Konten des Dienstes) liegt jetzt unter
`/mnt/usb-hdd/_to_delete/filebrowser-data-20260818` und wird nicht mehr gesichert.

### Restart-Policies

Die Aufteilung ist konsistent: Die Dienste, deren Ausfall wehtut (Paperless-Stack,
Portainer), stehen auf `always`; die anderen auf `unless-stopped`. Der Unterschied
zeigt sich nur beim manuellen Stoppen — `always` startet den Container auch nach einem
`sudo docker stop` beim nächsten Daemon-Start wieder, `unless-stopped` nicht.

Nachgeprüft beim Neustart am 18.08.2026: alle acht Container kamen von selbst hoch.

---

## ✅ Behoben: Logrotation wirkt jetzt tatsächlich (18.08.2026)

Am 18.08.2026 wurde in `/etc/docker/daemon.json` eine Logrotation eingetragen
(`max-size: 10m`, `max-file: 3`) und der Daemon mit `systemctl reload` neu geladen.
Die Annahme war, die Einstellung greife dann für neu erstellte Container.

**Beides war falsch, und zwar messbar:**

| Prüfung | Ergebnis |
|---|---|
| Effektive Daemon-Konfiguration nach dem Reload | enthielt `log-driver`, aber **kein** `log-opts` |
| Neu angelegter Testcontainer | `LogConfig: json-file map[]` — leer, keine Rotation |
| Größte Logdatei | `bichon`: **39 MB** in einer einzigen, nie gedrehten Datei |

Der Grund: `log-driver` und `log-opts` gehören **nicht** zu den Werten, die Docker
bei einem `reload` (SIGHUP) übernimmt. Dafür braucht es einen echten Neustart des
Daemons. Eine Neuerstellung der Container allein hätte also nichts gebracht — sie
hätten die Vorgabe schlicht nicht vorgefunden.

**Behebung:** Die Vorgabe steht jetzt als YAML-Anker in **jeder** Compose-Datei und
wirkt damit unabhängig vom Daemon, überlebt jede Änderung an `daemon.json` und ist
beim Nachlesen sichtbar:

```yaml
x-logging: &logging
  driver: json-file
  options:
    max-size: "10m"
    max-file: "3"

services:
  beispiel:
    logging: *logging
```

Nachgemessen nach der Neuerstellung: **8 von 8 Containern** tragen
`max-size 10m` / `max-file 3`. Die 39-MB-Datei ist mit dem alten Container
verschwunden.

**Merken:** Eine Einstellung in `daemon.json` ist erst dann in Kraft, wenn sie in
`docker inspect` eines *neu erstellten* Containers auftaucht. Ein Blick in die
Datei beweist gar nichts.

---

## ✅ Behoben: Speicherbuchführung war abgeschaltet (18.08.2026)

`sudo docker stats` meldete bei **jedem** Container `0B / 0B`, und `sudo docker info`
gab aus:

```
WARNING: No memory limit support
WARNING: No swap limit support
```

Ursache: In `/boot/firmware/cmdline.txt` fehlten `cgroup_enable=memory` und
`cgroup_memory=1`. Auf Raspberry-Pi-Kerneln ist der Speicher-Controller ohne diese
Parameter nicht aktiv — `/sys/fs/cgroup/cgroup.controllers` führte nur
`cpuset cpu io pids`.

Die Folge war nicht nur eine fehlende Anzeige: Ein `mem_limit` in einer
Compose-Datei wäre **wirkungslos** geblieben. Ein durchdrehender OCR-Lauf hätte den
Pi ungebremst in den OOM-Killer fahren können.

Behoben durch Ergänzung der Parameter und einen Neustart (Sicherungskopie:
`/boot/firmware/cmdline.txt.bak-20260818`, versionierte Kopie:
`system/updates/cmdline.txt`). Nachgemessen: `cgroup.controllers` enthält
jetzt `memory`, `docker info` meldet keine Warnung mehr.

## Ressourcenverbrauch

Messung im eingeschwungenen Zustand, 20.08.2026, nach zwei Tagen und fünf Stunden
Laufzeit:

| Container | RAM | Anteil |
|---|---|---|
| paperless | 736 MiB | 19,4 % |
| bichon | 356 MiB | 9,4 % |
| homepage | 91 MiB | 2,4 % |
| paperless-db-1 | 33 MiB | 0,9 % |
| portainer | 27 MiB | 0,7 % |
| ntfy | 23 MiB | 0,6 % |
| homepage-dockerproxy | 16 MiB | 0,4 % |
| paperless-redis-1 | 5 MiB | 0,1 % |
| **zusammen** | **rund 1,26 GiB** | **33,9 %** |

**Der Vergleich mit der Kaltstartmessung ist die eigentliche Information.** Sechs Minuten
nach dem Neustart am 18.08.2026 lagen dieselben Container bei zusammen rund 1,4 GB
(38 %), aber mit völlig anderer Verteilung: paperless 953 MiB, homepage 168 MiB,
portainer 88 MiB — und **bichon bei 51 MiB (1,4 %)**. Zwei Tage später belegt bichon
356 MiB, das Siebenfache. Das ist kein Leck, sondern der normale Arbeitssatz eines
Dienstes, der E-Mails verarbeitet und indiziert; er war beim Kaltstart schlicht noch
nicht aufgebaut.

Daraus folgt für die Limits: **eine Momentaufnahme kurz nach dem Start taugt nicht als
Grundlage.** Wer bichon damals ein Limit von 128 MiB gegeben hätte, hätte den Dienst
zwei Tage später abgewürgt.

### Speicher-Limits — gesetzt am 20.08.2026

Grundlage ist die Messung, die seit dem 18.08.2026 alle fünf Minuten nach
`/mnt/usb-hdd/messungen/docker-speicher.csv` schreibt: **603 Punkte je Container**
zwischen dem 18.08. 06:03 und dem 20.08. 11:39.

| Container | gemessenes Maximum | Limit | Reserve |
|---|---|---|---|
| paperless | 907 MiB | **1280 MiB** | 41 % |
| bichon | 462 MiB | **768 MiB** | 66 % |
| homepage | 176 MiB | **320 MiB** | 82 % |
| paperless-db | 61 MiB | **256 MiB** | 319 % |
| portainer | 89 MiB | **192 MiB** | 116 % |
| paperless-redis | 15 MiB | **128 MiB** | 742 % |
| ntfy | 51 MiB | **96 MiB** | 90 % |
| homepage-dockerproxy | 30 MiB | **64 MiB** | 113 % |
| **Summe** | **1.790 MiB** | **3.104 MiB** | von 3.796 MiB RAM |

**Die Limits sind bewusst großzügig.** Sie sind eine Reißleine gegen einen ausgerissenen
Dienst, kein Sparprogramm. Der Grund steht in der Messung selbst: Sie tastet alle fünf
Minuten ab und **sieht kurze Spitzen überhaupt nicht** — ein OCR-Lauf in Paperless dauert
oft unter zwei Minuten. Das gemessene Maximum von 907 MiB ist deshalb eine Untergrenze,
keine Obergrenze. Ein Limit knapp darüber würde irgendwann mitten in einer Texterkennung
zuschlagen, und das Dokument bliebe unbearbeitet im Einwurf liegen.

Dazu kommt, dass **bichon noch wächst**: niedrigster Wert 14,7 MiB (Kaltstart), Median
370 MiB, Maximum 462 MiB. Der Arbeitssatz eines E-Mail-Indexers baut sich über Tage auf
und war am Ende des Messfensters erkennbar noch nicht am Ende.

**Die Summe aller Limits liegt mit 3.104 MiB unter den 3.796 MiB RAM.** Damit ist nichts
überbucht: Selbst wenn alle acht Container gleichzeitig ihre Decke erreichen, bleibt dem
Betriebssystem Luft. Das ist die eigentliche Absicherung — der OOM-Killer sucht sich
sonst ein beliebiges Opfer, und das ist selten der Schuldige.

**Nachgemessen nach dem Setzen** (20.08.2026): Alle acht Container melden ihr Limit über
`docker inspect`, `OOMKilled=false`, `RestartCount=0`, Paperless nach 125 s wieder
`healthy`. `pi-guard` hat das Neuerzeugen überstanden — die Ketten stehen samt Referenz.

> **Ein Limit greift erst, wenn der Container neu erzeugt wird.** Ein `restart` genügt
> nicht, `compose up -d` schon. Wer nur die Compose-Datei ändert und committet, hat die
> Änderung an einer von zwei Stellen gemacht.

**Die Messung läuft vorerst weiter.** Ihr ursprünglicher Zweck ist erfüllt, aber sie hat
jetzt einen zweiten: zu zeigen, ob ein Container gegen seine neue Decke läuft — vor allem
bichon. Erst wenn das über ein bis zwei Wochen nicht passiert, wird sie entfernt;
Anleitung in `system/messung/README.md`.

**Bewertung:** Der Pi ist von seiner Kapazitätsgrenze entfernt, aber nicht mehr
komfortabel weit: 34 % Speicher im Leerlauf lassen für einen schweren zusätzlichen
Dienst (Immich, Nextcloud) keinen Raum. Zwei bis drei schlanke Dienste
(Uptime Kuma, Diun, Dozzle) sind problemlos möglich.

---

## ✅ Behoben: Images aktualisiert und vollständig gepinnt

Der frühere Befund lautete: kein einziges Image seit dem ersten Start aktualisiert,
Alter zwischen 8 und 17 Monaten.

| Image | vorher | jetzt | Anlass |
|---|---|---|---|
| `paperless-ngx` | 2.15.3 (16 Monate) | **3.0.5** | zwei Major-Sprünge, siehe unten |
| `postgres` | `:15` (17 Monate) | **15.19** | Minor gepinnt, kein Sprung auf 16 möglich |
| `redis` | `:7` (15 Monate) | **7.4** | Minor gepinnt |
| `portainer-ce` | `:latest` (8 Monate) | **2.39.6 LTS** | schließt sieben CVEs |
| `ntfy` | `:latest` | **v2.27.0** | |
| `docker-socket-proxy` | `:latest` | **v0.5.0** | |
| `homepage` | `:latest` | **v1.13.2** (18.08.2026) | die bereits laufende Version festgenagelt, **kein** Sprung auf v2.0.0 |
| `bichon` | `:latest` | **`@sha256:5766707…`** (18.08.2026) | das Projekt vergibt keine Versions-Tags, deshalb Digest |

**Kein Image trägt mehr den Tag `:latest`.** Damit ist reproduzierbar, welche Version
läuft, und ein Neustart holt nie unbemerkt eine andere Version. Bis zum 18.08.2026
galt das nur für sechs von acht Images — `homepage` und `bichon` waren die Ausnahmen,
obwohl die Doku bereits „alle gepinnt" behauptete.

Stand aller Images am 18.08.2026 gegen die jeweils neueste Veröffentlichung geprüft:
Paperless 3.0.5, Portainer 2.39.6 LTS, ntfy v2.27.0, Postgres 15.19, Redis 7.4 und
docker-socket-proxy v0.5.0 sind **jeweils die aktuelle Fassung**. Ein Update-Lauf war
nicht nötig.

### Der Update-Pfad von Paperless-ngx

Ein direkter Sprung von 2.15.3 auf 3.0.5 wäre gescheitert. Die offizielle
Migrationsanleitung sagt: *„Upgrading to Paperless-ngx v3 can only be performed from
version 2.20.15."* Gefahren wurde deshalb in zwei Stufen:

```
2.15.3  →  2.20.15 (27.04.2026)  →  3.0.5 (01.08.2026)
```

Sechs Einstellungen in der Compose-Datei mussten dabei umgeschrieben werden. Details
in [Kapitel 13](13-paperless.md).

### Nebenbefund: Collation-Konflikt bei PostgreSQL

Beim Wechsel von `postgres:15` auf `15.19` wanderte das Basis-Image von Debian
Bookworm (glibc 2.36) auf Trixie (glibc 2.41). PostgreSQL meldete daraufhin:

```
WARNING: database "paperless" has a collation version mismatch
DETAIL:  created using collation version 2.36, OS provides version 2.41
```

Das ist kein kosmetisches Problem. Eine geänderte Sortierreihenfolge macht bestehende
B-Tree-Indizes auf Textspalten still falsch — Abfragen liefern dann unvollständige
Ergebnisse, ohne dass irgendetwas einen Fehler wirft. Behoben durch `REINDEX DATABASE`
und `ALTER DATABASE … REFRESH COLLATION VERSION` für `paperless`, `postgres` und
`template1`.

**Merken für künftige Postgres-Updates:** Nach jedem Sprung, der die Debian-Basis
wechselt, in den Logs nach `collation version mismatch` sehen.

---

## ⚠️ Befund: Homepage v2.0.0 steht aus

`homepage` läuft auf **v1.13.2** und ist dort seit dem 18.08.2026 festgenagelt.
**v2.0.0** (14.08.2026) bringt einen Breaking Change bei der Authentifizierung.
Das ist bewusst kein Update, sondern eine Entscheidung: erst Release Notes lesen,
dann gezielt umstellen.

`bichon` läuft auf einem Stand vom 07.12.2025 und ist damit der älteste Dienst.
Da Bichon E-Mails verarbeitet, also fremdgestaltete Inhalte, ist es zugleich die
exponierteste Stelle. Seit dem 18.08.2026 immerhin nur noch über Tailscale
erreichbar und auf einen Digest gepinnt, sodass ein Pull nichts unbemerkt
austauscht.

### ✅ Aufgeräumt am 18.08.2026

Aus 18 Images für 8 Container wurden **8 Images für 8 Container**:

| | vorher | nachher |
|---|---|---|
| Images | 18 | **8** |
| Belegung | 8,66 GB | **3,63 GB** |
| davon freigebbar | 4,81 GB (55 %) | **0 B** |
| Wurzeldateisystem | 14 GB belegt | **7,7 GB belegt** |

Entfernt wurden die drei Dashy-Tags, `filebrowser:latest`,
`paperless-ngx:latest` und `:2.20.15`, `postgres:15`, `redis:7`,
`portainer-ce:latest`, `docker-socket-proxy:0.3.0` und `:latest`,
`ntfy:latest` sowie `homepage:latest`.

Bewusst gezielt entfernt statt `docker image prune -a` — die Liste ist damit
nachvollziehbar und es kann nichts mitgerissen werden, was noch als Rückfallebene
gedacht war.

### Was weiterhin gilt

**Diun** (Punkt 2.7 in [Kapitel 09](09-empfehlungen.md)) ist durch das Pinnen nicht
überflüssig geworden, sondern wichtiger: Mit festen Tags und Digests erfährt man von
neuen Versionen sonst gar nichts mehr. Diun meldet, aktualisiert aber nicht — die
Entscheidung bleibt bei dir. Watchtower mit Auto-Update bleibt die falsche Antwort;
der Paperless-Zwischenschritt über 2.20.15 ist das Lehrstück dazu.

---

## Diun — Update-Meldungen (seit 25.08.2026)

*Eingerichtet am 25.08.2026.*

Alle Images sind auf feste Versionen gepinnt. Das ist eine bewusste Entscheidung, und
sie hat einen Preis: **Ohne `:latest` erfährt man von einer neuen Version gar nichts
mehr** — auch nicht von einer, die eine Sicherheitslücke schließt. Genau diese Lücke
schließt Diun. Es fragt täglich um 06:15 die Registries ab und meldet über ntfy, was es
findet. **Es aktualisiert nichts.** Eingespielt wird weiter von Hand über den Skill
`docker-updates`, mit vorherigem Backup.

| | |
|---|---|
| Stack | `stacks/diun/` — `docker-compose.yml` und `diun.yml` |
| Zustandsdatenbank | `/mnt/usb-hdd/diun/diun.db` — **bewusst nicht im Backup**, vollständig rekonstruierbar |
| Docker-Zugriff | über einen **eigenen** Socket-Proxy, nicht über den von Homepage |
| ntfy-Konto | `diun` — darf **nur** auf das Thema `raspberrypi` schreiben, nicht lesen |
| Token | `/etc/diun/ntfy-token`, Modus 600, `1000:1000`, außerhalb des Git |
| Überwacht | 11 Images (25.08.2026), `watchByDefault` — ein neuer Dienst kommt von selbst dazu |

**Warum ein zweiter Socket-Proxy statt des vorhandenen?** Der von Homepage hängt am Netz
`homepage_default`. Diun dort anzuhängen würde die Überwachung von einem fremden Stack
abhängig machen: Wer den Homepage-Stack einmal mit `down` abräumt, nimmt Diun stumm die
Datenquelle weg — und **Stille meldet Diun nicht**. Ein Überwachungsdienst muss dann
funktionieren, wenn niemand hinschaut. Preis: 48 MiB.

### Zwei Fehler beim Einrichten, beide lehrreich

**`IMAGES: 0` im Proxy ließ Diun leerlaufen.** Die Annahme war, Diun brauche nur die
Container-Liste, weil es die Versionen ohnehin bei den Registries erfragt. Falsch: Es
braucht `ImageInspect`, um den lokal laufenden Digest zu kennen. Mit `IMAGES: 0` startete
der Dienst klaglos, schrieb elfmal `Cannot inspect image … 403` ins Log, meldete dann
`No image found` und `Jobs completed added=0` — **er lief und überwachte nichts.** Wer
nur auf `docker ps` geschaut hätte, hätte einen gesunden Container gesehen. Der Fehler
war nur im Log sichtbar, und Diun meldet ihn nicht über ntfy.

**Der Token in der Datei endete auf einen Zeilenumbruch.** `ntfy token add … | tee`
schreibt ihn mit `\n`; Diun liest die Datei roh und setzt den Umbruch in den
`Authorization`-Header, was mit `invalid header field value` scheitert. Aufgefallen ist
das erst beim `diun notif test` — der vorherige Test mit
`curl -H "… $(cat datei)"` war **blind dafür**, weil die Kommandosubstitution den Umbruch
verschluckt. **Ein Test, der den echten Konsumenten nicht nachbildet, prüft die falsche
Sache.**

## ⚠️ Fallstrick: eine einzelne Datei im Bind-Mount

*Nachgemessen am 25.08.2026 an `stacks/ntfy/server.yml`.*

Wird eine **einzelne Datei** in einen Container gebunden — nicht ihr Verzeichnis —,
hängt der Mount an der Inode, nicht am Pfad. `sed -i`, `cp` mit anschließendem
Umbenennen und die meisten Editoren erzeugen beim Speichern eine **neue** Inode. Der
Container liest danach weiter die alte Fassung, ohne dass irgendetwas eine Warnung
ausgibt.

| Messung vom 25.08.2026 | |
|---|---|
| Inode der Datei im Repository nach `sed -i` | 256855 |
| Inode, die der Container gemountet hat | 256054 |
| Sichtbare Folge | keine — der Dienst läuft normal weiter |

Docker löst den Mount **bei jedem Containerstart** neu auf. Ein `docker compose
restart` genügt also, um die geänderte Datei wirksam zu machen — nur passiert ohne
diesen Schritt eben gar nichts, und das fällt nicht auf.

**Betroffen sind hier:** `stacks/ntfy/server.yml` und jede weitere Einzeldatei aus der
`volumes:`-Liste eines Stacks. Verzeichnis-Mounts (`/mnt/usb-hdd/...`) haben das
Problem nicht.

**Konsequenz für Prüfungen:** Der Blick ins Repository beweist nichts über den
laufenden Dienst. `inventar/collect.sh` vergleicht deshalb seit dem 25.08.2026 den
**Inhalt der Datei im Container** mit dem im Repository und meldet eine Abweichung als
`ACHTUNG`.

## Volumes

| Volume | Genutzt von |
|---|---|
| `paperless_paperless_db` | PostgreSQL-Datenverzeichnis |
| `paperless_paperless_redis` | Redis-Datenverzeichnis |
| `portainer_portainer_data` | Portainer-Konfiguration (seit 18.08.2026 im Backup) |
| fünf Volumes mit Hash-Namen | anonym, verwaist |

Die fünf Volumes mit Hash-Namen sind **anonyme Volumes** — sie entstehen, wenn ein
Image ein `VOLUME` deklariert, das in der Compose-Datei nicht explizit gemappt wurde.
`sudo docker volume ls -qf dangling=true` zählt alle fünf als verwaist; sie gehören
zu den mittlerweile entfernten Containern. Zusammen belegen alle Volumes 72,4 MB,
davon sind laut `docker system df` 479 Byte freigebbar — die Hash-Volumes sind also
faktisch leer.

**Empfehlung:** Bei nächster Gelegenheit mit `sudo docker volume prune` entfernen.
Vorher prüfen, dass keiner der laufenden Container sie referenziert — der Befehl
unterscheidet nicht zwischen „leer" und „wichtig".

## Speicherbelegung

| Typ | Anzahl | Größe | Davon freigebbar |
|---|---|---|---|
| Images | 8 | 3,63 GB | **0 B** |
| Container | 8 | 97 KB | 0 B |
| Volumes | 8 | 72,4 MB | 479 B |
| Build-Cache | 0 | 0 B | 0 B |

*Gemessen am 18.08.2026 nach dem Aufräumen.*

---

## Compose-Dateien

Alle Stacks liegen unter `/home/simon/raspi/` und sind in einem **Git-Repository**
versioniert (`git@github.com:qsimonbrn/raspi.git`).

```
/home/simon/raspi/
├── .git/
├── .gitignore              # schliesst .env, *.db, **/data/, *.log, secrets/ aus
├── _archiviert/            # abgeschaltete Dienste, Konfiguration bleibt nachvollziehbar
│   ├── README.md
│   ├── dashy/docker-compose.yml
│   └── filebrowser/docker-compose.yml
├── backup/                 # restic-Backup: Skript, Service, Timer
├── bichon/                 # docker-compose.yml + .env (nicht versioniert)
├── firewall/               # pi-guard: Zugriffsbegrenzung, siehe 07
├── homepage/               # docker-compose.yml + config/
├── messung/                # befristete Speichermessung, siehe README dort
├── ntfy/                   # docker-compose.yml + server.yml + .env
├── paperless/              # docker-compose.yml + .env
├── portainer/docker-compose.yml
├── sudoers/                # versionierte Kopie der Regeln fuer das Konto claude
└── updates/                # unattended-upgrades, daemon.json, cmdline.txt
```

**Achtung, wiederkehrender Fallstrick:** Die Skripte liegen **doppelt** vor — unter
`/usr/local/bin/` läuft die installierte Fassung, im Repository steht eine Kopie.
Eine Änderung nur im Repository wird nicht wirksam. Nach jeder Änderung beides
anfassen und mit `diff` gegenprüfen.

**Bewertung:** Das ist der durchdachteste Teil des gesamten Setups. Compose-Dateien unter
Versionskontrolle bedeuten, dass die Konfiguration jedes Dienstes nachvollziehbar und
reproduzierbar ist — und im Ernstfall aus GitHub zurückgeholt werden kann.

Für den Stand **vor** der Überarbeitung vom 18.08.2026 gibt es den Tag
`vor-anpassungen-2026-08-18`.

✅ **Der frühere Befund „offene Änderungen im Repository" ist erledigt** — der
Arbeitsstand ist committet, das Repository sauber.

✅ **Der frühere Befund „Pfad-Drift beim Paperless-Stack" ist erledigt.** Das Label
`com.docker.compose.project.config_files` zeigt korrekt auf
`/home/simon/raspi/stacks/paperless/docker-compose.yml` — nachgeprüft am 18.08.2026.

---

## ✅ Behoben: Geheimnis im Compose-Repository (18.08.2026)

In `bichon/docker-compose.yml` stand `BICHON_ENCRYPT_PASSWORD` im **Klartext** und
war in allen 22 Commits des Repositories enthalten. Das Repository ist privat, es war
also kein Leck nach außen — aber der Wert wanderte bei jedem Klon mit und stand
dauerhaft im Verlauf.

**Nicht behoben durch einen Passwortwechsel.** Die Herstellerdokumentation ist
eindeutig: *„Once the password is set, it cannot be changed. Changing it later will
make all encrypted data unreadable."* Ein Wechsel hätte das 690-MB-Archiv unlesbar
gemacht; einen Weg zum Umschlüsseln gibt es nicht. Hinzu kommt: Das Passwort schützt
das Archiv im Ruhezustand auf derselben Platte, auf der auch die Compose-Datei liegt.
Wer an das eine kommt, kommt auch an das andere — der Gewinn eines neuen Passworts
wäre praktisch null gewesen, der Preis das gesamte Archiv.

Behoben stattdessen durch:

1. Wert **unverändert** nach `bichon/.env` (Modus 660, über `.gitignore`
   ausgeschlossen), Compose bindet ihn über `env_file` ein
2. `git filter-repo --replace-text` über alle 22 Commits, danach Force-Push

Nachgeprüft: Der Wert taucht in keinem Commit mehr auf, der Container läuft, das
Archiv ist unverändert lesbar.

**Einschränkung, die man kennen sollte:** GitHub behält umgeschriebene Commits noch
eine Weile als unerreichbare Objekte vor. Vollständig verschwunden sind sie erst nach
einer Garbage Collection auf GitHub-Seite. Für ein privates Repository ist das
vertretbar; bei einem öffentlichen wäre das Passwort als kompromittiert zu behandeln.
