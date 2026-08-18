# 05 — Docker

*Erfasst: 18.08.2026*

## Überblick

| | |
|---|---|
| Docker-Version | 29.6.2 (build dfc4efb) |
| Laufende Container | 10 von 10 |
| Compose-Stacks | 7 |
| Images gesamt | 20 (8,66 GB) — die alten Tags sind noch da, siehe Aufräumhinweis unten |
| Alle Images | auf feste Versionen gepinnt (seit 16.08.2026) |

## Container

| Container | Image | Port (Host) | Zweck | Restart-Policy |
|---|---|---|---|---|
| **paperless** | `…/paperless-ngx:3.0.5` | 8000 🔒 | Dokumentenarchiv mit OCR | `always` |
| paperless-paperless-db-1 | `postgres:15.19` | — (intern) | Datenbank für Paperless | `always` |
| paperless-paperless-redis-1 | `redis:7.4` | — (intern) | Task-Queue für Paperless | `always` |
| **bichon** | `rustmailer/bichon` | 15630 🔒 | E-Mail-Archivierung | `unless-stopped` |
| **portainer** | `portainer/portainer-ce:2.39.6` | 9000, 9443 🔒 | Docker-Verwaltung | `always` |
| **homepage** | `ghcr.io/gethomepage/homepage` | 3000 | Dashboard mit Live-Status | `unless-stopped` |
| **ntfy** | `binwiederhier/ntfy:v2.27.0` | 2586 | Push-Benachrichtigungen | `unless-stopped` |
| homepage-dockerproxy | `…/docker-socket-proxy:v0.5.0` | — (intern) | Gefilterter, nur lesender Docker-Zugriff für Homepage | `unless-stopped` |

**Acht Container** (zuvor zehn). 🔒 markiert Dienste, die seit dem 18.08.2026 nur noch
über Tailscale erreichbar sind — siehe [07 — Sicherheit](07-sicherheit.md).

Kein Container läuft mit `privileged`, kein Container nutzt `network_mode: host`.

### Abgeschaltet am 18.08.2026

| Dienst | Grund |
|---|---|
| **filebrowser** | Lief in Version 2.51.2 und ist von **CVE-2026-32759** betroffen — Remote Code Execution über den TUS-Upload, **kein Patch verfügbar**. Das Projekt wird zum 01.09.2026 archiviert. Erschwerend: Der Container hatte die gesamte SSD unter `/srv` eingebunden. Ein Nachfolger wird gesucht |
| **Dashy** | Durch Homepage abgelöst, Image neun Monate alt auf `:latest` |

Die Compose-Dateien liegen weiterhin versioniert unter `docker-stacks/_archiviert/`
samt Begründung. Daten wurden nicht gelöscht: `/mnt/usb-hdd/filebrowser-data` (44 KB)
und die Docker-Volumes sind unverändert.
Beides ist gut — es bedeutet, dass kein Dienst mehr Rechte hat als nötig.

### Restart-Policies

Die Aufteilung ist konsistent: Die Dienste, deren Ausfall wehtut (Paperless-Stack,
Portainer), stehen auf `always`; die anderen auf `unless-stopped`. Der Unterschied
zeigt sich nur beim manuellen Stoppen — `always` startet den Container auch nach einem
`sudo docker stop` beim nächsten Daemon-Start wieder, `unless-stopped` nicht.

## Ressourcenverbrauch

| Container | CPU |
|---|---|
| paperless | 3,96 % |
| paperless-redis-1 | 1,89 % |
| bichon | 0,09 % |
| paperless-db-1 | 0,02 % |
| portainer | 0,00 % |

Zusammen unter 6 % CPU im Leerlauf (Messung vom 16.08.2026, noch mit zehn Containern). Beim RAM ist **bichon** mit rund 11,7 % des
Systemspeichers der größte Einzelverbraucher (`/opt/bichon/bichon`), gefolgt von den
Celery-Workern von Paperless.

**Bewertung:** Der Pi ist weit von seiner Kapazitätsgrenze entfernt. Zwei bis drei
zusätzliche schlanke Dienste (Uptime Kuma, Caddy, Diun) sind problemlos möglich.

---

## ✅ Behoben: Images aktualisiert und gepinnt (16.08.2026)

Der frühere Befund lautete: kein einziges Image seit dem ersten Start aktualisiert,
Alter zwischen 8 und 17 Monaten. Das ist für die kritischen Dienste erledigt.

| Image | vorher | jetzt | Anlass |
|---|---|---|---|
| `paperless-ngx` | 2.15.3 (16 Monate) | **3.0.5** | zwei Major-Sprünge, siehe unten |
| `postgres` | `:15` (17 Monate) | **15.19** | Minor gepinnt, kein Sprung auf 16 möglich |
| `redis` | `:7` (15 Monate) | **7.4** | Minor gepinnt |
| `portainer-ce` | `:latest` (8 Monate) | **2.39.6 LTS** | schließt sieben CVEs |
| `ntfy` | `:latest` | **v2.27.0** | |
| `docker-socket-proxy` | `:latest` | **v0.5.0** | |

**Kein Image trägt mehr den Tag `:latest`.** Damit ist reproduzierbar, welche Version
läuft, und ein Neustart holt nie unbemerkt eine andere Version.

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
`template1`. Bei 41 Dokumenten dauerte das Sekunden; bei einem großen Archiv wäre es
eine Wartungsfenster-Aufgabe.

**Merken für künftige Postgres-Updates:** Nach jedem Sprung, der die Debian-Basis
wechselt, in den Logs nach `collation version mismatch` sehen.

---

## ⚠️ Befund: Drei Stacks noch offen

Diese drei sind bewusst nicht mitaktualisiert worden — sie sind Entscheidungen,
keine reinen Updates.

| Stack | Lage | Zu entscheiden |
|---|---|---|
| **homepage** | läuft auf 1.13.2; **v2.0.0** (14.08.2026) bringt einen Breaking Change bei der Authentifizierung | Release Notes lesen, dann gezielt umstellen. Zwei Tage alt — noch nicht abgehangen. |
| ~~**filebrowser**~~ | ✅ **erledigt am 18.08.2026 — abgeschaltet.** Zusätzlich zur Einstellung des Projekts kam CVE-2026-32759 ohne Patch hinzu | Nachfolger wird gesucht |
| ~~**Dashy**~~ | ✅ **erledigt am 18.08.2026 — abgeschaltet.** Die drei Image-Tags liegen noch im System und können beim nächsten Aufräumen weg | — |

`bichon` bleibt auf `:latest` — das Projekt veröffentlicht keine nachvollziehbaren
Versions-Tags. Das Image ist acht Monate alt und damit der letzte verbleibende Dienst
auf altem Stand. Da Bichon E-Mails verarbeitet, also fremdgestaltete Inhalte, ist es
zugleich die exponierteste Stelle. Seit dem 18.08.2026 immerhin nur noch über Tailscale
erreichbar.

### 🟡 Aufräumen: 20 Images für 10 Container

Durch die Updates liegen jetzt alte und neue Images nebeneinander (8,66 GB gesamt).
Nicht mehr referenziert sind unter anderem `paperless-ngx:latest` und `:2.20.15`,
`postgres:15`, `redis:7`, `portainer-ce:latest`, `docker-socket-proxy:0.3.0` und
`:latest` sowie die drei Dashy-Tags.

Aufräumen erst, wenn die neuen Versionen ein paar Tage unauffällig gelaufen sind —
ein altes Image ist die schnellste Rückfallebene:

```bash
sudo docker image prune -a        # entfernt alles, was kein Container referenziert
```

### Was weiterhin gilt

**Diun** (Punkt 2.7 in [Kapitel 09](09-empfehlungen.md)) ist durch das Pinnen nicht
überflüssig geworden, sondern wichtiger: Mit festen Tags erfährt man von neuen
Versionen sonst gar nichts mehr. Diun meldet, aktualisiert aber nicht — die
Entscheidung bleibt bei dir. Watchtower mit Auto-Update bleibt die falsche Antwort;
der Paperless-Zwischenschritt über 2.20.15 ist das Lehrstück dazu.

---

## Volumes

| Volume | Genutzt von |
|---|---|
| `paperless_paperless_db` | PostgreSQL-Datenverzeichnis |
| `portainer_portainer_data` | Portainer-Konfiguration |
| `03d82858…`, `169ffc10…`, `de3a8348…`, `f60d5d85…` | anonyme Volumes |

Die vier Volumes mit Hash-Namen sind **anonyme Volumes** — sie entstehen, wenn ein Image
ein `VOLUME` deklariert, das in der Compose-Datei nicht explizit gemappt wurde. Ihr
Inhalt ist schwer zuzuordnen und geht bei `sudo docker compose down -v` verloren.

Zwei davon sind laut `sudo docker system df` inaktiv.

**Empfehlung:** Zuordnen, welche anonymen Volumes noch gebraucht werden, und die
zugehörigen Compose-Dateien um explizite Volume-Namen ergänzen. Solange das offen ist,
ist bei Aufräumarbeiten mit `sudo docker volume prune` Vorsicht geboten.

## Speicherbelegung

| Typ | Anzahl | Größe | Davon freigebbar |
|---|---|---|---|
| Images | 9 | 3,78 GB | **1,18 GB (31 %)** |
| Container | 7 | 52,94 MB | 0 B |
| Volumes | 6 | 74,42 MB | 130 B |
| Build-Cache | 0 | 0 B | 0 B |

Die 1,18 GB entfallen auf zwei verwaiste Dashy-Tags:

| Image | Größe | Alter |
|---|---|---|
| `lissy93/dashy:3.0.1` | 504 MB | 2 Jahre |
| `lissy93/dashy:arm64v8` | 806 MB | 4 Jahre |

Beides Überbleibsel früherer Installationsversuche. `sudo docker image prune -a` entfernt sie.
Bei 214 GB freiem Speicher ist das kein dringendes Problem, aber unnötiger Ballast.

---

## Compose-Dateien

Alle Stacks liegen unter `/home/simon/docker-stacks/` und sind in einem **Git-Repository**
versioniert (`git@github.com:qsimonbrn/docker-stacks.git`).

```
/home/simon/docker-stacks/
├── .git/
├── .gitignore
├── _archiviert/            # abgeschaltete Dienste, Konfiguration bleibt nachvollziehbar
│   ├── README.md
│   ├── dashy/docker-compose.yml
│   └── filebrowser/docker-compose.yml
├── backup/                 # restic-Backup: Skript, Service, Timer
├── bichon/docker-compose.yml
├── firewall/               # pi-guard: Zugriffsbegrenzung, siehe 07
├── homepage/
├── ntfy/
├── paperless/docker-compose.yml
└── portainer/docker-compose.yml
```

**Bewertung:** Das ist der durchdachteste Teil des gesamten Setups. Compose-Dateien unter
Versionskontrolle bedeuten, dass die Konfiguration jedes Dienstes nachvollziehbar und
reproduzierbar ist — und im Ernstfall aus GitHub zurückgeholt werden kann.

✅ **Der frühere Befund „offene Änderungen im Repository" ist erledigt** — der
Arbeitsstand ist seit dem 18.08.2026 committet, das Repository sauber.

✅ **Der frühere Befund „Pfad-Drift beim Paperless-Stack" ist erledigt.** Das Label
`com.docker.compose.project.config_files` zeigt seit dem Update vom 16.08.2026 korrekt auf
`/home/simon/docker-stacks/paperless/docker-compose.yml` — nachgeprüft am 18.08.2026.

**Behebung:** Einmal `sudo docker compose up -d` aus `docker-stacks/paperless/` heraus
ausführen. Die Container werden dabei neu erstellt und tragen anschließend den
richtigen Pfad. **Vorher Backup anlegen** — bei dieser Gelegenheit werden auch die
Images neu ausgewertet.

---

## ⚠️ Befund: Dashy-Konfiguration ist nicht persistent

In `dashy/docker-compose.yml` ist der Volume-Block **auskommentiert**:

```yaml
    # volumes:
      # - /root/my-config.yml:/app/user-data/conf.yml
```

Damit existiert die Dashy-Konfiguration ausschließlich im Container-Dateisystem. Jedes
`sudo docker compose pull && sudo docker compose up -d`, jedes `sudo docker compose down` und jeder
Image-Wechsel löscht sie ersatzlos.

Zusammen mit der im Git gelöschten `dashy/config/conf.yml` erklärt das, warum das
Dashboard nie über einen Testzustand hinausgekommen ist: Jede Konfiguration ging beim
nächsten Update verloren.

**Das war der eigentliche Grund, warum ein neues Dashboard-Setup nötig war** — nicht die
Wahl der Software.

### ✅ Behoben: Dashboard mit persistenter Konfiguration (13.08.2026)

Als Nachfolger läuft **Homepage** auf Port 3000. Die Konfiguration liegt unter
`docker-stacks/homepage/config/` — also als Volume eingebunden **und** im Git
versioniert. Ein `sudo docker compose pull && up -d` verliert sie nicht mehr.

Der Docker-Zugriff läuft über einen **Socket-Proxy** mit Allowlist statt über einen
direkt eingebundenen Socket. Hintergrund: Ein Bind-Mount mit `:ro` schützt nur die
Socket-*Datei*, nicht die dahinterliegende API — wer den Socket erreicht, kann
Container starten und damit faktisch Root auf dem Host werden. Der Proxy lässt
ausschließlich lesende Container- und Info-Abfragen durch; schreibende Anfragen
werden mit `403` abgewiesen (verifiziert).

Dashy läuft vorerst unverändert auf Port 8080 weiter, damit ein Vergleich möglich
ist. Sobald Homepage sich bewährt hat, kann der Dashy-Stack entfernt werden.
