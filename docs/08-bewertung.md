# 08 — Bewertung

*Stand: 13.08.2026*

Eine ehrliche Einordnung des Gesamtzustands. Messwerte stehen in den Fachkapiteln; hier
geht es um die Einschätzung.

---

## Gesamteindruck

Das ist ein **überdurchschnittlich gut gebauter Heimserver**. Wer Pi-hole mit einem
eigenen unbound-Resolver kombiniert, Fernzugriff über WireGuard statt über Portfreigaben
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
- **WireGuard statt Portfreigaben.** Genau ein verschlüsselter Eingang von außen,
  statt sechs offener Weboberflächen.
- **unbound nur auf localhost.** Kein missbrauchbarer offener Resolver.
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
| Container-Images 8–17 Monate alt | Ungepatchte Sicherheitslücken, u. a. in Paperless und PostgreSQL | [05](05-docker.md) |
| Öffentliche IPv6-Adresse ohne lokale Firewall | Eine Fehlkonfiguration in der FRITZ!Box legt alle Dienste offen | [03](03-netzwerk.md) |
| Keine automatischen Sicherheitsupdates | Patch-Prozess hängt an einer einzelnen Person | [02](02-betriebssystem.md) |

### 🟡 Aufräumen

| Befund | Kapitel |
|---|---|
| Dashy-Konfiguration nicht persistent — geht bei jedem Update verloren | [05](05-docker.md) |
| `dhcpcd` und `NetworkManager` laufen parallel, stündliche Journal-Fehler | [02](02-betriebssystem.md) |
| Ungenutzte Dienste: `ModemManager`, `triggerhappy`, `wpa_supplicant` | [02](02-betriebssystem.md) |
| 1,18 GB verwaiste Docker-Images | [05](05-docker.md) |
| Pfad-Drift beim Paperless-Stack (Label zeigt auf gelöschtes Verzeichnis) | [05](05-docker.md) |
| Anonyme Docker-Volumes ohne klare Zuordnung | [05](05-docker.md) |
| Verwaistes `filebrowser.db/`-Verzeichnis | [06](06-daten-und-speicher.md) |
| Offene, nicht committete Änderungen im `docker-stacks`-Repo | [05](05-docker.md) |
| `smartmontools` fehlt — keine SSD-Gesundheitsdaten | [01](01-hardware.md) |

---

## Die eine Zahl

Für einen vollständigen Wiederaufbau nach Totalausfall werden sieben Dinge gebraucht.
**Eines davon ist gesichert** — die Compose-Dateien in GitHub.

Nicht gesichert: Paperless-Dokumente, Bichon-E-Mail-Archiv, Pi-hole-Konfiguration,
WireGuard-Schlüssel, Samba-Konfiguration, 310 GB Nutzdaten.

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
