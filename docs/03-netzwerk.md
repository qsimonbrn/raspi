# 03 — Netzwerk

*Erfasst: 18.08.2026 · ergänzt 23.08.2026 · Netze und Ports nachgemessen: 13.09.2026*

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
| Von `tailscaled` belegt | **8443** (`tailscale serve` → Vaultwarden) und **8444** (→ ntfy), nur auf `100.108.219.87` und der Tailnet-IPv6 |
| Nur über das Tailnet nutzbar | **5678** (n8n) — der Port ist auf allen Schnittstellen veröffentlicht, `pi-guard` verwirft ihn aber auf `eth0`, siehe [19](19-n8n.md) |
| Beworbene Route | `192.168.178.0/24` (Subnetz-Router) |

Der Pi ist unter `100.108.219.87` aus jedem verbundenen Gerät erreichbar, unabhängig
vom Standort. Über den Subnetz-Router gilt das auch für alle anderen Geräte im
Heimnetz.

Die Ablösung von WireGuard und ihre Begründung stehen in
[04 — Systemdienste](04-dienste-system.md).

## Docker-Netzwerke

*Nachgemessen am 13.09.2026.*

| Bridge | Netz | Stack bzw. Zweck | Container darin |
|---|---|---|---|
| `br-3a32f2228553` | `172.18.0.0/16` | paperless | paperless, paperless-db-1, paperless-redis-1 |
| `br-4123f2bc2193` | `172.19.0.0/16` | portainer | portainer |
| `br-5b3f94d4d9ce` | `172.20.0.0/16` | bichon | bichon |
| `br-595d6ab60da4` | `172.21.0.0/16` | vaultwarden | vaultwarden |
| `br-5e5230370cca` | `172.22.0.0/16` | diun | diun, diun-dockerproxy |
| `br-cc867486ae27` | `172.23.0.0/16` | homepage | homepage, homepage-dockerproxy |
| `br-f56477634ea2` | `172.24.0.0/16` | ntfy | ntfy |
| `br-18b595dd662e` | `172.25.0.0/16` | insta-triage | insta-triage |
| `br-1e6c4fb71502` | `172.26.0.0/16` | `n8n_default` | **leer** — siehe unten |
| `br-a802d3804ca0` | `172.27.0.0/16` | **`werkbank`** — stackübergreifend, außerhalb beider Stacks angelegt | n8n, yt-werk |
| `docker0` | `172.17.0.0/16` | Standard-Bridge | **DOWN**, ungenutzt |

Die Netze von Dashy und Filebrowser sind mit den Diensten am 18.08.2026 entfallen; ihre
damaligen Nummern (`172.21`, `172.22`) sind inzwischen an Vaultwarden und Diun neu
vergeben. Die Zuordnung Bridge → Stack ist deshalb nichts, was man aus einer alten
Fassung dieser Tabelle ablesen darf.

**Bewertung:** Die Grundregel gilt weiter — jeder Compose-Stack hat sein eigenes Netz,
und Container erreichen einander nur innerhalb des eigenen Stacks. Paperless kann so etwa
nicht auf die Bichon-Datenbank zugreifen, obwohl beide auf demselben Host laufen.

**`werkbank` ist seit dem 12.09.2026 die eine bewusste Ausnahme.** n8n und `yt-werk`
liegen in zwei getrennten Stacks, müssen sich aber erreichen: n8n ruft den Sidecar unter
`http://yt-werk:8722` auf. Das Netz ist deshalb **außerhalb beider Stacks** angelegt
(`docker network create werkbank`, in beiden Compose-Dateien als `external: true`
eingetragen) — läge es in einem der beiden, zöge ein `compose down` es dem anderen unter
den Füßen weg. Der Preis der Ausnahme ist benannt: Zwischen diesen beiden Containern
trennt die Stack-Grenze nicht mehr. Vertretbar ist sie, weil `yt-werk` überhaupt keinen
Port auf dem Host veröffentlicht und damit *ausschließlich* über dieses Netz erreichbar
ist — siehe [20 — yt-werk](20-yt-werk.md).

**`n8n_default` ist seit dem 12.09.2026 leer**, weil n8n nur noch in `werkbank` hängt.
Compose legt das Netz beim nächsten `up` trotzdem wieder an; es kostet nichts außer einer
Zeile in dieser Tabelle. Aufräumen: [09 — Empfehlungen](09-empfehlungen.md), 3.4.

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
| 5678 | n8n | `0.0.0.0` + `[::]` — 🔒 per Firewall auf Tailscale begrenzt |
| 8080 | insta-triage | **nur `100.108.219.87`** — an die Tailscale-Adresse gebunden, lauscht im Heimnetz gar nicht |
| zufällig (UDP) | Tailscale (`tailscaled`) | `100.108.219.87` + Tailnet-IPv6 |

> **🔒 bedeutet nicht „nicht gebunden".** Diese Dienste lauschen weiterhin auf allen
> Adressen — die Begrenzung erfolgt in der Firewall (`pi-guard`), nicht in der Bindung.
> Die Portliste sieht deshalb unverändert aus, obwohl aus dem Heimnetz nichts mehr
> durchkommt. Siehe [07 — Sicherheit](07-sicherheit.md).

### Nur lokal gebunden

| Port | Dienst |
|---|---|
| `127.0.0.1:5335` | unbound |
| `127.0.0.1:8222` | Vaultwarden — von außen nur über `tailscale serve` auf 8443, siehe [18](18-vaultwarden.md) |

**Gar nicht auf dem Host:** `yt-werk` lauscht auf 8722, aber nur *im Container*. Die
Compose-Datei veröffentlicht keinen Port; der Dienst taucht in `ss -tulpn` deshalb nicht
auf und ist ausschließlich aus dem Docker-Netz `werkbank` erreichbar (13.09.2026
nachgemessen). Das ist die dichteste der drei Varianten, die hier vorkommen — dichter als
die Firewall-Sperre (`pi-guard`) und dichter als die Bindung an die Tailscale-Adresse.

**Bewertung:** Dass unbound ausschließlich auf `127.0.0.1` lauscht, ist genau richtig —
ein offener rekursiver Resolver im Netz wäre für DNS-Amplification-Angriffe missbrauchbar.

Alle übrigen Dienste binden auf `0.0.0.0` **und** `[::]`, sind also über IPv4 *und* IPv6
erreichbar. Innerhalb des Heimnetzes ist das beabsichtigt. In Verbindung mit der
globalen IPv6-Adresse und fehlender lokaler Firewall ist es allerdings der Punkt, an dem
eine einzige Fehlkonfiguration in der FRITZ!Box teuer wird.
