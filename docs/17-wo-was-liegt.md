# 17 — Wo was liegt

*Erfasst: 18.08.2026 · Rechte nachgemessen und bereinigt: 14.09.2026*

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

### ✅ Behoben am 13.09.2026: Das Gruppenschreibrecht gilt jetzt überall

Die Aussage „Verzeichnisse `2775`" stimmte am 18.08.2026 und stimmte danach nicht mehr
durchgängig. **Der Befund und seine Behebung stehen im Betriebstagebuch**
([15](15-aenderungshistorie.md), Eintrag 13.09.2026), die Begründung zur `umask` in
[16 — Konten und Rechte](16-konten-und-rechte.md). Hier nur der Stand.

Gezählt über `find -type d` bzw. `-type f`, ohne `.git`, am 13.09.2026 **nach** der
Bereinigung:

| Modus, Besitzer | Anzahl | Wer kann darin anlegen |
|---|---|---|
| `2775 simon:pi-admin` | 24 | beide Konten |
| `2775 claude:pi-admin` | 8 | beide Konten |
| `2775 simon:simon` | 1 | nur `simon` |
| `2755 simon:simon` | 1 | `stacks/homepage/config/logs` — Container-Verzeichnis, bleibt bewusst |

Dateien: 67 × `664 simon:pi-admin`, 63 × `664 claude:pi-admin`, dazu ausführbare `775`.
**Ohne Gruppenschreibrecht bleiben nur noch sechs**, jede davon mit Grund: die drei `.env`
mit Modus 600, `stacks/n8n/.n8n-api-key` (640), das Logfile des Homepage-Containers und
`system/backup/pi-backup.sh` (offener Punkt 3.10). **Keine Datei gehört mehr `root`.**

> **Die Ursache lag nicht im Repository, sondern in der `umask`** beider Konten. setgid
> vererbt die Gruppe, nicht das Schreibrecht. Seit dem 13.09.2026 steht `umask 002` in
> beiden `.bashrc` — **vor** der Interaktiv-Sperre, weil die SSH-Automatisierung in einer
> nicht-interaktiven Shell läuft. Einzelheiten und der Nachweis in
> [16](16-konten-und-rechte.md).
>
> **Für neue Geheimnisse gilt damit ausdrücklich:** `chmod 600` von Hand, nicht der
> `umask` überlassen — unter `002` entstünde sonst eine `.env` mit 664.

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
| `stacks/n8n/workflows-einspielen.py` | den Workflows **in der n8n-Datenbank** (`/mnt/usb-hdd/n8n/database.sqlite`) | 14.09.2026 eingetragen. Das Skript erzeugt sie über die n8n-API. **Wer sie im n8n-Editor ändert, verliert die Änderung** beim nächsten Lauf des Skripts |
| `stacks/yt-werk/app/app.py` | dem **Image** `yt-werk:1.0.0` | 14.09.2026 eingetragen. Die Anwendung steckt im Image; eine Änderung wirkt erst nach `docker compose build` **und** einem neuen Tag — kein `:latest` |
| `stacks/stirling-pdf/docker-compose.yml`, Zeile `JAVA_BASE_OPTS` | den **JVM-Einstellungen des laufenden Dienstes** | 14.09.2026 eingetragen. **`JAVA_TOOL_OPTIONS` wäre hier wirkungslos** — das Startskript des Images überschreibt die Variable. Wer den Speicher ändern will, ändert `JAVA_BASE_OPTS` oder `mem_limit`, siehe [21](21-stirling-pdf.md) |
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
| `/mnt/usb-hdd/workbench-eingang/` | dort, `simon:pi-admin` **2770** | Ablagefach der Workbench: Rohmaterial und fertige Notizen auf dem Weg in den Vault. Warteschlange, kein Bestand — im restic-Backup, siehe [06](06-daten-und-speicher.md). Seit 14.09.2026 an diesem Ort, vorher unter `second-brain/eingang/` |
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
