# 08 — Bewertung

*Stand: 20.08.2026*

Eine ehrliche Einordnung des Gesamtzustands. Messwerte stehen in den Fachkapiteln; hier
geht es um die Einschätzung.

---

## Gesamteindruck

Das ist ein **überdurchschnittlich gut gebauter Heimserver**. Wer Pi-hole mit einem
eigenen unbound-Resolver kombiniert, Fernzugriff über ein VPN statt über Portfreigaben
löst und seine Compose-Dateien in Git versioniert, weiß, was er tut. Das sind drei
Entscheidungen, die in typischen Heimserver-Setups selten alle drei richtig getroffen
werden.

Das System läuft entsprechend: am 20.08.2026 zwei Tage Uptime seit dem geplanten
Neustart, Load 0,74, nie gedrosselt, kein fehlgeschlagener Dienst, ein ausstehendes
Paketupdate.

Die Schwächen lagen nicht im Aufbau, sondern in dem, was **nach** dem Aufbau kommt:
Backups, Updates, Aufräumen. Genau dort ist zwischen dem 13. und 20.08.2026 das meiste
geschlossen worden — Backup eingerichtet und als wiederherstellbar nachgewiesen,
Sicherheitsupdates automatisiert, Verwaltungsoberflächen aus dem Heimnetz genommen. Was
offen bleibt, steht unten und ist kürzer geworden.

---

## Was gut gelöst ist

### Architektur

- **Pi-hole + unbound.** DNS wird selbst rekursiv aufgelöst. Kein externer Resolver sieht
  das Surfprofil des Haushalts. Alle drei Pi-hole-Komponenten aktuell.
- **Tailscale statt Portfreigaben.** Gar kein eingehender Port, statt sechs offener
  Weboberflächen. Seit dem 18.08.2026; der Vorgänger WireGuard war am DS-Lite-Anschluss
  von außen nie erreichbar (siehe [04](04-dienste-system.md)).
- **unbound nur auf localhost.** Kein missbrauchbarer offener Resolver.
- **Verwaltungsoberflächen nicht im Heimnetz.** Seit 18.08.2026 sind Portainer, Bichon
  und Paperless nur noch über Tailscale erreichbar — nachgemessen an den Trefferzählern
  der Firewall. Siehe [07](07-sicherheit.md).
- **Automatisierung mit eigenem, aufgezeichnetem Konto.** Seit 18.08.2026 läuft sie als
  `claude` statt als `simon`; jede erhöhte Sitzung ist abspielbar. Siehe
  [16](16-konten-und-rechte.md).
- **Getrennte Docker-Netze pro Stack.** Dienste sind gegeneinander isoliert.
- **Keine privilegierten Container, kein `network_mode: host`.**

### Betrieb

- **Compose-Dateien in Git mit GitHub-Remote.** Der beste Einzelaspekt des Setups —
  Konfiguration ist nachvollziehbar und wiederherstellbar.
- **Sicherheitsupdates laufen selbsttätig.** Seit dem 18.08.2026 `unattended-upgrades`
  ohne automatischen Neustart. Am 20.08.2026 ein ausstehendes Paket, und zwar eines aus
  einem Fremd-Repository (Tailscale), das dieses Verfahren bauartbedingt nicht erfasst.
- **Backup nicht nur eingerichtet, sondern geprüft.** Am 20.08.2026 `restic check` über
  alle 10 Snapshots ohne Fehler und eine Stichprobe byte-identisch zurückgeholt. Der
  Unterschied zwischen „es wird gesichert" und „es lässt sich zurückholen" ist der
  einzige, der im Ernstfall zählt.
- **Sinnvolle Mount-Optionen.** `noatime` schont die SD-Karte, `nofail` verhindert
  Boot-Blockaden bei abgezogener SSD, `fstrim.timer` ist aktiv.
- **Nutzdaten auf der SSD, nicht auf der SD-Karte.**

### Hardware

- **Thermik und Stromversorgung unauffällig.** `throttled=0x0`, auch historisch nie
  gedrosselt; 48,7 °C am 20.08.2026 — Kühlung und Netzteil sind korrekt dimensioniert.
- **Reserven vorhanden, aber kleiner als gedacht.** 2,1 GiB RAM verfügbar im
  eingeschwungenen Zustand (20.08.2026), 560 GB freier SSD-Speicher. Die früher
  genannten 2,4 GiB stammten aus einer Messung sechs Minuten nach dem Neustart.

---

## Was fehlt

### 🔴 Kritisch

| Befund | Konsequenz | Kapitel |
|---|---|---|
| ~~**Keine automatisierten Backups** — letzter Lauf 12.12.2025~~ | ✅ **erledigt am 13.08.2026** — restic läuft täglich; am 20.08.2026 erstmals als wiederherstellbar nachgewiesen (`restic check` über 10 Snapshots ohne Fehler, Stichprobe byte-identisch) | [12](12-backup.md) |
| **Wurzeldateisystem auf SD-Karte von 02/2023** | Ausfall wahrscheinlich und ohne Vorwarnung, während eine SSD zu 64 % leer danebenliegt | [01](01-hardware.md) |

Diese beiden Punkte hingen zusammen und verstärkten sich: Der wahrscheinlichste
Ausfallpunkt ist die SD-Karte — und für genau diesen Fall gab es kein Backup. Seit dem
13.08.2026 gibt es eines, seit dem 20.08.2026 ist es geprüft. Der Ausfall der SD-Karte
bleibt wahrscheinlich, kostet aber keine Daten mehr, sondern einen Wiederaufbau nach
[Kapitel 11](11-disaster-recovery.md).

### 🟠 Wichtig

| Befund | Konsequenz | Kapitel |
|---|---|---|
| ~~Keine Firewall auf dem Host~~ | ✅ **erledigt am 18.08.2026** — `pi-guard` sperrt die Verwaltungsoberflächen gegen das Heimnetz, nachgemessen an den Trefferzählern | [07](07-sicherheit.md) |
| **SSH-Passwortanmeldung aktiv, kein `fail2ban`** | Unbegrenzte Brute-Force-Versuche möglich; `passwordauthentication yes` am 20.08.2026 erneut nachgemessen | [07](07-sicherheit.md) |
| ~~`filebrowser` wird eingestellt~~ | ✅ **erledigt am 18.08.2026 — abgeschaltet.** Zusätzlich kam CVE-2026-32759 ohne Patch hinzu. Nachfolger noch offen | [05](05-docker.md) |
| Öffentliche IPv6-Adresse ohne lokale Firewall | Eine Fehlkonfiguration in der FRITZ!Box legt alle Dienste offen | [03](03-netzwerk.md) |
| ~~Keine automatischen Sicherheitsupdates~~ | ✅ **erledigt am 18.08.2026** — `unattended-upgrades` ohne selbsttätigen Neustart. Bleibt: Fremd-Repositories wie Tailscale sind davon **nicht** erfasst | [02](02-betriebssystem.md) |

### 🟡 Aufräumen

| Befund | Kapitel |
|---|---|
| ~~Dashy-Konfiguration nicht persistent~~ | ✅ **erledigt am 18.08.2026 — Dienst abgeschaltet** | [05](05-docker.md) |
| `dhcpcd` und `NetworkManager` laufen parallel, stündliche Journal-Fehler | [02](02-betriebssystem.md) |
| Ungenutzte Dienste: `ModemManager`, `triggerhappy`, `wpa_supplicant` | [02](02-betriebssystem.md) |
| ~~1,18 GB verwaiste Docker-Images~~ | ✅ **erledigt am 18.08.2026** — 18 → 8 Images, 8,66 → 3,63 GB | [05](05-docker.md) |
| ~~Pfad-Drift beim Paperless-Stack~~ | ✅ **erledigt** | [05](05-docker.md) |
| Anonyme Docker-Volumes ohne klare Zuordnung | [05](05-docker.md) |
| ~~Verwaistes `filebrowser-data/`-Verzeichnis~~ | ✅ **erledigt am 18.08.2026** | [06](06-daten-und-speicher.md) |
| ~~Offene, nicht committete Änderungen im `raspi`-Repo~~ | ✅ **erledigt am 18.08.2026** | [05](05-docker.md) |
| `smartmontools` fehlt — keine SSD-Gesundheitsdaten | [01](01-hardware.md) |

---

## Die eine Zahl

Für einen vollständigen Wiederaufbau nach Totalausfall werden neun Dinge gebraucht.
**Acht davon sind gesichert** — seit Einrichtung des restic-Backups am 13.08.2026, um
ntfy und Portainer erweitert am 18.08.2026 und am 20.08.2026 als wiederherstellbar
nachgewiesen.

Nicht gesichert bleiben die 310 GB Nutzdaten auf der SSD; sie passen nicht in den
verfügbaren Cloud-Speicher.

Details in [11 — Notfallwiederherstellung](11-disaster-recovery.md).

---

## Einordnung

Die Sicherheitsbefunde sind real, aber keiner davon ist ein akuter Notfall — solange das
Heimnetz vertrauenswürdig bleibt und die FRITZ!Box korrekt konfiguriert ist. Sie sind
Vorsorge.

Die Backup-Lücke ist etwas anderes. Sie ist kein hypothetisches Risiko, sondern eine
Frage der Zeit: SD-Karten und SSDs fallen irgendwann aus, Dateien werden versehentlich
gelöscht, Updates gehen schief. Und die betroffenen Daten — eingescannte Dokumente, deren
Papieroriginale vermutlich nicht mehr existieren — sind genau die Art von Daten, bei
denen ein Verlust nicht durch erneutes Herunterladen zu beheben ist.

**Wenn von allen Empfehlungen in dieser Dokumentation nur eine umgesetzt wird, sollte es
das automatisierte Backup sein.**
