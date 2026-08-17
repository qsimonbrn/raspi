# 04 — Systemdienste

*Erfasst: 18.08.2026*

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

### iCloud Private Relay wird absichtlich blockiert

**Symptom.** Apple-Geräte melden gelegentlich, Private Relay sei in diesem Netzwerk
nicht verfügbar. Bei Gästen, die das WLAN zum ersten Mal betreten, erscheint die Meldung
regelmäßig; sie müssen Private Relay abschalten, bevor alles rund läuft.

**Das ist kein Fehler, sondern eine Voreinstellung von Pi-hole.**

| | |
|---|---|
| Einstellung | `dns.specialDomains.iCloudPrivateRelay = true` (Standard) |
| Wirkung | NXDOMAIN auf `mask.icloud.com` und `mask-h2.icloud.com` |
| Herkunft | eingebaut in Pi-hole — **nicht** aus einer der Blocklisten |
| Nachweis | `dig @127.0.0.1 mask.icloud.com` → `status: NXDOMAIN`; in der Abfrageliste erscheinen diese Domains mit Status 16 (`SPECIAL_DOMAIN`) |

**Warum das so gebaut ist.** Private Relay leitet Safaris Datenverkehr *und dessen
DNS-Anfragen* über Apples Server. Ein Gerät mit aktivem Private Relay umgeht Pi-hole
also — jedenfalls in Safari. Pi-hole schließt diese Lücke, indem es die Anmeldung beim
Relay verhindert.

Bemerkenswert: **Apple empfiehlt genau dieses Verfahren selbst.** In der Anleitung für
Netzwerkbetreiber steht, eine NXDOMAIN-Antwort auf diese beiden Namen sei der schnellste
und zuverlässigste Weg, und die Nutzer würden daraufhin benachrichtigt, Private Relay
für dieses Netz abzuschalten oder ein anderes Netz zu wählen. Die Meldung ist also
vorgesehenes Verhalten, kein Defekt.

**Was Private Relay tatsächlich umfasst** — wichtig für die Abwägung:

| Bereich | Mit aktivem Private Relay |
|---|---|
| Safari | läuft an Pi-hole vorbei, ungefiltert |
| Apps, auch mit HTTPS | fragen weiterhin Pi-hole, **bleiben gefiltert** |
| Andere Browser (Chrome, Firefox) | bleiben gefiltert |
| Geräte ohne Apple-Konto | unberührt |

Es entsteht also ein Loch, kein Totalausfall — allerdings genau dort, wo Werbung am
meisten auffällt.

### Was man Gästen sagt

> „Kurz in Einstellungen → WLAN → auf das **(i)** neben dem Netznamen tippen → *iCloud
> Private Relay* ausschalten. Das gilt nur für dieses WLAN; unterwegs bleibt es aktiv."

Der Schalter ist netzbezogen. Wer ihn hier deaktiviert, verliert Private Relay
anderswo nicht.

### Geprüfte Alternative, falls es künftig stören sollte

Am 18.08.2026 auf diesem Pi nachgemessen: Ein **Allowlist-Eintrag überstimmt die
eingebaute Sperre** (vorher NXDOMAIN, nach `pihole allow mask.icloud.com` reguläre
Auflösung; Testeintrag anschließend wieder entfernt). Da Allowlist-Einträge einzelnen
Gerätegruppen zugewiesen werden können, ließe sich beides trennen:

1. `mask.icloud.com` und `mask-h2.icloud.com` auf die Allowlist, zugewiesen **nur** der
   Standardgruppe
2. Die eigenen Apple-Geräte als Clients anlegen und einer eigenen Gruppe ohne diese
   Ausnahme zuordnen

Ergebnis: Gäste kommen ohne Warnung ins Netz und verlieren dabei die Safari-Filterung,
die eigenen Geräte bleiben vollständig gefiltert. **Bewusst nicht umgesetzt** — die
volle Filterwirkung wiegt schwerer als die gelegentliche Erklärung an Gäste.

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

## Tailscale — VPN-Fernzugriff

Seit dem 18.08.2026 läuft der Fernzugriff über Tailscale. Es ersetzt die vorherige
WireGuard-Installation, die von außen nie erreichbar war — die Begründung steht
weiter unten.

| | |
|---|---|
| Version | 1.102.2 |
| Dienst | `tailscaled` — aktiviert, läuft |
| Tailnet | `tailf372ec.ts.net` |
| Konto | GitHub (`qsimonbrn`) |
| Schnittstelle | `tailscale0` |
| Adresse des Pi | `100.108.219.87` · `fd7a:115c:a1e0::aa01:dbd5` |
| Name im Tailnet | `raspberrypi.tailf372ec.ts.net` (MagicDNS) |
| Zustand und Schlüssel | `/var/lib/tailscale/` (Modus 700) |
| Schlüsselablauf | **deaktiviert** — der Pi meldet sich nicht selbsttätig ab |

### Rolle des Pi im Tailnet

| Funktion | Zustand | Wirkung |
|---|---|---|
| Subnetz-Router | aktiv für `192.168.178.0/24` | Verbundene Geräte erreichen das ganze Heimnetz, nicht nur den Pi — etwa die FRITZ!Box unter `192.168.178.1` |
| Exit Node | angeboten und freigegeben | Auf Wunsch läuft der **gesamte** Verkehr eines Clients über den Anschluss zuhause. Am Client einzeln zuschaltbar, im Alltag aus |
| DNS-Server | `100.108.219.87` als Global Nameserver | Alle Geräte im Tailnet nutzen Pi-hole, auch unterwegs |
| `--accept-dns` | **false** | Der Pi darf sein eigenes DNS nicht überschreiben lassen — er *ist* der Resolver |

### Verbundene Geräte

| Gerät | Tailnet-Adresse | System |
|---|---|---|
| `raspberrypi` | `100.108.219.87` | Linux |
| `iphone-sibr` | `100.94.181.68` | iOS |

### Warum WireGuard ersetzt wurde

Der Anschluss läuft über eine FRITZ!Box 6660 Cable an Vodafone Kabel — und damit über
**DS-Lite**. Die öffentliche IPv4-Adresse `92.208.222.35` gehört dem Provider und wird
von vielen Kunden geteilt; die FRITZ!Box meldet über UPnP gar keine eigene externe
IPv4-Adresse. Eine Portfreigabe für 51820/UDP war damit technisch unmöglich. Die
Messung bestätigte das: Der eingerichtete Peer hatte **null Bytes und keinen einzigen
Handshake** — es hat nie eine Verbindung gegeben.

Tailscale löst das, weil beide Geräte die Verbindung von innen nach außen aufbauen. Es
muss nichts von außen hereinkommen, und DS-Lite spielt keine Rolle mehr. Als Verschlüsselung
kommt weiterhin WireGuard zum Einsatz — nur die Verbindungsvermittlung ist eine andere.

**Preis dieser Lösung:** Die Vermittlung läuft über Server von Tailscale (US-Unternehmen).
Diese kennen Metadaten — welche Geräte wann online sind und über welche IP-Adressen sie
sprechen. Die übertragenen Inhalte sind zwischen den eigenen Geräten Ende zu Ende
verschlüsselt und für Tailscale auch dann nicht lesbar, wenn der Verkehr über deren
Relays läuft. Der Zugang zum Heimnetz hängt zusätzlich am GitHub-Konto: Wer dieses
übernimmt, kommt auf den Pi. Zwei-Faktor-Anmeldung bei GitHub ist deshalb Pflicht.

**Bewertung:** Sachlich die richtige Entscheidung, weil sie die einzige war, die am
DS-Lite-Anschluss ohne fremden Server überhaupt funktioniert. Die Abhängigkeit von einem
Anbieter ist der bewusst in Kauf genommene Preis. Anders als zuvor ist der Fernzugriff
jetzt nachweislich in Betrieb.

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
