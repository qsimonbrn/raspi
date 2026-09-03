# 15 — Änderungshistorie des Systems

*Erfasst: 18.08.2026 · zuletzt ergänzt 03.09.2026*

Dieses Kapitel ist das Betriebstagebuch des Pi: **was am laufenden System geändert
wurde, wann und warum**. Es beantwortet die Frage „seit wann ist das eigentlich so?"
und, wichtiger noch, „warum haben wir das damals so entschieden?".

> **Abgrenzung zum [CHANGELOG](../CHANGELOG.md):** Der CHANGELOG verzeichnet Änderungen
> an *dieser Dokumentation*. Hier stehen Änderungen am *System*. Beides gehört zusammen,
> ist aber nicht dasselbe: Eine reine Aktualisierung von Messwerten erscheint im
> CHANGELOG, nicht hier. Ein Systemumbau erscheint in beiden.

**Was hier hineingehört:** neue oder entfernte Dienste, Versionswechsel mit Folgen,
geänderte Ports und Zugriffswege, Sicherheitsentscheidungen, Umbauten an Speicher und
Backup.

**Was nicht:** Tests, Fehlersuche ohne Ergebnis, reine Abfragen, Container-Neustarts.

---

## 03.09.2026 — Richtigstellung: Diun meldet keine neuen Versionen

| | |
|---|---|
| Behauptet seit 25.08.2026 | „Diun meldet neue Image-Versionen" |
| Gemessen am 03.09.2026 | 9 Läufe, jedes Mal `unchanged=11`, `failed=0` |
| Gegenprobe | Paperless-ngx 3.1.0 (27.08.), 3.1.1 (31.08.), 3.1.2 (01.09.) — auf dem Pi läuft 3.0.5, gemeldet wurde keine |
| Ursache | Ohne `diun.watch_repo` beobachtet Diun nur den **Digest des gepinnten Tags**, nicht die Tag-Liste der Registry |
| Am System geändert | **nichts** — die Umstellung braucht `include_tags` je Image, sonst Meldungsflut. Als Punkt 2.14 aufgenommen |

**Warum das hier steht, obwohl nichts geändert wurde:** Der Befund ist eine
Richtigstellung, keine Systemänderung — aber er betrifft eine Alarmkette, die seit neun
Tagen als geschlossen galt. Der Eintrag vom 25.08.2026 bleibt unverändert stehen; er
beschreibt richtig, was gebaut wurde, und falsch, was es leistet.

**Die Lehre, und sie ist die Schwester der ntfy-Lehre vom 25.08.:** Damals war
`http=200` die Annahme durch den Server, nicht die Zustellung. Diesmal ist
`Jobs completed failed=0` der fehlerfreie Lauf, nicht die Erkennung. **Beide Male sah
die Prüfung gut aus, weil sie die Frage maß, die leicht zu messen war.** Der Nachweis
für einen Melder ist immer derselbe: eine bekannte Änderung von außen hineingeben und
sehen, ob sie ankommt.

---

## 03.09.2026 — Neuer Dienst: insta-triage

| | |
|---|---|
| Neu | Stack `stacks/insta-triage`, Container `insta-triage`, Image lokal gebaut `insta-triage:1.0.0` |
| Port | 8080, gebunden an `100.108.219.87` (Tailscale) — **nicht** an `0.0.0.0` |
| Daten | `/mnt/usb-hdd/insta-triage/` (SQLite, Profilbilder, Import-Ablage) |
| Grenzen | `mem_limit: 256m`, `no-new-privileges`, Logrotation über den üblichen YAML-Anker |
| Nachweis | Container läuft, Upload- und Importweg mit Testdaten durchgespielt, Testdaten danach entfernt; Datenbank beim Eintrag leer |

**Wozu:** Der Instagram-Hauptaccount folgt 1955 Accounts, über zehn Jahre gewachsen. Die
App liest den Instagram-Datenexport samt einer im Browser gezogenen Profilliste ein, zeigt
die Abos mit Bild und Klarnamen an und führt drei Listen: behalten, entfolgen, auf einen
Zweitaccount migrieren. **Sie hat keinen Zugang zu Instagram und entfolgt selbst nichts** —
es gibt keine offizielle Schnittstelle dafür, und alles Inoffizielle riskiert einen zehn
Jahre alten Account, ohne schneller zu sein als Handarbeit (Instagram lässt rund 100–150
Unfollows am Tag durch). Die App sagt nur, was als Nächstes dran ist, und merkt sich, was
erledigt wurde.

**Warum die Bindung an die Tailscale-Adresse und nicht `pi-guard`:** `pi-guard` sperrt
Ports anhand einer festen Liste im Skript. Ein neuer Dienst wäre so lange im ganzen
Heimnetz offen, bis jemand daran denkt, die Liste zu ergänzen — und das Skript ist ein
laufender Sicherheitsbaustein, an dem für einen Nebendienst nichts geändert werden sollte.
Die Bindung an `100.108.219.87` erreicht dasselbe Ziel in der Datei, die den Dienst
ohnehin startet. Einzelheiten in [05 — Docker](05-docker.md).

**Offen:** ob `/mnt/usb-hdd/insta-triage/` ins restic-Backup gehört. Die Entscheidungen
darin sind Handarbeit, die Bilder sind nachladbar — die Frage ist in
[12 — Backup](12-backup.md) noch nicht beantwortet.

## 02.09.2026 — Pi-hole: Gerätegruppe `bild-frei` für zwei Geräte

| | |
|---|---|
| Neu | Gruppe `bild-frei` (id 1) in `gravity.db`, neun Regex-Allowlist-Einträge |
| Mitglieder | `192.168.178.96` (Notebook Vater), `192.168.178.142` (Smart-TV) |
| Wirkung auf übrige Geräte | keine — gegen einen unbeteiligten Client nachgemessen |
| Nachweis | Notebook `.96` am 02.09. zwischen 11 und 18 Uhr mehrere hundert bild-Anfragen, davon null geblockt; um 09 Uhr, vor der Einrichtung, 62 von 88 |

**Warum:** BILD zeigt statt der Inhalte eine Anti-Blocker-Schranke, wenn seine Werbe- und
Consent-Dienste nicht laden. `bild.de` selbst war nie gesperrt — die Domain löste von
Anfang an auf. Freigegeben ist deshalb nicht die Seite, sondern der Satz Prüfpunkte, den
sie abfragt: Sourcepoint (`html-load.com`, `content-loader.com` und drei rotierende
Wegwerfnamen), das Consent-Banner (`cookielaw.org`) und der Adition-Werbeserver
(`asadcdn.com`). Werbeauslieferung und Profilbildung bleiben auch für diese beiden Geräte
gesperrt. Einzelheiten und das Runbook für den Wiederholungsfall in
[04 — Systemdienste](04-dienste-system.md).

**Was dabei schiefging und behoben wurde:** Pi-hole hängt jede neu angelegte Freigabe per
Datenbank-Trigger zusätzlich in die Gruppe `Default` — also netzweit. Das ist beim Anlegen
zweimal passiert und erst bei der Kontrollabfrage aufgefallen; die Default-Zuordnungen
wurden entfernt und der Zustand gegen einen unbeteiligten Client nachgemessen. Zwischen
etwa 10:17 und 10:40 Uhr war die Regex für `bild.de` dadurch für alle Geräte wirksam.

**Verworfen:** Simons MacBook war zum Testen kurzzeitig Mitglied und wurde am selben Tag
wieder entfernt. Es fragt über Tailscale (`100.69.172.65`), nicht unter seiner
Heimnetz-Adresse — eine Regel für `192.168.178.94` hätte nie gewirkt.

---

## 25.08.2026 — Diun eingerichtet: Update-Meldungen ohne `:latest`

| | |
|---|---|
| Neu | `stacks/diun/` mit `crazymax/diun:4.33.0` und einem eigenen `docker-socket-proxy:v0.5.0` |
| Zeitplan | täglich 06:15 — nach Backup (03:17) und Blocklisten-Lauf (03:02) |
| Meldeweg | ntfy, Thema `raspberrypi`, über das **neue Dienstkonto `diun`** |
| Zustand | `/mnt/usb-hdd/diun/diun.db`, bewusst nicht im Backup |
| Ports | keine — Diun hat keine Oberfläche und taucht in `pi-guard` nicht auf |
| Nachweis | `Jobs completed added=11 failed=0`, Testmeldung über `diun notif test` vom Server angenommen |

**Warum überhaupt:** Alle Images sind auf feste Versionen gepinnt. Ohne `:latest`
erfährt man von einer neuen Version gar nichts mehr — auch nicht von einer, die eine
Lücke schließt. Seit dem 23.08.2026 liegt ein Passwort-Tresor auf diesem Pi; dort soll
eine Lücke am selben Tag auffallen, nicht beim nächsten Blick ins Repository.

**Warum ein eigener Socket-Proxy und nicht der von Homepage:** Diun am Netz
`homepage_default` wäre von einem fremden Stack abhängig. Wer Homepage einmal mit `down`
abräumt, nimmt Diun stumm die Datenquelle weg — **und Stille meldet Diun nicht.** Preis
48 MiB, dafür steht die Überwachung für sich.

**Warum ein eigenes ntfy-Konto und nicht der vorhandene Token:** `diun` darf
ausschließlich auf `raspberrypi` schreiben, nicht lesen, kein anderes Thema. Gegen alle
drei Fälle gemessen. Damit ist der Zugang einzeln widerrufbar, ohne den Backup-Alarm
mitzunehmen.

**Zwei eigene Fehler, beide erst durch Nachmessen sichtbar geworden:**

1. **`IMAGES: 0` im Socket-Proxy** — die Annahme, Diun brauche nur die Container-Liste,
   war falsch. Es braucht `ImageInspect`. Der Dienst startete klaglos, schrieb elfmal
   `403` ins Log und meldete `added=0`: **er lief und überwachte nichts.** Auf `IMAGES: 1`
   korrigiert, danach `added=11`.
2. **Zeilenumbruch in der Tokendatei** — `ntfy token add | tee` hängt `\n` an, Diun
   setzt es in den `Authorization`-Header, Versand scheitert. Der vorherige Test mit
   `curl -H "… $(cat datei)"` war blind dafür, weil die Kommandosubstitution den Umbruch
   schluckt. Gefunden erst durch `diun notif test`.

**Offen geblieben:** Ob eine *echte* Update-Meldung auf dem iPhone erscheint, ist erst
nachweisbar, wenn eine neue Version herauskommt. Der Zustellweg selbst wurde am selben
Tag mit der ntfy-Reparatur bewiesen, der Absender `diun` bis zur Annahme durch den
Server.

---

## 25.08.2026 — ntfy stellt zu: `upstream-base-url` ergänzt

| | |
|---|---|
| Geändert | `stacks/ntfy/server.yml`: `upstream-base-url: "https://ntfy.sh"` ergänzt, Container neu gestartet |
| Unverändert | `base-url` bleibt `http://192.168.178.80:2586` |
| Nachweis | Meldung auf dem gesperrten iPhone erschienen, App vorher geschlossen |
| Gegenprobe | iptables-Zählregel: 13 Pakete des Containers an `ntfy.sh`, Kontrollregel auf eine unbeteiligte Adresse 0 |

**Warum so und nicht anders:** Die `base-url` hätte auf einen `tailscale serve`-Port
umgestellt werden können — mit echtem TLS statt Klartext-HTTP im WLAN. Dagegen sprach,
dass beide Wege gleichermaßen von aktivem Tailscale auf dem Handy abhängen: Der Pi
bietet `192.168.178.0/24` ins Tailnet an, die Route ist freigegeben. Der TLS-Gewinn
beträfe nur den Transport im Heimnetz, der Aufwand hätte sich verdreifacht. Bei
sensiblerem Inhalt als „Backup fehlgeschlagen“ wäre die Abwägung eine andere.

**Was dabei auffiel und die Prüfung entwertete:** Ein erfundener Konfigurationsschlüssel
(`quatsch-option-negativkontrolle`) hindert ntfy **nicht** am Start — der Server
übergeht Unbekanntes kommentarlos. „Container läuft nach dem Neustart“ beweist also
nicht, dass er die geänderte Datei gelesen hat. Der Nachweis musste über den
tatsächlichen Netzverkehr geführt werden.

**Rechtsstellung des Vortags:** Der Eintrag vom 23.08.2026 bleibt unverändert stehen.
Er beschreibt den damaligen Zustand richtig.

**Nachgezogen:** [14 — Benachrichtigungen](14-benachrichtigungen.md) Abschnitt 4 neu
geschrieben, [09 — Empfehlungen](09-empfehlungen.md) Punkt 2.1 auf erledigt,
`inventar/collect.sh` um eine Prüfung der Zustellvoraussetzung erweitert.

---

## 23.08.2026 — Korrektur: ntfy stellt nicht zu

| | |
|---|---|
| Betroffen | Eintrag von heute weiter unten („Passwörter erneuert, ntfy-Token gewechselt") |

**Zurückgenommen:** Dort steht, der offene Punkt „ntfy-Meldung einmal echt auslösen"
sei erledigt. Das war falsch. Bewiesen wurde, dass der Server die Meldung *annimmt*
(`http=200`) — nicht, dass sie ankommt. Genau um den zweiten Teil ging es bei diesem
Punkt.

**Auf Nachfrage hat Simon bestätigt: von heute ist keine einzige Meldung auf dem
iPhone angekommen.** Die anschließende Messung zeigt `subscribers=0` über den ganzen
Abend und eine fehlende `upstream-base-url` in `server.yml`. Ohne sie kann die
iOS-App von einem selbst gehosteten Server im Hintergrund nichts empfangen.

**Folge:** Die Alarmkette für fehlgeschlagene Backups war seit dem 13.08.2026 nie
geschlossen. Der Punkt bleibt offen und steht als 2.1 in
[09 — Empfehlungen](09-empfehlungen.md). Nach Absprache mit Simon **nicht dringend**.

**Warum das hier steht und der alte Eintrag stehen bleibt:** Verlaufsdateien werden
nicht umgeschrieben. Eine Korrektur, die die falsche Aussage verschwinden ließe,
würde auch verschwinden lassen, dass derselbe Denkfehler zweimal an einem Tag
gemacht wurde — und der ist die eigentliche Lehre.

---

## 23.08.2026 — Passwörter erneuert, ntfy-Token gewechselt

| | |
|---|---|
| Betroffen | Pi-hole, Samba, Paperless, ntfy |
| Anlass | Nach dem Aufsetzen von Vaultwarden sollten die Dienstpasswörter durch starke, im Tresor erzeugte ersetzt werden |

**Geändert:** Weboberflächen-Passwort von Pi-hole, Samba-Passwort für `simon`,
Paperless-Anmeldung `admin`, ntfy-Benutzer `simon`.

**Nachtrag 23:00 Uhr — Portainer.** Das Passwort war nicht mehr bekannt und liess
sich nicht auslesen: Das Image ist distroless, es gibt keine Shell im Container.
Zuruecksetzen ueber `portainer/helper-reset-password` gegen das Volume
`portainer_portainer_data`, bei angehaltenem Container. Dabei zwei Erkenntnisse:
Das Konto heisst **`simon`**, nicht `admin` — die Doku hatte das nie festgehalten.
Und der Helfer *fragt* nicht nach einem Passwort, er erzeugt eines und gibt es aus;
wer damit rechnet, gefragt zu werden, haelt den Lauf faelschlich fuer gescheitert.

`stop`/`start` statt `down`/`up` gewaehlt, damit der Container nicht neu erzeugt wird
und Docker die iptables-Regeln nicht neu schreibt. Nachgemessen: `pi-guard` mit allen
vier DROP-Regeln, Portainer `http=200`.

Das Helfer-Image `portainer/helper-reset-password:latest` liegt seitdem ungepinnt auf
dem Pi und wird nicht mehr gebraucht — Aufraeumpunkt in `docs/09-empfehlungen.md`.
Bichon bleibt bewusst unangetastet — das Verschlüsselungspasswort ist laut Hersteller
nicht änderbar, ohne das Archiv unlesbar zu machen.

**Nachgemessen**, ohne die Passwörter zu kennen: `pihole.toml` (22:28),
`passdb.tdb` (22:30) und `user.db` (22:41) sind neu geschrieben; der
Paperless-Hash weicht von dem im Snapshot `143d751d` (21:41) ab.

**Der ntfy-Zugriffstoken wurde ersetzt.** Grund war ein Fehler von Claude: Der alte
Token wurde bei einer Prüfung im Klartext ausgegeben und war damit verbrannt. Ablauf
in der Reihenfolge neu → prüfen → alt löschen → Gegenprobe: Versand mit dem neuen
Token `200`, mit dem alten danach `401`, über `/root/.ntfy-token` `200`.

**Damit erledigt sich ein offener Punkt:** Der ntfy-Zustellweg ist zum ersten Mal
tatsächlich ausgelöst worden. Bis dahin waren nur die Voraussetzungen geprüft.

**`stacks/ntfy/.env` enthält keine Zugangsdaten mehr.** Der Container hat kein
`env_file` und hat die Datei nie gelesen — die drei Zeilen waren eine Zweitschrift,
die beim Passwortwechsel am selben Tag still falsch wurde. Ein Ort für ein Geheimnis
ist besser als zwei, von denen einer niemandem auffällt.

---

## 23.08.2026 — Vaultwarden aufgesetzt

| | |
|---|---|
| Betroffen | neuer Container `vaultwarden`, `pi-backup.sh`, Homepage, `inventar/collect.sh` |
| Anlass | Passwörter lagen bis dahin nicht an einem gemeinsamen, gesicherten Ort |

**Was gemacht wurde:** Vaultwarden 1.37.2 als neuer Stack unter `stacks/vaultwarden/`,
erreichbar ausschließlich über `tailscale serve` auf Port 8443. Der Container bindet an
`127.0.0.1:8222` und ist damit selbst aus dem Heimnetz nicht ansprechbar. Erstes Konto
angelegt, danach `SIGNUPS_ALLOWED=false`. Die Admin-Oberfläche `/admin` bleibt
abgeschaltet.

**Warum 1.37.2, obwohl einen Tag alt:** Die Release Notes nennen die Version als
Voraussetzung für Clients ab 2026.8.0. Ein frisch installierter Bitwarden-Client hätte
sich mit 1.37.1 mit hoher Wahrscheinlichkeit nicht verbunden. Das Risiko einer sehr
frischen Version wurde gegen die Gewissheit eines nicht verbindungsfähigen Clients
abgewogen.

**Reihenfolge mit Absicht:** Der Backup-Pfad wurde eingerichtet, *bevor* der Container
lief. Ein Tresor, der Daten sammelt, bevor er im Backup steht, ist ein Zeitfenster, in
dem ein Ausfall echten Schaden anrichtet.

**Backup erweitert:** `pi-backup.sh` legt einen konsistenten SQLite-Abzug an, statt die
laufende Datei zu kopieren, und prüft ihn. Dabei wurde gemessen, dass
`PRAGMA integrity_check` eine **leere Datei mit `ok`** durchgehen lässt — die Prüfung
wurde deshalb um eine Abfrage der Benutzertabelle ergänzt. Einzelheiten in
[18 — Vaultwarden](18-vaultwarden.md), Abschnitt 6.

**Nebenbefund, behoben:** `inventar/collect.sh` fragte `gravity.db` ohne `sudo` ab. Seit
dem Wechsel auf das Konto `claude` am 18.08.2026 scheiterte das still — die
Bestandsaufnahme meldete `?` statt der Zahlen. Mit `sudo` liefert dieselbe Abfrage
1.039.885 Domains.

**Nebenbefund, geklärt:** Die vier Blocklisten mit `status=2` sind unauffällig. Laut der
installierten `gravity.sh` bedeutet 2 „List stayed unchanged" — Cache benutzt, weil
oben nichts neu war. Der bedenkliche Fall wäre 3 („download failed, using cached"); den
hat keine Liste.

**Geprüft:** `tailscale serve --bg` übersteht einen Neustart — die offene Frage vom
23.08.2026 ist damit beantwortet.

---

## 23.08.2026 — Neustartverhalten geprüft

| | |
|---|---|
| Betroffen | Pi-hole, Docker, `pi-guard` |
| Kapitel | [04 — Dienste](04-dienste-system.md) |

**Anlass.** Kontrollierter Neustart, um das Verhalten der Dienste nach einem Kaltstart
zu kennen.

**Befund.** 8/8 Container hoch, `pi-guard` unbeschädigt (alle vier Ketten, IPv4 und IPv6,
je `DOCKER-USER` und `INPUT`), fünf Timer aktiv, Zertifikat unverändert.

**Aber: Pi-hole blockt in den ersten ein bis zwei Minuten nach dem Boot nicht.**
`dig doubleclick.net @127.0.0.1` lieferte bei einer Minute Uptime die echte Google-IP
(`142.251.13.113`), bei drei Minuten `0.0.0.0`. `sudo pihole -q doubleclick.net` bestätigte
durchgehend, dass die Domain auf zwei Listen steht, und `pihole status` meldete die ganze
Zeit „blocking is enabled". FTL reicht Anfragen also an den Upstream durch, bis die
gravity-Liste im Speicher ist — ohne dass irgendeine Statusabfrage das anzeigt.

**Nachgemessen.** `/var/log/pihole/pihole.log` nach dem Ladevorgang:
`gravity blocked doubleclick.net is 0.0.0.0`.

> **Fallstrick:** Vor jeder Blocklisten-Messung `uptime` prüfen. Wer direkt nach einem
> Neustart misst, hält Pi-hole für kaputt.

**Neu offen.** Vier von acht Blocklisten stehen auf `status=2`. Ob das „upstream
unverändert, Cache benutzt" (harmlos) oder „Download fehlgeschlagen, Cache benutzt"
(nicht harmlos) bedeutet, ist ungeklärt. `pihole -g` endet in beiden Fällen mit Exit 0,
und `pi-gravity.sh` achtet nur auf Schrumpfen um mehr als ein Viertel — der zweite Fall
wäre still. Gravity zählt 1.039.885 Domains gegenüber 1.115.658 am 20.08.

---

## 20.08.2026 — HTTPS im Tailnet freigeschaltet, Weg über Port 8443 erprobt

| | |
|---|---|
| Betroffen | Tailscale, Pi-hole (Portbelegung), Vorbereitung Vaultwarden |
| Kapitel | [10 — Zugriff](10-zugriff.md) |

**Anlass.** Vaultwarden soll auf den Pi. Die Bitwarden-Clients nutzen die
Web-Crypto-API, und die läuft nur in einem „secure context" — über `http://`
verweigern sie den Dienst. HTTPS ist hier ausdrücklich **kein Sicherheitsgewinn**:
Der Verkehr zu Paperless, Portainer und Bichon läuft schon durch Tailscale und ist
per WireGuard verschlüsselt. HTTPS ist reine Freischaltbedingung.

**Befund.** Vor der Freischaltung war `CertDomains` leer, es lag kein Zertifikat vor,
kein Reverse Proxy war installiert — und **`pihole-FTL` belegt `0.0.0.0:80` und
`0.0.0.0:443`**, auch auf der Tailscale-Adresse. Eine Anfrage an
`https://raspberrypi.tailf372ec.ts.net/` scheiterte mit `tls_verify=20`, weil Pi-hole
sein selbstsigniertes `CN=pi.hole` auslieferte.

**Entscheidung.** `tailscale serve` auf **8443** statt Pi-hole von 443 zu verdrängen.
Der Eingriff in `pihole.toml` würde bei jedem Pi-hole-Core-Update überschrieben — wie
schon bei `/etc/cron.d/pihole` — und brächte außer einer schöneren URL nichts. Preis:
ein Port in der URL. Ebenfalls verworfen: eine Sicherung des Zertifikatsschlüssels auf
dem Mac, weil `tailscale serve` das Zertifikat selbsttätig holt und erneuert; eine
Kopie vergrößert nur die Zahl der Orte mit Schlüsselmaterial.

**Durchgeführt.** Simon hat HTTPS in der Tailscale-Admin-Konsole freigeschaltet
(DNS → HTTPS Certificates → Enable HTTPS). Danach `tailscale cert` einmal von Hand,
`tailscale serve` testweise auf 443 und auf 8443, anschließend `tailscale serve reset`.
Die vom Handaufruf zusätzlich in `/home/claude` abgelegte Kopie des privaten Schlüssels
wurde noch am selben Tag gelöscht.

**Nachgemessen.**

| Messung | Ergebnis |
|---|---|
| `CertDomains` nach der Freischaltung | `['raspberrypi.tailf372ec.ts.net']` |
| Zertifikat | Let's Encrypt, gültig bis 18.11.2026, in `/var/lib/tailscale/certs/` |
| `serve` auf **443** | **meldet Erfolg, wirkt nicht** — 443 liefert weiter `CN=pi.hole` |
| `serve` auf **8443** | `http=200`, `tls_verify=0`, Let's-Encrypt-Zertifikat validiert |
| Negativkontrolle aus dem LAN (`192.168.178.80:8443`) | `http=000` — tailnet-only |
| Zustand danach | `No serve config`, 443 wieder bei Pi-hole |

> **Fallstrick:** `tailscale serve --https=443` gibt „Serve started and running in the
> background" aus und ändert nichts, weil `pihole-FTL` schon am Socket sitzt. Es gibt
> **keine** Fehlermeldung. Wer nur die Erfolgsmeldung liest, hält HTTPS für eingerichtet.

> **Zweiter Fallstrick:** `tailscale cert` von Hand aufgerufen schreibt den privaten
> Schlüssel zusätzlich ins Arbeitsverzeichnis. Für `tailscale serve` ist der Handaufruf
> ohnehin unnötig.

**Offen geblieben.** Ob `tailscale serve --bg` einen Neustart überlebt, ist **nicht**
geprüft — beim Neustart am 23.08. bestand gar keine serve-Konfiguration mehr. Die
Frage klärt sich beim Aufsetzen von Vaultwarden.

---

## 20.08.2026 — Speicher-Limits gesetzt, Tailscale aktualisiert

| | |
|---|---|
| Betroffen | Alle fünf Compose-Stacks, Paket `tailscale` |
| Kapitel | [05](05-docker.md), [02](02-betriebssystem.md) |
| Rückfallebene | Die Limits stehen versioniert in den Compose-Dateien; ein Entfernen der Zeilen plus `compose up -d` stellt den vorherigen Zustand her |

**Anlass.** Die Messung lief seit dem 18.08.2026 und war überfällig. Ohne Limits sucht
sich der OOM-Killer im Ernstfall ein beliebiges Opfer, und das ist selten der Dienst, der
das Problem verursacht hat.

**Grundlage.** 603 Messpunkte je Container über zwei Tage und fünf Stunden.

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

**Zwei Gründe für die Großzügigkeit — beide aus den Daten, nicht aus Vorsicht:**

1. **Die Messung sieht kurze Spitzen nicht.** Sie tastet alle fünf Minuten ab; ein
   OCR-Lauf dauert oft unter zwei Minuten. Das Maximum von 907 MiB bei Paperless ist eine
   Untergrenze. Ein knappes Limit hätte irgendwann mitten in einer Texterkennung
   zugeschlagen, und das Dokument wäre im Einwurf liegen geblieben.
2. **bichon wächst noch.** 14,7 MiB beim Kaltstart, Median 370, Maximum 462 — der
   Arbeitssatz baute sich über die zwei Tage auf und war am Ende nicht am Ende.

Die Summe der Limits liegt bei 3.104 MiB von 3.796 MiB RAM. **Nichts ist überbucht:**
Selbst wenn alle acht gleichzeitig anschlagen, bleibt dem System Luft.

**Durchgeführt.** Stack für Stack `compose up -d`, zuerst die vier kleinen, dann
Paperless. Ein `mem_limit` greift erst beim Neuerzeugen des Containers — ein Neustart
genügt nicht.

**Nachgemessen.** Alle acht Container melden ihr Limit über `docker inspect`
(`HostConfig.Memory`), `OOMKilled=false`, `RestartCount=0`. Paperless war nach 125 s
wieder `healthy` und liegt bei 753 MiB von 1,25 GiB (59 %). **`pi-guard` hat das
Neuerzeugen überstanden** — beide Ketten stehen mit je einer Referenz, die Zähler laufen
weiter. Das war die eigentliche Frage bei dieser Änderung: Docker schreibt seine
iptables-Regeln beim Erzeugen eines Containers neu, und die Sperre der
Verwaltungsoberflächen hängt genau dort.

**Die Messung läuft weiter.** Ihr erster Zweck ist erfüllt, ihr zweiter beginnt gerade:
zu zeigen, ob ein Container gegen seine neue Decke läuft. Entfernt wird sie erst, wenn
das ein bis zwei Wochen lang nicht passiert.

**Tailscale 1.102.2 → 1.102.3.** Von Hand, weil das Paket aus einem eigenen Repository
kommt und `unattended-upgrades` auf `origin=Debian` beschränkt ist. Danach: Tailnet
vollständig, alle drei Geräte sichtbar, Exit Node weiterhin angeboten, 0 ausstehende
Pakete. **Das bleibt ein Dauerauftrag** — dieses eine Paket wird nie selbsttätig
aktualisiert.

---

## 20.08.2026 — Zwei Passwörter aus dem Git-Verlauf entfernt

| | |
|---|---|
| Betroffen | Repository `qsimonbrn/raspi` (alle 61 Commits neu geschrieben), `docs/07`, `CHANGELOG.md`, `inventar/collect.sh` |
| Kapitel | [07](07-sicherheit.md) |
| Rückfallebene | `/mnt/usb-hdd/backups-manuell/raspi-vor-filter-repo-20260820.tar.gz` (Modus 600, 671 Dateien, vor dem Eingriff geprüft) · GitHub-Tag `vor-anpassungen-2026-08-18` |

**Anlass.** Die Behauptungsprüfung meldete beim zweiten Lauf erneut eine verdächtige
Zeile im Git-Verlauf. Beim Nachsehen waren es **zwei** Geheimnisse, nicht eines:
`POSTGRES_PASSWORD` und `PAPERLESS_ADMIN_PASSWORD`, beide in neun Commits zwischen dem
10.12.2025 und dem 13.08.2026.

**Vor dem Eingriff nachgemessen — beide Werte sind tot:**

| Wert | Ergebnis | Prüfung |
|---|---|---|
| `POSTGRES_PASSWORD` | wird abgelehnt | Verbindung aus dem Paperless-Container über TCP gegen `paperless-db`; Positivkontrolle mit dem laufenden Wert aus `.env` angenommen, Negativkontrolle mit Zufallswert abgelehnt |
| `PAPERLESS_ADMIN_PASSWORD` | wird abgelehnt | `check_password()` gegen das Konto `admin` → `False` |

Die Positiv- und Negativkontrolle war nötig, weil der erste Versuch **wertlos** war: Ein
`psql` im Datenbankcontainer läuft über den lokalen Socket, und dafür steht in
`pg_hba.conf` `trust` — dort wird *jedes* Passwort angenommen, auch ein zufälliges. Ohne
die Gegenprobe wäre die Meldung „das alte Passwort gilt noch" in die Doku gewandert.

**Durchgeführt.**

1. `docs/07` und `CHANGELOG.md` maskiert und committet. **Diese Reihenfolge ist
   zwingend:** Beide Dateien schrieben die Werte im Klartext aus. Wer erst den Verlauf
   bereinigt und dann committet, schreibt das Geheimnis im selben Zug wieder hinein.
2. `git filter-repo --replace-text` über alle 61 Commits. Das Admin-Passwort als
   `literal`, das Postgres-Passwort **nur in der Zuweisung** als `regex` — es lautete
   `paperless`, und eine literale Ersetzung hätte jedes Vorkommen dieses Wortes im
   gesamten Repository zerstört.
3. Force-Push auf `origin`, Tag mitgezogen. Danach: 0 Treffer im gesamten Verlauf,
   67 Blobs tragen die Marke `***ENTFERNT-20260820***`.

**Der wichtigere Teil: die Prüfung hatte nur eines von zwei gefunden.** Ihr
Ausschlussfilter verwarf Werte, die nach Platzhalter aussehen — und der Wert des
Admin-Passworts begann mit `changeme`. Der Filter urteilte über den Wert, obwohl nur die
Datei etwas darüber sagt, ob ein Wert benutzt wird. Korrigiert: Ausgeschlossen wird jetzt
nach Pfad (`*.example`, `*.sample`, `*.dist`, `*.template`, `*beispiel*`), nicht nach
Aussehen des Wertes.

**Und ein Fehler in der Korrektur selbst.** Die erste Fassung filterte mit
`grep -E '\t…'` — in POSIX-ERE ist `\t` kein Tabulator, sondern der Buchstabe `t`. Der
Filter lief, meldete aber eine längst maskierte Zeile als Treffer. Aufgefallen ist das
nur, weil die Änderung gegen drei Fälle geprüft wurde: das bereinigte Repository
(erwartet 0, geliefert 0), die Sicherung von vorher (erwartet 2, geliefert 2) und ein
eigens gebautes Testrepository mit demselben Platzhalter in einer `.example`-Datei und in
einer echten Compose-Datei (erwartet: nur die echte wird gemeldet — genau so). Seitdem
filtert `awk`, nicht `grep`.

**Folgen für vorhandene Klone.** Alle Commit-Kennungen haben sich geändert. Ein
bestehender Klon lässt sich nicht mehr per `git pull` angleichen und muss neu gezogen
werden. Auf dem Pi selbst ist das erledigt; ein Klon auf dem Mac wäre neu zu holen.

**Was offen bleibt.** GitHub hält verwaiste Objekte noch eine Weile unter ihrer direkten
Kennung erreichbar; erzwingen lässt sich das Aufräumen nur über den GitHub-Support. Da
beide Werte nachweislich ungültig sind und beide Repositories privat, ist das nicht
verfolgt worden.

---

## 20.08.2026 — Pi-hole-Blocklisten überarbeitet, Gravity-Update täglich

| | |
|---|---|
| Betroffen | Pi-hole (`gravity.db`, `/etc/cron.d/pihole`) |
| Kapitel | [04](04-dienste-system.md) |
| Rückfallebene | `/mnt/usb-hdd/backups-manuell/pi-hole_raspberrypi_teleporter_2026-08-20_01-27-04_CEST.zip`, `gravity.db.vor-listen-20260820`, `cron.d-pihole.vor-taeglich-20260820` |

**Anlass.** Auf dem iPhone (`192.168.178.164`) erschienen beim Lesen auf
`weebcentral.com` Banner, Pop-ups und selbsttätig geöffnete Tabs mit Betrugsseiten.
Der naheliegende Verdacht — Pi-hole arbeite nicht — war falsch: In den betroffenen
15 Minuten wurden 167 von 385 Anfragen dieses Geräts geblockt.

**Der eigentliche Befund.** Alle vier eingebundenen Listen lagen im **Hosts-Format**,
das ausschließlich exakte Domainnamen sperrt. Die Werbenetzwerke liefern über
Subdomains aus. Von fünfzehn nachweislich durchgelassenen Werbedomains hatten sechs
ihre Eltern-Domain bereits in `gravity` — `magsrv.com` stand drin, abgefragt und
durchgelassen wurde `s.magsrv.com`. Eine Blockliste mit 485.267 Einträgen sagt über
die Wirksamkeit also nichts aus, solange das Format nicht dazu passt.

**Vorgehen.** Vor jeder Änderung gemessen: die fünfzehn durchgelassenen Domains gegen
Kandidatenlisten geprüft, anschließend die 6.176 Domains, die im gesamten Heimnetz in
sieben Tagen erlaubt beantwortet wurden, gegen jede Kandidatenliste gehalten — um
Fehlblockaden zu finden, bevor sie auftreten.

| Kandidat | zusätzlich gesperrte, bisher genutzte Domains | Entscheidung |
|---|---|---|
| HaGeZi Pop-Up Ads | 0 | aufgenommen |
| HaGeZi TIF Medium | 0 | aufgenommen |
| HaGeZi Badware Hoster | 0 | verworfen, Nutzen neben TIF gering |
| Phishing Army extended | 0 | verworfen, Überschneidung mit TIF |
| HaGeZi DynDNS | 1 (`karlsruhe-wired-….dynamic-m.com`) | verworfen |
| HaGeZi Anti-Piracy | sperrt `weebcentral.com`, `mangadex.org` | verworfen |

**Geändert:**

| | |
|---|---|
| Aufgenommen | HaGeZi Pro++, OISD Big, HaGeZi Pop-Up Ads, HaGeZi TIF Medium — alle im Adblock-Format |
| Abgeschaltet | `blocklistproject` ads.txt und tracking.txt (Hosts-Format, für Fehlblockaden bekannt) — `enabled = 0`, nicht gelöscht |
| Behalten | StevenBlack und adaway — sie enthalten 59.379 bzw. 3.934 Domains, die weder in Pro++ noch in OISD stehen |
| Ergänzt | fünf Regex-Regeln für `girlzsearch.com`, `planeptune.us`, `405kk.com`, `jump5geo.com`, `openwebschool.de` — diese Domains stehen in **keiner** der sechs geprüften Listen |
| Zeitplan | `/etc/cron.d/pihole`: `updateGravity` von sonntags auf **täglich** 03:02 |

**Nachgemessen.** Alle fünfzehn Werbedomains antworten mit `0.0.0.0`. Zehn
Gegenproben (`weebcentral.com`, `de.wikipedia.org`, `rewe.de`, `paypal.com`,
`spotify.com`, `usercentrics.eu` und weitere) lösen unverändert auf. `gravity`
wuchs von 485.267 auf 800.598 eindeutige Domains, `pihole-FTL` belegt dabei 47 MB
statt vorher 51 MB.

**Nachkontrolle am selben Abend, 01:38 Uhr.** Erneuter Besuch auf `weebcentral.com`,
diesmal über Tailscale (Client `100.94.181.68`, nicht `192.168.178.164` — das ist beim
Auswerten leicht zu übersehen). In zehn Minuten **111 geblockte Anfragen**, darunter
`sootoarathus.net`, `my.rtmark.net`, `aqle3.com`, `ad.a-ads.com`, `484r.com`,
`platform.pubadx.one`, `chagnougroalry.net`, `405kk.com` — alles Domains, die vor der
Umstellung durchgegangen wären.

Durchgekommen war genau eine Werbedomain: **`openwebschool.de`**, einmalig um 01:38:45
unmittelbar nach `weebcentral.com` abgefragt. Der Name gibt sich als Bildungsangebot;
die Seite ist tatsächlich ein Affiliate-Portal für Online-Casinos ohne Verifizierung.
Klassische Tarnung — deutscher, harmlos klingender Domainname, deshalb in keiner
Blockliste. Als fünfte Regex-Regel ergänzt.

> **Nicht sperren:** `temp.compsci88.com` (seit 18.05.2026, 138 Anfragen) und
> `scans.lastation.us` (seit 24.05.2026, 33 Anfragen) sind die Bildserver von
> `weebcentral.com`. Sie sehen wie Werbe-CDNs aus und liefern die Seiteninhalte. Eine
> Sperre würde die Seite unbrauchbar machen, ohne eine einzige Werbung zu entfernen.

**Was offen bleibt.** DNS-Sperren verhindern nicht, dass eine Seite per JavaScript
einen neuen Tab öffnet, und trennen keine Werbung, die von der Domain der Seite selbst
kommt. Empfohlen wurde ein Content-Blocker in Safari (AdGuard, Wipr, 1Blocker) samt
*Einstellungen → Apps → Safari → Pop-ups blockieren*. Nicht umgesetzt — das ist eine
Einstellung am Endgerät, nicht am Pi.

**Nachtrag, 01:50 Uhr — der Zeitplan überlebt jetzt ein Pi-hole-Update.** Zunächst
stand die tägliche Ausführung in `/etc/cron.d/pihole`. Diese Datei gehört Pi-hole und
wird bei jedem Core-Update neu geschrieben; die Änderung wäre beim nächsten
`pihole -up` still auf wöchentlich zurückgefallen. Ersetzt durch einen eigenen
systemd-Timer — `/etc/systemd/system/` fasst Pi-hole nicht an.

| | |
|---|---|
| Neu | `pi-gravity.sh`, `pi-gravity.service`, `pi-gravity.timer` (täglich 03:02, Zufallsversatz 5 min) |
| Geändert | Cron-Zeile in `/etc/cron.d/pihole` auskommentiert, mit Begründung im Kopf |
| Abgleich | vier neue Paare im Manifest, darunter `/etc/cron.d/pihole` selbst — meldet, wenn ein Core-Update die Anpassung zurücksetzt |
| Meldung | ntfy bei Fehlschlag **und** wenn die Einträge um mehr als ein Viertel schrumpfen — sonst fällt der Ausfall einer Quelle nicht auf, weil `pihole -g` trotzdem mit Exit 0 endet |

Nachgemessen: Testlauf mit `Result=success`, Journal-Eintrag `1115593 -> 1115593
Domains`, Eigentümer von `gravity.db` unverändert `pihole:pihole`, `pi-abgleich check`
meldet **24 von 24 Paaren identisch**. Der ntfy-Weg selbst ist nur auf seine
Voraussetzungen geprüft (URL, Topic, Token-Datei lesbar), nicht durch einen echten
Versand — das erste Mal meldet er sich also ungetestet.

---
## 18.08.2026 (abends) — Repositories zusammengeführt

| | |
|---|---|
| Betroffen | Ablage sämtlicher Konfiguration und Dokumentation, Backup, alle Systemdateien |
| Kapitel | [12](12-backup.md), [17](17-wo-was-liegt.md), README |

**Anlass.** Am selben Tag war Kapitel 17 eine Stunde lang falsch: Es behauptete, es
gebe kein Werkzeug für den Abgleich zwischen Repository und System — während das
Werkzeug bereits lief. Der Grund war strukturell und nicht menschlich: Werkzeug und
Dokumentation lagen in zwei Repositories und wurden nacheinander gepusht. Zwischen
den beiden Pushes kann die Doku gar nicht anders, als falsch zu sein.

**Umgesetzt.** `docker-stacks` und `raspi-doku` sind zu **`qsimonbrn/raspi`**
zusammengeführt, beide Verläufe vollständig erhalten (`merge
--allow-unrelated-histories`, 51 Commits, `git log --follow` findet jede Datei über
die Verschiebung hinweg).

```
raspi/
├── docs/        Kapitel, CHANGELOG, README
├── inventar/    Sammelskript und Snapshots
├── stacks/      Compose-Dateien — laufen DIREKT von hier
└── system/      Systemkonfiguration — nur Kopie, läuft aus /etc, /usr/local, /boot
```

Der Unterschied zwischen `stacks/` und `system/` ist der wichtigste Teil des
Aufbaus: Er macht im Verzeichnisbaum sichtbar, was vorher nur in einer Tabelle stand.

**Was mitgezogen werden musste**, und wie es geprüft wurde:

| Betroffen | Nachweis |
|---|---|
| 6 installierte Systemdateien (Backup, Firewall, Wartung, Aliase) | `pi-abgleich.sh install`, danach 20 von 20 Paaren identisch |
| Manifest des Abgleichs, `sync.sh` | Werkzeug erfasst sich selbst weiterhin |
| Backup-Pfade | Snapshot `29b44d40`, 5747 Dateien, `restic ls` zeigt `/home/simon/raspi` |
| Label `com.docker.compose.project.config_files` aller 8 Container | zeigt auf `/home/simon/raspi/stacks/…`, für sechs Container war `--force-recreate` nötig |
| Aliase `wartung` und `abgleich` | in beiden Shell-Arten geprüft |

**Zwei Funde nebenbei:**

- **`claude-skills` lag in keinem einzigen Snapshot.** Darin liegen die beiden Skills
  und der `pi-ssh`-MCP-Server — also genau das Werkzeug, über das die Automatisierung
  auf den Pi kommt. Auf GitHub gesichert, lokal nicht. Jetzt im Backup.
- **In `raspi-doku` lag unter `.claude/skills/` eine veraltete Kopie des
  `raspi-doku`-Skills** — älter als die maßgebliche Fassung in `claude-skills`, ohne
  den `sudo docker`-Hinweis und ohne die Job-Werkzeuge. Entfernt.

**Entschieden.**

- **`claude-skills` bleibt getrennt.** Es wird von Claude Desktop gelesen, hat eine
  eigene Lebensdauer, und ein fehlerhafter Commit darin nähme der Automatisierung das
  Werkzeug, mit dem sie den Fehler beheben müsste.
- **`CHANGELOG.md` und dieses Kapitel wurden von der Pfadumstellung ausgenommen.** Sie
  beschreiben, wie es damals war; alte Pfade sind dort richtig, nicht veraltet.
- **Die alten Arbeitskopien bleiben vorerst liegen** als
  `docker-stacks.alt-20260818` und `raspi-doku.alt-20260818`. Die GitHub-Repositories
  sollen archiviert statt gelöscht werden, damit alte Verweise nicht ins Leere zeigen.

**Rückfallebene.** `/mnt/usb-hdd/backups-manuell/vor-repo-umbau-20260818.tar.gz`
(1 MB, alle drei Repositories samt Verlauf und `.env`), Modus 600.

---

## 18.08.2026 (nachmittags) — Docker-Durchsicht: Logrotation, Pinning, Speicher-Cgroup

| | |
|---|---|
| Betroffen | Alle acht Container, Backup, Kernel-Parameter |
| Kapitel | [05](05-docker.md), [06](06-daten-und-speicher.md), [07](07-sicherheit.md), [11](11-disaster-recovery.md), [12](12-backup.md) |

**Anlass.** Am Vormittag war in `daemon.json` eine Logrotation eingetragen worden mit
der Aussage, sie greife bei neu erstellten Containern. Die Nachfrage, ob sich eine
Neuerstellung lohnt, führte zu einer vollständigen Durchsicht der Docker-Einrichtung.

**Befund: die Logrotation war überhaupt nicht in Kraft.** Nicht bei den laufenden und
auch nicht bei neuen Containern. `log-driver` und `log-opts` gehören nicht zu den
Werten, die Docker bei einem `systemctl reload` übernimmt; ein echter Neustart des
Daemons hatte nie stattgefunden. Bewiesen mit einem Wegwerf-Container: `docker create`
lieferte `LogConfig: json-file map[]`. Bichon hatte zu dem Zeitpunkt eine ungedrehte
Logdatei von **39 MB**.

**Zweiter Befund: Speicher-Limits waren technisch unmöglich.** `docker stats` zeigte
bei jedem Container `0B / 0B`, `docker info` meldete *No memory limit support*. In
`cmdline.txt` fehlten `cgroup_enable=memory` und `cgroup_memory=1`. Ein `mem_limit`
in einer Compose-Datei wäre wirkungslos geblieben.

**Dritter Befund: das Backup meldete seit Tagen Fehlschlag** (`ExecMainStatus=1`),
obwohl es durchlief. Ursache war eine stehengebliebene Prüfung auf eine
WireGuard-Konfiguration, die es seit der Umstellung auf Tailscale nicht mehr gibt.
Ein Alarm, der jede Nacht grundlos kommt, verdeckt den echten Fehlschlag.

**Umgesetzt.**

| Änderung | Nachweis |
|---|---|
| Logrotation als YAML-Anker in allen fünf aktiven Compose-Dateien | 8 von 8 Containern tragen `max-size 10m` / `max-file 3` |
| `security_opt: no-new-privileges` für alle acht Dienste | `docker inspect` je Container |
| `homepage` auf `v1.13.2`, `bichon` auf Digest gepinnt | kein `:latest` mehr im laufenden Betrieb |
| `BICHON_ENCRYPT_PASSWORD` nach `bichon/.env`, Verlauf per `git filter-repo` bereinigt | Wert in keinem der 22 Commits mehr auffindbar |
| Backup um `/mnt/usb-hdd/ntfy` und das Portainer-Volume erweitert, `filebrowser-data` entfernt | `restic ls latest` |
| `ReadWritePaths` für rclone in `pi-backup.service` | keine `read-only`-Meldung mehr, Exit 0 statt 1 |
| `cgroup_enable=memory cgroup_memory=1` in `cmdline.txt`, Neustart | `cgroup.controllers` enthält `memory` |
| Images von 18 auf 8 reduziert | 8,66 GB → 3,63 GB, Wurzel 14 GB → 7,7 GB |
| Befristete Speichermessung alle 5 Minuten | `/mnt/usb-hdd/messungen/docker-speicher.csv` |

**Entschieden.**

- **Kein Passwortwechsel bei Bichon.** Laut Herstellerdoku nicht änderbar, ohne das
  690-MB-Archiv unlesbar zu machen. Dazu kommt, dass das Passwort das Archiv auf
  derselben Platte schützt, auf der die Compose-Datei liegt — der Gewinn wäre null
  gewesen, der Preis das ganze Archiv. Stattdessen Wert unverändert nach `.env` und
  Verlauf bereinigt.
- **Kein Update-Lauf.** Alle gepinnten Images waren bereits die jeweils neueste
  Fassung. `homepage` v2.0.0 bleibt bewusst liegen (Breaking Change bei der
  Authentifizierung, vier Tage alt).
- **Kein `cap_drop: ALL`.** Paperless braucht Root, um über `USERMAP_UID` die
  Dateirechte zu setzen; dasselbe gilt für Postgres und Redis. Der Aufwand stünde in
  keinem Verhältnis.
- **Keine Bindung der Ports an `127.0.0.1`.** `pi-guard` verwirft die Verwaltungsports
  aus dem LAN nachweislich; eine zweite Schicht würde nur riskieren, den
  Tailscale-Zugriff mit zu verlieren.
- **Speicher-Limits erst nach Messung.** Heute wäre jede Zahl geraten. Der Timer läuft,
  die Auswertung folgt.

**Nebenbefund.** Der Neustart dauerte rund fünf Minuten statt der erwarteten ein bis
zwei — beim nächsten Mal entsprechend ansagen.

**Rückfallebene.** Vor allen Änderungen: `restic`-Snapshot `94f0076d`, ein Tar der
gesamten Arbeitskopie unter `/mnt/usb-hdd/backups-manuell/` und der GitHub-Tag
`vor-anpassungen-2026-08-18` im Repository `docker-stacks`.

---

## 18.08.2026 — Erste Härtungsstufe und eigenes Automatisierungskonto

| | |
|---|---|
| Betroffen | Erreichbarkeit der Dienste, Konten und Rechte, zwei abgeschaltete Dienste |
| Kapitel | [03](03-netzwerk.md), [04](04-dienste-system.md), [05](05-docker.md), [07](07-sicherheit.md), [09](09-empfehlungen.md), [10](10-zugriff.md), [11](11-disaster-recovery.md), [12](12-backup.md), **[16](16-konten-und-rechte.md) neu** |

**Anlass.** Der Pi hat immer mehr wichtige Aufgaben übernommen — Dokumente, E-Mail-Archiv,
Dateien, seit dem Vortag ein VPN-Zugang ins gesamte Heimnetz. Der Schutz war mit dieser
Bedeutung nicht mitgewachsen. Eine vollständige Sicherheitsprüfung sollte den Ist-Zustand
erheben und eine priorisierte Maßnahmenliste liefern.

**Befund.** Das vollständige Konzept mit Bedrohungsmodell liegt im Claude-Projekt unter
`claude/sicherheitskonzept.md`. Die Kurzfassung:

*Von außen ist der Pi solide* — kein eingehender Port, DS-Lite, **ein einziger**
fehlgeschlagener Anmeldeversuch in 30 Tagen. *Von innen war er weit offen* — **33 Geräte**
im Heimnetz erreichten ohne jede Hürde die Portainer-Oberfläche, und wer Portainer
übernimmt, ist Administrator auf dem Pi.

Der schwerwiegendste Einzelbefund: **Die Gruppe `docker` ist ein Generalschlüssel ohne
Passwort.** Wer Docker steuern darf, startet einen Container mit eingebundenem
Wurzeldateisystem und ist damit `root` — ohne sudo, ohne Protokoll. Solange `simon` in
dieser Gruppe ist, bleibt jede Verschärfung der sudo-Regeln wirkungslos.

**Durchgeführt.**

| # | Maßnahme | Nachweis |
|---|---|---|
| 1 | **Filebrowser abgeschaltet** — CVE-2026-32759 (RCE über TUS-Upload) ohne verfügbaren Patch, Projekt wird zum 01.09.2026 archiviert. Der Container hatte die gesamte SSD unter `/srv` eingebunden | Port 8082 geschlossen, Daten unangetastet |
| 2 | **Dashy abgeschaltet** — durch Homepage abgelöst, Image neun Monate alt | Port 8080 geschlossen |
| 3 | **`pi-guard`** — Portainer, Bichon und Paperless nur noch über Tailscale | 101 Pakete aus dem Heimnetz verworfen, 305 über Tailscale durchgelassen |
| 4 | **Konto `claude`** mit eigenem Schlüssel und vollständiger sudo-Sitzungsaufzeichnung | Anmeldung protokolliert samt Fingerabdruck, Wiedergabe mit `sudoreplay` geprüft |
| 5 | Gruppe `pi-admin`, `/home/simon` auf `710` | Gegenprobe: `claude` kann durchqueren, aber nicht auflisten |
| 6 | Eigener GitHub-Schlüssel, Git-Identität „Claude (Raspberry Pi)" | Commit und Push getestet, in der Historie sichtbar |

**Zwei Dinge zurückgenommen.** Die SSH-Härtung (`PasswordAuthentication no`,
`PermitRootLogin no`, `AllowUsers`, `MaxAuthTries 3`) und die Sperrung des
root-Passworts wurden eingerichtet, erfolgreich getestet und **auf Wunsch wieder
entfernt** — sie sollen gemeinsam und mit Vorlauf umgesetzt werden, nicht nebenbei. Der
Ausgangszustand wurde vollständig wiederhergestellt und geprüft.

**Nebenwirkung, die auffiel.** Weil `claude` nicht in der Gruppe `docker` ist, laufen
Docker-Befehle über sudo — und werden protokolliert. Das ist gewollt, brach aber sofort
`inventar/collect.sh`: Die erste Bestandsaufnahme unter dem neuen Konto lieferte 374
statt 650 Zeilen mit leeren Container-Tabellen, weil zehn Docker-Aufrufe an
`permission denied` scheiterten. Das Skript ist seitdem auf `sudo docker` umgestellt.
**Für neue Skripte gilt: immer `sudo docker` schreiben** — das funktioniert unter beiden
Konten.

**Nachgemessen.** Bestandsaufnahme nach der Korrektur vollständig (650 Zeilen, keine
Rechtefehler), acht statt zehn Container, Ports 8080 und 8082 geschlossen,
Firewall-Trefferzähler belegen die Wirkung, Sitzungsaufzeichnung abspielbar, Push unter
der neuen Identität erfolgreich.

**Am selben Abend nachgezogen (zweiter Durchgang).**

| Maßnahme | Nachweis |
|---|---|
| **`simon` aus der Gruppe `docker` entfernt** — die Gruppe ist jetzt leer | Gegenprobe: `docker ps` als `simon` scheitert, `sudo docker ps` funktioniert, alle acht Container laufen weiter |
| **Alle Docker-Aufrufe systemweit auf `sudo docker`** — Skripte, beide Skills, 25 Beispielbefehle in der Doku | Geprüft mit negativem Lookbehind, damit `sudo docker` nicht mitgezählt wird |
| **`unattended-upgrades`** ohne selbsttätigen Neustart, mit ntfy-Meldung bei fälligem Neustart | Vorgetäuschter Neustart löste die Meldung nachweislich aus |
| **Docker-Log-Rotation** (`daemon.json`, 10 MB × 3, `live-restore`) | Übernommen per `reload`, alle Container liefen durch |
| **Obsolete WireGuard-Schlüssel entfernt** | Dabei fiel `/root/iphone.conf` auf: enthielt `PrivateKey` bei Modus **644** — beim ersten Durchgang übersehen |
| **Pi-hole-Eintrag `applovin.com`** aus der Listenverwaltung entfernt | Domain bleibt über eine reguläre Blockliste gesperrt, nachgeprüft |
| `claude-skills` an die Gruppe `pi-admin` angeglichen | Voraussetzung, um die Skills überhaupt anpassen zu können |

**Zwei Fehler dabei, beide bemerkt und behoben.** Die `daemon.json` wurde zunächst mit
**0 Bytes** angelegt — eine leere Datei hätte Docker beim nächsten Start unbrauchbar
gemacht; sie wurde vor jedem Neuladen korrigiert. Und eine erste Zählung der
Docker-Aufrufe zählte `sudo docker` fälschlich als „ohne sudo" mit und ergab ein
falsches Bild.

**Ein Detail zur Log-Rotation:** Sie gilt nur für **neu erstellte** Container. Die acht
laufenden zeigen weiterhin `map[]` — beim nächsten Update greift die Einstellung
automatisch.

**Offen geblieben.** SSH-Passwortanmeldung (wichtigster Punkt), Alarmierung über ntfy,
Bichon-Passwort im Klartext in Git, Konten und Protokolle nicht im Backup, `fail2ban`,
`auditd`, Samba-Härtung, Tailscale-Zugriffsregeln. Vollständig in
[07 — Sicherheit](07-sicherheit.md).

---

## 18.08.2026 — WireGuard durch Tailscale ersetzt

| | |
|---|---|
| Betroffen | Fernzugriff, DNS unterwegs, Backup-Umfang, Homepage-Kachel |
| Kapitel | [03](03-netzwerk.md), [04](04-dienste-system.md), [07](07-sicherheit.md), [10](10-zugriff.md), [11](11-disaster-recovery.md), [12](12-backup.md) |

**Anlass.** Eine für das iPhone eingerichtete WireGuard-Verbindung funktionierte nicht.

**Befund.** WireGuard selbst war korrekt konfiguriert — Dienst aktiv, Schnittstelle
`wg0` oben, Port 51820 gebunden, Weiterleitung eingeschaltet, keine störende
Firewall-Regel. Der eingetragene Peer hatte jedoch **null übertragene Bytes und keinen
einzigen Handshake**: Es hatte nie eine Verbindung gegeben.

Die Ursache lag außerhalb des Pi. Der Anschluss (FRITZ!Box 6660 Cable an Vodafone Kabel)
läuft über **DS-Lite**. Die FRITZ!Box meldet über UPnP keine eigene öffentliche
IPv4-Adresse; die nach außen sichtbare `92.208.222.35` gehört dem Provider und wird von
vielen Kunden geteilt. Eine Portfreigabe für 51820/UDP ist damit technisch unmöglich —
unabhängig von jeder Konfiguration auf dem Pi.

**Erwogene Wege.**

| Weg | Bewertung |
|---|---|
| WireGuard über IPv6 + MyFRITZ | Machbar, bleibt in Eigenregie. Aber nur nutzbar, wenn das Netz unterwegs IPv6 spricht — in fremden WLANs oft nicht der Fall |
| Dual-Stack bei Vodafone beantragen | Ausgang ungewiss, Wartezeit Wochen |
| Headscale (Tailscale selbst gehostet) | Scheitert am selben Problem: Der Koordinationsserver müsste von außen erreichbar sein |
| **Tailscale** | Gewählt. Funktioniert in jedem Netz, kein eingehender Port nötig |

**Entscheidung.** Tailscale, bewusst mit der Abhängigkeit von einem fremden
Vermittlungsdienst und vom GitHub-Konto als Anmeldung. Ohne fremden Server ist an einem
DS-Lite-Anschluss kein verlässlicher Fernzugriff möglich; das war die Abwägung.

**Durchgeführt.**

- Tailscale 1.102.2 aus dem offiziellen Debian-Repository installiert
- Angemeldet über GitHub (`qsimonbrn`), Tailnet `tailf372ec.ts.net`
- Pi als **Subnetz-Router** für `192.168.178.0/24` und als **Exit Node** freigegeben
- `--accept-dns=false` gesetzt, damit der Pi seinen eigenen Resolver behält
- IPv6-Weiterleitung dauerhaft in `/etc/sysctl.d/99-tailscale.conf` verankert
- **Schlüsselablauf deaktiviert** — sonst hätte sich der Pi nach 180 Tagen abgemeldet
- Pi-hole `listeningMode` von `LOCAL` auf `ALL` umgestellt (Begründung unten)
- In der Tailscale-Verwaltung `100.108.219.87` als Global Nameserver gesetzt,
  „Override DNS servers" aktiviert
- WireGuard-Dienst deaktiviert, Pakete entfernt, `/etc/wireguard` gelöscht;
  Sicherungskopie unter `/root/wireguard-entfernt-20260818.tar.gz` (Modus 600)
- Backup-Skript sichert `/var/lib/tailscale` statt `/etc/wireguard`
- Homepage-Kachel von WireGuard auf Tailscale geändert

**Zur Pi-hole-Umstellung.** Die Schnittstelle `tailscale0` trägt eine `/32`-Adresse.
Im Modus `LOCAL` gilt damit jede andere Tailnet-Adresse als „nicht lokal", und Pi-hole
hätte die Anfragen des iPhones abgewiesen. `ALL` ist hier vertretbar, weil kein
eingehender Port aus dem Internet existiert — es gibt keine Portfreigabe, und die
FRITZ!Box blockiert eingehendes IPv6. Sollte sich daran je etwas ändern, muss diese
Einstellung erneut geprüft werden, sonst entsteht ein offener DNS-Resolver.

**Nachgemessen.** Handshake steht, das iPhone verbindet sich direkt über IPv6. DNS-Anfragen
des iPhones erscheinen in der Pi-hole-Abfrageliste und werden gefiltert — darunter
`mask.icloud.com`, wodurch Apples *iCloud Private Relay* nicht am Filter vorbeiläuft.
Alle Dienste (8000, 3000, 8080, 8082, 9000, 2586, 80) sind über die Tailnet-Adresse
erreichbar. Über Mobilfunk vom Nutzer bestätigt.

---

## Ältere Änderungen

Vor dem 18.08.2026 wurden Systemänderungen nicht gesondert festgehalten. Nachvollziehbar
sind sie über den [CHANGELOG](../CHANGELOG.md) und die Git-Historie der beiden
Repositories `raspi-doku` und `docker-stacks`. Bekannte Eckdaten:

| Datum | Änderung |
|---|---|
| 16.08.2026 | Alle Docker-Images auf feste Versionen gepinnt |
| 13.08.2026 | restic-Backup nach OneDrive eingerichtet, Benachrichtigung über ntfy |
| 23.04.2025 | WireGuard eingerichtet (nie von außen erreichbar, siehe oben) |

---

## Vorlage für neue Einträge

```markdown
## TT.MM.JJJJ — Kurzer Titel

| | |
|---|---|
| Betroffen | Welche Bereiche |
| Kapitel | Verweise auf die aktualisierten Kapitel |

**Anlass.** Warum wurde etwas geändert?

**Befund.** Was wurde gemessen? Zahlen, keine Vermutungen.

**Entscheidung.** Was wurde gewählt, welche Alternativen gab es, welcher Preis
wurde bewusst in Kauf genommen?

**Durchgeführt.** Konkrete Schritte.

**Nachgemessen.** Woran ist erkennbar, dass es wirkt?
```
