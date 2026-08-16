# 09 — Empfehlungen

*Stand: 16.08.2026*

Priorisiert nach Schadenshöhe, nicht nach Aufwand. Jede Maßnahme mit Begründung — auch
die, von denen abgeraten wird.

---

## Stufe 1 — Datenverlust verhindern

### 1.1 Automatisiertes Backup einrichten — ✅ erledigt am 13.08.2026

> Umgesetzt mit **restic über rclone** nach OneDrive, täglich 03:17 Uhr per
> systemd-Timer, verschlüsselt und versioniert (7 Tage / 4 Wochen / 6 Monate).
> Paperless wird über `document_exporter` plus `pg_dump` gesichert, Pi-hole über
> den Teleporter-Export. Vollständig beschrieben in [12 — Backup](12-backup.md).
>
> **Nicht abgedeckt:** die 222 GB unter `SSD_Müll` — dafür reichen 5 GB nicht.

<details>
<summary>Ursprüngliche Empfehlung</summary>


**Warum zuerst:** Alle anderen Maßnahmen schützen vor Ereignissen, die eintreten
*können*. Ein Datenträgerausfall tritt irgendwann *ein*.

| | |
|---|---|
| Werkzeug | `restic` mit rclone-Backend (nutzt die vorhandene OneDrive-Konfiguration weiter) |
| Auslöser | systemd-Timer, täglich nachts |
| Umfang | Paperless-Export, Bichon-Archiv, `/etc`-Konfigurationen, ausgewählte SSD-Verzeichnisse |
| Aufwand | 1–2 Stunden einmalig |

**Warum `restic` und nicht `rclone sync`:** Verschlüsselung vor dem Upload,
Versionierung statt Spiegelung, Deduplizierung. Eine Spiegelung repliziert ein
versehentliches Löschen zuverlässig in die Cloud — genau das soll ein Backup verhindern.

**Sonderfall Paperless:** Muss über `document_exporter` gesichert werden, nicht durch
Kopieren des Datenverzeichnisses. Sonst fehlen Tags, Korrespondenten und OCR-Zuordnungen.
Details in [06 — Daten & Speicher](06-daten-und-speicher.md).

</details>

### 1.2 Wiederherstellung testen

Ein Backup, aus dem nie zurückgespielt wurde, ist eine Vermutung. Konkreter erster Test:
Paperless-Export in eine leere Testinstanz importieren und prüfen, ob die
Ordnungsstruktur vollständig ist.

**Aufwand:** 30 Minuten. **Wert:** Der Unterschied zwischen einem Backup und der Hoffnung
auf eines.

### 1.3 Wurzeldateisystem auf die SSD umziehen

| | |
|---|---|
| Grund | SD-Karte von 02/2023, 3,5 Jahre Dauerbetrieb mit hoher Schreiblast |
| Voraussetzung | Bereits erfüllt — Pi 4 kann per USB booten, SSD ist zu 64 % leer |
| Aufwand | 2–3 Stunden, mit Neustart |
| Risiko | mittel — sollte mit physischem Zugang zum Pi erfolgen |

**Zwischenlösung**, falls der Umzug warten soll: ein Image-Abbild der SD-Karte auf die
SSD, damit im Ausfall wenigstens ein Klon existiert.

> **Reihenfolge:** Erst 1.1 und 1.2, dann 1.3. Ein Datenträgerumzug ohne funktionierendes
> Backup ist eine schlechte Idee.

### 1.4 `smartmontools` installieren

Ohne SMART-Daten gibt es keine Vorwarnung, bevor die SSD ausfällt.
**Aufwand:** 10 Minuten. Bei USB-Anbindung ist `-d sat` als Parameter nötig.

---

## Stufe 2 — Absicherung

Ausführliche Begründungen in [07 — Sicherheit](07-sicherheit.md).

| # | Maßnahme | Aufwand | Wirkung |
|---|---|---|---|
| 2.1 | `PasswordAuthentication no` in der SSH-Konfiguration | 5 min | hoch |
| 2.2 | IPv6-Freigaben in der FRITZ!Box prüfen | 5 min | hoch |
| 2.3 | `unattended-upgrades` aktivieren (nur Security, ohne Auto-Reboot) | 5 min | hoch |
| 2.4 | `fail2ban` für SSH und Samba | 10 min | mittel |
| 2.5 | `ufw` mit LAN-/VPN-Regelwerk | 30 min | hoch |
| ~~2.6~~ | ~~Container-Updates einspielen~~ — **erledigt 16.08.2026**, siehe [05](05-docker.md) | — | — |
| 2.7 | **Diun** installieren (meldet neue Images, aktualisiert nicht) | 20 min | mittel |
| ~~2.8~~ | ~~Datenbank-Images auf feste Tags pinnen~~ — **erledigt 16.08.2026**: `postgres:15.19`, `redis:7.4`, alle übrigen ebenfalls gepinnt | — | — |
| 2.9 | **Ersatz für `filebrowser`** — Projekt wird am 01.09.2026 archiviert | 1 h | mittel |
| 2.10 | **homepage auf v2.0.0** — Breaking Change bei der Authentifizierung, Release Notes lesen | 30 min | mittel |
| 2.11 | **Dashy abschalten** — durch Homepage abgelöst, drei alte Images im System | 15 min | niedrig |
| 2.9 | Samba härten (`map to guest = Never`, `server min protocol = SMB3`) | 15 min | niedrig |

**Zu 2.1 — Sicherheitsnetz:** Die bestehende SSH-Sitzung offen lassen und den Login in
einer *zweiten* Sitzung testen, bevor die erste geschlossen wird.

**Zu 2.5 — Stolperfalle:** Docker umgeht `ufw`, weil es eigene iptables-Regeln schreibt.
Container-Ports müssen zusätzlich über die `DOCKER-USER`-Chain abgesichert oder an
`127.0.0.1` gebunden werden. Letzteres funktioniert gut zusammen mit 3.2.

---

## Stufe 3 — Betrieb und Komfort

### 3.1 Dashboard richtig aufsetzen — ✅ erledigt am 13.08.2026

> Umgesetzt mit **Homepage** auf Port 3000, Konfiguration persistent und im Git,
> Docker-Anbindung über einen lesenden Socket-Proxy.
> Siehe [05 — Docker](05-docker.md).

<details>
<summary>Ursprüngliche Analyse und Optionsvergleich</summary>


**Das Problem ist nicht die Software, sondern die fehlende Persistenz.** In der aktuellen
`dashy/docker-compose.yml` ist der Volume-Block auskommentiert — jede Konfiguration geht
beim nächsten Update verloren. Das erklärt, warum das Dashboard nie fertig wurde.

| Option | Für wen |
|---|---|
| **Dashy reparieren** | Vertraut, bereits installiert. Konfiguration über eine `conf.yml`, die dann persistent gemountet wird. Kein Live-Status der Dienste. |
| **Homepage** (`gethomepage.dev`) | Liest die laufenden Docker-Container automatisch aus, zeigt live an, ob ein Dienst erreichbar ist, mit Widgets für CPU, RAM und Speicher. Konfiguration ebenfalls per YAML. Der inhaltliche Nachfolger von Heimdall. |
| **Heimdall** | Sehr schlank, reine Kachel-Sammlung. Wird seit längerem kaum noch gepflegt und zeigt keinen Status. |

**Empfehlung: Homepage.** Bei sieben Containern ist die Auto-Erkennung der spürbare
Unterschied — neue Dienste erscheinen von selbst, statt manuell nachgetragen werden zu
müssen. Und der Live-Status beantwortet die Frage, für die man ein Dashboard überhaupt
öffnet: „Läuft alles?"

In jedem Fall: **Konfiguration als Volume mounten und ins Git-Repo aufnehmen.**

</details>

### 3.2 Reverse Proxy plus lokale DNS-Einträge

Statt `192.168.178.80:8000` einfach `paperless.home`.

| | |
|---|---|
| Werkzeug | Caddy (kleinste Konfiguration, HTTPS automatisch) |
| DNS | Lokale Einträge direkt in Pi-hole — die Infrastruktur läuft bereits |
| Aufwand | 1 Stunde |

**Warum das hier besonders gut passt:** Pi-hole ist ohnehin der DNS-Server des gesamten
Heimnetzes. Lokale DNS-Einträge sind dort in zwei Minuten gesetzt und gelten sofort für
alle Geräte. Zusätzlicher Nutzen: Alle Container-Ports können anschließend auf
`127.0.0.1` gebunden werden — dann ist der Reverse Proxy der einzige Weg hinein, und die
`ufw`-Problematik aus 2.5 entschärft sich von selbst.

### 3.3 Uptime Kuma

Meldet den Ausfall eines Dienstes, **bevor** er auffällt. Besonders relevant, weil
Pi-hole der DNS-Server für den gesamten Haushalt ist — ein unbemerkter Ausfall bedeutet
„Internet kaputt" für alle.

**Aufwand:** 30 Minuten. Läuft problemlos auf einem Pi 4.

### 3.4 Aufräumen

| Maßnahme | Aufwand | Nutzen |
|---|---|---|
| `dhcpcd` **oder** `NetworkManager` deaktivieren | 15 min | Beendet stündliche Journal-Fehler |
| `ModemManager`, `triggerhappy` deaktivieren | 5 min | Weniger Angriffsfläche |
| `docker image prune -a` | 2 min | 1,18 GB frei |
| `/mnt/usb-hdd/filebrowser.db/` entfernen | 1 min | Aufräumen |
| Paperless-Stack aus dem korrekten Pfad neu erzeugen | 15 min | Behebt Pfad-Drift |
| Anonyme Volumes zuordnen und explizit benennen | 30 min | Verhindert versehentlichen Datenverlust beim Aufräumen |
| Offene Git-Änderungen committen | 5 min | Repo deckungsgleich mit der Realität |

**Vorsicht bei `dhcpcd`/`NetworkManager`:** Ein Fehler kappt die Netzwerkverbindung. Nur
mit physischem Zugang oder zweitem Zugangsweg durchführen.

---

## Bewusst nicht empfohlen

| Idee | Warum nicht |
|---|---|
| **Watchtower mit Auto-Update auf `:latest`** | Paperless-ngx hatte Releases mit erforderlichen manuellen Migrationsschritten — ein unbeaufsichtigtes Update über mehrere Versionen kann Datenbank-Migrationen auslösen, die nicht rückwärtskompatibel sind. Benachrichtigung (Diun) ist hier klar besser als Automatik. |
| **Nextcloud** | Neben Paperless und PostgreSQL wird es bei 3,7 GB RAM eng. Für Dateizugriff existieren mit Samba und Filebrowser bereits zwei funktionierende Wege. Der Nutzen rechtfertigt die Last nicht. |
| **Grafana + Prometheus** | Für sieben Container ist das Overhead ohne Erkenntnisgewinn. Uptime Kuma beantwortet die relevante Frage („läuft es?") mit einem Bruchteil der Ressourcen. |
| **SSH-Port von 22 verlegen** | Verhindert nur Log-Rauschen, keine gezielten Angriffe. `PasswordAuthentication no` bringt ungleich mehr. |
| **Zweiter dauerhafter DNS-Server in der FRITZ!Box** | Naheliegend als Ausfallschutz, hebelt aber die Werbefilterung teilweise aus, weil Clients frei wählen dürfen. Bewusste Abwägung — als *temporäre* Umstellung vor einem geplanten Neustart dagegen sinnvoll. |

---

## Vorgeschlagene Reihenfolge

```
Woche 1   1.1 Backup einrichten
          1.2 Wiederherstellung testen
          2.1 SSH-Passwortlogin abschalten
          2.2 FRITZ!Box-Freigaben prüfen
          2.3 unattended-upgrades

Woche 2   2.6 Container-Updates          ✅ erledigt 16.08.2026
          2.8 Datenbank-Tags pinnen      ✅ erledigt 16.08.2026
          2.7 Diun — jetzt wichtiger: mit festen Tags erfährt man
              von neuen Versionen sonst gar nichts mehr
          2.9 Ersatz für filebrowser (Frist: 01.09.2026)
          3.1 Dashboard

Später    1.3 Umzug auf SSD
          2.5 ufw
          3.2 Reverse Proxy + lokale DNS-Namen
          3.3 Uptime Kuma
          3.4 Aufräumen
```

Der rote Faden: erst eine Rückfallebene schaffen, dann Dinge verändern.
