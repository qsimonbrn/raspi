# 17 — Wo was liegt

*Erfasst: 18.08.2026 · Rechte nachgemessen: 13.09.2026*

Dieses Kapitel beantwortet eine Frage, die sich sonst über ein halbes Dutzend Kapitel
verteilt: **Welche Datei ist das Original, welche nur eine Kopie?** Wer das verwechselt,
ändert etwas, committet es, sieht es auf GitHub — und wundert sich, warum am System
nichts anders ist.

---

## Die zwei Repositories

| Repository auf GitHub | Auf dem Pi | Inhalt |
|---|---|---|
| `qsimonbrn/raspi` | `/home/simon/raspi` | Konfiguration **und** Dokumentation |
| `qsimonbrn/claude-skills` | `/mnt/usb-hdd/claude-skills` | Skills und MCP-Server |

Bis zum 18.08.2026 waren es drei: `docker-stacks` und `raspi-doku` sind an diesem Tag
zu `raspi` zusammengeführt worden, beide Verläufe vollständig erhalten. Der Grund war
kein Aufräumdrang, sondern ein wiederkehrender Fehler: Jede Systemänderung brauchte
zwei Commits in zwei Repositories, und zwischen den beiden Pushes konnte die
Dokumentation von der Realität abweichen. Genau das passierte am selben Tag — Kapitel
17 behauptete eine Stunde lang, es gebe kein Abgleich-Werkzeug, das bereits lief.
Jetzt trägt ein Commit beides.

`claude-skills` bleibt getrennt: Es wird von Claude Desktop gelesen, hat eine eigene
Lebensdauer, und ein fehlerhafter Commit darin nimmt der Automatisierung genau das
Werkzeug, mit dem sie den Fehler beheben müsste. Seit dem 18.08.2026 ist es
immerhin im Backup — vorher war es das nicht.

Beide pushen direkt vom Pi über einen SSH-Schlüssel, der am GitHub-Konto hinterlegt
ist. Der GitHub-Connector aus Claude darf in diese Repositories **nicht** schreiben
(403, nachgemessen) — er taugt zum Lesen und kann keine Repositories anlegen.

**Rechte.** Beide gehören `simon:pi-admin`, das setgid-Bit ist durchgängig gesetzt. Beide
Konten — `simon` und `claude` — sind in `pi-admin`. `.git` und `.git/objects` stehen auf
`2775 simon:pi-admin`; beide Konten können committen.

> **Nicht mit `chown` „aufräumen".** Wer die Dateien einem einzelnen Benutzer zuschlägt,
> nimmt dem anderen Konto das Schreibrecht auf Teile von `.git` — der Fehler lautet dann
> `insufficient permission for adding an object to repository database`. Entscheidend
> ist die **Gruppe** `pi-admin` samt Gruppenschreibrecht, nicht der Besitzer.

### ⚠️ Das Gruppenschreibrecht gilt nicht überall (nachgemessen 13.09.2026)

Die Aussage „Verzeichnisse `2775`" stimmte am 18.08.2026 und stimmt seither nicht mehr
durchgängig. Gezählt über `find -type d`, ohne `.git`:

| Modus, Besitzer | Anzahl | Wer kann darin anlegen |
|---|---|---|
| `2775 simon:pi-admin` | 24 | beide Konten |
| `2755 claude:pi-admin` | 8 | **nur `claude`** |
| `2775 simon:simon` | 1 | nur `simon` |
| `2755 simon:simon` | 1 | nur `simon` (`stacks/homepage/config/logs`) |

Die acht Verzeichnisse ohne Gruppenschreibrecht sind `stacks/diun`, `stacks/insta-triage`
(samt `app/`, `app/static/`), `stacks/yt-werk` (samt `app/`), `system/journald` und
`system/pihole` — durchweg Verzeichnisse, die das Konto `claude` angelegt hat.

**Negativkontrolle statt Vermutung:** `sudo -u simon touch stacks/yt-werk/.schreibtest`
scheitert mit `Permission denied`, während `touch stacks/paperless/.schreibtest` als
`claude` durchläuft. Die Sperre wirkt also **gegen `simon`**, nicht gegen `claude` — genau
umgekehrt zu der Annahme, die am 12.09.2026 zum `chmod g+w` auf `stacks/n8n/` geführt hat.
Dort lag der Fall andersherum: Das Verzeichnis hatte `simon` angelegt.

**Die Ursache ist in beiden Fällen dieselbe und liegt nicht im Repository, sondern in der
`umask`.** Beide Konten laufen mit `022` (`/etc/login.defs`, Zeile 151; für `claude` in der
Anmelde- *und* der interaktiven Shell nachgemessen). Jedes neu angelegte Verzeichnis
bekommt damit `755` plus das geerbte setgid-Bit — also `2755`, ohne Gruppenschreibrecht.
Wer das mit `chmod g+w` repariert, repariert den heutigen Bestand; das nächste `mkdir`
erzeugt denselben Fall erneut. Vorschlag und Preis in
[09 — Empfehlungen](09-empfehlungen.md), 3.11.

**Vier Dateien gehören `root`** (`inventar/snapshots/2026-09-07-00{22,40}-*`, Modus 644
`root:pi-admin`). Sie sind der sichtbare Rest genau dieses Musters: Wo das
Gruppenschreibrecht fehlt, weicht die Automatisierung auf `sudo` aus, und was danach
liegen bleibt, gehört `root`. Überschreiben kann sie keines der beiden Konten; ersetzen
schon, weil das umgebende Verzeichnis gruppenschreibbar ist.

---

## Zwei Sorten von Dateien

### Sorte A — das Repository ist das Original

Diese Dateien werden **direkt aus dem Repository** gelesen. Eine Änderung wirkt sofort
(bei Compose nach `sudo docker compose up -d`).

| Was | Wo |
|---|---|
| Alle `docker-compose.yml` | `stacks/<dienst>/` |
| Dashboard-Konfiguration | `stacks/homepage/config/` |
| ntfy-Serverkonfiguration | `stacks/ntfy/server.yml` |
| Skills und MCP-Server | `/mnt/usb-hdd/claude-skills/` |

### Sorte B — das Repository ist nur eine Kopie

Diese Dateien laufen von einem anderen Ort. Eine Änderung **nur** im Repository ist
wirkungslos. Der Grund ist banal: systemd startet nichts aus einem Home-Verzeichnis,
Docker liest ausschließlich `/etc/docker`, der Kernel ausschließlich `/boot`, `sudo`
ausschließlich `/etc/sudoers.d`.

| Im Repository | Läuft von hier | Stand 20.08.2026 |
|---|---|---|
| `backup/pi-backup.sh` | `/usr/local/bin/pi-backup.sh` | identisch |
| `backup/pi-backup.service` | `/etc/systemd/system/` | identisch |
| `backup/pi-backup.timer` | `/etc/systemd/system/` | identisch |
| `firewall/pi-guard.sh` | `/usr/local/sbin/pi-guard.sh` | identisch |
| `firewall/pi-guard.service` | `/etc/systemd/system/` | identisch |
| `messung/docker-stats-messung.sh` | `/usr/local/bin/` | identisch |
| `messung/docker-stats-messung.service` | `/etc/systemd/system/` | identisch |
| `messung/docker-stats-messung.timer` | `/etc/systemd/system/` | identisch |
| `updates/pi-reboot-check.sh` | `/usr/local/sbin/pi-reboot-check.sh` | identisch |
| `updates/pi-reboot-check.service` | `/etc/systemd/system/` | identisch |
| `updates/pi-reboot-check.timer` | `/etc/systemd/system/` | identisch |
| `updates/docker-daemon.json` | `/etc/docker/daemon.json` | identisch |
| `updates/cmdline.txt` | `/boot/firmware/cmdline.txt` | identisch |
| `updates/52unattended-upgrades-lokal` | `/etc/apt/apt.conf.d/` | identisch |
| `sudoers/010-claude` | `/etc/sudoers.d/010-claude` | identisch |
| `wartung/pi-wartung.sh` | `/usr/local/sbin/pi-wartung.sh` | identisch |
| `wartung/pi-aliase.sh` | `/etc/profile.d/pi-aliase.sh` | identisch |
| `abgleich/sync.sh` | `/usr/local/sbin/pi-abgleich.sh` | identisch |
| `abgleich/pi-abgleich.service` | `/etc/systemd/system/` | identisch |
| `abgleich/pi-abgleich.timer` | `/etc/systemd/system/` | identisch |
| `pihole/pi-gravity.sh` | `/usr/local/sbin/pi-gravity.sh` | identisch |
| `pihole/pi-gravity.service` | `/etc/systemd/system/` | identisch |
| `pihole/pi-gravity.timer` | `/etc/systemd/system/` | identisch |
| `pihole/cron.d-pihole` | `/etc/cron.d/pihole` | identisch |

**Drei Fallen stecken allein in dieser Tabelle:**

1. Die Skripte liegen teils in `/usr/local/bin`, teils in `/usr/local/sbin`. Welches wo,
   ist nicht zu erraten — man muss es nachsehen (`systemctl show <unit> -p ExecStart`).
2. Namen können auseinanderlaufen. `pi_wartung.sh` hieß installiert `pi-maintenance.sh` —
   ein Abgleich, der den Dateinamen fortschreibt, findet so ein Paar nicht und meldet
   fälschlich „fehlt". Am 18.08.2026 beidseitig auf `pi-wartung.sh` vereinheitlicht.
3. **`pihole/cron.d-pihole` gehört nicht uns.** Die Datei wird von Pi-hole selbst
   angelegt und bei jedem Core-Update neu geschrieben. Sie steht hier nicht, weil wir
   sie pflegen wollen, sondern damit der Abgleich **meldet**, wenn ein Update die
   Anpassung überschrieben hat. Bei allen anderen Zeilen der Tabelle ist eine
   Abweichung ein Versehen — bei dieser ist sie der erwartete Normalfall nach einem
   Pi-hole-Update. Was dann zu tun ist, steht in `system/pihole/README.md`.

---

## ✅ Behoben: `pi-maintenance.sh` war nicht nachgezogen

Der CHANGELOG-Eintrag 1.9.0 vom 18.08.2026 vermerkte, alle Docker-Aufrufe seien
systemweit auf `sudo docker` umgestellt worden, `pi_wartung.sh` ausdrücklich genannt.
Geändert war jedoch **nur die Kopie im Repository**. Aufgefallen ist das erst, als der
Abgleich zum ersten Mal lief — von Hand war es acht Monate lang niemandem aufgefallen.

Behoben am 18.08.2026: Das Skript wurde überarbeitet (siehe
[02 — Betriebssystem](02-betriebssystem.md)), beidseitig auf `pi-wartung.sh`
vereinheitlicht und installiert. Die alten Fassungen liegen unter
`/mnt/usb-hdd/_to_delete/`.

---

## Was bewusst **nicht** im Git liegt

| Was | Wo | Warum |
|---|---|---|
| `.env` von bichon, ntfy, paperless, n8n, vaultwarden | bei den Stacks, Modus 660 bzw. **600** (n8n, ntfy, vaultwarden) | Geheimnisse, über `.gitignore` ausgeschlossen. Stand 13.09.2026 |
| Nutzdaten | `/mnt/usb-hdd/{paperless,bichon,ntfy,n8n,vaultwarden,insta-triage,diun,second-brain}` | zu groß bzw. Geheimnisse, im restic-Backup — siehe [06](06-daten-und-speicher.md) |
| `/mnt/usb-hdd/messungen/` | dort | laufende Messwerte, keine Konfiguration |
| `/mnt/usb-hdd/backups-manuell/` | dort, Modus 600 | Rückfallebene vom 18.08.2026, **enthält `.env` im Klartext** |
| `/mnt/usb-hdd/_to_delete/` | dort | zum Löschen vorgemerkt |

---

## Der Abgleich prüft sich seit 18.08.2026 selbst

Die Tabelle oben ist nicht mehr nur Prosa: Sie steht maschinenlesbar in
`system/abgleich/manifest.tsv` — eine Zeile je Paar, mit Systempfad,
Besitzer, Rechten und dem, was nach dem Installieren zu tun ist (`daemon-reload`,
`visudo -c`, nichts). Alle Werte sind mit `stat` gemessen, nicht angenommen.

```bash
sudo pi-abgleich.sh list              # alle Paare mit Inhalts- und Rechtezustand
sudo pi-abgleich.sh check             # nur prüfen, Exit 1 bei Abweichung
sudo pi-abgleich.sh diff pi_wartung   # Unterschiede im Klartext
sudo pi-abgleich.sh install backup    # Repository -> System, zeigt diff und fragt
sudo pi-abgleich.sh pull   daemon     # System -> Repository, zeigt diff und fragt
```

`pi-abgleich.timer` läuft täglich um 09:15 und meldet über ntfy, **wenn** etwas
abweicht. Er ruft ausschließlich `check` auf und **kopiert unter keinen Umständen
von selbst.**

### Warum der Timer nicht automatisch kopiert

Ein Cronjob, der System → Repository kopiert und committet, kehrt die Beweisrichtung
um. Das Repository würde der Realität stumm hinterherlaufen — auch dann, wenn die
Realität kaputt ist. Ersetzt ein `apt`-Update eine Konfigurationsdatei, oder verstellt
sich jemand versehentlich etwas, wandert genau das als scheinbar gewollter Commit nach
GitHub. Damit ginge die eine Eigenschaft verloren, wegen der sich das Repository lohnt:
dass darin steht, was **entschieden** wurde, nicht was zufällig der Fall ist.

Deshalb meldet der Timer nur. Kopiert wird auf Ansage, mit vorherigem `diff`.

### Von Hand, falls das Werkzeug einmal ausfällt

```bash
sudo diff /home/simon/raspi/system/backup/pi-backup.sh /usr/local/bin/pi-backup.sh
sudo install -o root -g root -m 750 backup/pi-backup.sh /usr/local/bin/pi-backup.sh
sudo systemctl daemon-reload      # nur bei .service und .timer
```

`install` setzt Besitzer und Rechte in einem Schritt — `cp` vergisst sie.

---

## Reste, die noch herumliegen

| Datei | Größe | Anmerkung |
|---|---|---|
| `/usr/local/bin/pi-backup.sh.bak-20260818` | 7,2 KB | Sicherungskopie vor der Backup-Änderung |
| `/usr/local/sbin/pi-maintenance.sh.old` | 292 B | Vorgängerfassung |
| `/boot/firmware/cmdline.txt.bak-20260818` | — | Sicherungskopie vor dem Cgroup-Eintrag |

Alle drei sind bewusst stehen geblieben, bis die jeweiligen Änderungen sich bewährt
haben. Sie gehören beim nächsten Aufräumen weg — und sie sind ein Grund mehr, einen
Abgleich nicht stumpf über Dateinamen laufen zu lassen: `*.bak-*` und `*.old` dürfen
dabei nicht als Kandidaten gelten.
