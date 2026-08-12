# 03 — Netzwerk

*Erfasst: 13.08.2026*

## Anbindung

| Merkmal | Wert |
|---|---|
| Aktive Schnittstelle | `eth0` (Gigabit-Ethernet, kabelgebunden) |
| IPv4 | `192.168.178.80/24` |
| Gateway | `192.168.178.1` (FRITZ!Box) |
| Router-Metrik | 1002 |
| WLAN (`wlan0`) | vorhanden, **DOWN** — nicht in Betrieb |

Kabelgebunden ist für einen Server, der DNS für das gesamte Heimnetz bereitstellt, die
richtige Wahl: Bei einem WLAN-Aussetzer würde im ganzen Haus die Namensauflösung
ausfallen.

## IPv6

| Typ | Adresse | Reichweite |
|---|---|---|
| ULA (privat) | `fdd9:128:ed22:0:1bd6:bc23:2ab1:d5da/64` | nur lokales Netz |
| **GUA (global)** | `2a02:8071:2c83:1440:f534:6e65:78af:735d/64` | **weltweit routbar** |
| Link-Local | `fe80::7440:ebae:4350:582f/64` | nur Segment |

### ⚠️ Was die globale IPv6-Adresse bedeutet

Anders als bei IPv4 steckt der Pi bei IPv6 nicht hinter NAT. Er hat eine eigene,
weltweit erreichbare Adresse. Ob jemand von außen darauf zugreifen kann, entscheidet
**allein die Firewall der FRITZ!Box**.

Standardmäßig blockiert die FRITZ!Box eingehende IPv6-Verbindungen. Das Problem ist die
fehlende zweite Verteidigungslinie: Auf dem Pi selbst läuft **keine Firewall**
(siehe [07 — Sicherheit](07-sicherheit.md)). Wenn in der FRITZ!Box versehentlich
„Selbstständige Portfreigaben für IPv6-Geräte erlauben" aktiviert wird oder eine
Freigabe zu weit gefasst ist, stehen Pi-hole-Oberfläche, Portainer, Paperless und
Filebrowser **sofort und ungeschützt im Internet**.

**Zu prüfen (manuell, in der FRITZ!Box):**
*Internet → Freigaben → Portfreigaben* — dort die IPv6-Einstellungen des Geräts
`raspberrypi` kontrollieren. Erwartung: keine Freigaben außer ggf. WireGuard.

## Routing

```
default via 192.168.178.1 dev eth0 src 192.168.178.80 metric 1002
10.66.66.0/24 dev wg0 proto kernel scope link src 10.66.66.1
169.254.0.0/16 dev veth… (mehrfach, Docker)
```

Die zahlreichen `169.254.0.0/16`-Routen auf `veth`-Schnittstellen sind
Link-Local-Adressen der Docker-Container. Sie entstehen, weil `NetworkManager` auch die
virtuellen Container-Schnittstellen anfasst — kosmetisch unschön, funktional
unkritisch. Siehe dazu den Befund zu den zwei Netzwerk-Managern in
[02 — Betriebssystem](02-betriebssystem.md).

## WireGuard-Tunnel

| | |
|---|---|
| Schnittstelle | `wg0` |
| Server-Adresse | `10.66.66.1/24` |
| Port | **51820/UDP** |
| Peers | 1 (`10.66.66.2/32`) |

Details in [04 — Systemdienste](04-dienste-system.md).

## Docker-Netzwerke

| Bridge | Netz | Stack |
|---|---|---|
| `br-5b3f94d4d9ce` | `172.20.0.0/16` | bichon |
| `br-0c5104073e48` | `172.22.0.0/16` | dashy |
| `br-3a32f2228553` | `172.18.0.0/16` | paperless |
| `br-4123f2bc2193` | `172.19.0.0/16` | portainer |
| `br-46c78dafdfb7` | `172.21.0.0/16` | filebrowser |
| `docker0` | `172.17.0.0/16` | **DOWN**, ungenutzt |

**Bewertung:** Jeder Compose-Stack hat sein eigenes Netz — das ist die saubere Variante.
Container können nur die Dienste im eigenen Stack direkt erreichen. Paperless kann so
etwa nicht auf die Filebrowser-Datenbank zugreifen, obwohl beide auf demselben Host
laufen.

Der ungenutzte `docker0` ist der Standard-Bridge, den Compose-Projekte nicht verwenden.
Dass er DOWN ist, bestätigt: Es läuft kein Container außerhalb eines Compose-Stacks.

## Belegte Ports (extern erreichbar)

| Port | Dienst | Bindung |
|---|---|---|
| 22 | SSH | `0.0.0.0` + `[::]` |
| 53 | Pi-hole DNS | `0.0.0.0` + `[::]` |
| 80 | Pi-hole Web | `0.0.0.0` + `[::]` |
| 443 | Pi-hole | `0.0.0.0` + `[::]` |
| 139 / 445 | Samba | `0.0.0.0` + `[::]` |
| 8000 | Paperless-ngx | `0.0.0.0` + `[::]` |
| 8080 | Dashy | `0.0.0.0` + `[::]` |
| 8082 | Filebrowser | `0.0.0.0` + `[::]` |
| 9000 / 9443 | Portainer | `0.0.0.0` + `[::]` |
| 15630 | Bichon | `0.0.0.0` + `[::]` |
| 51820/UDP | WireGuard | — |

### Nur lokal gebunden

| Port | Dienst |
|---|---|
| `127.0.0.1:5335` | unbound |

**Bewertung:** Dass unbound ausschließlich auf `127.0.0.1` lauscht, ist genau richtig —
ein offener rekursiver Resolver im Netz wäre für DNS-Amplification-Angriffe missbrauchbar.

Alle übrigen Dienste binden auf `0.0.0.0` **und** `[::]`, sind also über IPv4 *und* IPv6
erreichbar. Innerhalb des Heimnetzes ist das beabsichtigt. In Verbindung mit der
globalen IPv6-Adresse und fehlender lokaler Firewall ist es allerdings der Punkt, an dem
eine einzige Fehlkonfiguration in der FRITZ!Box teuer wird.
