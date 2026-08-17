# 15 — Änderungshistorie des Systems

*Erfasst: 18.08.2026*

Dieses Kapitel ist das Betriebstagebuch des Pi: **was am laufenden System geändert
wurde, wann und warum**. Es beantwortet die Frage „seit wann ist das eigentlich so?"
und, wichtiger noch, „warum haben wir das damals so entschieden?".

> **Abgrenzung zum [CHANGELOG](../CHANGELOG.md):** Der CHANGELOG verzeichnet Änderungen
> an *dieser Dokumentation*. Hier stehen Änderungen am *System*. Beides gehört zusammen,
> ist aber nicht dasselbe: Eine reine Aktualisierung von Messwerten erscheint im
> CHANGELOG, nicht hier. Ein Systemumbau erscheint in beiden.

**Was hier hineingehört:** neue oder entfernte Dienste, Versionswechsel mit Folgen,
geänderte Ports und Zugriffswege, Sicherheitsentscheidungen, Umbauten an Speicher und
Backup.

**Was nicht:** Tests, Fehlersuche ohne Ergebnis, reine Abfragen, Container-Neustarts.

---

## 18.08.2026 — WireGuard durch Tailscale ersetzt

| | |
|---|---|
| Betroffen | Fernzugriff, DNS unterwegs, Backup-Umfang, Homepage-Kachel |
| Kapitel | [03](03-netzwerk.md), [04](04-dienste-system.md), [07](07-sicherheit.md), [10](10-zugriff.md), [11](11-disaster-recovery.md), [12](12-backup.md) |

**Anlass.** Eine für das iPhone eingerichtete WireGuard-Verbindung funktionierte nicht.

**Befund.** WireGuard selbst war korrekt konfiguriert — Dienst aktiv, Schnittstelle
`wg0` oben, Port 51820 gebunden, Weiterleitung eingeschaltet, keine störende
Firewall-Regel. Der eingetragene Peer hatte jedoch **null übertragene Bytes und keinen
einzigen Handshake**: Es hatte nie eine Verbindung gegeben.

Die Ursache lag außerhalb des Pi. Der Anschluss (FRITZ!Box 6660 Cable an Vodafone Kabel)
läuft über **DS-Lite**. Die FRITZ!Box meldet über UPnP keine eigene öffentliche
IPv4-Adresse; die nach außen sichtbare `92.208.222.35` gehört dem Provider und wird von
vielen Kunden geteilt. Eine Portfreigabe für 51820/UDP ist damit technisch unmöglich —
unabhängig von jeder Konfiguration auf dem Pi.

**Erwogene Wege.**

| Weg | Bewertung |
|---|---|
| WireGuard über IPv6 + MyFRITZ | Machbar, bleibt in Eigenregie. Aber nur nutzbar, wenn das Netz unterwegs IPv6 spricht — in fremden WLANs oft nicht der Fall |
| Dual-Stack bei Vodafone beantragen | Ausgang ungewiss, Wartezeit Wochen |
| Headscale (Tailscale selbst gehostet) | Scheitert am selben Problem: Der Koordinationsserver müsste von außen erreichbar sein |
| **Tailscale** | Gewählt. Funktioniert in jedem Netz, kein eingehender Port nötig |

**Entscheidung.** Tailscale, bewusst mit der Abhängigkeit von einem fremden
Vermittlungsdienst und vom GitHub-Konto als Anmeldung. Ohne fremden Server ist an einem
DS-Lite-Anschluss kein verlässlicher Fernzugriff möglich; das war die Abwägung.

**Durchgeführt.**

- Tailscale 1.102.2 aus dem offiziellen Debian-Repository installiert
- Angemeldet über GitHub (`qsimonbrn`), Tailnet `tailf372ec.ts.net`
- Pi als **Subnetz-Router** für `192.168.178.0/24` und als **Exit Node** freigegeben
- `--accept-dns=false` gesetzt, damit der Pi seinen eigenen Resolver behält
- IPv6-Weiterleitung dauerhaft in `/etc/sysctl.d/99-tailscale.conf` verankert
- **Schlüsselablauf deaktiviert** — sonst hätte sich der Pi nach 180 Tagen abgemeldet
- Pi-hole `listeningMode` von `LOCAL` auf `ALL` umgestellt (Begründung unten)
- In der Tailscale-Verwaltung `100.108.219.87` als Global Nameserver gesetzt,
  „Override DNS servers" aktiviert
- WireGuard-Dienst deaktiviert, Pakete entfernt, `/etc/wireguard` gelöscht;
  Sicherungskopie unter `/root/wireguard-entfernt-20260818.tar.gz` (Modus 600)
- Backup-Skript sichert `/var/lib/tailscale` statt `/etc/wireguard`
- Homepage-Kachel von WireGuard auf Tailscale geändert

**Zur Pi-hole-Umstellung.** Die Schnittstelle `tailscale0` trägt eine `/32`-Adresse.
Im Modus `LOCAL` gilt damit jede andere Tailnet-Adresse als „nicht lokal", und Pi-hole
hätte die Anfragen des iPhones abgewiesen. `ALL` ist hier vertretbar, weil kein
eingehender Port aus dem Internet existiert — es gibt keine Portfreigabe, und die
FRITZ!Box blockiert eingehendes IPv6. Sollte sich daran je etwas ändern, muss diese
Einstellung erneut geprüft werden, sonst entsteht ein offener DNS-Resolver.

**Nachgemessen.** Handshake steht, das iPhone verbindet sich direkt über IPv6. DNS-Anfragen
des iPhones erscheinen in der Pi-hole-Abfrageliste und werden gefiltert — darunter
`mask.icloud.com`, wodurch Apples *iCloud Private Relay* nicht am Filter vorbeiläuft.
Alle Dienste (8000, 3000, 8080, 8082, 9000, 2586, 80) sind über die Tailnet-Adresse
erreichbar. Über Mobilfunk vom Nutzer bestätigt.

---

## Ältere Änderungen

Vor dem 18.08.2026 wurden Systemänderungen nicht gesondert festgehalten. Nachvollziehbar
sind sie über den [CHANGELOG](../CHANGELOG.md) und die Git-Historie der beiden
Repositories `raspi-doku` und `docker-stacks`. Bekannte Eckdaten:

| Datum | Änderung |
|---|---|
| 16.08.2026 | Alle Docker-Images auf feste Versionen gepinnt |
| 13.08.2026 | restic-Backup nach OneDrive eingerichtet, Benachrichtigung über ntfy |
| 23.04.2025 | WireGuard eingerichtet (nie von außen erreichbar, siehe oben) |

---

## Vorlage für neue Einträge

```markdown
## TT.MM.JJJJ — Kurzer Titel

| | |
|---|---|
| Betroffen | Welche Bereiche |
| Kapitel | Verweise auf die aktualisierten Kapitel |

**Anlass.** Warum wurde etwas geändert?

**Befund.** Was wurde gemessen? Zahlen, keine Vermutungen.

**Entscheidung.** Was wurde gewählt, welche Alternativen gab es, welcher Preis
wurde bewusst in Kauf genommen?

**Durchgeführt.** Konkrete Schritte.

**Nachgemessen.** Woran ist erkennbar, dass es wirkt?
```
