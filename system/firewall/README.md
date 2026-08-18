# pi-guard — Zugriffsbegrenzung auf Verwaltungsoberflächen

Begrenzt den Zugriff auf ausgewählte Ports auf Tailscale und den Pi selbst. Aus dem
Heimnetz sind diese Dienste nicht mehr erreichbar.

## Warum nicht einfach ufw?

Docker schreibt eigene iptables-Regeln, die `ufw` **umgehen**. Eine mit `ufw`
eingerichtete Sperre für Container-Ports sieht aus, als würde sie wirken, tut es aber
nicht. Der vom Hersteller vorgesehene Einhängepunkt ist die Kette `DOCKER-USER`, die vor
allen Docker-Regeln ausgewertet wird.

## Warum zwei Ketten?

Es gibt zwei Wege, auf denen ein Paket einen Container erreicht:

| Weg | Kette | Wann |
|---|---|---|
| Docker leitet per DNAT direkt an den Container | `FORWARD` → `DOCKER-USER` | üblicher Fall bei IPv4 |
| Der `userland-proxy` nimmt die Verbindung auf dem Host an | `INPUT` | vor allem bei IPv6 |

Nur eine der beiden Ketten zu belegen, lässt ein Loch offen. `pi-guard` belegt beide,
jeweils für IPv4 und IPv6.

## Gesperrte Ports (Stand 18.08.2026)

| Port | Dienst | Grund |
|---|---|---|
| 9000, 9443 | Portainer | Vollzugriff auf den Docker-Socket — ein Passwort trennt einen Angreifer von Systemrechten |
| 15630 | Bichon | E-Mail-Archiv, Image acht Monate alt |
| 8000 | Paperless | Dokumentenarchiv |

## Bewusst offen gelassen

| Port | Dienst | Begründung |
|---|---|---|
| 22 | SSH | Rettungsanker, falls Tailscale ausfällt. Nur Schlüsselanmeldung |
| 53 | Pi-hole DNS | Das ganze Haus hängt daran |
| 80, 443 | Pi-hole-Web | Vorerst im LAN belassen, hat ein eigenes Passwort |
| 139, 445 | Samba | Dateizugriff im Heimnetz, eigene Anmeldung |
| 2586 | ntfy | Mit `auth-default-access: deny-all` abgesichert, nachgemessen |
| 3000 | Homepage | Reines Linkverzeichnis, Socket-Proxy nur lesend |

## Bedienung

```bash
sudo systemctl status pi-guard      # läuft es?
sudo /usr/local/sbin/pi-guard.sh status   # Regeln samt Trefferzählern
sudo systemctl stop pi-guard        # Regeln vorübergehend entfernen
```

Das Skript ist idempotent — mehrfaches Ausführen ändert nichts. Es startet nach
`docker.service`, damit die Kette `DOCKER-USER` bereits existiert.

## Installiert unter

`/usr/local/sbin/pi-guard.sh` · `/etc/systemd/system/pi-guard.service`
Die Dateien hier sind die versionierte Kopie.
