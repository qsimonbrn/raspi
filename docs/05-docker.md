# 05 — Docker

*Erfasst: 13.08.2026*

## Überblick

| | |
|---|---|
| Docker-Version | 29.6.2 (build dfc4efb) |
| Laufende Container | 10 von 10 |
| Compose-Stacks | 7 |
| Images gesamt | 9 (3,78 GB) |
| Neustarts seit 2 Wochen | keine |

## Container

| Container | Image | Port (Host) | Zweck | Restart-Policy |
|---|---|---|---|---|
| **Dashy** | `lissy93/dashy` | 8080 | Dashboard / Startseite | `unless-stopped` |
| **paperless** | `ghcr.io/paperless-ngx/paperless-ngx` | 8000 | Dokumentenarchiv mit OCR | `always` |
| paperless-paperless-db-1 | `postgres:15` | — (intern) | Datenbank für Paperless | `always` |
| paperless-paperless-redis-1 | `redis:7` | — (intern) | Task-Queue für Paperless | `always` |
| **filebrowser** | `filebrowser/filebrowser` | 8082 | Dateizugriff im Browser | `unless-stopped` |
| **bichon** | `rustmailer/bichon` | 15630 | E-Mail-Archivierung | `unless-stopped` |
| **portainer** | `portainer/portainer-ce` | 9000, 9443 | Docker-Verwaltung | `always` |
| **homepage** | `ghcr.io/gethomepage/homepage` | 3000 | Dashboard mit Live-Status | `unless-stopped` |
| **ntfy** | `binwiederhier/ntfy` | 2586 | Push-Benachrichtigungen | `unless-stopped` |
| homepage-dockerproxy | `tecnativa/docker-socket-proxy` | — (intern) | Gefilterter, nur lesender Docker-Zugriff für Homepage | `unless-stopped` |

Kein Container läuft mit `privileged`, kein Container nutzt `network_mode: host`.
Beides ist gut — es bedeutet, dass kein Dienst mehr Rechte hat als nötig.

### Restart-Policies

Die Aufteilung ist konsistent: Die Dienste, deren Ausfall wehtut (Paperless-Stack,
Portainer), stehen auf `always`; die anderen auf `unless-stopped`. Der Unterschied
zeigt sich nur beim manuellen Stoppen — `always` startet den Container auch nach einem
`docker stop` beim nächsten Daemon-Start wieder, `unless-stopped` nicht.

## Ressourcenverbrauch

| Container | CPU |
|---|---|
| paperless | 3,96 % |
| paperless-redis-1 | 1,89 % |
| bichon | 0,09 % |
| Dashy | 0,04 % |
| paperless-db-1 | 0,02 % |
| filebrowser | 0,00 % |
| portainer | 0,00 % |

Zusammen unter 6 % CPU im Leerlauf. Beim RAM ist **bichon** mit rund 11,7 % des
Systemspeichers der größte Einzelverbraucher (`/opt/bichon/bichon`), gefolgt von den
Celery-Workern von Paperless.

**Bewertung:** Der Pi ist weit von seiner Kapazitätsgrenze entfernt. Zwei bis drei
zusätzliche schlanke Dienste (Uptime Kuma, Caddy, Diun) sind problemlos möglich.

---

## ⚠️ Befund: Images seit 8 bis 17 Monaten nicht aktualisiert

| Image | Alter | Risiko |
|---|---|---|
| `postgres:15` | **17 Monate** | hoch — Datenbank mit Netzwerkzugang |
| `ghcr.io/paperless-ngx/paperless-ngx:latest` | **16 Monate** | hoch — verarbeitet eingehende Dokumente |
| `redis:7` | **15 Monate** | mittel |
| `lissy93/dashy:latest` | 9 Monate | mittel |
| `rustmailer/bichon:latest` | 8 Monate | mittel |
| `filebrowser/filebrowser:latest` | 8 Monate | mittel |
| `portainer/portainer-ce:latest` | 8 Monate | mittel |

Seit dem jeweils ersten Start wurde **kein einziges Image aktualisiert**. In diesen
Zeiträumen sind für praktisch alle genannten Projekte Sicherheitsupdates erschienen.

Besonders relevant sind Paperless-ngx und PostgreSQL: Paperless nimmt Dokumente
entgegen und verarbeitet sie mit OCR — also mit Bibliotheken, die untrusted Input
parsen, historisch eine ergiebige Fehlerquelle. PostgreSQL ist über das Docker-Netz
erreichbar.

### Warum ein pauschales Auto-Update hier **nicht** die Lösung ist

Der naheliegende Reflex wäre Watchtower mit automatischem Update aller `:latest`-Tags.
Das ist bei diesem Setup gefährlich:

- **`postgres:15`** bleibt dauerhaft bei PostgreSQL 15 — ein unbeabsichtigter Sprung
  auf 16 ist über diesen Tag **nicht** möglich. *(Korrektur vom 13.08.2026: Die erste
  Fassung dieser Dokumentation behauptete das Gegenteil. Das war schlicht falsch.)*
  Das tatsächliche Risiko liegt woanders: Ein Sprung innerhalb von 15 kann mit einem
  gleichzeitigen Paperless-Update unglücklich zusammenfallen.
- **Paperless-ngx** hat in der Vergangenheit Releases mit erforderlichen manuellen
  Migrationsschritten gehabt. Ein Auto-Update über mehrere Versionen hinweg kann
  Datenbank-Migrationen auslösen, die nicht rückwärtskompatibel sind.

### Empfohlenes Vorgehen

1. **Diun** installieren — meldet neue Images per Benachrichtigung, aktualisiert aber
   nichts selbst. Die Entscheidung bleibt bei dir.
2. **Datenbank-Images auf feste Versionen pinnen**: `postgres:15.14` statt `postgres:15`.
   Damit kann kein unbeabsichtigter Major-Sprung passieren.
3. **Vor jedem Update ein Backup** — insbesondere vor Paperless-Updates.
4. Updates **einzeln und nacheinander** einspielen, nicht alle gleichzeitig. Wenn etwas
   bricht, ist die Ursache dann eindeutig.

**Reihenfolge nach Dringlichkeit:** Paperless-ngx → Portainer → filebrowser → bichon →
Dashy. Redis und PostgreSQL zuletzt und nur mit vorherigem Datenbank-Dump.

---

## Volumes

| Volume | Genutzt von |
|---|---|
| `paperless_paperless_db` | PostgreSQL-Datenverzeichnis |
| `portainer_portainer_data` | Portainer-Konfiguration |
| `03d82858…`, `169ffc10…`, `de3a8348…`, `f60d5d85…` | anonyme Volumes |

Die vier Volumes mit Hash-Namen sind **anonyme Volumes** — sie entstehen, wenn ein Image
ein `VOLUME` deklariert, das in der Compose-Datei nicht explizit gemappt wurde. Ihr
Inhalt ist schwer zuzuordnen und geht bei `docker compose down -v` verloren.

Zwei davon sind laut `docker system df` inaktiv.

**Empfehlung:** Zuordnen, welche anonymen Volumes noch gebraucht werden, und die
zugehörigen Compose-Dateien um explizite Volume-Namen ergänzen. Solange das offen ist,
ist bei Aufräumarbeiten mit `docker volume prune` Vorsicht geboten.

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

Beides Überbleibsel früherer Installationsversuche. `docker image prune -a` entfernt sie.
Bei 214 GB freiem Speicher ist das kein dringendes Problem, aber unnötiger Ballast.

---

## Compose-Dateien

Alle Stacks liegen unter `/home/simon/docker-stacks/` und sind in einem **Git-Repository**
versioniert (`git@github.com:qsimonbrn/docker-stacks.git`).

```
/home/simon/docker-stacks/
├── .git/
├── .gitignore
├── bichon/docker-compose.yml
├── dashy/docker-compose.yml
├── filebrowser/docker-compose.yml
├── paperless/docker-compose.yml
└── portainer/docker-compose.yml
```

**Bewertung:** Das ist der durchdachteste Teil des gesamten Setups. Compose-Dateien unter
Versionskontrolle bedeuten, dass die Konfiguration jedes Dienstes nachvollziehbar und
reproduzierbar ist — und im Ernstfall aus GitHub zurückgeholt werden kann.

### ⚠️ Befund: Offene Änderungen im Repository

```
 D dashy/config/conf.yml      (gelöscht, nicht committet)
 M dashy/docker-compose.yml   (geändert, nicht committet)
```

Der Arbeitsstand weicht vom letzten Commit (`a1f8986 latest dashy test`) ab. Die
Dashy-Konfigurationsdatei wurde gelöscht — siehe Befund unten.

### ⚠️ Befund: Pfad-Drift beim Paperless-Stack

Die Paperless-Container tragen im Label `com.docker.compose.project.config_files` den
Pfad `/home/simon/paperless/docker-compose.yml`. **Dieses Verzeichnis existiert nicht
mehr** — der Stack wurde nach `docker-stacks/paperless/` verschoben, ohne die Container
neu zu erzeugen.

Solange die Container laufen, ist das folgenlos. Sobald jemand aber `docker compose`
aus dem Verzeichnis heraus bedienen will, oder Portainer den Stack anhand des Labels
sucht, führt der Weg ins Leere.

**Behebung:** Einmal `docker compose up -d` aus `docker-stacks/paperless/` heraus
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
`docker compose pull && docker compose up -d`, jedes `docker compose down` und jeder
Image-Wechsel löscht sie ersatzlos.

Zusammen mit der im Git gelöschten `dashy/config/conf.yml` erklärt das, warum das
Dashboard nie über einen Testzustand hinausgekommen ist: Jede Konfiguration ging beim
nächsten Update verloren.

**Das war der eigentliche Grund, warum ein neues Dashboard-Setup nötig war** — nicht die
Wahl der Software.

### ✅ Behoben: Dashboard mit persistenter Konfiguration (13.08.2026)

Als Nachfolger läuft **Homepage** auf Port 3000. Die Konfiguration liegt unter
`docker-stacks/homepage/config/` — also als Volume eingebunden **und** im Git
versioniert. Ein `docker compose pull && up -d` verliert sie nicht mehr.

Der Docker-Zugriff läuft über einen **Socket-Proxy** mit Allowlist statt über einen
direkt eingebundenen Socket. Hintergrund: Ein Bind-Mount mit `:ro` schützt nur die
Socket-*Datei*, nicht die dahinterliegende API — wer den Socket erreicht, kann
Container starten und damit faktisch Root auf dem Host werden. Der Proxy lässt
ausschließlich lesende Container- und Info-Abfragen durch; schreibende Anfragen
werden mit `403` abgewiesen (verifiziert).

Dashy läuft vorerst unverändert auf Port 8080 weiter, damit ein Vergleich möglich
ist. Sobald Homepage sich bewährt hat, kann der Dashy-Stack entfernt werden.
