# 07 — Sicherheit

*Erfasst: 18.08.2026*

## Zusammenfassung

Die Architektur ist richtig gedacht: Fernzugriff läuft über Tailscale statt über
Portfreigaben, der rekursive DNS-Resolver ist auf localhost beschränkt, kein Container
läuft privilegiert, die Samba-Freigabe ist auf einen Benutzer begrenzt, und das
Betriebssystem ist vollständig gepatcht.

**Am 18.08.2026 wurde die erste Härtungsstufe umgesetzt.** Bis dahin schützte genau eine
Schicht — die FRITZ!Box. Seitdem gibt es dahinter eine zweite: Die
Verwaltungsoberflächen sind aus dem Heimnetz nicht mehr erreichbar, zwei verwundbare
Dienste wurden abgeschaltet, und die Automatisierung läuft unter einem eigenen,
aufgezeichneten Konto.

Das Bedrohungsmodell dieses Systems ist dabei ungewöhnlich, und das prägt die
Prioritäten: **Von außen ist der Pi kaum angreifbar** — der Anschluss läuft über DS-Lite
und hat nicht einmal eine eigene öffentliche IPv4-Adresse, es gibt keine Portfreigabe,
und Tailscale benötigt keinen eingehenden Port. In 30 Tagen gab es genau **einen**
fehlgeschlagenen Anmeldeversuch. Die Arbeit gehört deshalb ins Innere des Netzes, wo
**33 Geräte** stehen, von denen viele niemand patcht.

---

## 🟠 Firewall — teilweise umgesetzt

**Stand seit 18.08.2026:** Es gibt keine vollständige Firewall, aber eine gezielte
Zugriffsbegrenzung für die Dienste mit dem größten Schadenspotenzial.

### Warum kein `ufw`

Docker schreibt eigene iptables-Regeln, die `ufw` **umgehen**. Eine mit `ufw`
eingerichtete Sperre für Container-Ports sieht aus, als würde sie wirken, tut es aber
nicht — das ist eine der häufigsten Fehlannahmen bei Docker-Hosts. Der vom Hersteller
vorgesehene Einhängepunkt ist die Kette `DOCKER-USER`, die vor allen Docker-Regeln
ausgewertet wird.

### `pi-guard`

| | |
|---|---|
| Skript | `/usr/local/sbin/pi-guard.sh` |
| Dienst | `pi-guard.service`, startet nach `docker.service` |
| Versioniert unter | `system/firewall/` |
| Ketten | `PI-GUARD` in `DOCKER-USER` (weitergeleiteter Verkehr) und `PI-GUARD-IN` in `INPUT` (Verkehr, den der `userland-proxy` annimmt), jeweils für IPv4 und IPv6 |

Zwei Ketten sind nötig, weil ein Paket auf zwei Wegen zu einem Container gelangen kann:
per DNAT direkt (dann greift `FORWARD`) oder über den `userland-proxy` auf dem Host
(dann greift `INPUT`, vor allem bei IPv6). Nur eine der beiden zu belegen, ließe ein Loch
offen.

**Gesperrt aus dem Heimnetz:**

| Port | Dienst | Warum |
|---|---|---|
| 9000, 9443 | Portainer | Der Docker-Socket ist schreibend eingebunden — ein erratenes Passwort bedeutet vollständige Systemrechte |
| 15630 | Bichon | E-Mail-Archiv, Image acht Monate alt |
| 8000 | Paperless | Dokumentenarchiv |

**Bewusst offen gelassen:**

| Port | Dienst | Begründung |
|---|---|---|
| 22 | SSH | Rettungsanker, falls Tailscale ausfällt. Ohne ihn käme man nur noch mit Tastatur und Monitor an den Pi |
| 53 | Pi-hole DNS | Das ganze Haus hängt daran |
| 80, 443 | Pi-hole-Web | Vorerst im Heimnetz belassen, hat ein eigenes Passwort |
| 139, 445 | Samba | Dateizugriff im Heimnetz, eigene Anmeldung |
| 2586 | ntfy | Mit `auth-default-access: deny-all` abgesichert — unauthentifiziertes Veröffentlichen wird mit HTTP 403 abgewiesen, nachgemessen |
| 3000 | Homepage | Reines Linkverzeichnis, der Socket-Proxy dahinter ist streng lesend konfiguriert |

> **Wichtig zu verstehen:** Die gesperrten Dienste lauschen weiterhin auf `0.0.0.0` — in
> der Portliste sieht es deshalb unverändert aus. Die Sperre erfolgt in der Firewall,
> nicht durch die Bindung. `sudo /usr/local/sbin/pi-guard.sh status` zeigt die Regeln
> samt Trefferzählern.

**Nachgemessen am 18.08.2026:** 101 Pakete aus dem Heimnetz verworfen, 305 über Tailscale
durchgelassen. Die Regel wirkt nachweislich, nicht nur auf dem Papier.

### Was weiterhin fehlt

Eine vollständige Firewall mit `default deny incoming` für die übrigen Ports. Angesichts
dessen, dass die verbleibenden offenen Dienste entweder gebraucht werden (DNS, Samba,
SSH) oder geringes Schadenspotenzial haben (ntfy, Homepage), ist das kein dringender
Punkt mehr.

---

## 🟠 SSH-Passwortanmeldung ist aktiv

| Parameter | Aktuell | Empfohlen |
|---|---|---|
| `PasswordAuthentication` | **`yes`** | `no` |
| `PubkeyAuthentication` | `yes` | `yes` |
| `PermitRootLogin` | `without-password` | `prohibit-password` (gleichbedeutend) ✅ |
| `PermitEmptyPasswords` | `no` | `no` ✅ |
| Port | 22 | 22 (unkritisch) |

**Nachgemessen am 18.08.2026 über 60 Tage: 414 Schlüsselanmeldungen gegen 6 per
Passwort.** Kein Skript und kein Dienst meldet sich per Passwort an — die sechs Fälle
waren durchweg manuelle Anmeldungen. Die Passwortanmeldung ist damit ein Notausgang,
den praktisch niemand nutzt, aber zusätzliche Angriffsfläche für jeden im Heimnetz.

> **Am 18.08.2026 wurde diese Härtung eingerichtet und auf Wunsch wieder
> zurückgenommen** — sie soll gemeinsam und mit Vorlauf umgesetzt werden, nicht
> nebenbei. Die Konfiguration lag als `/etc/ssh/sshd_config.d/99-haertung.conf` vor und
> funktionierte nachweislich: Eine neue Verbindung nach dem Neuladen kam per Schlüssel
> zustande. Sie umfasste zusätzlich `PermitRootLogin no`, `AllowUsers simon`,
> `MaxAuthTries 3`, `LoginGraceTime 30`, `X11Forwarding no` und `LogLevel VERBOSE`.
>
> **Zu bedenken bei der Wiederaufnahme:** `AllowUsers` müsste jetzt `simon claude`
> lauten, sonst sperrt es das Automatisierungskonto aus.

**Vor der Umstellung prüfen:** Von *jedem* Gerät, das SSH-Zugang braucht, einmal
verbinden und sicherstellen, dass es ohne Passwortabfrage klappt. Danach:

```
PasswordAuthentication no
```

in `/etc/ssh/sshd_config.d/99-hardening.conf` (nicht direkt in der Hauptdatei — das
überlebt Paketupdates besser), dann `sudo systemctl reload ssh`.

**Sicherheitsnetz:** Die bestehende SSH-Sitzung geöffnet lassen und erst in einer
*zweiten* Sitzung testen, ob der Login noch klappt. Falls nicht, lässt sich die Änderung
über die noch offene Verbindung zurücknehmen.

---

## 🟠 Kein `fail2ban`

Es gibt keinerlei Begrenzung fehlgeschlagener Anmeldeversuche. In Kombination mit der
aktiven Passwortanmeldung bedeutet das: Ein Angreifer im LAN kann beliebig oft Passwörter
durchprobieren, ohne dass etwas passiert.

Zur Einordnung: In 30 Tagen gab es genau **einen** fehlgeschlagenen Anmeldeversuch. Das
ist kein Zufall, sondern die Folge davon, dass von außen niemand klopfen kann. Die
Dringlichkeit ist entsprechend gering — die Lücke bleibt trotzdem eine.

Wird `PasswordAuthentication` deaktiviert, sinkt die Dringlichkeit deutlich — sinnvoll
bleibt `fail2ban` trotzdem, unter anderem für Samba.

---

## 🟠 Öffentliche IPv6-Adresse ohne lokale Absicherung

Der Pi ist unter `2a02:8071:2c83:1440:…` global adressierbar. Details in
[03 — Netzwerk](03-netzwerk.md).

Die FRITZ!Box blockiert eingehende IPv6-Verbindungen in der Standardkonfiguration. Das
Risiko liegt in der Kombination: **einzige Schutzschicht** plus **alle Dienste auf
`[::]` gebunden**. Ein falsch gesetzter Haken genügt, damit Paperless, Portainer und
Filebrowser aus dem Internet erreichbar sind.

**Zu prüfen (manuell):**

1. FRITZ!Box → *Internet → Freigaben → Portfreigaben* → Gerät `raspberrypi`
2. Insbesondere: „Selbstständige Portfreigaben für dieses Gerät erlauben" — sollte
   **deaktiviert** sein
3. FRITZ!Box → *Internet → Freigaben → FRITZ!Box-Dienste* — prüfen, was nach außen offen ist

**Gegenprobe von außen:** Über das Mobilfunknetz (nicht über WLAN) versuchen, die
IPv6-Adresse des Pi auf Port 8000 oder 9000 zu erreichen. Keine Verbindung = korrekt
abgeschottet.

---

## 🟠 Schwache Standardpasswörter bei Paperless

In `stacks/paperless/docker-compose.yml` stehen unveränderte Beispielwerte:

| Variable | Wert |
|---|---|
| `PAPERLESS_ADMIN_PASSWORD` | `***ENTFERNT-20260820***` |
| `POSTGRES_PASSWORD` | `paperless` |

Paperless ist auf `0.0.0.0:8000` gebunden, also aus dem gesamten Heimnetz erreichbar.
`***ENTFERNT-20260820***` ist in jeder Standard-Wortliste enthalten.

Erschwerend: Die Datei liegt in einem **Git-Repository**. Es ist privat, aber Passwörter
gehören auch dort nicht hinein — sie landen dauerhaft in der Versionsgeschichte, wo sie
auch nach einer Änderung noch nachlesbar bleiben.

**Empfehlung:** Beide Werte in eine `.env`-Datei auslagern, diese über `.gitignore`
ausschließen und in der Compose-Datei nur noch referenzieren. Anschließend das
Paperless-Administratorpasswort in der Weboberfläche ändern — die Umgebungsvariable
wirkt nur bei der Ersteinrichtung. Beim PostgreSQL-Passwort ist zu beachten, dass die
Datenbank es beim ersten Start übernommen hat; eine Änderung erfordert `ALTER USER`
in der laufenden Datenbank.

---

## ✅ Automatische Sicherheitsupdates — eingerichtet am 18.08.2026

Bis dahin war `unattended-upgrades` **nicht installiert**. Der Timer `apt-daily-upgrade`
lief zwar, fand aber kein Programm, das etwas hätte installieren können. Das System war
trotzdem vollständig gepatcht — von Hand. Der Prozess funktionierte also, hatte aber
keine Rückfallebene für Wochen, in denen niemand dazu kommt.

| | |
|---|---|
| Paket | `unattended-upgrades` 2.9.1 |
| Umfang | ausschließlich Sicherheitsquellen (Debian-Security, Raspbian, Raspberry Pi Foundation) |
| Konfiguration | `/etc/apt/apt.conf.d/52unattended-upgrades-lokal` |
| Selbsttätiger Neustart | **nein** — bewusste Entscheidung |
| Meldung bei fälligem Neustart | über ntfy, täglich 08:30 (`pi-reboot-check.timer`) |

**Warum kein automatischer Neustart:** An diesem Gerät hängt der DNS des gesamten
Haushalts. Ein unbemerkt fehlgeschlagener Neustart um drei Uhr nachts bedeutet, dass
morgens im ganzen Haus nichts mehr geht. Stattdessen meldet sich der Pi und wartet auf
eine Entscheidung.

Die Meldung nennt die betroffenen Pakete und die bisherige Laufzeit und kommt höchstens
einmal pro Tag — eine Erinnerung, die dreimal täglich erscheint, wird nach einer Woche
ignoriert.

**Nachgemessen:** Ein vorgetäuschter fälliger Neustart löste die ntfy-Meldung
nachweislich aus; der Testzustand wurde anschließend entfernt.

---

## 🟡 Container-Images veraltet

Zwischen 8 und 17 Monate ohne Update. Ausführlich in [05 — Docker](05-docker.md),
inklusive der Begründung, warum ein pauschales Auto-Update hier die falsche Antwort wäre.

**Am 18.08.2026 entschärft:** Zwei der drei ungepinnten Dienste wurden abgeschaltet.

| Dienst | Entscheidung |
|---|---|
| `filebrowser` | **abgeschaltet.** Lief in Version 2.51.2 und ist von CVE-2026-32759 betroffen (Remote Code Execution über den TUS-Upload, kein Patch verfügbar). Das Projekt wird zum 01.09.2026 archiviert. Der Container hatte die gesamte SSD unter `/srv` eingebunden |
| `Dashy` | **abgeschaltet.** Durch Homepage abgelöst, Image neun Monate alt |
| `bichon` | läuft weiter, Image acht Monate alt. **Verbleibender Befund** — der Dienst verarbeitet E-Mails, also fremdgestaltete Inhalte, und ist damit die exponierteste Stelle. Seit dem 18.08.2026 immerhin nur noch über Tailscale erreichbar |

---

## 🟢 Samba: kleinere Härtungsmöglichkeiten

| Parameter | Aktuell | Vorschlag | Begründung |
|---|---|---|---|
| `map to guest` | `Bad User` | `Never` | Unbekannte Logins werden derzeit stillschweigend zu Gast-Zugriffen |
| `usershare allow guests` | `Yes` | `No` | Es gibt keine Gast-Freigabe, die das braucht |
| `server min protocol` | nicht gesetzt | `SMB3` | Schließt veraltetes SMB1/SMB2 aus |
| `[printers]`, `[print$]` | aktiv | entfernen | Werden nicht genutzt |

Die eigentliche Freigabe `[usb-share]` ist korrekt eng gefasst: `valid users = simon`,
kein Gastzugriff. Die Punkte oben sind Debian-Standardwerte, keine Fehler — aber
unnötige Fläche.

---

## Positiv hervorzuheben

| | Warum es zählt |
|---|---|
| **Tailscale statt Portfreigaben** | Gar kein eingehender Port. Ein Portscan von außen findet nichts, weil es nichts zu finden gibt. Der Preis ist die Abhängigkeit von Tailscales Vermittlung und vom GitHub-Konto. |
| **unbound nur auf `127.0.0.1`** | Ein offener rekursiver Resolver wäre für DNS-Amplification-Angriffe missbrauchbar. Korrekt vermieden. |
| **Kein `privileged`-Container** | Ein Ausbruch aus einem Container führt nicht direkt zu Root auf dem Host. |
| **Kein `network_mode: host`** | Container sind netzwerkseitig isoliert. |
| **Getrennte Docker-Netze je Stack** | Seitwärtsbewegung zwischen Diensten ist erschwert. |
| **`PermitRootLogin without-password`** | Root ist nur per Schlüssel erreichbar. |
| **OS vollständig gepatcht** | 0 ausstehende Updates. |
| **Verwaltungsoberflächen nicht im Heimnetz** | Seit 18.08.2026. Portainer, Bichon und Paperless sind nur noch über Tailscale erreichbar — nachgemessen an den Trefferzählern der Firewall. |
| **Automatisierung mit eigenem Konto** | Seit 18.08.2026 arbeitet die Automatisierung als `claude`, nicht mehr als `simon`. Jede erhöhte Sitzung wird vollständig aufgezeichnet und ist abspielbar. Siehe [16 — Konten und Rechte](16-konten-und-rechte.md). |
| **Docker-Socket-Proxy vorbildlich konfiguriert** | Nur `CONTAINERS` und `INFO` erlaubt, `POST` und `EXEC` ausdrücklich verboten, Socket nur lesend eingebunden. |
| **ntfy mit `deny-all`** | Unauthentifiziertes Veröffentlichen wird mit HTTP 403 abgewiesen, nachgemessen. |
| **Geheimnisse getrennt** | `.gitignore` greift, keine `.env` je committet, Dateirechte `600`. **Einschränkung:** Bis zum 18.08.2026 stand `BICHON_ENCRYPT_PASSWORD` im Klartext in `bichon/docker-compose.yml` und damit in allen 22 Commits. Behoben durch Auslagerung nach `.env` und `git filter-repo`, siehe [05](05-docker.md). |

---

## Priorisierte Maßnahmenliste

Stand 18.08.2026. Die Reihenfolge folgt der Wirkung pro Aufwand, nicht streng der
Kritikalität.

### Erledigt

| Maßnahme | Datum |
|---|---|
| Verwaltungsoberflächen aus dem Heimnetz nehmen (`pi-guard`) | 18.08.2026 |
| Filebrowser abschalten (CVE ohne Patch, Projekt wird archiviert) | 18.08.2026 |
| Dashy abschalten | 18.08.2026 |
| Automatisierungskonto mit Sitzungsaufzeichnung | 18.08.2026 |
| **`simon` aus der Gruppe `docker` entfernt** — die Gruppe ist jetzt leer | 18.08.2026 |
| **Automatische Sicherheitsupdates** (`unattended-upgrades`, ohne selbsttätigen Neustart, mit ntfy-Meldung) | 18.08.2026 |
| **Docker-Log-Rotation** — Eintrag in `daemon.json` war **wirkungslos** (`reload` übernimmt `log-opts` nicht), am selben Tag als YAML-Anker in alle Compose-Dateien übernommen, 8 von 8 Containern nachgemessen | 18.08.2026 |
| **`no-new-privileges` für alle acht Container** | 18.08.2026 |
| **`BICHON_ENCRYPT_PASSWORD` aus dem Git-Verlauf entfernt** (`git filter-repo`, Force-Push), Wert unverändert nach `.env` | 18.08.2026 |
| **Speicher-Cgroup aktiviert** (`cgroup_enable=memory`) — vorher waren `mem_limit`-Angaben wirkungslos | 18.08.2026 |
| Obsolete WireGuard-Schlüssel entfernt, darunter `/root/iphone.conf` mit privatem Schlüssel bei Modus 644 | 18.08.2026 |
| Fehlerhaften Pi-hole-Eintrag `applovin.com` aus der Listenverwaltung entfernt | 18.08.2026 |

### Offen

| # | Maßnahme | Aufwand | Wirkung | Anmerkung |
|---|---|---|---|---|
| 1 | `PasswordAuthentication no` | 10 min | hoch | **Wichtigster offener Punkt.** Vorbereitet und am 18.08.2026 erfolgreich getestet, auf Wunsch zurückgenommen — soll gemeinsam mit Vorlauf erfolgen. `AllowUsers` müsste **beide** Konten nennen (`simon claude`) |
| 4 | Alarmierung über ntfy | 1–2 h | hoch | Anmeldungen, sudo-Nutzung, Änderungen an `/etc/passwd` und `/etc/sudoers` |
| 5 | IPv6-Freigaben in der FRITZ!Box prüfen | 5 min | hoch | Manuell, nicht vom Pi aus feststellbar |
| 7 | `fail2ban` | 30 min | mittel | Dringlichkeit sinkt mit Punkt 2 |
| 8 | Bichon aktualisieren und pinnen | 30 min | mittel | Update-Pfad vorher prüfen |
| 9 | `auditd` mit gezielten Regeln | 1 h | mittel | Zugriffe auf Benutzerdatenbank, sudo-Regeln, SSH-Konfiguration |
| 10 | Protokolle ins Backup | 30 min | mittel | Ein Angreifer mit Systemrechten löscht als Erstes die Spuren |
| 11 | Samba härten | 15 min | niedrig | `map to guest`, Mindestprotokoll SMB3 |

> **Reihenfolge beachten:** Punkt 8 gehört *hinter* ein geprüftes Backup. Ein
> Container-Update ohne Rückfallebene ist selbst ein Risiko.

Das vollständige Sicherheitskonzept mit Bedrohungsmodell und Begründungen liegt im
Claude-Projekt unter `claude/sicherheitskonzept.md`.
