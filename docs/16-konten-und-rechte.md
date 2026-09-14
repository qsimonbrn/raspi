# 16 — Konten, Rechte und Überwachung

*Erfasst: 18.08.2026 · Rechte und `umask` nachgemessen: 14.09.2026*

Wer darf auf diesem Pi was, und wie ist nachvollziehbar, wer was getan hat. Dieses
Kapitel ist der Einstiegspunkt, wenn ein Zugang eingerichtet, geprüft oder entzogen
werden soll.

---

## Die Befehle, die man im Ernstfall braucht

Vorneweg, damit man nicht suchen muss:

```bash
# Was hat das Automatisierungskonto getan?
sudo sudoreplay -l

# Eine einzelne Sitzung ansehen (Kennung aus der Liste oben)
sudo sudoreplay claude/00/00/04

# Nur die Befehle, ohne Sitzungsinhalt
sudo tail -50 /var/log/sudo-claude.log

# Wer hat sich per SSH angemeldet, womit, von wo?
sudo journalctl -u ssh --since '-7 days' | grep 'Accepted'

# Fehlgeschlagene Anmeldeversuche
sudo journalctl -u ssh --since '-7 days' | grep -E 'Failed|Invalid'
```

### Notausschalter

Entzieht dem Automatisierungskonto **sofort** jeden Zugang, ohne das eigene Konto zu
berühren:

```bash
sudo usermod -L claude                    # Konto sperren
sudo rm /etc/sudoers.d/010-claude         # erhöhte Rechte entziehen
```

Rückgängig: `sudo usermod -U claude` und die Datei aus dem Repository
`system/sudoers/` zurückspielen.

Härtere Variante, falls der Verdacht besteht, dass der Schlüssel abhandengekommen ist:

```bash
sudo mv /home/claude/.ssh/authorized_keys /home/claude/.ssh/authorized_keys.gesperrt
```

Damit ist auch die Anmeldung selbst unmöglich, nicht nur die Rechteausweitung.

---

## Konten auf dem System

| Konto | UID | Zweck | Anmeldung | Rechte |
|---|---|---|---|---|
| `simon` | 1000 | Persönliches Konto | Schlüssel **und** Passwort | `NOPASSWD: ALL` |
| `claude` | 1001 | Automatisierung über den MCP-Server | **nur** Schlüssel, kein Passwort | `NOPASSWD: ALL` **mit Sitzungsaufzeichnung**, *nicht* in Gruppe `docker` |
| `root` | 0 | — | kein SSH-Zugang in der Praxis | — |

### Gruppe `pi-admin`

Enthält `simon` und `claude`. Beide Repositories gehören dieser Gruppe mit gesetztem
setgid-Bit (`2775`), damit neu angelegte Dateien die Gruppe erben und beide Konten
gleichberechtigt arbeiten können.

#### Das setgid-Bit allein genügt nicht — die `umask` gehört dazu (13.09.2026)

**setgid vererbt die Gruppe, nicht das Schreibrecht.** Bis zum 13.09.2026 liefen beide
Konten mit `umask 022`. Jedes neu angelegte Verzeichnis wurde damit `2755`: Gruppe
`pi-admin` korrekt geerbt, aber ohne `w`. Wer das Verzeichnis angelegt hatte, konnte
darin arbeiten — das jeweils **andere** Konto nicht.

Der Fehler fällt selten sofort auf, weil er sich als etwas anderes tarnt: Die
Automatisierung weicht auf `sudo` aus, das funktioniert, und zurück bleiben Dateien, die
`root` gehören. Vier solche Dateien lagen am 13.09.2026 unter `inventar/snapshots/`.

| Gemessen am 13.09.2026, vorher | nachher |
|---|---|
| 8 Verzeichnisse `2755 claude:pi-admin` — `simon` ausgesperrt | 0 |
| 1 Verzeichnis `2755 simon:pi-admin` (am 12.09. von Hand repariert) | — |
| 60 Dateien `644 claude:pi-admin` | 0 |
| 4 Dateien `root:pi-admin` | 0 |

**Behoben in zwei Teilen.** Der Bestand mit `chmod g+w` (Verzeichnisse und Dateien der
Gruppe `pi-admin`, **Geheimnisse ausdrücklich ausgenommen**), die Ursache mit `umask 002`
in `/home/claude/.bashrc` und `/home/simon/.bashrc`.

> **Die Zeile steht dort ganz oben, vor der `If not running interactively`-Sperre, und
> das ist kein Schönheitsfehler.** Die SSH-Automatisierung läuft in einer
> nicht-interaktiven Shell. Die liest `.bashrc` zwar — Debians bash tut das für
> SSH-Verbindungen —, kehrt an der Sperre aber sofort zurück. Eine `umask`-Zeile weiter
> unten wäre für genau den Fall wirkungslos, um den es geht. **Nachgemessen**, nicht
> angenommen: Eine Probezeile `umask 0077` am Dateianfang schlug in der
> Automatisierungs-Shell durch, dieselbe Zeile hinter der Sperre nicht.
>
> `/etc/login.defs` hilft hier nicht: `UMASK 022` steht dort zwar, aber **`pam_umask` ist
> in keiner Datei unter `/etc/pam.d/` eingebunden** (13.09.2026 geprüft). Der Wert wirkt
> deshalb nur für `login` und `su`, nicht für eine SSH-Sitzung.
>
> `.profile` hilft ebenfalls nicht — sie wird nur von Login-Shells gelesen.

**Was `umask 002` kostet.** Neue Dateien werden `664` statt `644`, Verzeichnisse `2775`.
Außerhalb der Repositories betrifft das nur die eigene Primärgruppe jedes Kontos
(`simon:simon`, `claude:claude`) und damit niemanden sonst. **Innerhalb** der
Repositories ist die Gruppe `pi-admin`, und genau das ist gewollt.

> **Die Ausnahme, die man nicht vergessen darf: Geheimnisse.** Eine unter `umask 002` neu
> angelegte `.env` bekäme `664` und wäre für `pi-admin` **schreibbar**. Geheimnisse
> deshalb immer ausdrücklich setzen, nie der `umask` überlassen:
> `chmod 600` nach dem Anlegen, Gegenprobe `git check-ignore -v stacks/<name>/.env`.
> Beim Aufräumen am 13.09.2026 waren `stacks/*/.env` und `stacks/n8n/.n8n-api-key`
> ausdrücklich vom `chmod g+w` ausgenommen; ein pauschales `chmod -R g+w` hätte sie von
> 600 bzw. 640 auf 660 gezogen und damit das Gegenteil bewirkt.

**Zwei Dinge bleiben bewusst stehen:**

| Was | Warum |
|---|---|
| `stacks/homepage/config/logs/` (`2755 simon:simon`) | Wird vom Homepage-Container geschrieben, nicht von einem der beiden Konten. Über `.gitignore` ausgeschlossen. Gruppe `pi-admin` bringt hier nichts |
| `system/backup/pi-backup.sh` (`755 simon:simon`) | Ungeklärte Ausnahme, siehe [09 — Empfehlungen](09-empfehlungen.md), 3.10 |

> **Richtigstellung vom 14.09.2026: Es sind nicht zwei Ausnahmen, es sind dreizehn.**
> Beim Ergänzen der Homepage-Kacheln für die neuen Dienste scheiterte `claude` an
> `stacks/homepage/config/services.yaml` mit `Permission denied`. Gemessen: Die Datei
> gehört `simon:simon` mit Modus 664 — Gruppe `simon`, und `claude` ist in `claude` und
> `pi-admin`, nicht in `simon`.
>
> Anschließend gezählt: **13** Objekte im Repository tragen die Gruppe `simon`, **814**
> die Gruppe `pi-admin`. Die Reparatur vom 13.09.2026 hat sie nicht erfasst, weil sie
> ausdrücklich nur Objekte der Gruppe `pi-admin` anfasste — der Bestand wurde über
> `chmod g+w` auf genau diese Gruppe gesetzt.
>
> **Die Lehre ist dieselbe wie am 13.09., nur eine Ebene höher:** Damals hat eine
> Reparatur die Rechte berichtigt und die Gruppe unangetastet gelassen; die Prüfung
> danach maß Schreibrechte, nicht Gruppenzugehörigkeit, und konnte den Rest deshalb nicht
> finden. **Eine Reparatur, die nach ihrem eigenen Kriterium auswählt, prüft sich selbst
> nicht.**
>
> Behelf bis zur Entscheidung: `sudo -u simon` — dabei bleibt der Eigentümer erhalten.
> Der Punkt steht in [09](09-empfehlungen.md), 3.10.

### Die `.env` der neuen Stacks (14.09.2026)

`stacks/snapotter/.env` und `stacks/stirling-pdf/.env` wurden beim Anlegen ausdrücklich
auf **600** gesetzt und über `git check-ignore -v` gegengeprüft — beide greifen an
Zeile 7 der `.gitignore`. Das ist seit `umask 002` kein Selbstläufer mehr: Ohne das
`chmod` wäre eine neu angelegte `.env` mit **664** entstanden und für `pi-admin`
schreibbar.

Die Passwörter darin wurden auf dem Pi mit `openssl rand` erzeugt und **nie durch den
Chat gereicht**. Vor dem Commit wurde gegengeprüft, dass keiner der vier Werte im
Commit-Inhalt vorkommt.

**Nachweis am 13.09.2026, in beide Richtungen und mit Negativkontrolle:**
`umask` in der Automatisierungs-Shell `0002` · `claude` legt ein Verzeichnis an → `2775` ·
`simon` ebenso → `2775` · `claude` legt in `stacks/paperless/` an und ändert `docs/05` ·
`simon` legt in `stacks/yt-werk/` an und ändert `stacks/yt-werk/app/app.py` ·
**Negativkontrolle: `claude` kann `stacks/n8n/.env` weiterhin nicht lesen.**

`/home/simon` steht auf `710` mit Gruppe `pi-admin`: `claude` darf das Verzeichnis
**durchqueren**, um an die Repositories zu kommen, es aber **nicht auflisten**. Der
Rest des persönlichen Home-Verzeichnisses bleibt damit verborgen.

---

## Das Automatisierungskonto `claude`

Eingerichtet am 18.08.2026. Bis dahin arbeitete die Automatisierung unter `simon` —
damit war in keinem Protokoll unterscheidbar, ob eine Aktion von Hand oder automatisiert
erfolgte.

| | |
|---|---|
| Anmeldung | ED25519-Schlüssel, privater Teil ausschließlich auf dem Mac |
| Herkunftsbindung | `from="192.168.178.0/24,100.64.0.0/10,fd7a:115c:a1e0::/48"` — der Schlüssel funktioniert nur aus dem Heimnetz und dem Tailnet |
| Weiterleitungen | `restrict` — keine Port-, Agent- oder X11-Weiterleitung; `pty` gezielt erlaubt, weil sudo eine Terminalsitzung braucht |
| Passwort | keines, Konto gesperrt (`passwd -S` meldet `L`) |
| sudo | volle Rechte, **jede Sitzung wird aufgezeichnet** |
| GitHub | eigener Schlüssel am Konto `qsimonbrn`, Git-Identität „Claude (Raspberry Pi)" |

### Warum volle sudo-Rechte, und kein Katalog erlaubter Befehle?

Das ist eine bewusste Entscheidung, keine Nachlässigkeit.

Für Systemadministration gibt es keine sinnvolle Befehlsliste, die nicht zugleich die
Arbeit unmöglich macht. Wer `tee` darf, kann jede Datei überschreiben — auch
`/etc/sudoers`. Wer `systemctl` darf, kann einen Dienst anlegen, der als `root` startet.
Wer `docker` darf, kann einen Container mit eingebundenem Wurzeldateisystem starten. Eine
Liste mit diesen Einträgen sieht streng aus und ist es nicht.

Der Schutz liegt deshalb an drei anderen Stellen:

| Prinzip | Umsetzung |
|---|---|
| **Zurechenbarkeit** | Getrenntes Konto — in Protokollen und Git-Historie ist erkennbar, wer gehandelt hat |
| **Aufzeichnung** | Jede erhöhte Sitzung wird vollständig mitgeschnitten und ist abspielbar |
| **Widerrufbarkeit** | Zwei Befehle entziehen den Zugang, ohne das eigene Konto zu berühren |

**Geplant:** Nach zwei bis vier Wochen Betrieb wird aus den Aufzeichnungen abgeleitet,
welche Befehle tatsächlich gebraucht werden. Daraus lässt sich eine belastbare
Befehlsliste bauen — beruhend auf Messung statt auf Vermutung. Dasselbe Vorgehen nutzt
man bei AppArmor-Profilen: erst beobachten, dann einschränken.

### Sitzungsaufzeichnung

| | |
|---|---|
| Konfiguration | `/etc/sudoers.d/010-claude` |
| Ablage | `/var/log/sudo-io/claude/`, Modus `700`, nur für root lesbar |
| Umfang | Ein- und Ausgabe vollständig (`log_input`, `log_output`) |
| Obergrenze | 2000 Sitzungen, danach wird die älteste überschrieben |
| Zusätzliches Protokoll | `/var/log/sudo-claude.log` |

> **Zu beachten:** Die Aufzeichnung schneidet auch Ausgaben mit. Gibt ein Befehl
> versehentlich ein Passwort aus, landet es in diesem Protokoll. Die Verzeichnisse sind
> nur für root lesbar, und die Obergrenze von 2000 Sitzungen begrenzt den Zeitraum —
> beseitigt das Risiko aber nicht. Bei der Arbeit mit Geheimnissen ist Sorgfalt geboten.

---

## Die Gruppe `docker` ist leer

Am 18.08.2026 wurde `simon` aus der Gruppe entfernt — seitdem ist **niemand** mehr darin.

Die Mitgliedschaft war ein Generalschlüssel: Wer Docker steuern darf, startet einen
Container mit eingebundenem Wurzeldateisystem und ist damit `root` — ohne sudo, ohne
Passwort, ohne Protokolleintrag. Solange sie bestand, wäre jede Verschärfung der
sudo-Regeln Fassade gewesen.

Beide Konten greifen jetzt über `sudo` auf Docker zu. Der spürbare Unterschied im Alltag
ist ein vorangestelltes `sudo`; der Gewinn ist, dass jeder Docker-Befehl im Protokoll
erscheint.

**Nicht betroffen:** `pi-backup.sh` läuft über systemd als `root` und braucht kein sudo.

---

## Folgen für Skripte

Weil `claude` **nicht** in der Gruppe `docker` ist, laufen Docker-Befehle über `sudo` —
und werden dadurch protokolliert. Das ist der gewünschte Effekt, hat aber eine
Nebenwirkung:

**Skripte, die `docker` ohne `sudo` aufrufen, scheitern unter diesem Konto.**

Aufgefallen ist das direkt bei der Umstellung: `inventar/collect.sh` lieferte eine
unvollständige Bestandsaufnahme (374 statt 650 Zeilen, leere Container-Tabellen), weil
zehn Docker-Aufrufe an `permission denied` scheiterten. Das Skript ist seitdem auf
`sudo docker` umgestellt.

Bei neuen Skripten deshalb immer `sudo docker` schreiben — das funktioniert unter beiden
Konten und auch als `root`.

**Am 18.08.2026 durchgängig umgestellt:**

| Ort | Betroffen |
|---|---|
| `inventar/collect.sh` | 12 Aufrufe |
| `raspi/pi_wartung.sh` | 4 Aufrufe |
| `stacks/paperless/kategorisieren.py` | Aufrufhinweis im Kopf |
| `claude-skills` — beide SKILL.md, `backup-paperless.sh`, `pruefen.sh` | 27 Stellen, dazu ein Hinweis am Anfang beider Skills |
| `raspi` — Beispielbefehle in sechs Kapiteln | 25 Stellen |

Geprüft mit einem negativen Lookbehind (`grep -P '(?<!sudo )docker …'`), damit
`sudo docker` nicht mitgezählt wird — eine erste, naivere Zählung hatte genau diesen
Fehler gemacht und ein falsches Bild ergeben.

---

## GitHub-Zugang

| | |
|---|---|
| Verfahren | SSH-Schlüssel am Konto `qsimonbrn` |
| Schlüssel | `/home/claude/.ssh/github` |
| Geltung | alle Repositories des Kontos, auch künftige |
| Git-Identität | `Claude (Raspberry Pi) <claude@raspberrypi.local>` |

Der Schlüssel von `simon` (`~/.ssh/id_ed25519_github`) bleibt unverändert. Jedes Konto
nutzt über seine eigene `~/.ssh/config` automatisch den passenden Schlüssel; die
Repository-Adressen mussten deshalb nicht angepasst werden.

### Bewusst in Kauf genommen

Ein Schlüssel am Benutzerkonto hat dieselben Git-Rechte wie das Konto selbst: Er kann in
**allen** Repositories schreiben, Branches löschen und Force-Push ausführen. Er läuft
nicht ab.

**Alternative für später — Fine-grained Personal Access Token.** Ein Token mit der
Einstellung „All repositories" gilt ebenfalls für alle bestehenden und künftigen
Repositories, lässt sich aber auf die Berechtigung `Contents: Read and write` begrenzen.
Damit könnte das Konto weiterhin pushen, aber **keine Repositories löschen, keine
Einstellungen ändern, keine Actions ausführen und keine Mitarbeiter hinzufügen**. Dazu
kommt ein Ablaufdatum und die Möglichkeit, den Token einzeln zu widerrufen.

Bewusst zurückgestellt am 18.08.2026 zugunsten der Einfachheit. Der Umstieg ist jederzeit
ohne Datenverlust möglich — es ändern sich nur die Repository-Adressen von `git@github.com:`
auf `https://github.com/` und die Ablage des Tokens.

---

## Offene Punkte

| Punkt | Wirkung |
|---|---|
| SSH-Passwortanmeldung für `simon` aktiv | 414 Schlüsselanmeldungen gegen 6 per Passwort in 60 Tagen — der Notausgang wird praktisch nicht genutzt |
| `/home/claude/.ssh` nicht im Backup | Die Schlüssel des Automatisierungskontos und `/etc/sudoers.d/010-claude` fehlen in der Sicherung. Verkraftbar (neu erzeugbar), aber vermeidbar |
| Befehlsliste aus Aufzeichnungen ableiten | Frühestens Anfang September 2026, wenn genug Betriebsdaten vorliegen |
| Umstieg auf Fine-grained Token | Siehe oben, zeitlich offen |
