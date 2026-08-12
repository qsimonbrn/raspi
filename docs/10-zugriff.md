# 10 — Zugriff

*Erfasst: 13.08.2026*

Alle Zugangswege zum System auf einen Blick.

---

## Weboberflächen

| Dienst | Adresse | Zweck |
|---|---|---|
| **Pi-hole** | `http://192.168.178.80/admin` | DNS-Statistiken, Blocklisten, lokale DNS-Einträge |
| **Homepage** | `http://192.168.178.80:3000` | **Dashboard — Einstieg zu allen Diensten** |
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
| Verfahren | WireGuard |
| Port | 51820/UDP |
| VPN-Netz | `10.66.66.0/24` |
| Pi im VPN | `10.66.66.1` |
| Eingerichtete Clients | 1 (`10.66.66.2`) |

Im aktiven Tunnel sind alle oben genannten Adressen unverändert erreichbar — der Pi ist
dann unter `192.168.178.80` **und** unter `10.66.66.1` ansprechbar.

**Es gibt keine direkten Portfreigaben ins Internet.** WireGuard ist der einzige Weg von
außen. Das ist beabsichtigt und richtig so.

---

## Zugriffsmatrix

| Dienst | Aus dem LAN | Über VPN | Aus dem Internet |
|---|---|---|---|
| Homepage | ✅ | ✅ | ❌ |
| Pi-hole Web | ✅ | ✅ | ❌ |
| Paperless | ✅ | ✅ | ❌ |
| Portainer | ✅ | ✅ | ❌ |
| Filebrowser | ✅ | ✅ | ❌ |
| Bichon | ✅ | ✅ | ❌ |
| Dashy | ✅ | ✅ | ❌ |
| Samba | ✅ | ✅ | ❌ |
| SSH | ✅ | ✅ | ❌ |
| WireGuard | ✅ | — | ✅ (Port 51820/UDP) |

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
- [ ] WireGuard-Client-Konfiguration (enthält private Schlüssel)
- [ ] PostgreSQL-Zugangsdaten für Paperless
