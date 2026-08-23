# 18 — Vaultwarden (Passwort-Tresor)

*Erfasst: 23.08.2026*

Vaultwarden ist eine eigenständige, in Rust geschriebene Umsetzung des
Bitwarden-Serverprotokolls. Die offiziellen Bitwarden-Clients — Browser-Erweiterung,
iOS-App, macOS-App — sprechen mit ihm, ohne dass sie es merken. Der Tresor liegt damit
auf eigener Hardware statt bei einem Anbieter.

Er läuft seit dem 23.08.2026 und ist **ausschließlich über das Tailnet erreichbar**.

---

## 1. Auf einen Blick

| | |
|---|---|
| Adresse | `https://raspberrypi.tailf372ec.ts.net:8443` |
| Image | `vaultwarden/server:1.37.2` (fest gepinnt) |
| Stack | `stacks/vaultwarden/` |
| Datenverzeichnis | `/mnt/usb-hdd/vaultwarden` (Modus 700, `root`) |
| Portbindung | `127.0.0.1:8222` — **nicht** auf allen Schnittstellen |
| Speicher-Limit | 256 MiB (gemessen am 23.08.2026: 46 MiB) |
| Registrierung | gesperrt seit dem 23.08.2026 |
| Admin-Oberfläche `/admin` | bewusst **abgeschaltet** |
| Konten | 1 (`simon.braun-ph@gmx.de`) |

## 2. Warum Port 8443 und nicht 443

Die Bitwarden-Clients verschlüsseln den Tresor im Browser beziehungsweise in der App,
bevor irgendetwas das Gerät verlässt. Dafür nutzen sie die **Web-Crypto-API**, und die
steht nur in einem *secure context* zur Verfügung — also unter HTTPS. Ohne HTTPS
verweigern die Clients schlicht den Dienst.

**HTTPS ist hier deshalb kein Sicherheitsgewinn.** Der Verkehr läuft ohnehin
verschlüsselt durch Tailscale; die Verschlüsselung liegt eine Schicht tiefer und wäre
auch ohne Zertifikat vorhanden. HTTPS ist eine reine Freischaltbedingung der Clients.

Port 443 wäre die schönere Adresse, ist aber belegt: `pihole-FTL` lauscht dort auf
`0.0.0.0:443`. `tailscale serve --https=443` meldet auf diesem Pi **Erfolg und wirkt
nicht** — ohne jede Fehlermeldung. Pi-hole von diesem Port zu verdrängen wäre möglich,
würde aber bei jedem Pi-hole-Core-Update überschrieben und brächte außer einer kürzeren
URL nichts. Details in [10 — Zugriff](10-zugriff.md).

## 3. Der Weg einer Anfrage

```
Bitwarden-Client (Mac/iPhone)
      │  https, Zertifikat von Let's Encrypt für *.tailf372ec.ts.net
      ▼
tailscaled, lauscht auf 100.108.219.87:8443   ← nur über tailscale0 erreichbar
      │  beendet TLS, setzt X-Forwarded-For
      ▼  http
127.0.0.1:8222  (docker-proxy)
      ▼
Container vaultwarden, Port 80
```

**Zwei voneinander unabhängige Absicherungen**, und das ist Absicht:

1. `tailscaled` bindet 8443 nur an die Tailnet-Adresse. Aus dem Heimnetz führt kein Weg
   dorthin.
2. Der Container bindet an `127.0.0.1:8222`. Selbst wenn Docker beim Erzeugen eines
   Containers die iptables-Regeln neu schreibt — was es regelmäßig tut, siehe
   [07 — Sicherheit](07-sicherheit.md) — bleibt der Port aus dem Netz unerreichbar.

Die Abschottung hängt hier also **nicht** allein an `pi-guard`. Das ist der Unterschied
zu den übrigen Diensten und bei einem Passwort-Tresor angemessen.

**Nachgemessen am 23.08.2026, nach einem Neustart:**

| Prüfung | Ergebnis |
|---|---|
| `https://…ts.net:8443/alive` über die Tailnet-Adresse | `http=200`, Zertifikat validiert (`curl` ohne `-k`) |
| Dieselbe URL über `192.168.178.80` | `http=000` |
| `http://192.168.178.80:8222/alive` | `http=000` |
| `ss -tlnp` für 8222 | nur `127.0.0.1` |
| `ss -tlnp` für 8443 | nur `100.108.219.87` und die Tailnet-IPv6 |

## 4. Warum die Admin-Oberfläche abgeschaltet ist

Vaultwarden bringt unter `/admin` eine Verwaltungsoberfläche mit. Sie wird über die
Umgebungsvariable `ADMIN_TOKEN` freigeschaltet; **ohne gesetzten Token weist Vaultwarden
sie vollständig ab.** Genau so ist es hier eingerichtet.

Die Abwägung: Der Token wäre ein zweites Geheimnis mit Vollzugriff auf den Tresor-Server,
neben dem Master-Passwort — und eine zusätzliche Angriffsfläche für einen Dienst, der von
einer einzigen Person genutzt wird. Der Preis ist, dass Einstellungen über die `.env` und
einen Container-Neustart laufen statt per Klick. Bei einem Ein-Personen-Tresor ist das
eher Vorteil als Last: Was selten geändert wird, soll nachvollziehbar in einer Datei
stehen.

## 5. Einstellungen

Alle Einstellungen stehen in `stacks/vaultwarden/.env` (Modus 600, über `.gitignore`
ausgeschlossen).

| Variable | Wert | Warum |
|---|---|---|
| `DOMAIN` | `https://raspberrypi.tailf372ec.ts.net:8443` | Muss **exakt** der Client-Adresse entsprechen, Port eingeschlossen. Weicht sie ab, brechen WebSocket-Abgleich und Zwei-Faktor-Anmeldung |
| `SIGNUPS_ALLOWED` | `false` | Seit dem 23.08.2026, nachdem das erste Konto stand |
| `SIGNUPS_VERIFY` | `false` | Es ist kein Mailversand eingerichtet; sonst bliebe das erste Konto unbestätigt und unbenutzbar |
| `INVITATIONS_ALLOWED` | `false` | Weitere Personen sind nicht vorgesehen |
| `SHOW_PASSWORD_HINT` | `false` | Der Hinweis verrät einem Fremden, dass es zu einer Adresse überhaupt ein Konto gibt — und ist erfahrungsgemäß halb das Passwort |
| `IP_HEADER` | `X-Forwarded-For` | `tailscale serve` reicht die echte Client-Adresse in diesem Kopf weiter. Ohne die Zeile stünde in jedem Anmeldeprotokoll `127.0.0.1` |
| `ADMIN_TOKEN` | *nicht gesetzt* | Siehe Abschnitt 4 |

### Nachweis, dass die Registrierung wirklich gesperrt ist

Eine unvollständige Anfrage beweist nichts — sie scheitert schon beim Einlesen mit `422`,
und zwar im offenen wie im gesperrten Zustand. Erst eine **vollständige** Anfrage trifft
die Prüfung:

```bash
curl -s -X POST http://127.0.0.1:8222/identity/accounts/register \
  -H 'Content-Type: application/json' \
  -d '{"email":"…","name":"…","masterPasswordHash":"…","key":"2.…","kdf":0,
       "kdfIterations":600000,"keys":{"publicKey":"…","encryptedPrivateKey":"2.…"}}'
```

Erwartete Antwort im gesperrten Zustand: `400` mit
`Registration not allowed or user already exists`, und die Kontenzahl in der Datenbank
bleibt unverändert. Am 23.08.2026 so nachgemessen.

## 6. Sicherung

Der Tresor liegt in einer SQLite-Datenbank. Ein bytweises Kopieren der **laufenden**
Datei kann sie zerrissen erwischen: WAL-Journal und Hauptdatei geraten auseinander, und
das fällt erst beim Wiederherstellen auf. `pi-backup.sh` legt deshalb einen konsistenten
Abzug über die Sicherungs-API von SQLite an und schließt die Live-Datei aus der
restic-Sicherung aus.

| Was | Wie gesichert |
|---|---|
| `db.sqlite3` | Abzug per `sqlite3 .backup` nach `$STAGE/vaultwarden/`, geprüft |
| `db.sqlite3-wal`, `-shm` | ausgeschlossen — im Abzug enthalten |
| `rsa_key.pem` | direkt. **Wichtig:** ohne diesen Schlüssel sind nach einer Wiederherstellung alle Sitzungen ungültig |
| `attachments/`, `sends/` | direkt, sobald vorhanden |
| `icon_cache/` | ausgeschlossen — jederzeit neu beschaffbar |

### Die Prüfung des Abzugs, und was sie nicht kann

Nach dem Abzug läuft `PRAGMA integrity_check`. Am 23.08.2026 wurde an absichtlich
beschädigten Kopien gemessen, was diese Prüfung tatsächlich erkennt:

| Schaden | `integrity_check` |
|---|---|
| 2000 Zufallsbytes mitten in der Datei | Fehler — erkannt |
| auf die Hälfte abgeschnitten | Fehler — erkannt |
| Kopf zerstört | Fehler — erkannt |
| **leere Datei** | **`ok`** — *nicht* erkannt |
| gültige Datei ohne Tabellen | **`ok`** — *nicht* erkannt |

Die letzten beiden Zeilen sind der Grund, warum `integrity_check` allein nicht genügt:
Ein Abzug kann formal heil und trotzdem wertlos sein. `pi-backup.sh` fragt deshalb
zusätzlich `SELECT count(*) FROM users` ab und warnt, wenn die Tabelle fehlt oder kein
einziges Konto enthält.

### Nachweis der Wiederherstellbarkeit

Am 23.08.2026 aus Snapshot `143d751d` zurückgeholt:

```
zurueckgeholt: 278528 Byte
integrity_check: ok
Konten im Abzug: 1
E-Mail im Abzug: simon.braun-ph@gmx.de
```

Gegenprobe: `/mnt/usb-hdd/vaultwarden/db.sqlite3` ist im Snapshot **nicht** enthalten,
`rsa_key.pem` schon.

## 7. Wiederherstellung

```bash
# 1. Abzug und Schlüssel aus dem Backup holen
sudo -E restic restore latest --include "*/vaultwarden/*" --target /tmp/wh

# 2. Container anhalten
cd /home/simon/raspi/stacks/vaultwarden && sudo docker compose down

# 3. Datenbank und Schlüssel zurücklegen
sudo cp /tmp/wh/mnt/usb-hdd/backup-stage/vaultwarden/db.sqlite3 /mnt/usb-hdd/vaultwarden/
sudo cp /tmp/wh/mnt/usb-hdd/vaultwarden/rsa_key.pem            /mnt/usb-hdd/vaultwarden/
sudo rm -f /mnt/usb-hdd/vaultwarden/db.sqlite3-wal /mnt/usb-hdd/vaultwarden/db.sqlite3-shm

# 4. Starten und prüfen
sudo docker compose up -d
sudo sqlite3 /mnt/usb-hdd/vaultwarden/db.sqlite3 "PRAGMA integrity_check; SELECT count(*) FROM users;"
```

Die verwaisten `-wal`- und `-shm`-Dateien müssen weg: Sie gehören zum alten Stand und
würden die zurückgespielte Datenbank beschädigen.

## 8. Bekannte Eigenheiten

**Der Pi kann seinen eigenen Tailnet-Namen nicht auflösen.** `CorpDNS` steht auf `false`,
weil der Pi selbst der DNS-Server des Hauses ist und MagicDNS nicht annimmt. Eine Prüfung
vom Pi aus braucht deshalb `--resolve`:

```bash
curl --resolve raspberrypi.tailf372ec.ts.net:8443:100.108.219.87 \
     https://raspberrypi.tailf372ec.ts.net:8443/alive
```

Mac und iPhone lösen den Namen über MagicDNS auf; für sie besteht das Problem nicht. Aus
demselben Grund hat der Eintrag auf dem Dashboard **keinen** `siteMonitor` — er stünde
dauerhaft auf Rot. Den Zustand liefert dort die Docker-Anbindung.

**`tailscale serve` überlebt einen Neustart.** Am 23.08.2026 geprüft: Die Konfiguration
liegt in `/var/lib/tailscale/tailscaled.state` und wurde nach dem Neustart unverändert
wiederhergestellt, `http=200`.

---

*Siehe auch: [10 — Zugriff](10-zugriff.md) · [12 — Backup](12-backup.md) ·
[05 — Docker](05-docker.md)*
