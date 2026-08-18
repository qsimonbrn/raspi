# 03 — Netzwerk

*Erfasst: 18.08.2026*

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
Paperless **sofort und ungeschützt im Internet**.

**Zu prüfen (manuell, in der FRITZ!Box):**
*Internet → Freigaben → Portfreigaben* — dort die IPv6-Einstellungen des Geräts
`raspberrypi` kontrollieren. Erwartung: **keine Freigaben**. Seit der Umstellung auf
Tailscale wird von außen kein einziger eingehender Port mehr benötigt.

## Routing

```
default via 192.168.178.1 dev eth0 src 192.168.178.80 metric 1002
100.108.219.87 dev tailscale0 proto kernel scope link
192.168.178.0/24 dev eth0 proto kernel scope link src 192.168.178.80
169.254.0.0/16 dev veth… (mehrfach, Docker)
```

Die zahlreichen `169.254.0.0/16`-Routen auf `veth`-Schnittstellen sind
Link-Local-Adressen der Docker-Container. Sie entstehen, weil `NetworkManager` auch die
virtuellen Container-Schnittstellen anfasst — kosmetisch unschön, funktional
unkritisch. Siehe dazu den Befund zu den zwei Netzwerk-Managern in
[02 — Betriebssystem](02-betriebssystem.md).

## Tailscale-Netz

| | |
|---|---|
| Schnittstelle | `tailscale0` |
| Adresse des Pi | `100.108.219.87/32` · `fd7a:115c:a1e0::aa01:dbd5/128` |
| Tailnet-Bereich | `100.64.0.0/10` (CGNAT-Bereich, von Tailscale genutzt) |
| Eingehender Port | **keiner** — Verbindungen werden von innen aufgebaut |
| Beworbene Route | `192.168.178.0/24` (Subnetz-Router) |

Der Pi ist unter `100.108.219.87` aus jedem verbundenen Gerät erreichbar, unabhängig
vom Standort. Über den Subnetz-Router gilt das auch für alle anderen Geräte im
Heimnetz.

Die Ablösung von WireGuard und ihre Begründung stehen in
[04 — Systemdienste](04-dienste-system.md).

## Docker-Netzwerke

| Bridge | Netz | Stack |
|---|---|---|
| `br-5b3f94d4d9ce` | `172.20.0.0/16` | bichon |
| `br-cc867486ae27` | `172.23.0.0/16` | homepage |
| `br-f56477634ea2` | `172.24.0.0/16` | ntfy |
| `br-3a32f2228553` | `172.18.0.0/16` | paperless |
| `br-4123f2bc2193` | `172.19.0.0/16` | portainer |
| `docker0` | `172.17.0.0/16` | **DOWN**, ungenutzt |

Die Netze von Dashy (`172.22.0.0/16`) und Filebrowser (`172.21.0.0/16`) sind mit den
Diensten am 18.08.2026 entfallen.

**Bewertung:** Jeder Compose-Stack hat sein eigenes Netz — das ist die saubere Variante.
Container können nur die Dienste im eigenen Stack direkt erreichen. Paperless kann so
etwa nicht auf die Bichon-Datenbank zugreifen, obwohl beide auf demselben Host
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
| 2586 | ntfy (Benachrichtigungen) | `0.0.0.0` + `[::]` |
| 3000 | Homepage (Dashboard) | `0.0.0.0` + `[::]` |
| 8000 | Paperless-ngx | `0.0.0.0` + `[::]` — 🔒 per Firewall auf Tailscale begrenzt |
| 9000 / 9443 | Portainer | `0.0.0.0` + `[::]` — 🔒 per Firewall auf Tailscale begrenzt |
| 15630 | Bichon | `0.0.0.0` + `[::]` — 🔒 per Firewall auf Tailscale begrenzt |
| zufällig (UDP) | Tailscale (`tailscaled`) | `100.108.219.87` + Tailnet-IPv6 |

> **🔒 bedeutet nicht „nicht gebunden".** Diese Dienste lauschen weiterhin auf allen
> Adressen — die Begrenzung erfolgt in der Firewall (`pi-guard`), nicht in der Bindung.
> Die Portliste sieht deshalb unverändert aus, obwohl aus dem Heimnetz nichts mehr
> durchkommt. Siehe [07 — Sicherheit](07-sicherheit.md).

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
