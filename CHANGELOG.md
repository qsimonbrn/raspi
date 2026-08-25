# Änderungsverlauf der Dokumentation

Dieser Verlauf dokumentiert Änderungen an der **Dokumentation**, nicht am System selbst.
Systemänderungen stehen im Betriebstagebuch
[15 — Änderungshistorie](docs/15-aenderungshistorie.md) und in den jeweiligen Kapiteln.

Format: [Keep a Changelog](https://keepachangelog.com/de/1.1.0/) ·
Datumsformat: JJJJ-MM-TT

---

## [2.9.0] — 2026-08-25

### Behoben

- **Die Alarmkette ist zum ersten Mal geschlossen.** `stacks/ntfy/server.yml` hat
  `upstream-base-url: "https://ntfy.sh"` bekommen; eine Meldung erscheint seitdem auf
  dem gesperrten iPhone. Nachweis über den Netzverkehr des Containers (13 Pakete an
  `ntfy.sh`, Negativkontrolle auf eine unbeteiligte Adresse: 0) und über die Anzeige
  auf dem Gerät. Gesendet wurde über denselben Pfad, den `pi-backup.sh` benutzt.
  → [14 — Benachrichtigungen](docs/14-benachrichtigungen.md) Abschnitt 4 neu
  geschrieben, [09 — Empfehlungen](docs/09-empfehlungen.md) Punkt 2.1 auf erledigt.

### Hinzugefügt

- **`docs/05-docker.md`: neuer Abschnitt „Fallstrick: eine einzelne Datei im
  Bind-Mount".** Hängt eine einzelne Datei im Mount, klebt der Container an ihrer
  Inode. `sed -i` erzeugt eine neue — der Container liest danach unbemerkt weiter die
  alte Fassung. Am 25.08.2026 an `server.yml` nachgemessen (Inode innen 256054, außen
  256855) und beim Prüfen der eigenen Änderung aufgefallen.
- **`inventar/collect.sh`: zwölfte Prüfung „ntfy kann an iOS zustellen".** Prüfung 2
  belegt nur, dass der Server annimmt — genau der blinde Fleck, der die Alarmkette
  zwei Wochen lang still ausfallen ließ. Die neue Prüfung misst die *notwendige*
  Bedingung: Sie liest `server.yml` **aus dem laufenden Container**, nicht aus dem
  Repository, und meldet drei Fälle getrennt — Zeile fehlt, Zeile nur im Container
  (geht beim nächsten `compose up` verloren), Container liest eine andere Fassung als
  das Repository. Alle drei Zweige wurden gegen einen erzeugten Fehlerfall gemessen,
  der Positivfall gegen den echten Zustand.

### Richtiggestellt

- **`docs/09-empfehlungen.md`, Punkt 2.1, Schritt 3 („App neu einrichten") war
  überflüssig.** Die ntfy-App berechnet das Upstream-Thema selbst und empfing sofort
  nach dem Neustart des Servers. Der Schritt hätte Simon unnötig Arbeit gemacht.

### Geändert

- `README.md`: Kennzahlen vom 25.08.2026, neue Zeile „Benachrichtigungen" im Kasten
  „Zustand auf einen Blick".
- `docs/15-aenderungshistorie.md`: Eintrag zum 25.08.2026 mit der Abwägung, warum die
  `base-url` **nicht** auf `tailscale serve` umgestellt wurde.

---

## [2.8.3] — 2026-08-23

### Hinzugefügt

- **`docs/15-aenderungshistorie.md`: Nachtrag zum Portainer-Passwort.** Weg über
  `helper-reset-password` bei angehaltenem Container, und zwei Dinge, die beim
  nächsten Mal Zeit sparen: Das Konto heißt `simon`, nicht `admin`, und der Helfer
  fragt nicht nach einem Passwort, sondern erzeugt eines.
- **`docs/09-empfehlungen.md`: 3.7** — das Helfer-Image entfernen; es ist das einzige
  ungepinnte Image auf dem System.

### Richtiggestellt

- **`docs/10-zugriff.md`:** Der Portainer-Benutzername stand nirgends. Er ist `simon`;
  ein Konto `admin` gibt es nicht.

---

## [2.8.2] — 2026-08-23

### Richtiggestellt

- **`docs/14-benachrichtigungen.md`, Abschnitt 4: Die Aussage „Das Handy erhält
  Nachrichten, solange es im WLAN zu Hause ist" war falsch.** Am 23.08.2026 kam auf
  dem iPhone keine einzige von 32 angenommenen Meldungen an. Ursache: fehlende
  `upstream-base-url`; ohne sie empfängt die iOS-App von einem selbst gehosteten
  Server im Hintergrund nichts. Die Alarmkette für fehlgeschlagene Backups war damit
  seit dem 13.08.2026 nie geschlossen.
- **Die Abhakung des offenen Punkts „ntfy-Meldung einmal echt auslösen" ist
  zurückgenommen.** Sie stützte sich auf ein `http=200` beim Versand — das beweist
  die Annahme durch den Server, nicht die Zustellung ans Gerät. Korrektureintrag in
  `docs/15-aenderungshistorie.md`.

### Hinzugefügt

- **`docs/09-empfehlungen.md`: 2.1 „ntfy-Zustellung aufs iPhone reparieren"** —
  Befund, Weg in vier Schritten und ausdrücklich die Vorgabe, wie nachzumessen ist
  (bei geschlossener App und gesperrtem Gerät, mit `subscribers` als Gegenprobe).
  Rund 45 Minuten, nach Absprache nicht dringend.

---

## [2.8.1] — 2026-08-23

Passwortwechsel und Token-Erneuerung nachgezogen.

### Geändert

- **`docs/14-benachrichtigungen.md`:** Der Verweis `grep NTFY_PASSWORD ~/stacks/ntfy/.env`
  ist entfallen — die Datei enthält seit dem 23.08.2026 keine Zugangsdaten mehr. Statt
  dessen der Weg zum Neusetzen und ein Kasten, der erklärt, warum die Zweitschrift weg ist.
- **`docs/15-aenderungshistorie.md`:** Eintrag zum Passwortwechsel und zur
  Token-Erneuerung, samt der Nachmessung ohne Kenntnis der Passwörter.

---

## [2.8.0] — 2026-08-23

Passwort-Tresor Vaultwarden aufgesetzt und dokumentiert. Zwei Prüfungen, die nichts
prüften, wurden dabei gefunden und repariert.

### Hinzugefügt

- **`docs/18-vaultwarden.md`: neues Kapitel.** Aufbau des Tresors, warum Port 8443 statt
  443, der Weg einer Anfrage über `tailscale serve`, die Begründung für die
  abgeschaltete Admin-Oberfläche, alle Einstellungen mit Herleitung, die Sicherung der
  SQLite-Datenbank und die Wiederherstellung Schritt für Schritt.
- **`docs/12-backup.md`: Abschnitt „Vaultwarden: warum die laufende Datei ausgeschlossen
  ist".** Mit der Messung, was `PRAGMA integrity_check` erkennt — und was nicht.
- **`docs/09-empfehlungen.md`: 3.5 und 3.6.** Überwachung des Blocklisten-Status und eine
  neustartfeste Quelle für den Zeitpunkt des letzten Gravity-Laufs.
- **`docs/15-aenderungshistorie.md`: Eintrag zum 23.08.2026.**
- Vaultwarden in `docs/03-netzwerk.md` (Port 8443), `docs/05-docker.md` (neunter
  Container), `docs/10-zugriff.md` (Weboberflächen), `docs/11-disaster-recovery.md`
  (Position 9 der gesicherten Bestände) und im README.

### Geändert

- **`inventar/collect.sh`: `sudo` vor allen sechs `gravity.db`-Abfragen.** Ohne `sudo`
  scheiterten sie seit dem Kontowechsel am 18.08.2026 still, und die Bestandsaufnahme
  meldete `?` statt der Domain- und Listenzahlen. Nachgemessen: mit `sudo` liefert
  dieselbe Abfrage 1.039.885 Domains.
- **`system/backup/pi-backup.sh`: konsistenter SQLite-Abzug für Vaultwarden**, mit
  Prüfung des Abzugs und Ausschluss der laufenden Datei aus der restic-Sicherung. Die
  Prüfung wurde nach einer Messung um eine Abfrage der Benutzertabelle ergänzt, weil
  `integrity_check` eine leere Datei mit `ok` durchgehen lässt.
- **`stacks/homepage/config/services.yaml`:** Eintrag für Vaultwarden, bewusst ohne
  `siteMonitor` — der Pi kann seinen eigenen Tailnet-Namen nicht auflösen, die Kachel
  stünde dauerhaft auf Rot.
- README: Container 8 → 9, Speicher-Limits 3.104 → 3.360 MiB, Eckwerte nachgezogen.

### Richtiggestellt

- **Blocklisten mit `status=2` sind unauffällig.** Die am 23.08.2026 offen notierte Frage
  ist beantwortet: Laut der installierten `gravity.sh` bedeutet 2 „List stayed
  unchanged". Der bedenkliche Fall wäre 3; den hat keine Liste. Die Frage stand seit dem
  Vortag als ungeklärt in der Doku.
- **`tailscale serve --bg` übersteht einen Neustart.** Am 23.08.2026 nachgewiesen —
  beim vorherigen Versuch war keine Konfiguration vorhanden, die den Neustart hätte
  überleben können.

---

## [2.7.0] — 2026-08-23

HTTPS im Tailnet freigeschaltet und der tragfähige Weg dorthin nachgemessen.

### Hinzugefügt

- **`docs/10-zugriff.md`: Abschnitt „HTTPS im Tailnet".** Zertifikat, der Weg über
  Port 8443 und zwei Fallstricke: `tailscale serve --https=443` meldet auf diesem Pi
  Erfolg und wirkt nicht, weil `pihole-FTL` am Socket sitzt; `tailscale cert` von Hand
  legt zusätzlich eine Kopie des privaten Schlüssels ins Arbeitsverzeichnis.
- **`docs/15-aenderungshistorie.md`: zwei Einträge** — HTTPS-Freischaltung (20.08.)
  und Neustartverhalten (23.08.). Letzterer hält fest, dass Pi-hole in den ersten ein bis zwei
  Minuten nach dem Boot nicht blockt und dabei durchgehend „blocking is enabled" meldet.

### Korrigiert

- **`docs/10-zugriff.md`: drei Tailnet-Geräte statt zwei.** `simons-macbook-pro` fehlte;
  an `tailscale status` nachgemessen.

---

## [2.6.0] — 2026-08-20

Die Backup-Prüfung prüft jetzt die Nutzdaten, nicht nur die Buchführung darüber.

### Geändert

- **`inventar/collect.sh`: `restic check` läuft mit `--read-data-subset=80M`.** Bisher
  prüfte die Bestandsaufnahme nur Index und Metadaten. Der Unterschied ist nicht
  theoretisch — **nachgemessen an einem Wegwerf-Repository**: In einer 3-MB-Pack-Datei
  wurde ein einziges Byte gekippt, danach meldete `restic check` weiterhin
  `no errors were found`, während `restic check --read-data`
  `Fatal: repository contains errors` lieferte. Stille Datenfäule in der Cloud wäre also
  bis zum Ernstfall unbemerkt geblieben.
- **Neuer Sonderfall in derselben Prüfung: „0 Packs gelesen" ergibt `?`, nicht `ok`.**
  Die erste Fassung dieser Erweiterung benutzte einen Bruch (`1/50`). Das Repository hat
  aber nur **45 Pack-Dateien** — an den meisten Tagen wären damit null Packs geprüft
  worden, und die Zeile hätte trotzdem Entwarnung gemeldet. Genau die Art Prüfung, gegen
  die dieser Abschnitt gebaut ist.
- **Der Befund nennt jetzt die gelesene Menge** („4 / 4 packs, Stichprobe 80M") statt nur
  zu behaupten, es sei geprüft worden.
- **Der Byte-Vergleich der Stichprobe ist nicht mehr die Grundlage der Marke**, sondern
  eine Zusatzangabe. Er sagt nichts, wenn das Original seit dem Snapshot geändert wurde —
  bei `README.md` der Normalfall. Die Prüfung schreibt das hin, statt Gleichheit zu
  behaupten.
- **Laufzeit** 84 s statt 82 s.

### Hinzugefügt

- **`docs/12` — neuer Abschnitt „6a. Wie geprüft wird, dass das Backup taugt"** mit der
  Gegenprobe, der Begründung für eine Größenangabe statt eines Bruchs und dem Hinweis,
  dass `restic check --read-data` von Hand der vollständige, aber langsame Nachweis ist.

### Abwägung, die dokumentiert bleibt

Eine Größe (`80M`) hält die Laufzeit konstant, wählt die Packs aber zufällig:
vollständige Abdeckung ist **wahrscheinlich, nicht garantiert**. Ein Bruch (`1/10`) würde
sie garantieren, ließe die Laufzeit aber mit dem Repository wachsen — bei 5 GB wären das
Minuten. Für stille Datenfäule, die zufällige Packs trifft, reicht die Stichprobe; für
den Nachweis „jedes Byte einmal geprüft" nicht.

---

## [2.5.0] — 2026-08-20

Speicher-Limits gesetzt und dokumentiert, Tailscale aktualisiert. Beides sind
Systemänderungen — die Begründungen stehen ausführlich im Betriebstagebuch
[15](docs/15-aenderungshistorie.md), hier nur die Doku-Seite.

### Hinzugefügt

- **`docs/05` — neuer Abschnitt „Speicher-Limits — gesetzt am 20.08.2026"** mit der
  Messgrundlage (603 Punkte je Container über zwei Tage), der Limit-Tabelle samt Reserve
  je Container und der Begründung, **warum großzügig statt knapp**: Die Messung tastet
  alle fünf Minuten ab und sieht einen OCR-Lauf von unter zwei Minuten überhaupt nicht,
  das gemessene Maximum ist also eine Untergrenze. Dazu der Hinweis, dass ein
  `mem_limit` erst beim Neuerzeugen des Containers greift, nicht beim Neustart.
- **`docs/15` — Eintrag zu beiden Systemänderungen**, mit der Nachmessung: alle acht
  Container melden ihr Limit, kein OOM, kein Neustart, Paperless nach 125 s wieder
  `healthy`, `pi-guard` unbeschädigt.

### Geändert

- **`README` und `docs/05`:** Speicher-Limits von „noch keine gesetzt" auf „gesetzt für
  alle acht, Summe 3.104 von 3.796 MiB, nicht überbucht".
- **`README` und `docs/02`:** ausstehende Updates von 1 auf 0. Der Hinweis bleibt, dass
  `unattended-upgrades` auf `origin=Debian` beschränkt ist und Tailscale deshalb **nie**
  selbsttätig aktualisiert wird — der Fall ist erledigt, die Lücke im Verfahren nicht.
- **`docs/09`:** beide Maßnahmen als erledigt gekennzeichnet. Bei Tailscale mit dem
  Zusatz, dass daraus ein Dauerauftrag wird.

### Anmerkung zur Messung

Der befristete Timer `docker-stats-messung` wird **noch nicht** entfernt, obwohl
`system/messung/README.md` das nach der Auswertung vorsieht. Sein erster Zweck ist
erfüllt, sein zweiter beginnt gerade: zu zeigen, ob ein Container gegen seine neue Decke
läuft — vor allem bichon, dessen Arbeitssatz im Messfenster noch wuchs. Entfernt wird er
nach ein bis zwei Wochen ohne Anschlag.

---

## [2.4.0] — 2026-08-20

Zwei Passwörter aus dem Git-Verlauf entfernt — und die Prüfung repariert, die nur eines
von beiden gefunden hatte.

### Sicherheit

- **`POSTGRES_PASSWORD` und `PAPERLESS_ADMIN_PASSWORD` aus allen 61 Commits entfernt**
  (`git filter-repo --replace-text`, Force-Push). Beide standen im Klartext in neun
  Commits zwischen dem 10.12.2025 und dem 13.08.2026. Vorgehen, Messungen und
  Fallstricke im Betriebstagebuch [15](docs/15-aenderungshistorie.md).
- **Vor dem Eingriff nachgemessen: beide Werte sind ungültig.** Das Admin-Passwort wird
  vom Konto `admin` abgelehnt, das Datenbankpasswort von Postgres über TCP — jeweils mit
  Positiv- und Negativkontrolle, weil der erste Versuch über den lokalen Socket lief, wo
  `pg_hba.conf` auf `trust` steht und **jedes** Passwort angenommen wird.
- **Klartextwerte in `docs/07` und im CHANGELOG maskiert**, und zwar **vor** der
  Bereinigung. Sonst hätte der Commit, der den Verlauf säubert, das Geheimnis im selben
  Zug neu hineingeschrieben. Die Maskierung im CHANGELOG-Eintrag vom 16.08.2026 ist eine
  bewusste Ausnahme von der Regel, dass Verlaufsdateien nicht umgeschrieben werden: Der
  Wortlaut bleibt, nur die Werte fallen weg.

### Behoben

- **Der Ausschlussfilter der Behauptungsprüfung urteilte über den Wert statt über die
  Datei.** Er verwarf alles, was nach Platzhalter aussieht — und übersah so ein
  Passwort, das mit `changeme` begann und trotzdem acht Monate lang in Gebrauch war.
  Jetzt entscheidet der Pfad: Vorlagen (`*.example`, `*.sample`, `*.dist`, `*.template`,
  `*beispiel*`) dürfen Platzhalter enthalten, echte Konfigurationsdateien nicht.
- **Die erste Fassung dieser Korrektur war selbst kaputt.** Sie filterte mit
  `grep -E '\t…'`; in POSIX-ERE ist `\t` kein Tabulator, sondern der Buchstabe `t`. Der
  Filter lief durch und meldete eine bereits maskierte Zeile als Treffer. Gefunden hat es
  nicht das Lesen, sondern die Gegenprobe gegen drei Fälle: bereinigtes Repository
  (erwartet 0 → 0), Sicherung von vorher (erwartet 2 → 2), Testrepository mit demselben
  Platzhalter in einer `.example`- und einer echten Compose-Datei (erwartet: nur die
  echte → genau so). Gefiltert wird seitdem in `awk`.
- **`docs/09` verwies mit `../docs/` auf ein Nachbarkapitel im selben Verzeichnis.**

### Richtiggestellt

- **„Beide Repositories sind öffentlich"** — ein Satz, den diese Dokumentation am
  Vormittag des 20.08.2026 selbst neu bekommen hatte, ungeprüft. Anonymes
  `git ls-remote` scheitert für beide: Sie sind **privat**. Ein hausgemachter Fall
  desselben Musters, das dieses Repository an sechs Beispielen vom 18.08.2026
  dokumentiert.
- **`docs/07`, „Schwache Standardpasswörter bei Paperless" stand auf 🟠 offen.**
  Nachgemessen ist der Befund erledigt: Beide Werte wurden geändert, der alte
  funktioniert nachweislich nicht mehr.

---

## [2.3.0] — 2026-08-20

Erste turnusmäßige Aktualisierung mit dem überarbeiteten Ablauf. Minor-Sprung, weil ein
neuer Befund dazukommt: das Postgres-Passwort im Git-Verlauf hat ein eigenes Kapitel
bekommen.

### Geändert

- **Messwerte in `README`, `01`, `02`, `04`, `05`, `08` nachgezogen** (Bestandsaufnahme
  `2026-08-20-1111`, Laufzeit 103 s). Behauptungsprüfung: 10 `ok` · 1 `ACHTUNG` ·
  0 nicht prüfbar.
- **`05` — Ressourcenverbrauch neu gemessen.** Die bisherige Tabelle stammte von einer
  Messung sechs Minuten nach dem Neustart; im eingeschwungenen Zustand nach zwei Tagen
  sieht die Verteilung anders aus. **bichon: 51 MiB kalt, 356 MiB warm** — das
  Siebenfache. Daraus die Konsequenz für die noch zu setzenden Limits: Eine
  Kaltstartmessung taugt nicht als Grundlage, ein Limit von 128 MiB hätte den Dienst zwei
  Tage später abgewürgt. Beide Messungen stehen jetzt im Kapitel, mit Erklärung des
  Unterschieds.
- **`04` — Pi-hole-Kennzahlen.** 1.115.658 Domains statt 800.598, sechs aktive Listen
  statt vier; `pihole-FTL` belegt 60 MB statt 47 MB.
- **`09` — Maßnahme 1.2 „Wiederherstellung testen" auf 🟡 teilweise erledigt.** Die
  Speicherebene ist bewiesen, die Anwendungsebene nicht: Dass ein zurückgeholter
  Paperless-Export sich auch **importieren** lässt, ist weiterhin ungeprüft.
- **`09` — zwei neue Maßnahmen:** 2.13 Postgres-Passwort aus dem Verlauf entfernen,
  sowie `tailscale` von Hand aktualisieren.

### Richtiggestellt

- **`08` widersprach sich selbst.** Oben stand „Keine automatisierten Backups — letzter
  Lauf 12.12.2025" als 🔴 kritischer Befund, unten im selben Kapitel „sechs davon sind
  gesichert — seit Einrichtung des restic-Backups am 13.08.2026". Der Befund ist seit dem
  13.08.2026 erledigt und seit dem 20.08.2026 als wiederherstellbar nachgewiesen.
- **`08` führte zwei weitere erledigte Befunde als offen:** „Keine Firewall auf dem Host"
  (seit 18.08.2026 `pi-guard`) und „Keine automatischen Sicherheitsupdates" (seit
  18.08.2026 `unattended-upgrades`).
- **`08` und `11` zählten „sechs von sieben" gesicherten Bausteinen.** Die Tabelle in `11`
  führt seit dem 18.08.2026 neun Positionen, acht davon gesichert — ntfy und das
  Portainer-Volume kamen dazu, der Fließtext blieb stehen. In `11` verwies der Satz
  danach außerdem auf „Position 7", gemeint war Position 9.
- **`README` beschrieb die Compose-Dateien als „in einem separaten Repository"**, während
  weiter unten im selben `README` korrekt steht, dass die Repositories am 18.08.2026
  zusammengelegt wurden.
- **`02` — „0 ausstehende Updates" mit der Deutung „wird regelmäßig manuell gepflegt".**
  Gemessen: ein ausstehendes Paket (`tailscale` 1.102.2 → 1.102.3). Wichtiger als die
  Zahl ist der Grund: `unattended-upgrades` ist auf `origin=Debian` beschränkt
  (nachgemessen in `50unattended-upgrades`), Tailscale kommt aus einem eigenen
  Repository und wird deshalb **nie** selbsttätig aktualisiert.
- **`09` — zwei Maßnahmen trugen beide die Nummer 2.9.** Samba-Härtung ist jetzt 2.12.

### Hinzugefügt

- **`07` — eigener Abschnitt „🟡 Postgres-Passwort im Git-Verlauf".** Klartext in neun
  Commits zwischen dem 10.12.2025 und dem 13.08.2026. Nachgemessen und entschärfend: Der
  Wert stimmt **nicht** mit dem laufenden überein, und Postgres veröffentlicht keinen
  Port nach außen. Der eigentliche Befund ist, dass das Geheimnis acht Monate unbemerkt
  im Verlauf lag und nicht von einem Menschen gefunden wurde, sondern von einer Prüfung,
  die es seit dem 20.08.2026 gibt.
- **`README` — Zeile „Backup" im Kasten „Zustand auf einen Blick"**, mit dem Nachweis der
  Wiederherstellbarkeit statt nur der Tatsache, dass gesichert wird.

### Nicht geändert

Am System wurde nichts angefasst. Das ausstehende Tailscale-Update und die Bereinigung
des Git-Verlaufs sind als Maßnahmen aufgenommen, nicht ausgeführt.

---

## [2.2.0] — 2026-08-20

Minor-Sprung: Die Bestandsaufnahme prüft jetzt Behauptungen statt nur Werte zu sammeln.

### Geändert

- **`inventar/collect.sh` überarbeitet.** Der Anlass war nicht der Skill-Text, sondern
  seine Datengrundlage: Das Skript kannte `pi-abgleich`, `pi-guard`, `pi-gravity`, die
  Logrotation, `no-new-privileges` und die Speicher-Cgroup mit null Treffern. Der
  Diff-Mechanismus, auf dem die Doku-Pflege beruht, war blind für alles seit dem
  16.08.2026.
- **Neuer Abschnitt „Behauptungsprüfung"** mit elf Prüfungen. Maßstab ist nicht, was
  leicht zu messen ist, sondern was still scheitert, was oft angefasst wird und was
  ungeprüft hingenommen wird — bis hin zum Wiederherstellungspfad des Backups.
- **Drei Marken statt leerer Zellen:** `ok` geprüft und in Ordnung · `ACHTUNG` geprüft
  und abweichend · `?` konnte nicht geprüft werden. Die Unterscheidung zwischen der
  ersten und der letzten Marke ist der Zweck der Änderung: Eine leere Zelle las sich
  bisher wie „nichts vorhanden".
- **Neue Datei `inventar/snapshots/aktuell-werte.tsv`** — maschinenlesbare Zahlen, damit
  der nächste Lauf Wachstum gegen den vorigen vergleichen kann statt gegen einen
  absoluten Grenzwert.
- **Laufzeit** rund 86 s statt 27 s; die restic-Prüfungen sprechen über rclone mit
  OneDrive. Mit `--ohne-tiefpruefung` bleibt es bei rund 27 s.

### Richtiggestellt

- **`rclone listremotes` lief ohne `sudo`** und lieferte deshalb eine leere Zeile, die
  sich wie „kein Remote konfiguriert" las. Ebenso irreführend: der rclone-Log-Eintrag
  vom 12.12.2025 als scheinbar letzter Backup-Zeitpunkt, der Cronjob-Zähler `0` bei vier
  laufenden systemd-Timern und `ufw: nicht installiert` als scheinbarer Mangel, wo eine
  bewusste Entscheidung für `pi-guard` steht. Alle vier Zeilen ersetzt.
- **`restic snapshots --latest 1` liefert nicht den neuesten Snapshot**, sondern den
  neuesten je Pfad-Gruppe (gemessen am 20.08.2026). Nach der Umstellung der gesicherten
  Pfade am 18.08. kam dadurch ein zwei Tage alter Snapshot zurück — das Backup sah still
  stehend aus. Das Skript sortiert jetzt selbst nach Zeit.
- **Der Wiederherstellungspfad des Backups war nie getestet.** Am 20.08.2026 erstmals
  nachgewiesen: `restic check` über alle 9 Snapshots ohne Fehler, Stichprobe aus Snapshot
  `fd04740b` zurückgeholt und byte-identisch.

### Offen

- **Ein Postgres-Passwort steht im Klartext im Git-Verlauf**, in neun Commits zwischen
  dem 10.12.2025 und dem 13.08.2026 (`paperless/docker-compose.yml`, alter Pfad). Der
  aktuelle Stand ist sauber, und der Wert stimmt nachweislich **nicht** mit dem heute
  laufenden überein — Postgres und `.env` tragen einen anderen. Gefunden von der neuen
  Prüfung beim ersten Lauf. Aufräumen des Verlaufs steht aus, siehe
  [09 — Empfehlungen](docs/09-empfehlungen.md).

---

## [2.1.0] — 2026-08-20

Minor-Sprung: Kapitel 04 bekommt einen neuen Abschnitt.

### Geändert am System

- **Pi-hole-Blocklisten auf Adblock-Format umgestellt.** Alle bisherigen Listen lagen im
  Hosts-Format und sperrten deshalb keine Subdomains — der Grund, warum trotz 485.267
  Einträgen Werbung durchkam. Neu: HaGeZi Pro++, HaGeZi Pop-Up Ads, HaGeZi TIF Medium,
  OISD Big. Die beiden `blocklistproject`-Listen abgeschaltet, StevenBlack und adaway
  behalten. `gravity` wuchs auf 800.598 eindeutige Domains.
- **Fünf Regex-Regeln** für Werbedomains, die in keiner der sechs geprüften Listen
  stehen.
- **`updateGravity` von wöchentlich auf täglich** (03:02) umgestellt — als eigener
  systemd-Timer `pi-gravity`, nicht in `/etc/cron.d/pihole`. Diese Datei gehört Pi-hole
  und wird bei jedem Core-Update neu geschrieben; die Änderung wäre dort still
  zurückgefallen. Das Skript meldet über ntfy, wenn ein Lauf scheitert oder die Zahl
  der Einträge um mehr als ein Viertel fällt.
- **Vier neue Paare im Abgleich** (`system/pihole/`), darunter `/etc/cron.d/pihole`
  selbst — damit ein Core-Update, das die Anpassung zurücksetzt, am nächsten Morgen
  gemeldet wird. 24 statt 20 Paare.

### Hinzugefügt

- `docs/04-dienste-system.md`: Abschnitt **Blocklisten** — Bestand, Format-Fallstrick,
  bewusst nicht eingebundene Listen, Abfragen zur Wirksamkeitsprüfung, Speicherbedarf.
- `docs/15-aenderungshistorie.md`: Eintrag vom 20.08.2026 mit Messwerten und Nachkontrolle.
- `system/pihole/` samt README: warum der Zeitplan nicht in Pi-holes Cronjob gehört und
  was nach einem Core-Update zu tun ist.
- `docs/17-wo-was-liegt.md`: vier neue Zeilen in der Tabelle, dritte Falle ergänzt —
  bei `cron.d-pihole` ist eine Abweichung der erwartete Normalfall, kein Versehen.
- `docs/02-betriebssystem.md`: `pi-gravity.timer` in der Timer-Tabelle.

### Geändert

- Erfassungsdatum in `docs/04-dienste-system.md` und `docs/15-aenderungshistorie.md`.

---

## [2.0.0] — 2026-08-18

Major-Sprung, weil sich die Ablage der gesamten Dokumentation geändert hat.

### Geändert am System

- **`docker-stacks` und `raspi-doku` zu `qsimonbrn/raspi` zusammengeführt.** Beide
  Verläufe erhalten. Neuer Aufbau: `docs/`, `inventar/`, `stacks/`, `system/`.
  Ausschlaggebend war kein Aufräumdrang, sondern ein struktureller Fehler: Eine
  Systemänderung brauchte zwei Commits in zwei Repositories, und zwischen den Pushes
  konnte die Doku von der Realität abweichen — was am selben Tag passiert ist.
- **`/mnt/usb-hdd/claude-skills` ins Backup aufgenommen.** Es lag in **keinem**
  Snapshot, obwohl darin die Skills und der `pi-ssh`-MCP-Server liegen.
- **Alle acht Container neu erstellt**, damit
  `com.docker.compose.project.config_files` auf den neuen Pfad zeigt. Für sechs von
  ihnen war `--force-recreate` nötig: Ein einfaches `up -d` ändert das Label nicht,
  weil die Dienstkonfiguration selbst unverändert bleibt.
- **Veraltete Skill-Kopie entfernt**, die unter `.claude/skills/` im Doku-Repository
  lag.

### Geändert an der Dokumentation

- **README**: Aufbau neu, mit dem Hinweis auf den Unterschied zwischen `stacks/`
  (läuft direkt von hier) und `system/` (nur Kopie).
- **[17 — Wo was liegt](docs/17-wo-was-liegt.md)**: aus drei Repositories wurden zwei.
- **[12 — Backup](docs/12-backup.md)**: `claude-skills` in der Pfadliste.
- **[15 — Änderungshistorie](docs/15-aenderungshistorie.md)**: Eintrag zum Umbau.

### Nicht geändert

- `CHANGELOG.md` und `docs/15-aenderungshistorie.md` sind von der maschinellen
  Pfadumstellung **ausgenommen** geblieben. Sie beschreiben vergangene Zustände; ein
  Pfad, der damals galt, ist dort richtig und nicht veraltet.

---

## [1.13.0] — 2026-08-18

### Geändert am System

- **Wartungsskript überarbeitet.** `pi_wartung.sh` (12/2025, per Alias `wartung` von
  Hand benutzt) hatte vier Defekte, gegen die der bekannte `sudo`-Unterschied harmlos
  war: der Abschnitt „Compose-Stacks aktualisieren" lief über `/opt/stacks/*`, ein
  Verzeichnis, das es auf diesem Pi **nie gab**; die letzte Zeile ließ das Skript unter
  `set -e` **immer** mit Exit 1 enden, wenn kein Neustart fällig war; `apt full-upgrade`
  und `pihole -up` liefen bedingungslos mit; und die Ausgabe bestand zu neun Zehnteln
  aus debconf-Klagen. Neu als `pi-wartung.sh` mit acht Abschnitten, getrennten Warnungen
  und Hinweisen, Abgleichprüfung, Backup-Alter und einer Kontrolle auf ungedrehte
  Docker-Logs. Aktualisiert keine Container mehr und startet nicht neu.
- **Aliase versioniert.** `wartung`, `abgleich`, `temp`, `throttled` und `bootcheck`
  standen von Hand in `/etc/bash.bashrc`. Jetzt in `docker-stacks/wartung/pi-aliase.sh`,
  installiert nach `/etc/profile.d/pi-aliase.sh`. Da `profile.d` nur von **Login**-Shells
  gelesen wird, lädt `bash.bashrc` dieselbe Datei nach — sonst fehlten die Aliase in
  interaktiven Nicht-Login-Shells.
- **Namen vereinheitlicht** auf `pi-wartung.sh` in Repository und System. Die alten
  Fassungen liegen unter `/mnt/usb-hdd/_to_delete/`.
- **Sechs Pakete aktualisiert** beim ersten Testlauf, darunter `docker-compose-plugin`
  **5.4.0 → 5.5.0**. Danach geprüft: alle fünf Stacks gültig, alle acht Container
  `healthy`.

### Richtiggestellt

- Die Angabe „0 Pakete aktualisierbar" von vorhin beruhte auf **veralteten
  Paketlisten**. Nach einem `apt-get update` waren es sechs.
- Die Aussage, `pi_wartung.sh` werde „von nichts aufgerufen", galt nur für Timer und
  Cron. Es wird über den Alias `wartung` von Hand benutzt.

### Geändert an der Dokumentation

- **[02 — Betriebssystem](docs/02-betriebssystem.md)**: neuer Abschnitt „Wartung von
  Hand" mit den acht Abschnitten, den beiden Schaltern und den vier Befunden am
  Vorgänger.
- **[17 — Wo was liegt](docs/17-wo-was-liegt.md)**: Paare nachgezogen, der Befund zu
  `pi-maintenance.sh` auf erledigt gesetzt. Das Werkzeug hat die Abweichung beim
  **ersten** Lauf gefunden — von Hand war sie acht Monate lang unentdeckt geblieben.

---

## [1.12.0] — 2026-08-18

### Geändert am System

- **Abgleich zwischen Repository und installierten Fassungen als Werkzeug.**
  `docker-stacks/abgleich/` enthält ein Manifest mit allen 19 Dateipaaren (Systempfad,
  Besitzer, Rechte, Nachlauf — alle Werte mit `stat` gemessen) und ein Skript, das
  prüft (`list`, `check`, `diff`) und auf Ansage in beide Richtungen kopiert
  (`install`, `pull`, jeweils mit vorherigem `diff` und Rückfrage). Installiert als
  `/usr/local/sbin/pi-abgleich.sh`.
- **`pi-abgleich.timer`**, täglich 09:15, meldet über ntfy, wenn etwas abweicht.
  Er ruft ausschließlich `check` auf und **kopiert nie von selbst** — Begründung in
  [17](docs/17-wo-was-liegt.md).

  Nachgemessen: 19 Paare erfasst, 18 identisch, die eine bekannte Abweichung
  (`pi_wartung.sh`) korrekt erkannt, ntfy-Meldung zugestellt, das Werkzeug erfasst
  sich selbst.

### Geändert an der Dokumentation

- **[17 — Wo was liegt](docs/17-wo-was-liegt.md)** um die drei neuen Dateipaare und
  den Abschnitt zum Werkzeug ergänzt. Der Abschnitt „Abgleich von Hand" ist zur
  Rückfallebene geworden.

---

## [1.11.0] — 2026-08-18

### Hinzugefügt

- **[17 — Wo was liegt](docs/17-wo-was-liegt.md)** — neues Kapitel. Beantwortet die
  Frage, welche Datei das Original ist und welche nur eine Kopie. Enthält die
  vollständige, gemessene Zuordnung aller 16 Dateipaare zwischen Repository und
  installierter Fassung, die Rechtekonvention der drei Repositories und die zwei
  Fallen, die sich darin verstecken: unterschiedliche Zielverzeichnisse
  (`/usr/local/bin` gegen `/usr/local/sbin`) und ein abweichender Dateiname
  (`pi_wartung.sh` gegen `pi-maintenance.sh`).

### Befund

- **`/usr/local/sbin/pi-maintenance.sh` ist nicht nachgezogen.** Der Eintrag 1.9.0
  vermerkt, alle Docker-Aufrufe seien systemweit auf `sudo docker` umgestellt worden,
  `pi_wartung.sh` ausdrücklich genannt. Geändert wurde nur die Kopie im Repository; die
  installierte Fassung ruft an sechs Stellen weiterhin `docker` ohne `sudo` auf. Das
  Skript wird von keinem Timer aufgerufen, der Schaden ist begrenzt — der Befund zeigt
  aber, dass der Abgleich von Hand nicht verlässlich passiert.

### Richtiggestellt

- Der Rechtehinweis in 1.10.0 war unvollständig. Nicht der Besitzer entscheidet, ob
  beide Konten in einem Repository arbeiten können, sondern die **Gruppe** `pi-admin`
  samt Gruppenschreibrecht auf den Verzeichnissen. Schreibgeschützte Objektdateien in
  `.git/objects` (`444`) sind normales Git-Verhalten und **kein** Rechteproblem — der
  Blocker waren Verzeichnisse mit `2755` statt `2775`.

---

## [1.10.0] — 2026-08-18

### Richtiggestellt

- **Die Aussage aus 1.9.0, die Docker-Log-Rotation gelte für neu erstellte Container,
  war falsch.** Sie galt für gar keine. `log-driver` und `log-opts` gehören nicht zu
  den Werten, die Docker bei einem `systemctl reload` übernimmt, und ein echter
  Daemon-Neustart hatte nie stattgefunden. Nachgewiesen mit einem Wegwerf-Container:
  `docker create` lieferte `LogConfig: json-file map[]`. Bichon hatte zu dem Zeitpunkt
  eine ungedrehte Logdatei von 39 MB.
- **Die Aussage „Alle Images sind auf feste Versionen gepinnt" stimmte nicht.**
  `homepage` und `bichon` liefen weiter auf `:latest`. Jetzt zutreffend.
- **Die Angabe, bichon sei mit 11,7 % der größte Speicherverbraucher, war eine
  Schätzung aus `ps`** — zu dem Zeitpunkt gab es keine Speicherbuchführung im Kernel.
  Gemessen liegt bichon bei 1,4 %, Paperless bei 25,1 %.
- **Der Stacks-Pfad `~/docker-stacks` ist irreführend**, wenn er aus dem Konto `claude`
  gelesen wird: Die Stacks liegen unter `/home/simon/docker-stacks`.

### Geändert am System

- **Logrotation als YAML-Anker `x-logging` in allen fünf aktiven Compose-Dateien.**
  Wirkt unabhängig vom Daemon und ist beim Nachlesen sichtbar. Nachgemessen: 8 von 8
  Containern mit `max-size 10m` / `max-file 3`.
- **`security_opt: no-new-privileges` für alle acht Dienste.**
- **`homepage` auf `v1.13.2` gepinnt** (die laufende Version, **kein** Sprung auf
  v2.0.0), **`bichon` auf den Digest `sha256:5766707…`** — das Projekt vergibt keine
  Versions-Tags.
- **`BICHON_ENCRYPT_PASSWORD` nach `bichon/.env`** (Modus 660, über `.gitignore`
  ausgeschlossen), Wert **unverändert**. Der Klartextwert wurde per `git filter-repo`
  aus allen 22 Commits entfernt und das Repository force-gepusht. Ein Wechsel des
  Wertes hätte laut Herstellerdoku das 690-MB-Archiv unlesbar gemacht.
- **`cgroup_enable=memory cgroup_memory=1`** in `/boot/firmware/cmdline.txt` ergänzt,
  Neustart durchgeführt. Erst dadurch sind Speicher-Limits überhaupt durchsetzbar.
- **Backup erweitert** um `/mnt/usb-hdd/ntfy` und das Portainer-Volume,
  `/mnt/usb-hdd/filebrowser-data` entfernt. **`ReadWritePaths=/home/simon/.config/rclone`**
  in `pi-backup.service`, damit rclone sein erneuertes OneDrive-Token zurückschreiben
  kann. Testlauf: Exit 0 statt 1, Snapshot `36275ea4`.
- **Images von 18 auf 8 reduziert** (8,66 GB → 3,63 GB, Wurzeldateisystem
  14 GB → 7,7 GB). Gezielt entfernt statt `prune -a`.
- **Befristete Speichermessung** alle fünf Minuten nach
  `/mnt/usb-hdd/messungen/docker-speicher.csv` als Grundlage für spätere Limits.
- **Filebrowser-Reste weggeräumt:** `/mnt/usb-hdd/filebrowser-data` (44 KB) liegt jetzt
  unter `/mnt/usb-hdd/_to_delete/`.
- **`homepage/config/proxmox.yaml` ist wieder da** — Homepage legt die Vorlage beim
  Start selbst an. 104 Byte, nur Kommentare. Diesmal versioniert statt gelöscht, damit
  sie nicht bei jedem Neustart erneut als Änderung auftaucht.

### Geändert an der Dokumentation

- **[05 — Docker](docs/05-docker.md)** überarbeitet: neuer Abschnitt zur Logrotation
  mit dem Nachweis, warum `daemon.json` allein nichts bewirkte; neuer Abschnitt zur
  Speicherbuchführung; erste belastbare Speichermessung; Aufräumergebnis; Abschnitt
  zum Geheimnis im Repository. Die überholten Abschnitte zu Dashy und zum
  „Aufräumhinweis" sind entfallen.
- **[15 — Änderungshistorie](docs/15-aenderungshistorie.md)** um den Eintrag zur
  Docker-Durchsicht ergänzt, samt der bewusst **nicht** umgesetzten Punkte
  (`cap_drop`, Portbindung) mit Begründung.

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
  und `POSTGRES_PASSWORD` stehen auf unveränderten Beispielwerten, beides im
  Git-Repository. Aufgenommen in `docs/07-sicherheit.md`.
  *(Die Werte standen hier ursprünglich im Klartext und wurden am 20.08.2026
  maskiert — siehe Eintrag 2.4.0.)*
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
