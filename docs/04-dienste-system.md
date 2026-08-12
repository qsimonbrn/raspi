# 04 — Systemdienste

*Erfasst: 13.08.2026*

Dienste, die **direkt auf dem Betriebssystem** laufen — nicht in Containern.
Container siehe [05 — Docker](05-docker.md).

---

## Pi-hole — netzwerkweiter Werbeblocker und DNS-Server

| Komponente | Version | Aktuell? |
|---|---|---|
| Core | v6.4.3 | ✅ neueste |
| Web-Oberfläche | v6.6 | ✅ neueste |
| FTL (DNS-Engine) | v6.7 | ✅ neueste |

| | |
|---|---|
| Dienst | `pihole-FTL.service` |
| Ports | 53 (DNS), 80 (Web), 443 |
| Oberfläche | `http://192.168.178.80/admin` |
| **Upstream-DNS** | `127.0.0.1#5335` → unbound |

Pi-hole ist auf allen drei Komponenten auf dem neuesten Stand. Das ist bemerkenswert,
weil Pi-hole 6 ein größerer Umbau gegenüber Version 5 war — das Update wurde also aktiv
nachgezogen.

### Rolle im Netz

Pi-hole ist der DNS-Server für das gesamte Heimnetz. Damit hängt die Namensauflösung
**aller** Geräte an diesem Pi.

> **Konsequenz:** Fällt der Pi aus, funktioniert im Haushalt kein Internet mehr — auch
> wenn die FRITZ!Box läuft. Geräte bekommen keine DNS-Antworten mehr.
>
> **Empfehlung:** In der FRITZ!Box einen zweiten DNS-Server als Rückfallebene eintragen,
> oder — sauberer — bei einem geplanten Neustart des Pi kurz auf den Router-DNS
> umstellen. Ein zweiter dauerhaft eingetragener DNS-Server hebelt allerdings die
> Werbefilterung teilweise aus, weil Clients frei wählen dürfen. Bewusste Abwägung.

---

## unbound — rekursiver DNS-Resolver

| | |
|---|---|
| Bindung | `127.0.0.1:5335` — **nur lokal** |
| Funktion | Löst DNS-Namen selbst ab den Root-Servern auf |

### Warum das die gute Variante ist

Ein typisches Pi-hole leitet nicht geblockte Anfragen an einen externen Resolver weiter —
Google (`8.8.8.8`), Cloudflare (`1.1.1.1`) oder den Provider. Dieser kennt dann jede
aufgerufene Domain.

Hier passiert das nicht: unbound fragt selbst bei den Root-Servern, dann bei den
zuständigen Nameservern nach. Es gibt keine zentrale Stelle, die das vollständige
Surfprofil des Haushalts sieht.

**Bewertung:** Technisch die sauberste Pi-hole-Konfiguration. Gut gebaut, korrekt
abgesichert (Bindung nur auf localhost).

---

## WireGuard — VPN-Fernzugriff

| | |
|---|---|
| Schnittstelle | `wg0` |
| Server-IP | `10.66.66.1/24` |
| Port | **51820/UDP** |
| Autostart | `wg-quick@wg0` — aktiviert |
| Konfiguration | `/etc/wireguard/` |
| Server Public Key | `wFxaG88cs8vWlDQLDt52NXFUVRc6pHG15OCtC7rPVEg=` |

### Peers

| Peer Public Key | Erlaubte IPs |
|---|---|
| `H5gftIdvDz1dg+wKldntyQOBTMgStGT7s24372X9D3Q=` | `10.66.66.2/32` |

Ein einzelner Client ist eingerichtet.

**Bewertung:** Der richtige Ansatz für Fernzugriff. Statt einzelne Dienste per
Portfreigabe ins Internet zu stellen, gibt es genau einen verschlüsselten Eingang.
WireGuard antwortet auf unauthentifizierte Pakete überhaupt nicht — ein Portscan von
außen sieht den Dienst nicht.

### ⚠️ Die WireGuard-Schlüssel sind nicht gesichert

`/etc/wireguard/` ist in keinem Backup enthalten. Geht der Pi verloren, muss der Tunnel
komplett neu aufgesetzt und **jedes Client-Gerät neu konfiguriert** werden. Die Dateien
sind wenige Kilobyte groß — es gibt keinen Grund, sie nicht zu sichern.
Siehe [11 — Notfallwiederherstellung](11-disaster-recovery.md).

---

## Samba — Datei­freigabe für Windows und macOS

### Freigabe `[usb-share]`

| Parameter | Wert |
|---|---|
| Pfad | `/mnt/usb-hdd` |
| Schreibzugriff | ja |
| Berechtigte Benutzer | `simon` |
| `force user` | `simon` |
| Zugriff | `smb://192.168.178.80/usb-share` |

### Weitere Freigaben

| Freigabe | Zweck | Sichtbar |
|---|---|---|
| `[homes]` | Home-Verzeichnisse | nein (`browseable = No`) |
| `[printers]` | Druckerfreigabe | nein |
| `[print$]` | Druckertreiber | ja |

### Globale Einstellungen

| Parameter | Wert | Anmerkung |
|---|---|---|
| `server role` | standalone server | korrekt für ein Heimnetz |
| `map to guest` | `Bad User` | unbekannte Benutzer werden zu Gast |
| `usershare allow guests` | `Yes` | Benutzer dürfen Gast-Freigaben anlegen |
| `unix password sync` | `Yes` | Samba- und Systempasswort werden synchron gehalten |

**Samba-Benutzer:** `simon` (UID 1000) — der einzige.

### Bewertung

Die Freigabe selbst ist eng gefasst: nur ein berechtigter Benutzer, kein Gastzugriff auf
`usb-share`. Die beiden Gast-bezogenen Globaleinstellungen sind Debian-Standardwerte und
im Heimnetz vertretbar, aber unnötig — es gibt keine Gast-Freigabe, die sie brauchen
würde.

**Optionale Härtung:** `map to guest = Never` und `usershare allow guests = No` setzen.
Zusätzlich lohnt `server min protocol = SMB3`, um veraltete und unsichere
SMB1-Verbindungen auszuschließen.

Die Freigaben `[printers]` und `[print$]` werden vermutlich nicht genutzt und können
entfallen.

---

## SSH

| Parameter | Wert | Bewertung |
|---|---|---|
| Port | 22 | Standard |
| `PubkeyAuthentication` | `yes` | ✅ |
| **`PasswordAuthentication`** | **`yes`** | ⚠️ siehe unten |
| `PermitRootLogin` | `without-password` | ✅ nur mit Schlüssel |
| `PermitEmptyPasswords` | `no` | ✅ |

### ⚠️ Befund: Passwort-Anmeldung ist aktiv

Der Schlüssel-Login funktioniert nachweislich. Damit ist die Passwort-Authentifizierung
nur noch zusätzliche Angriffsfläche: Sie erlaubt Brute-Force-Versuche gegen das
Benutzerpasswort. In Verbindung mit dem fehlenden `fail2ban` gibt es dagegen keinerlei
Bremse.

**Empfehlung:** `PasswordAuthentication no`. Vorher unbedingt sicherstellen, dass der
Schlüssel-Login von allen benötigten Geräten funktioniert — sonst sperrt man sich aus.
Details in [07 — Sicherheit](07-sicherheit.md).

---

## Weitere Dienste

| Dienst | Zweck | Bewertung |
|---|---|---|
| `avahi-daemon` | mDNS — macht `raspberrypi.local` auflösbar | sinnvoll |
| `NetworkManager` | Netzwerkkonfiguration | ⚠️ Konflikt mit `dhcpcd` |
| `dhcpcd` | DHCP-Client | ⚠️ Konflikt mit `NetworkManager` |
| `nmbd` | NetBIOS-Namen für Samba | nur für alte Windows-Clients nötig |
| `ModemManager` | Mobilfunk-Modems | überflüssig |
| `triggerhappy` | Tastatur-Hotkeys | überflüssig (headless) |
| `wpa_supplicant` | WLAN | überflüssig (`wlan0` DOWN) |
| `cron`, `polkit`, `dbus`, `systemd-*` | Systembasis | erforderlich |
