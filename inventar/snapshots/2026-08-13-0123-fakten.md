# Kennzahlen -- 13.08.2026

Erzeugt von `inventar/collect.sh`. Diese Datei ist die Grundlage fuer den
Abgleich mit der bestehenden Dokumentation.

## System

| Kennzahl | Wert |
|---|---|
| Modell | Raspberry Pi 4 Model B Rev 1.1 |
| OS | Debian GNU/Linux 12 (bookworm) |
| Kernel | 6.12.96+rpt-rpi-v8 |
| Uptime | up 2 weeks, 2 days, 47 minutes |
| Load | 0.18 0.24 0.22 |
| Temperatur | 49.6'C |
| Throttled | 0x0 |
| RAM verfuegbar | 2.4Gi von 3.7Gi |
| Root belegt | 8.9G von 235G (5%) |
| SSD belegt | 310G von 916G (36%) |
| Ausstehende Updates | 0 |
| Fehlgeschlagene Dienste | 0 |

## Container

| Name | Image | Status | Ports |
|---|---|---|---|
| Dashy | lissy93/dashy | Up 2 weeks (healthy) | 0.0.0.0:8080->8080/tcp, [::]:8080->8080/tcp |
| filebrowser | filebrowser/filebrowser:latest | Up 2 weeks (healthy) | 0.0.0.0:8082->80/tcp, [::]:8082->80/tcp |
| bichon | rustmailer/bichon:latest | Up 2 weeks (healthy) | 0.0.0.0:15630->15630/tcp, [::]:15630->15630/tcp |
| portainer | portainer/portainer-ce:latest | Up 2 weeks | 0.0.0.0:9000->9000/tcp, [::]:9000->9000/tcp, 8000/tcp, 0.0.0.0:9443->9443/tcp, [::]:9443->9443/tcp |
| paperless-paperless-db-1 | postgres:15 | Up 2 weeks | 5432/tcp |
| paperless | ghcr.io/paperless-ngx/paperless-ngx:latest | Up 2 weeks (healthy) | 0.0.0.0:8000->8000/tcp, [::]:8000->8000/tcp |
| paperless-paperless-redis-1 | redis:7 | Up 2 weeks | 6379/tcp |

## Image-Alter

| Image | Alter |
|---|---|
| rustmailer/bichon:latest | 8 months ago |
| filebrowser/filebrowser:latest | 8 months ago |
| portainer/portainer-ce:latest | 8 months ago |
| lissy93/dashy:latest | 9 months ago |
| redis:7 | 15 months ago |
| ghcr.io/paperless-ngx/paperless-ngx:latest | 16 months ago |
| postgres:15 | 17 months ago |
| lissy93/dashy:3.0.1 | 2 years ago |
| lissy93/dashy:arm64v8 | 4 years ago |

## Offene Ports

```
0.0.0.0:139 "smbd",pid=803,fd=31
0.0.0.0:15630 "docker-proxy",pid=2057,fd=8
0.0.0.0:22 "sshd",pid=708,fd=3
0.0.0.0:443 "pihole-FTL",pid=775,fd=36
0.0.0.0:445 "smbd",pid=803,fd=30
0.0.0.0:53 "pihole-FTL",pid=775,fd=22
0.0.0.0:8000 "docker-proxy",pid=2029,fd=8
0.0.0.0:8080 "docker-proxy",pid=2113,fd=8
0.0.0.0:8082 "docker-proxy",pid=2084,fd=8
0.0.0.0:80 "pihole-FTL",pid=775,fd=35
0.0.0.0:9000 "docker-proxy",pid=1968,fd=8
0.0.0.0:9443 "docker-proxy",pid=1996,fd=8
127.0.0.1:5335 "unbound",pid=707,fd=4
[::]:139 "smbd",pid=803,fd=29
[::]:15630 "docker-proxy",pid=2065,fd=8
[::]:22 "sshd",pid=708,fd=4
[::]:443 "pihole-FTL",pid=775,fd=38
[::]:445 "smbd",pid=803,fd=28
[::]:53 "pihole-FTL",pid=775,fd=24
[::]:8000 "docker-proxy",pid=2036,fd=8
[::]:8080 "docker-proxy",pid=2120,fd=8
[::]:8082 "docker-proxy",pid=2091,fd=8
[::]:80 "pihole-FTL",pid=775,fd=37
[::]:9000 "docker-proxy",pid=1977,fd=8
[::]:9443 "docker-proxy",pid=2004,fd=8
```

## Sicherheitslage

| Pruefpunkt | Zustand |
|---|---|
| ufw | nicht installiert |
| fail2ban | nicht installiert |
| SSH Passwortlogin | yes |
| unattended-upgrades | nicht aktiv |
| iptables INPUT policy | policy ACCEPT |

## Backup-Lage

| Pruefpunkt | Zustand |
|---|---|
| Cronjobs (simon) | 0 |
| Cronjobs (root) | 0 |
| restic | nicht installiert |
| rclone-Remotes | onedrive: dropbox:  |
| Letzter rclone-Log-Eintrag | 12.12.2025 |

## Compose-Repository

```
## main...origin/main
 D dashy/config/conf.yml
 M dashy/docker-compose.yml
```
