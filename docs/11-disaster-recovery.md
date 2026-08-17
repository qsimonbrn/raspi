# 11 — Notfallwiederherstellung

*Stand: 16.08.2026*

Was passiert, wenn der Pi morgen nicht mehr startet?

---

## Bestandsaufnahme: Was für einen Wiederaufbau gebraucht wird

| # | Baustein | Gesichert? | Wo liegt es? |
|---|---|---|---|
| 1 | **Compose-Dateien** aller Stacks | ✅ **ja** | GitHub: `qsimonbrn/docker-stacks` |
| 2 | **Paperless-Dokumente + Datenbank** | ✅ **ja** | restic-Backup, täglich |
| 3 | **Bichon-E-Mail-Archiv** | ✅ **ja** | restic-Backup, täglich |
| 4 | **Pi-hole-Konfiguration** (Blocklisten, lokale DNS-Einträge, Anpassungen) | ✅ **ja** | Teleporter-Export im Backup |
| 5 | **Tailscale-Zustand** (`/var/lib/tailscale`) | ✅ **ja** | restic-Backup, täglich — im Notfall aber entbehrlich, siehe unten |
| 6 | **Samba-Konfiguration und Passwortdatenbank** | ✅ **ja** | restic-Backup, täglich |
| 7 | **Nutzdaten auf der SSD** (310 GB) | ❌ nein | passt nicht in 5 GB OneDrive |

**Sechs von sieben** — seit Einrichtung des Backups am 13.08.2026.
Details in [12 — Backup](12-backup.md).

Offen bleibt Position 7: die 222 GB unter `SSD_Müll` und 86 GB unter `rclone_bak`.
Empfehlung dazu in [12 — Backup, Abschnitt 8](12-backup.md#8-was-dieses-backup-nicht-abdeckt).

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
DNS-Einträgen, unbound, Samba mit Freigaben und Benutzern, Tailscale, Docker,
alle Container.

Die Compose-Dateien kommen aus GitHub — das ist der Teil, der funktioniert. Alles unter
`/etc` muss aus dem Gedächtnis rekonstruiert werden.

**Beim VPN entspannt sich die Lage seit der Umstellung auf Tailscale.** Geht
`/var/lib/tailscale` verloren, genügt nach der Neuinstallation ein `tailscale up` mit
Anmeldung über das GitHub-Konto — der Pi bekommt dieselbe Adresse `100.108.219.87`
zurück, und **kein einziges Client-Gerät muss angefasst werden**. Der alte Eintrag ist
in der Verwaltungsoberfläche zu löschen. Zu WireGuard-Zeiten war genau das der
schmerzhafteste Punkt dieses Szenarios.

Nachzuziehen sind nach dem Wiederaufbau nur die drei Einstellungen aus der
Tailscale-Oberfläche: Subnetz-Route `192.168.178.0/24`, Exit Node und der
DNS-Eintrag auf `100.108.219.87`.

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

Die Punkte 4, 5 und 6 der Tabelle oben — Pi-hole, Tailscale, Samba — sind **zusammen
wenige Megabyte**. Sie fehlen nicht aus technischen Gründen, sondern weil bisher niemand
einen Job dafür eingerichtet hat.

Ein wöchentlicher Job dieser Art würde Szenario A von „1–2 Tage Rekonstruktion aus dem
Gedächtnis" auf „ein paar Stunden" verkürzen:

| Quelle | Inhalt |
|---|---|
| `/var/lib/tailscale/` | Node-Schlüssel (im Notfall auch durch Neuanmeldung ersetzbar) |
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
9. Tailscale installieren, `tailscale up` mit Subnetz-Route ausführen, in der
   Verwaltungsoberfläche Route, Exit Node und DNS-Eintrag wieder setzen
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
- [ ] Ist das GitHub-Konto `qsimonbrn` mit Zwei-Faktor-Anmeldung gesichert? Es ist seit
      der Tailscale-Umstellung der Schlüssel zum Heimnetz.
- [ ] Ist das Bichon-Master-Passwort im Passwortmanager? (Es ist nachträglich nicht änderbar.)
- [ ] Existiert eine Liste der Paperless-Zugangsdaten und der PostgreSQL-Konfiguration?
- [ ] Weiß außer dir jemand, wie das Netz wieder zum Laufen kommt?

Die letzte Frage ist keine technische. Wenn Pi-hole DNS für den ganzen Haushalt macht,
betrifft ein Ausfall alle Mitbewohner — auch dann, wenn du gerade nicht da bist.

---

## Nachtrag 16.08.2026 — Vollständiges Paperless-Backup vorhanden

Vor dem Update auf Version 3 wurde unter `/mnt/usb-hdd/backup/2026-08-16-vor-update/`
ein geprüftes Backup abgelegt, das über den turnusmäßigen restic-Lauf hinausgeht:

| Teil | Wofür es beim Wiederaufbau gut ist |
|---|---|
| `db/paperless-2026-08-16.dump` | Vollständige Datenbank inklusive Papierkorb, einspielbar mit `pg_restore` |
| `db/paperless-2026-08-16.sql` | Dieselben Daten als Klartext — lesbar auch ohne passende PostgreSQL-Version |
| `export/documents/` | Dokumente als Dateien plus `manifest.json` mit allen Metadaten. Damit lässt sich ein Archiv **ohne** Datenbank neu aufbauen (`document_importer`) |
| `compose/` | Alle Compose- und `.env`-Dateien, Rechte `go-rwx` |

Die `manifest.json` ist zusätzlich die Rückfallebene für Metadaten: Sie enthält Titel,
Tags, Korrespondent und Dokumenttyp jedes Dokuments im Zustand vor dem Update. Werden
diese Felder später fehlerhaft überschrieben — etwa durch eine automatische
Verschlagwortung — lassen sie sich daraus per API einzeln zurückschreiben, ohne die
ganze Datenbank zurückzurollen.

**Grenze:** Das Verzeichnis liegt auf derselben SSD wie die Nutzdaten. Es schützt vor
einem fehlgeschlagenen Update, nicht vor einem Ausfall der Platte. Dafür ist weiterhin
der restic-Lauf nach OneDrive zuständig → [Kapitel 12](12-backup.md).
