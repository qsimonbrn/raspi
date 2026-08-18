# 16 — Konten, Rechte und Überwachung

*Erfasst: 18.08.2026*

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
`docker-stacks/sudoers/` zurückspielen.

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
| `raspi-doku/inventar/collect.sh` | 12 Aufrufe |
| `docker-stacks/pi_wartung.sh` | 4 Aufrufe |
| `docker-stacks/paperless/kategorisieren.py` | Aufrufhinweis im Kopf |
| `claude-skills` — beide SKILL.md, `backup-paperless.sh`, `pruefen.sh` | 27 Stellen, dazu ein Hinweis am Anfang beider Skills |
| `raspi-doku` — Beispielbefehle in sechs Kapiteln | 25 Stellen |

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
