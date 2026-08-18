# 05 — Docker

*Erfasst: 18.08.2026*

## Überblick

| | |
|---|---|
| Docker-Version | 29.7.2 (build a7dcaa6) |
| Laufende Container | 8 von 8 |
| Compose-Stacks | 5 aktiv, 2 archiviert |
| Images gesamt | **8 (3,63 GB), nichts freigebbar** — aufgeräumt am 18.08.2026 |
| Alle Images | auf feste Versionen bzw. Digests gepinnt (vollständig seit 18.08.2026) |
| Logrotation | 10 MB je Datei, 3 Dateien — in jeder Compose-Datei gesetzt |
| Speicher-Limits | technisch möglich seit dem Neustart am 18.08.2026, noch keine gesetzt |

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

**Acht Container.** 🔒 markiert Dienste, die seit dem 18.08.2026 nur noch über
Tailscale erreichbar sind — siehe [07 — Sicherheit](07-sicherheit.md).

Kein Container läuft mit `privileged`, kein Container nutzt `network_mode: host`,
alle acht laufen mit `no-new-privileges`.

### Abgeschaltet am 18.08.2026

| Dienst | Grund |
|---|---|
| **filebrowser** | Lief in Version 2.51.2 und ist von **CVE-2026-32759** betroffen — Remote Code Execution über den TUS-Upload, **kein Patch verfügbar**. Das Projekt wird zum 01.09.2026 archiviert. Erschwerend: Der Container hatte die gesamte SSD unter `/srv` eingebunden. Ein Nachfolger wird gesucht; aktiv gepflegt wird der Fork **FileBrowser Quantum** (`gtsteffaniak/filebrowser`) |
| **Dashy** | Durch Homepage abgelöst, Image neun Monate alt auf `:latest` |

Die Compose-Dateien liegen weiterhin versioniert unter `docker-stacks/_archiviert/`
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
`docker-stacks/updates/cmdline.txt`). Nachgemessen: `cgroup.controllers` enthält
jetzt `memory`, `docker info` meldet keine Warnung mehr.

## Ressourcenverbrauch

Erste belastbare Speichermessung, 18.08.2026, sechs Minuten nach dem Neustart:

| Container | RAM | Anteil | CPU |
|---|---|---|---|
| paperless | 953 MiB | 25,1 % | 87,9 % (Startlast) |
| homepage | 168 MiB | 4,4 % | 0,0 % |
| portainer | 88 MiB | 2,3 % | 0,0 % |
| paperless-db-1 | 62 MiB | 1,6 % | 0,0 % |
| bichon | 51 MiB | 1,4 % | 0,0 % |
| ntfy | 50 MiB | 1,3 % | 0,0 % |
| homepage-dockerproxy | 30 MiB | 0,8 % | 0,0 % |
| paperless-redis-1 | 15 MiB | 0,4 % | 1,2 % |
| **zusammen** | **rund 1,4 GB** | **38 %** | |

Die CPU-Spitze bei Paperless ist Startlast, kein Dauerzustand. Die früher
dokumentierte Aussage, **bichon** sei mit 11,7 % der größte Speicherverbraucher,
stammte aus einer Zeit ohne Speicherbuchführung und war eine Schätzung aus `ps` —
gemessen ist Paperless mit Abstand der größte Posten, bichon liegt bei 1,4 %.

**Speicher-Limits sind noch nicht gesetzt.** Ein Timer schreibt seit dem 18.08.2026
alle fünf Minuten nach `/mnt/usb-hdd/messungen/docker-speicher.csv`, damit die
Werte auf einer Messung über 24 Stunden beruhen statt auf einer Schätzung. Skript,
Unit und Anleitung zum Entfernen liegen unter `docker-stacks/messung/`.

**Bewertung:** Der Pi ist von seiner Kapazitätsgrenze entfernt, aber nicht mehr
komfortabel weit: 38 % Speicher im Leerlauf lassen für einen schweren zusätzlichen
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

Alle Stacks liegen unter `/home/simon/docker-stacks/` und sind in einem **Git-Repository**
versioniert (`git@github.com:qsimonbrn/docker-stacks.git`).

```
/home/simon/docker-stacks/
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
`/home/simon/docker-stacks/paperless/docker-compose.yml` — nachgeprüft am 18.08.2026.

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
