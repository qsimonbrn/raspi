# 04 — Systemdienste

*Erfasst: 18.08.2026 · Blocklisten 20.08.2026*

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

### Blocklisten

*Stand: 20.08.2026 — 800.598 eindeutige Domains, vier Listen aktiv*

| Liste | Format | Domains | Zweck |
|---|---|---|---|
| [StevenBlack/hosts](https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts) | Hosts | 95.667 | Werbung und Tracker, breite Grundlage |
| [adaway.org](https://adaway.org/hosts.txt) | Hosts | 6.540 | mobile Werbung |
| [HaGeZi Pro++](https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/pro.plus.txt) | **Adblock** | 245.443 | Werbung, Tracker, Telemetrie, Betrug |
| [HaGeZi Pop-Up Ads](https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/popupads.txt) | **Adblock** | 54.146 | Pop-ups und selbsttätig öffnende Tabs |
| [HaGeZi TIF Medium](https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/tif.medium.txt) | **Adblock** | 439.389 | Scam, Phishing, Malware, C&C-Server |
| [OISD Big](https://big.oisd.nl/) | **Adblock** | 273.269 | breiter Filter, auf wenige Fehlblockaden ausgelegt |

Dazu 17 exakte Sperren (Werbe-SDKs mobiler Apps) und fünf Regex-Regeln für Werbedomains,
die in keiner der sechs geprüften Listen stehen: `girlzsearch.com`, `planeptune.us`,
`405kk.com`, `jump5geo.com`, `openwebschool.de`.

> **Nicht sperren, auch wenn sie so aussehen:** `temp.compsci88.com` und
> `scans.lastation.us` sind die Bildserver von `weebcentral.com` und liefern die
> Seiteninhalte, nicht Werbung.

**Abgeschaltet, nicht gelöscht:** die beiden Listen von `blocklistproject`
(`ads.txt`, `tracking.txt`, zusammen 379.777 Domains). Sie liegen im Hosts-Format,
gelten als anfällig für Fehlblockaden und wurden zuletzt am 26.07. bzw. 19.07.2026
erfolgreich abgerufen. Wer sie wieder braucht, setzt `enabled = 1` in der Tabelle
`adlist` der `gravity.db`.

> **Der wichtigste Punkt zum Verständnis: Hosts-Listen sperren keine Subdomains.**
> Ein Eintrag `magsrv.com` im Hosts-Format sperrt `magsrv.com` — und sonst nichts.
> Das Werbenetzwerk liefert über `s.magsrv.com` aus, und diese Anfrage geht durch.
> Adblock-Listen schreiben stattdessen `||magsrv.com^`, was Pi-hole seit Version 5
> nativ versteht und was die gesamte Domain samt aller Subdomains erfasst.
>
> Bis zum 20.08.2026 lagen **alle vier** eingebundenen Listen im Hosts-Format. Sechs
> von fünfzehn nachgewiesen durchgelassenen Werbedomains hatten ihre Eltern-Domain
> bereits in `gravity` — geblockt wurden sie trotzdem nicht. Das ist der Grund, warum
> eine hohe Domainzahl allein nichts über die Wirksamkeit aussagt.

**Bewusst nicht eingebunden:**

| Liste | Grund |
|---|---|
| HaGeZi Anti-Piracy | sperrt `weebcentral.com` und `mangadex.org` — nachgeprüft |
| HaGeZi DynDNS | sperrte im Test eine tatsächlich genutzte Domain (`dynamic-m.com`), Nutzen im Heimnetz gering |
| HaGeZi TIF (voll) | 2,1 Mio. Einträge, laut Hersteller ab 2 GB RAM; die Medium-Variante reicht |
| Phishing Army | überschneidet sich stark mit TIF Medium |

**Aktualisierung:** täglich um 03:02 über `/etc/cron.d/pihole` (bis 20.08.2026
wöchentlich sonntags). Von Hand: `sudo pihole -g`, Dauer rund 15 Sekunden.

**Speicherbedarf:** `pihole-FTL` belegt mit 800.598 Domains 47 MB. Die Domainzahl ist
für den Speicherbedarf also praktisch bedeutungslos — vor dem Ausbau waren es bei
522.422 Domains 51 MB.

**Wirksamkeit prüfen** — der Weg, der den Befund vom 20.08.2026 aufgedeckt hat:

```bash
# Was hat ein bestimmtes Geraet in den letzten 15 Minuten abgefragt und durfte durch?
sudo pihole-FTL sqlite3 -separator ' | ' /etc/pihole/pihole-FTL.db \
  "select domain, count(*) c from queries
   where client='192.168.178.164'
     and timestamp > strftime('%s','now')-900
     and status in (2,3,12,13,14,17)
   group by domain order by c desc;" </dev/null

# Wird eine Domain tatsaechlich gesperrt? 0.0.0.0 oder leer = ja
dig +short @127.0.0.1 s.magsrv.com A
```

Statuswerte: 1 und 9 geblockt über `gravity`, 2 weitergeleitet, 3 aus dem Cache,
16 Sonderdomain (iCloud Private Relay), 17 aus veraltetem Cache.

**Was DNS-Sperren grundsätzlich nicht leisten.** Ein Tab, den eine Seite per
JavaScript öffnet, geht auf — Pi-hole verhindert nur, dass Inhalt hineingeladen wird.
Werbung, die von der Domain der Seite selbst ausgeliefert wird, ist über DNS nicht
trennbar. Gegen beides hilft nur ein Content-Blocker im Browser. Pi-hole ist die
netzwerkweite Grundsicherung, nicht der vollständige Werbeschutz.

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
| `MaxAuthTries` | 6 | Standard |
| `LogLevel` | `INFO` | protokolliert keine Schlüssel-Fingerabdrücke |

### Wer sich anmeldet

| Konto | Verfahren | Zweck |
|---|---|---|
| `simon` | Schlüssel (`pi-zugriff`, `macbook-simon`) und Passwort | persönliches Konto |
| `claude` | ausschließlich Schlüssel (`pi-claude`), herkunftsgebunden | Automatisierung über den MCP-Server |

Vollständige Beschreibung in [16 — Konten und Rechte](16-konten-und-rechte.md).

### ⚠️ Befund: Passwort-Anmeldung ist aktiv

**Nachgemessen über 60 Tage: 414 Schlüsselanmeldungen gegen 6 per Passwort.** Kein Skript
und kein Dienst meldet sich per Passwort an. Die Passwort-Authentifizierung ist damit ein
Notausgang, den praktisch niemand nutzt — aber zusätzliche Angriffsfläche für jedes Gerät
im Heimnetz. In Verbindung mit dem fehlenden `fail2ban` gibt es dagegen keinerlei Bremse.

**Empfehlung:** `PasswordAuthentication no`, als eigene Datei unter
`/etc/ssh/sshd_config.d/`. Am 18.08.2026 wurde das eingerichtet, erfolgreich getestet und
auf Wunsch wieder zurückgenommen — die Umstellung soll gemeinsam und mit Vorlauf
erfolgen. Bei der Wiederaufnahme ist zu beachten: Eine `AllowUsers`-Zeile müsste
**beide** Konten nennen (`simon claude`), sonst sperrt sie die Automatisierung aus.

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
