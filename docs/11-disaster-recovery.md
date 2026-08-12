# 11 — Notfallwiederherstellung

*Stand: 13.08.2026*

Was passiert, wenn der Pi morgen nicht mehr startet?

---

## Bestandsaufnahme: Was für einen Wiederaufbau gebraucht wird

| # | Baustein | Gesichert? | Wo liegt es? |
|---|---|---|---|
| 1 | **Compose-Dateien** aller Stacks | ✅ **ja** | GitHub: `qsimonbrn/docker-stacks` |
| 2 | **Paperless-Dokumente + Datenbank** | ❌ nein | nur `/mnt/usb-hdd/paperless/` |
| 3 | **Bichon-E-Mail-Archiv** | ❌ nein | nur `/mnt/usb-hdd/bichon/` |
| 4 | **Pi-hole-Konfiguration** (Blocklisten, lokale DNS-Einträge, Anpassungen) | ❌ nein | nur `/etc/pihole/` |
| 5 | **WireGuard-Schlüssel und Peer-Konfiguration** | ❌ nein | nur `/etc/wireguard/` |
| 6 | **Samba-Konfiguration und Passwortdatenbank** | ❌ nein | nur `/etc/samba/` |
| 7 | **Nutzdaten auf der SSD** (310 GB) | ⚠️ veraltet | Teilstand vom 12.12.2025 in OneDrive/Dropbox |

**Eins von sieben.**

---

## Was das im Einzelfall bedeutet

### Szenario A — SD-Karte fällt aus, SSD intakt

Der wahrscheinlichste Fall (siehe [01 — Hardware](01-hardware.md)).

| | |
|---|---|
| Verloren | Betriebssystem, alle Konfigurationen unter `/etc`, Docker-Metadaten |
| Erhalten | Alle Nutzdaten auf der SSD |
| Aufwand | 1–2 Tage |

**Was neu aufgebaut werden muss:** Betriebssystem, Pi-hole samt Blocklisten und lokalen
DNS-Einträgen, unbound, Samba mit Freigaben und Benutzern, WireGuard **inklusive
Neueinrichtung jedes Client-Geräts**, Docker, alle Container.

Die Compose-Dateien kommen aus GitHub — das ist der Teil, der funktioniert. Alles unter
`/etc` muss aus dem Gedächtnis rekonstruiert werden.

**Der unangenehmste Punkt:** Die WireGuard-Schlüssel. Ohne sie muss der Tunnel komplett
neu aufgesetzt werden, und jedes Client-Gerät braucht eine neue Konfiguration. Die
Dateien sind zusammen wenige Kilobyte groß.

### Szenario B — SSD fällt aus, System intakt

| | |
|---|---|
| Verloren | **Alle Nutzdaten**: Paperless-Archiv, E-Mail-Archiv, 310 GB Dateien |
| Erhalten | Betriebssystem, alle Konfigurationen, Container laufen (ohne Daten) |
| Aufwand | Wiederherstellung nicht möglich — Stand vom Dezember 2025 in Teilen vorhanden |

Der schlimmere Fall, obwohl er weniger dramatisch klingt. Ein Betriebssystem lässt sich
neu aufsetzen. Eingescannte Dokumente, deren Papieroriginale entsorgt wurden, nicht.

### Szenario C — Beides weg (Diebstahl, Blitzschlag, Wasser)

| | |
|---|---|
| Erhalten | ausschließlich die Compose-Dateien in GitHub |
| Aufwand | vollständiger Neuaufbau, Daten unwiederbringlich |

---

## Was sich mit geringem Aufwand ändern lässt

Die Punkte 4, 5 und 6 der Tabelle oben — Pi-hole, WireGuard, Samba — sind **zusammen
wenige Megabyte**. Sie fehlen nicht aus technischen Gründen, sondern weil bisher niemand
einen Job dafür eingerichtet hat.

Ein wöchentlicher Job dieser Art würde Szenario A von „1–2 Tage Rekonstruktion aus dem
Gedächtnis" auf „ein paar Stunden" verkürzen:

| Quelle | Inhalt |
|---|---|
| `/etc/wireguard/` | Server- und Peer-Schlüssel |
| `/etc/samba/smb.conf` + Samba-Passwortdatenbank | Freigaben und Benutzer |
| Pi-hole-Teleporter-Export | Blocklisten, lokale DNS-Einträge, Anpassungen |
| `/etc/fstab`, `/etc/ssh/sshd_config*` | Mounts und SSH-Konfiguration |
| Liste installierter Pakete (`apt-mark showmanual`) | Für den Wiederaufbau |

Punkt 2 und 3 — Paperless und Bichon — sind der Kern von Stufe 1 in
[09 — Empfehlungen](09-empfehlungen.md).

---

## Wiederaufbau-Reihenfolge (für den Ernstfall)

1. Raspberry Pi OS Lite 64-bit installieren, SSH aktivieren, Schlüssel hinterlegen
2. Statische IP `192.168.178.80` setzen — **wichtig**, weil die FRITZ!Box diese Adresse
   als DNS-Server verteilt
3. Docker installieren
4. `docker-stacks` aus GitHub klonen
5. SSD einbinden (`/etc/fstab` mit `nofail`)
6. Nutzdaten aus dem Backup zurückspielen — **vor** dem Start der Container
7. Container starten, Stack für Stack, mit Prüfung dazwischen
8. Pi-hole und unbound aufsetzen, Konfiguration importieren
9. WireGuard-Schlüssel zurückspielen, Tunnel testen
10. Samba einrichten, Freigabe prüfen
11. **Backup-Job als Erstes wieder einrichten** — nicht als Letztes

> **Zu Schritt 2:** Solange der Pi nicht läuft, funktioniert im Haushalt keine
> Namensauflösung. Für die Dauer des Wiederaufbaus sollte in der FRITZ!Box
> übergangsweise ein anderer DNS-Server eingetragen werden — sonst arbeitet man ohne
> Internet.

---

## Prüffragen

Eine Wiederherstellungsstrategie ist so gut wie die Antworten auf diese Fragen:

- [ ] Wenn die SD-Karte heute ausfällt — wie lange dauert es, bis Pi-hole wieder DNS macht?
- [ ] Wurde jemals ein Backup zurückgespielt, oder wird angenommen, dass es funktioniert?
- [ ] Sind die WireGuard-Schlüssel irgendwo außerhalb des Pi vorhanden?
- [ ] Ist das Bichon-Master-Passwort im Passwortmanager? (Es ist nachträglich nicht änderbar.)
- [ ] Existiert eine Liste der Paperless-Zugangsdaten und der PostgreSQL-Konfiguration?
- [ ] Weiß außer dir jemand, wie das Netz wieder zum Laufen kommt?

Die letzte Frage ist keine technische. Wenn Pi-hole DNS für den ganzen Haushalt macht,
betrifft ein Ausfall alle Mitbewohner — auch dann, wenn du gerade nicht da bist.
