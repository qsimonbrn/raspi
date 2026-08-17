# 10 — Zugriff

*Erfasst: 18.08.2026*

Alle Zugangswege zum System auf einen Blick.

---

## Weboberflächen

| Dienst | Adresse | Zweck |
|---|---|---|
| **Pi-hole** | `http://192.168.178.80/admin` | DNS-Statistiken, Blocklisten, lokale DNS-Einträge |
| **Homepage** | `http://192.168.178.80:3000` | **Dashboard — Einstieg zu allen Diensten** |
| **ntfy** | `http://192.168.178.80:2586` | Benachrichtigungen, Verlauf der Meldungen |
| **Paperless-ngx** | `http://192.168.178.80:8000` | Dokumentenarchiv, Suche, OCR |
| **Dashy** | `http://192.168.178.80:8080` | Dashboard / Startseite |
| **Filebrowser** | `http://192.168.178.80:8082` | Dateizugriff auf die SSD im Browser |
| **Portainer** | `http://192.168.178.80:9000`<br>`https://192.168.178.80:9443` | Container-Verwaltung |
| **Bichon** | `http://192.168.178.80:15630` | E-Mail-Archiv |

> Alle Weboberflächen laufen unverschlüsselt über HTTP (Ausnahme: Portainer auf 9443).
> Im Heimnetz vertretbar. Empfehlung zur Umstellung auf Namen mit HTTPS über einen
> Reverse Proxy in [09 — Empfehlungen](09-empfehlungen.md), Punkt 3.2.

## Dateizugriff

| Weg | Adresse | Hinweis |
|---|---|---|
| **Samba (macOS)** | `smb://192.168.178.80/usb-share` | Finder → *Gehe zu* → *Mit Server verbinden* |
| **Einwurf Paperless** | `smb://192.168.178.80/scans` | Dateien hier ablegen → werden automatisch eingelesen |
| **Samba (Windows)** | `\\192.168.178.80\usb-share` | |
| **Home-Verzeichnis** | `smb://192.168.178.80/simon` | nicht in der Netzwerkumgebung sichtbar |
| Benutzer | `simon` | einziger berechtigter Samba-Benutzer |

## Kommandozeile

| | |
|---|---|
| SSH | `ssh simon@192.168.178.80` |
| Alternativ per mDNS | `ssh simon@raspberrypi.local` |
| Authentifizierung | SSH-Schlüssel (Passwort derzeit ebenfalls möglich) |
| `sudo` | ohne Passwort möglich |

## Fernzugriff von außerhalb

| | |
|---|---|
| Verfahren | Tailscale (Mesh-VPN auf WireGuard-Basis) |
| Eingehender Port | **keiner** |
| Tailnet | `tailf372ec.ts.net` |
| Pi im Tailnet | `100.108.219.87` bzw. `raspberrypi.tailf372ec.ts.net` |
| Verbundene Geräte | 2 (`raspberrypi`, `iphone-sibr`) |
| Heimnetz über VPN | ja — `192.168.178.0/24` per Subnetz-Router |
| DNS über VPN | Pi-hole, tailnetweit erzwungen |

Bei aktiver Verbindung ist der Pi unter `192.168.178.80` **und** unter `100.108.219.87`
ansprechbar. Dank Subnetz-Router funktionieren unterwegs auch die gewohnten
`192.168.178.x`-Adressen — alle Lesezeichen bleiben gültig.

**Es gibt keine Portfreigaben ins Internet, und es werden auch keine mehr benötigt.**
Der Anschluss läuft über DS-Lite und hat gar keine eigene öffentliche IPv4-Adresse;
Tailscale baut die Verbindung deshalb von innen nach außen auf. Siehe
[04 — Systemdienste](04-dienste-system.md).

---

## Zugriffsmatrix

| Dienst | Aus dem LAN | Über Tailscale | Aus dem Internet |
|---|---|---|---|
| Homepage | ✅ | ✅ | ❌ |
| ntfy | ✅ | ✅ | ❌ |
| Pi-hole Web | ✅ | ✅ | ❌ |
| Paperless | ✅ | ✅ | ❌ |
| Portainer | ✅ | ✅ | ❌ |
| Filebrowser | ✅ | ✅ | ❌ |
| Bichon | ✅ | ✅ | ❌ |
| Dashy | ✅ | ✅ | ❌ |
| Samba | ✅ | ✅ | ❌ |
| SSH | ✅ | ✅ | ❌ |
| Tailscale | ✅ | — | ❌ (kein eingehender Port) |

> Die Spalte „Aus dem Internet" beschreibt den **Soll-Zustand**. Sie gilt, solange die
> FRITZ!Box eingehende IPv6-Verbindungen blockiert. Auf dem Pi selbst gibt es keine
> Firewall, die das zusätzlich absichert — siehe [07 — Sicherheit](07-sicherheit.md).

---

## Zugangsdaten

**Bewusst nicht in diesem Repository.** Passwörter, private Schlüssel und Tokens gehören
in einen Passwortmanager, nicht in eine Dokumentation — auch nicht in eine private.

Was hier steht, sind ausschließlich öffentliche Informationen: Adressen, Ports,
Benutzernamen und öffentliche Schlüssel.

## Erwartete Zugangsdaten

Checkliste dessen, was im Passwortmanager hinterlegt sein sollte:

- [ ] Systembenutzer `simon` (Passwort)
- [ ] SSH-Schlüssel (privat) — inkl. Speicherort
- [ ] Pi-hole Web-Oberfläche
- [ ] Paperless-ngx Administratorkonto
- [ ] Portainer Administratorkonto
- [ ] Filebrowser Administratorkonto
- [ ] Bichon Master-Passwort — ⚠️ laut Compose-Datei **nachträglich nicht änderbar**, ohne das Archiv zu zerstören
- [ ] Samba-Passwort für `simon`
- [ ] GitHub-Konto `qsimonbrn` — ⚠️ **Schlüssel zum Heimnetz**, seit der Tailscale-Anmeldung. Zwei-Faktor-Anmeldung zwingend
- [ ] PostgreSQL-Zugangsdaten für Paperless
