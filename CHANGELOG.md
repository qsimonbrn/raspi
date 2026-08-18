# Änderungsverlauf der Dokumentation

Dieser Verlauf dokumentiert Änderungen an der **Dokumentation**, nicht am System selbst.
Systemänderungen stehen im Betriebstagebuch
[15 — Änderungshistorie](docs/15-aenderungshistorie.md) und in den jeweiligen Kapiteln.

Format: [Keep a Changelog](https://keepachangelog.com/de/1.1.0/) ·
Datumsformat: JJJJ-MM-TT

---

## [1.9.0] — 2026-08-18

### Geändert am System

- **`simon` aus der Gruppe `docker` entfernt** — die Gruppe ist jetzt leer. Die
  Mitgliedschaft war ein Generalschlüssel: Wer Docker steuern darf, wird über einen
  Container mit eingebundenem Wurzeldateisystem zu `root` — ohne sudo, ohne Passwort,
  ohne Protokoll. Beide Konten greifen jetzt über `sudo` zu, jeder Befehl wird
  protokolliert. `pi-backup.sh` läuft als `root` und ist nicht betroffen.
- **Alle Docker-Aufrufe systemweit auf `sudo docker`:** `pi_wartung.sh`,
  `kategorisieren.py`, beide Skills samt Skripten (27 Stellen, dazu ein Hinweis am
  Anfang) und 25 Beispielbefehle in sechs Kapiteln.
- **`unattended-upgrades` eingerichtet** — nur Sicherheitsquellen, **kein**
  selbsttätiger Neustart. Wird einer fällig, meldet sich der Pi über ntfy und wartet auf
  eine Entscheidung (`pi-reboot-check.timer`, täglich 08:30, höchstens eine Meldung pro
  Tag). Grund: Am Pi hängt der DNS des ganzen Haushalts.
- **Docker-Log-Rotation** (`daemon.json`, 10 MB × 3, `live-restore`). Gilt für neu
  erstellte Container; die acht laufenden greifen beim nächsten Update.
- **Obsolete WireGuard-Schlüssel entfernt.** Dabei fiel `/root/iphone.conf` auf — sie
  enthielt einen privaten Schlüssel bei Modus **644** und war beim ersten Durchgang
  übersehen worden.
- **Pi-hole:** `applovin.com` aus der `adlist`-Tabelle entfernt, wo es als vermeintliche
  Listen-URL wirkungslos war. Die Domain bleibt über eine reguläre Blockliste gesperrt.
- **`homepage/config/proxmox.yaml`** entfernt — ungenutzte Beispieldatei.
- **`claude-skills` an die Gruppe `pi-admin` angeglichen**, damit beide Konten die Skills
  pflegen können.

### Geändert

- **Kapitel 07:** Automatische Sicherheitsupdates von „🟡 fehlt" auf „✅ eingerichtet",
  Maßnahmenliste um sechs erledigte Punkte ergänzt. Die SSH-Passwortanmeldung ist damit
  der wichtigste offene Punkt.
- **Kapitel 16** um den Abschnitt „Die Gruppe `docker` ist leer" und die vollständige
  Liste der umgestellten Stellen erweitert.
- **Kapitel 15** um den zweiten Durchgang des Abends ergänzt, samt der beiden Fehler, die
  dabei passiert sind: eine zunächst leere `daemon.json` und eine fehlerhafte Zählung der
  Docker-Aufrufe.

---

## [1.8.0] — 2026-08-18

### Geändert am System

- **Filebrowser abgeschaltet.** Version 2.51.2, betroffen von CVE-2026-32759 (Remote Code
  Execution über den TUS-Upload) — **kein Patch verfügbar**, Projekt wird zum 01.09.2026
  archiviert. Der Container hatte die gesamte SSD unter `/srv` eingebunden. Daten nicht
  gelöscht, Compose-Datei nach `_archiviert/` verschoben.
- **Dashy abgeschaltet.** Durch Homepage abgelöst, Image neun Monate alt auf `:latest`.
- **`pi-guard` eingerichtet.** Portainer (9000/9443), Bichon (15630) und Paperless (8000)
  sind aus dem Heimnetz nicht mehr erreichbar. Regeln in `DOCKER-USER` und `INPUT`, je für
  IPv4 und IPv6 — `ufw` allein würde von Dockers eigenen Regeln umgangen. Nachgemessen:
  101 Pakete verworfen, 305 über Tailscale durchgelassen.
- **Automatisierungskonto `claude`.** Eigener herkunftsgebundener Schlüssel, kein
  Passwort, **nicht** in der Gruppe `docker` — dadurch laufen Docker-Befehle über sudo und
  werden protokolliert. Jede erhöhte Sitzung wird vollständig aufgezeichnet und ist mit
  `sudoreplay` abspielbar.
- **Gruppe `pi-admin`**, `/home/simon` auf `710` — das Automatisierungskonto darf
  durchqueren, aber nicht auflisten.
- **`inventar/collect.sh` auf `sudo docker` umgestellt.** Ohne diese Korrektur lieferte
  die Bestandsaufnahme unter dem neuen Konto nur 374 statt 650 Zeilen mit leeren
  Container-Tabellen.

### Zurückgenommen

- **SSH-Härtung und Sperrung des root-Passworts.** Eingerichtet, erfolgreich getestet und
  auf Wunsch wieder entfernt — die Umstellung soll gemeinsam und mit Vorlauf erfolgen.
  Ausgangszustand vollständig wiederhergestellt und geprüft.

### Hinzugefügt

- **Kapitel [16 — Konten und Rechte](docs/16-konten-und-rechte.md).** Konten,
  Rechtemodell, Sitzungsaufzeichnung, die Befehle zur Überwachung und der Notausschalter.
  Enthält auch die Begründung, warum volle sudo-Rechte mit Aufzeichnung hier mehr bringen
  als ein Katalog erlaubter Befehle.
- **Befund in [12 — Backup](docs/12-backup.md):** Konten, sudo-Regeln und
  Sitzungsaufzeichnungen liegen außerhalb der gesicherten Pfade. Besonders die Protokolle
  wiegen schwer — sie sind genau das, was ein Angreifer zuerst löscht.
- **`docker-stacks/firewall/`** und **`docker-stacks/sudoers/`** als versionierte Kopien
  mit Erklärung.

### Geändert

- **Kapitel 03, 04, 05, 07, 08, 09, 10, 11, 12 und README** auf den neuen Stand gebracht.
- **Kapitel 07 grundlegend überarbeitet:** Der Befund „keine Firewall" ist zu „Firewall —
  teilweise umgesetzt" geworden, die Maßnahmenliste ist in Erledigtes und Offenes
  getrennt, und das Bedrohungsmodell steht jetzt in der Zusammenfassung.
- **Zugriffsmatrix in Kapitel 10** um die Spalte „nur über Tailscale" ergänzt, Kacheln und
  Adressen auf `100.108.219.87` umgestellt.

---

## [1.7.0] — 2026-08-18

### Hinzugefügt

- **[04](docs/04-dienste-system.md): Abschnitt „iCloud Private Relay wird absichtlich
  blockiert".** Erklärt die wiederkehrenden Meldungen auf Apple-Geräten — eigene wie
  die von Gästen. Ursache ist die Pi-hole-Voreinstellung
  `dns.specialDomains.iCloudPrivateRelay = true`, die NXDOMAIN auf `mask.icloud.com`
  und `mask-h2.icloud.com` liefert; sie stammt **nicht** aus einer Blockliste. Apple
  empfiehlt dieses Verfahren in seiner Anleitung für Netzwerkbetreiber selbst, die
  Meldung ist vorgesehenes Verhalten.
- **Abgrenzung, was Private Relay tatsächlich umfasst.** Nur Safari und dessen
  DNS-Anfragen laufen daran vorbei; Apps — auch solche mit HTTPS — fragen weiterhin
  Pi-hole und bleiben gefiltert. Die verbreitete Annahme „damit filtert Pi-hole gar
  nichts mehr" trifft nicht zu.
- **Handreichung für Gäste** (Einstellungen → WLAN → **(i)** → *iCloud Private Relay*),
  netzbezogen und ohne Wirkung auf andere Netze.
- **Dokumentierte, nachgemessene Alternative:** Ein Allowlist-Eintrag überstimmt die
  eingebaute Sperre (auf dem Pi getestet, Testeintrag wieder entfernt). Zusammen mit
  Gerätegruppen ließen sich Gäste und eigene Geräte trennen. Bewusst **nicht**
  umgesetzt — die volle Filterwirkung wiegt schwerer.

---

## [1.6.0] — 2026-08-18

### Geändert am System

- **WireGuard durch Tailscale ersetzt.** WireGuard war am DS-Lite-Anschluss von außen
  nie erreichbar — der eingerichtete Peer hatte null Bytes und keinen Handshake. Eine
  IPv4-Portfreigabe ist bei DS-Lite technisch unmöglich. Tailscale 1.102.2 baut die
  Verbindung von innen nach außen auf und benötigt keinen eingehenden Port.
  Vollständige Begründung und Abwägung in
  [15 — Änderungshistorie](docs/15-aenderungshistorie.md).
- **Pi als Subnetz-Router und Exit Node.** Unterwegs ist das gesamte Heimnetz unter den
  gewohnten `192.168.178.x`-Adressen erreichbar.
- **Pi-hole `listeningMode` von `LOCAL` auf `ALL`.** Notwendig, weil `tailscale0` eine
  `/32`-Adresse trägt und andere Tailnet-Geräte sonst als „nicht lokal" abgewiesen
  worden wären.
- **WireGuard rückstandslos entfernt**, Sicherungskopie unter
  `/root/wireguard-entfernt-20260818.tar.gz`.
- **Backup zieht `/var/lib/tailscale` statt `/etc/wireguard`** (`docker-stacks`,
  Commit `fbd6b53`).

### Hinzugefügt

- **Kapitel [15 — Änderungshistorie](docs/15-aenderungshistorie.md).** Betriebstagebuch
  für Systemänderungen mit Datum, Begründung und Nachmessung — abgegrenzt vom
  CHANGELOG, der die Dokumentation selbst verfolgt. Mit Vorlage für neue Einträge.

### Geändert

- **Kapitel 03, 04, 06, 07, 08, 10, 11, 12, 13, 14 und README** auf Tailscale
  umgestellt.
- **Kapitel 04** um die Messwerte erweitert, die den Befund belegen (kein Handshake,
  keine externe IPv4 laut UPnP).

### Behoben

- **Widerspruch in der Bewertung.** Der Abschnitt „Die eine Zahl" in
  [08](docs/08-bewertung.md) nannte weiterhin ein einziges gesichertes Element,
  während [11](docs/11-disaster-recovery.md) seit dem 13.08.2026 sechs von sieben
  ausweist. Auf den tatsächlichen Stand korrigiert.

---

## [1.5.0] — 2026-08-16

### Geändert am System

- **Paperless-ngx von 2.15.3 auf 3.0.5.** In zwei Stufen über 2.20.15 — die
  Migrationsanleitung lässt v3 ausschließlich von dieser Version aus zu. Ein direkter
  Sprung auf `:latest` wäre gescheitert.
- **Sechs Einstellungen in der Paperless-Compose umgeschrieben**, Verhalten unverändert:
  `CONSUMER_POLLING` → `CONSUMER_POLLING_INTERVAL`, `CONSUMER_POLLING_DELAY` →
  `CONSUMER_STABILITY_DELAY`, `CONSUMER_POLLING_RETRY_COUNT` entfällt,
  `OCR_MODE: skip` → `auto`, `OCR_SKIP_ARCHIVE_FILE: never` →
  `ARCHIVE_FILE_GENERATION: always`, neu `DBENGINE: postgresql` (ab v3 Pflicht).
- **Alle Images auf feste Versionen gepinnt.** Kein `:latest` mehr im Bestand:
  `postgres:15.19`, `redis:7.4`, `portainer-ce:2.39.6` (LTS, schließt sieben CVEs),
  `ntfy:v2.27.0`, `docker-socket-proxy:v0.5.0`.
- **Verifiziertes Backup vor dem Update** unter `/mnt/usb-hdd/backup/2026-08-16-vor-update/`:
  `pg_dump` in beiden Formaten, `document_exporter`, alle Compose- und `.env`-Dateien.

### Behoben

- **Collation-Konflikt in PostgreSQL.** Der Wechsel von `postgres:15` auf `15.19`
  brachte das Basis-Image von Debian Bookworm (glibc 2.36) auf Trixie (glibc 2.41).
  Eine geänderte Sortierreihenfolge macht B-Tree-Indizes auf Textspalten still falsch —
  Abfragen liefern unvollständige Ergebnisse, ohne dass ein Fehler auftritt. Behoben
  mit `REINDEX DATABASE` und `ALTER DATABASE … REFRESH COLLATION VERSION` für
  `paperless`, `postgres` und `template1`.
- **Befund „Images seit 8 bis 17 Monaten nicht aktualisiert" erledigt** für alle
  kritischen Dienste. In `docs/08-bewertung.md` aus der Mängelliste entfernt, in
  `docs/09-empfehlungen.md` sind die Punkte 2.6 und 2.8 abgehakt.
- **SSH-Zugang wiederhergestellt.** Der MCP-Server scheiterte mit
  `Permission denied (publickey,password)`. Ursache: In `authorized_keys` auf dem Pi
  lag nur der Schlüssel `pi-zugriff`, der Mac bot aber `macbook-simon` an — zwei
  verschiedene Schlüssel. Der Mac-Schlüssel war nie autorisiert. Behoben mit
  `ssh-copy-id`.

### Neue Befunde

- 🟠 **`document_exporter` erfasst ab v3 auch den Papierkorb.** Zu Dokument 1 (ein
  Testdokument, am 13.08.2026 gelöscht) fehlte die Datei; der Export brach mit
  `FileNotFoundError` ab. Damit war das Paperless-Backup nach dem Update nicht
  lauffähig — aufgefallen erst beim Testen der Backup-Automatisierung, nicht durch
  eine Fehlermeldung im Betrieb. Behoben durch Leeren des Papierkorbs. Bestand
  seither: 26 aktive Dokumente, 0 im Papierkorb. Vorabprüfung in
  `docs/13-paperless.md`.
- 🟠 **`filebrowser` wird eingestellt.** Letztes Release v2.63.23, Repository wird am
  **01.09.2026** archiviert. Danach keine Sicherheits- oder Fehlerkorrekturen mehr.
  Als Empfehlung 2.9 aufgenommen.
- 🟡 **homepage v2.0.0** (14.08.2026) enthält einen Breaking Change bei der
  Authentifizierung. Läuft weiterhin auf 1.13.2; bewusst nicht mitaktualisiert, weil
  das Release zwei Tage alt ist. Empfehlung 2.10.
- 🟡 **Dashy ist Altbestand.** Drei Image-Tags im System (`:latest` 9 Monate, `:3.0.1`
  2 Jahre, `:arm64v8` 4 Jahre); Homepage hat die Rolle als Einstiegsseite übernommen.
  Empfehlung 2.11.
- 🟡 **20 Images für 10 Container** (8,66 GB). Durch die Updates liegen alte und neue
  Fassungen nebeneinander. Bewusst noch nicht aufgeräumt — ein altes Image ist die
  schnellste Rückfallebene.

### Korrigiert

- Beim Pinnen des `docker-socket-proxy` zunächst `0.3.0` gewählt. Das ist der letzte
  Tag der alten Nummerierung (September 2024) und damit 23 Monate **älter** als das
  zuvor verwendete `:latest`. Auf `v0.5.0` (27.07.2026) korrigiert.

---

## [1.4.2] — 2026-08-13

### Geändert am System

- **Erstsortierung des Paperless-Bestands**: 26 Dokumente mit Titel, Korrespondent,
  Dokumenttyp und Tags versehen. 14 Leerseiten (Duplex-Rückseiten) in den Papierkorb
  verschoben — 30 Tage wiederherstellbar.
- Vier Dokumenttypen ergänzt: Arztbrief, Laborbefund, Verdienstabrechnung,
  Bussgeldbescheid. Sechs Tags angelegt: Gesundheit, Auto, Arbeit, Finanzen,
  Versicherung, Einkauf — dazu `Pruefen` für Zweifelsfälle.
- Elf Korrespondenten angelegt.
- Das Skript liegt unter `docker-stacks/paperless/kategorisieren.py`.

### Behoben

- **Falsche Dokumentdaten.** Bei Arztbriefen hatte der Datumsparser das im Text
  stehende Geburtsdatum übernommen. Neuer Ansatz: Geburtsdatum ausschließen,
  nur Punkte als Trenner akzeptieren (sonst werden Laborwerte wie `11.6-14` als
  Datum gelesen), zweistellige Jahre unterstützen, das späteste plausible Datum
  wählen. Ergebnis: kein Dokument mehr vor 2015 datiert.

### Offen

- Drei Dokumente tragen den Tag `Pruefen` und bleiben im Posteingang: zwei
  unlesbare Scans und ein Schreiben ohne auffindbares Datum.

---

## [1.4.1] — 2026-08-13

### Behoben

- **`PAPERLESS_FILENAME_DATE_ORDER` entfernt.** Die Variable war bei der Einrichtung
  fälschlich auf `DMY` gesetzt; aus Scanner-Dateinamen wurden dadurch sinnlose Daten
  abgeleitet (10 Dokumente auf den 10.11.2000). Stattdessen `PAPERLESS_DATE_ORDER: DMY`
  für die Auswertung des Inhalts. Die betroffenen Daten wurden aus dem Inhalt neu
  abgeleitet — alle 10 erfolgreich.

### Hinzugefügt zur Doku

- `docs/13-paperless.md`: Abschnitte zu **Duplex-Leerseiten** (14 von 40 Dokumenten
  beim ersten Durchlauf, Prüfung ergab 0,00 % dunkle Fläche) und zur bewussten
  Abschaltung der Datumsauswertung aus Dateinamen.

### Geändert am System

- Tag `Leerseite` angelegt und auf alle inhaltsleeren Dokumente gesetzt.

---

## [1.4.0] — 2026-08-13

### Geändert am System

- **ntfy eingerichtet** (Port 2586): selbst gehostete Push-Benachrichtigungen,
  Zugriffsschutz `deny-all`, Benutzer `simon` mit Rolle admin, Token für das
  Backup in `/root/.ntfy-token`.
- **Backup meldet sich jetzt**: fehlgeschlagen mit `urgent`, Warnungen mit `high`,
  Erfolg lautlos mit `min` — der stille Erfolgseintrag dient als Lebenszeichen.
- ntfy ins Dashboard aufgenommen, Lesezeichen für den Paperless-Einwurf ergänzt.

### Hinzugefügt zur Doku

- **[14 — Benachrichtigungen](docs/14-benachrichtigungen.md)** — Einrichtung auf dem
  Handy, Einschränkung auf das Heimnetz mit Abwägung der Alternativen, eigene
  Nachrichten verschicken, Zugriffsschutz, Betrieb.

### Geprüft

- Zweiter Backup-Lauf inkrementell: **12,2 MiB übertragen statt 705 MiB**, 32
  Sekunden. Erfolgsmeldung mit Priorität `min` nachweislich zugestellt.

---

## [1.3.1] — 2026-08-13

### Geändert am System

- Tag **`Posteingang`** als Inbox-Tag angelegt — jedes neu eingelesene Dokument
  wird damit markiert, bis es durchgesehen ist.
- Acht Dokumenttypen vorangelegt: Rechnung, Vertrag, Behördenpost, Kontoauszug,
  Versicherung, Quittung, Bescheinigung, Kündigung.

### Hinzugefügt zur Doku

- `docs/13-paperless.md`, neuer Abschnitt 4 **„Der Arbeitsablauf im Alltag"**:
  Schleife vom Einwurf bis zur Ablage, Posteingang-Konzept, Abgrenzung von
  Korrespondent / Dokumenttyp / Tag, Empfehlung zur Tag-Struktur, Vorsortieren
  über Unterordner, Suchsyntax mit Beispielen, Zugriff vom Mobilgerät.

---

## [1.3.0] — 2026-08-13

### Geändert am System

- **Paperless-ngx vollständig konfiguriert**: OCR auf `deu+eng`, Zeitzone
  Europe/Berlin, Ablageschema `Jahr/Korrespondent/Datum_Titel`, Deskew und
  Seitendrehung aktiv, `OCR_MODE: skip` für bereits durchsuchbare PDFs,
  Worker-Zahl auf den Pi 4 abgestimmt.
- **Samba-Freigabe `scans`** angelegt, zeigt auf den Consume-Ordner. macOS-Beiwerk
  (`._*`, `.DS_Store`) wird über `veto files` ausgesperrt.
- **Polling statt inotify** für den Einwurf-Ordner — verhindert, dass halb
  übertragene Dateien eingelesen werden.
- **Zugangsdaten bereinigt**: PostgreSQL-Passwort und Secret-Key zufällig erzeugt,
  in `.env` ausgelagert, über `.gitignore` ausgeschlossen. Das alte Passwort wurde
  per `ALTER USER` in der laufenden Datenbank ersetzt.
- Container-Abhängigkeiten über `condition: service_healthy` statt blossem
  `depends_on`; Healthchecks für Paperless und PostgreSQL ergänzt.

### Hinzugefügt zur Doku

- **[13 — Paperless-ngx](docs/13-paperless.md)** — Einwurfwege, Konfiguration mit
  Begründung, automatische Zuordnung, Einordnung von KI-Erweiterungen, Betrieb
  und Fehlersuche.

### Korrigiert

- **Sachfehler in `docs/05-docker.md`**: Die Behauptung, `postgres:15` könne
  unbeabsichtigt auf PostgreSQL 16 springen, war falsch — der Tag ist an die
  Major-Version gebunden. Auch in `docs/09` entsprechend richtiggestellt.

### Geprüft

- Vollständiger Durchlauf mit Testdokument: Erkennung nach 15 s, OCR korrekt,
  Ablage nach Schema, Einwurf-Ordner geleert, 62 s für eine Seite. Testdokument
  anschließend entfernt.

---

## [1.2.0] — 2026-08-13

### Geändert am System

- **Automatisiertes Backup eingerichtet**: restic über rclone nach OneDrive,
  täglich 03:17 Uhr per systemd-Timer, verschlüsselt und versioniert
  (7 Tage / 4 Wochen / 6 Monate).
- Paperless wird über `document_exporter` plus `pg_dump` gesichert, Pi-hole über
  `pihole-FTL --teleporter`, dazu `/etc/wireguard`, `/etc/samba`,
  `passdb.tdb`, SSH-Konfiguration und Paketlisten.
- Skript und Unit-Dateien liegen versioniert unter `docker-stacks/backup/`.
- `RESTIC_PACK_SIZE=32` und rclone-Drosselung (`TPSLIMIT`, erhöhte Wiederholungen)
  gegen die OneDrive-Antworten `resourceLocked` / HTTP 500 unter Last.

### Hinzugefügt zur Doku

- **[12 — Backup](docs/12-backup.md)** — Umfang, Ausschlüsse mit Begründung,
  Zeitplan, Wiederherstellung Schritt für Schritt, Überwachung, Grenzen der
  5-GB-Freeversion.

### Korrigiert

- **Paperless enthält 0 Dokumente.** Die erste Fassung nahm ein gefülltes
  Dokumentenarchiv an und stufte das Risiko entsprechend hoch ein. Die Messung
  ergab ein leeres Medienverzeichnis und 0 Datensätze in der Datenbank. Das
  Bichon-Archiv umfasst 45 E-Mails (689 MB). Betroffen: `docs/06`, `README.md`.

### Behoben

- Empfehlung 1.1 (automatisiertes Backup) abgeschlossen.
- `docs/11-disaster-recovery.md`: 6 von 7 Bausteinen gesichert statt 1 von 7.

### Neue Befunde

- **Schwache Standardpasswörter bei Paperless** — `PAPERLESS_ADMIN_PASSWORD`
  steht auf `***ENTFERNT-20260820***`, `POSTGRES_PASSWORD` auf ***ENTFERNT-20260820***, beides im
  Git-Repository. Aufgenommen in `docs/07-sicherheit.md`.
- **222 GB unter `SSD_Müll` sind ungesichert** — darunter 2.971 Bilddateien und
  ein vollständiges Windows-Benutzerprofil. Passt nicht in 5 GB.
- **86 GB unter `rclone_bak`** sind Sicherungskopien auf derselben Festplatte,
  die sie schützen sollen — keine wirksame Sicherung.

---

## [1.1.0] — 2026-08-13

### Geändert am System

- **Homepage als Dashboard installiert** (Port 3000), Stack unter
  `docker-stacks/homepage/`. Konfiguration als Volume eingebunden und im Git
  versioniert.
- **Socket-Proxy** (`tecnativa/docker-socket-proxy`) ergänzt: Homepage erhält
  Container-Status und Ressourcendaten über eine Allowlist statt über einen
  direkt eingebundenen Docker-Socket. Schreibende Anfragen werden mit `403`
  abgewiesen — verifiziert.
- SSD unter `/mnt/usb-hdd` schreibgeschützt in den Homepage-Container
  eingebunden, damit das Speicher-Widget die Belegung anzeigen kann.
- Dashy läuft unverändert weiter (Port 8080), zunächst zum Vergleich.

### Behoben

- **Dashy-Konfiguration nicht persistent** — der Nachfolger Homepage hat die
  Konfiguration als Volume. Siehe [05 — Docker](docs/05-docker.md).
- Empfehlung 3.1 (Dashboard) abgeschlossen.

### Aktualisiert

- `docs/03-netzwerk.md` — Port 3000 in der Portliste
- `docs/05-docker.md` — Containerzahl 7 → 9, Stacks 5 → 6, neue Einträge
- `docs/09-empfehlungen.md` — 3.1 als erledigt markiert
- `docs/10-zugriff.md` — Homepage in Übersicht und Zugriffsmatrix
- `README.md` — Dashboard-Link

### Offen

- Push zu GitHub steht aus: SSH-Schlüssel des Pi ist auf dem Konto nicht
  hinterlegt, und die OAuth-Freigabe des GitHub-Connectors umfasst keinen
  Repository-Zugriff (`403 Resource not accessible by integration`).

---

## [1.0.0] — 2026-08-13

Erste vollständige Bestandsaufnahme.

### Hinzugefügt

- Vollständige Dokumentation in elf Kapiteln
- `inventar/collect.sh` — rein lesendes Skript zur Bestandsaufnahme
- Skill `raspi-doku` zur automatisierten Pflege dieser Dokumentation

### Erfasster Systemzustand

| | |
|---|---|
| Hardware | Raspberry Pi 4 Model B Rev 1.1, 4 GB RAM |
| Betriebssystem | Debian 12 (bookworm), 64-bit, Kernel 6.12.96 |
| Uptime | 16 Tage |
| Container | 7 (Dashy, Paperless + DB + Redis, Filebrowser, Bichon, Portainer) |
| Systemdienste | Pi-hole v6.4.3, unbound, WireGuard, Samba, SSH |
| Speicher | SD 235 G (5 % belegt), SSD 916 G (36 % belegt) |

### Festgestellte Befunde

**Kritisch**

- Keine automatisierten Backups — letzter rclone-Lauf am 12.12.2025
- Wurzeldateisystem auf SD-Karte von 02/2023 bei hoher Schreiblast

**Wichtig**

- Keine Firewall auf dem Host (`iptables` policy ACCEPT, kein `ufw`)
- SSH-Passwortanmeldung aktiv, kein `fail2ban`
- Container-Images 8 bis 17 Monate ohne Update
- Öffentliche IPv6-Adresse ohne lokale Firewall als zweite Schicht
- `unattended-upgrades` nicht aktiv

**Aufräumen**

- Dashy-Konfiguration nicht persistent (Volume auskommentiert)
- `dhcpcd` und `NetworkManager` laufen parallel — stündliche Journal-Fehler
- Ungenutzte Dienste: `ModemManager`, `triggerhappy`, `wpa_supplicant`
- 1,18 GB verwaiste Docker-Images
- Pfad-Drift beim Paperless-Stack (Label verweist auf gelöschtes Verzeichnis)
- Verwaistes Verzeichnis `/mnt/usb-hdd/filebrowser.db/`
- Nicht committete Änderungen im `docker-stacks`-Repository
- `smartmontools` fehlt — keine SSD-Gesundheitsdaten verfügbar

---

## Vorlage für künftige Einträge

```markdown
## [X.Y.Z] — JJJJ-MM-TT

### Geändert am System
- Was am Pi tatsächlich verändert wurde

### Hinzugefügt zur Doku
- Neue Kapitel oder Abschnitte

### Aktualisiert
- Kapitel, deren Werte sich geändert haben

### Behoben
- Befunde, die erledigt sind (mit Verweis auf das Kapitel)
```

### Versionierung

| Stelle | Wann erhöhen |
|---|---|
| **Major** (X) | Grundlegender Umbau der Infrastruktur oder der Dokumentationsstruktur |
| **Minor** (Y) | Neuer Dienst, neues Kapitel, neuer Befund |
| **Patch** (Z) | Aktualisierte Messwerte, Korrekturen, erledigte Befunde |
