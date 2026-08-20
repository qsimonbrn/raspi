# 15 — Änderungshistorie des Systems

*Erfasst: 18.08.2026 · zuletzt ergänzt 20.08.2026 (zweiter Eintrag desselben Tages)*

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
