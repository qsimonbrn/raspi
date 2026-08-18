# 08 — Bewertung

*Stand: 16.08.2026*

Eine ehrliche Einordnung des Gesamtzustands. Messwerte stehen in den Fachkapiteln; hier
geht es um die Einschätzung.

---

## Gesamteindruck

Das ist ein **überdurchschnittlich gut gebauter Heimserver**. Wer Pi-hole mit einem
eigenen unbound-Resolver kombiniert, Fernzugriff über ein VPN statt über Portfreigaben
löst und seine Compose-Dateien in Git versioniert, weiß, was er tut. Das sind drei
Entscheidungen, die in typischen Heimserver-Setups selten alle drei richtig getroffen
werden.

Das System läuft entsprechend: 16 Tage Uptime, Load 0,05, nie gedrosselt, kein
fehlgeschlagener Dienst, keine ausstehenden Paketupdates.

Die Schwächen liegen nicht im Aufbau, sondern in dem, was **nach** dem Aufbau kommt:
Backups, Updates, Aufräumen. Klassisches Muster — das Interessante ist das Bauen, nicht
das Betreiben.

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
- **Betriebssystem manuell, aber zuverlässig gepflegt.** 0 ausstehende Updates.
- **Sinnvolle Mount-Optionen.** `noatime` schont die SD-Karte, `nofail` verhindert
  Boot-Blockaden bei abgezogener SSD, `fstrim.timer` ist aktiv.
- **Nutzdaten auf der SSD, nicht auf der SD-Karte.**

### Hardware

- **Thermik und Stromversorgung unauffällig.** `throttled=0x0` über 16 Tage — Kühlung
  und Netzteil sind korrekt dimensioniert.
- **Reichlich Reserven.** 2,4 GiB RAM verfügbar, unter 6 % CPU, 560 GB freier
  SSD-Speicher.

---

## Was fehlt

### 🔴 Kritisch

| Befund | Konsequenz | Kapitel |
|---|---|---|
| **Keine automatisierten Backups** — letzter Lauf 12.12.2025 | Paperless-Dokumente, E-Mail-Archiv und 310 GB Nutzdaten sind bei Ausfall verloren | [06](06-daten-und-speicher.md) |
| **Wurzeldateisystem auf SD-Karte von 02/2023** | Ausfall wahrscheinlich und ohne Vorwarnung, während eine SSD zu 64 % leer danebenliegt | [01](01-hardware.md) |

Diese beiden Punkte hängen zusammen und verstärken sich: Der wahrscheinlichste
Ausfallpunkt ist die SD-Karte — und für genau diesen Fall gibt es kein Backup.

### 🟠 Wichtig

| Befund | Konsequenz | Kapitel |
|---|---|---|
| Keine Firewall auf dem Host | Nur eine Schutzschicht (FRITZ!Box), keine Tiefenverteidigung | [07](07-sicherheit.md) |
| SSH-Passwortanmeldung aktiv, kein `fail2ban` | Unbegrenzte Brute-Force-Versuche möglich | [07](07-sicherheit.md) |
| ~~`filebrowser` wird eingestellt~~ | ✅ **erledigt am 18.08.2026 — abgeschaltet.** Zusätzlich kam CVE-2026-32759 ohne Patch hinzu. Nachfolger noch offen | [05](05-docker.md) |
| Öffentliche IPv6-Adresse ohne lokale Firewall | Eine Fehlkonfiguration in der FRITZ!Box legt alle Dienste offen | [03](03-netzwerk.md) |
| Keine automatischen Sicherheitsupdates | Patch-Prozess hängt an einer einzelnen Person | [02](02-betriebssystem.md) |

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
| ~~Offene, nicht committete Änderungen im `docker-stacks`-Repo~~ | ✅ **erledigt am 18.08.2026** | [05](05-docker.md) |
| `smartmontools` fehlt — keine SSD-Gesundheitsdaten | [01](01-hardware.md) |

---

## Die eine Zahl

Für einen vollständigen Wiederaufbau nach Totalausfall werden sieben Dinge gebraucht.
**Sechs davon sind gesichert** — seit Einrichtung des restic-Backups am 13.08.2026.

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
