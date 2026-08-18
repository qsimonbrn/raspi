# Abgleich Repository <-> System

Ein Teil der Dateien in diesem Repository ist **nicht** das Original. Sie laufen
aus `/etc`, `/usr/local/bin`, `/usr/local/sbin` oder `/boot`; hier liegt nur eine
Kopie. Eine Aenderung, die nur hier passiert, ist wirkungslos.

Am 18.08.2026 ist genau das aufgefallen: `pi_wartung.sh` war hier auf `sudo docker`
umgestellt, die installierte Fassung `/usr/local/sbin/pi-maintenance.sh` nicht.
Sie heisst installiert anders und liegt in `sbin` statt `bin` — zwei Gruende, warum
ein Abgleich von Hand unzuverlaessig ist.

## Bestandteile

| Datei | Zweck |
|---|---|
| `manifest.tsv` | Die Zuordnung. Eine Zeile je Dateipaar mit Systempfad, Besitzer, Rechten und Nachlauf |
| `sync.sh` | Prueft und kopiert — installiert als `/usr/local/sbin/pi-abgleich.sh` |
| `pi-abgleich.service` / `.timer` | Taegliche Pruefung um 09:15, Meldung ueber ntfy **nur bei Abweichung** |

## Benutzung

```bash
sudo pi-abgleich.sh list              # alle Paare mit Zustand und Rechten
sudo pi-abgleich.sh check             # nur pruefen, Exit 1 bei Abweichung
sudo pi-abgleich.sh diff pi_wartung   # Unterschiede im Klartext
sudo pi-abgleich.sh install backup    # Repository -> System, fragt vorher
sudo pi-abgleich.sh pull   daemon     # System -> Repository, fragt vorher
```

Das Muster filtert auf den Repo-Pfad. Ohne Terminal (Automatisierung) verlangen
`install` und `pull` zusaetzlich `--ja`.

## Warum nicht automatisch kopieren?

Ein Cronjob, der System -> Repository kopiert und committet, kehrt die Beweisrichtung
um: Das Repository folgt dann der Realitaet, auch wenn die kaputt ist. Ein
`apt`-Update, das eine Konfigurationsdatei ersetzt, oder ein Versehen wandern als
scheinbar gewollter Commit nach GitHub. Damit geht die eine Eigenschaft verloren,
wegen der sich das Repository lohnt: dass darin steht, was **entschieden** wurde.

Deshalb meldet der Timer nur. Kopiert wird auf Ansage.

## Eine neue Datei aufnehmen

Zeile ans `manifest.tsv` anhaengen (Spalten durch **Tabulator** getrennt):

```
repo/pfad	/system/pfad	root:root	644	systemd
```

Letzte Spalte: `systemd` (loest `daemon-reload` aus), `sudoers` (prueft mit
`visudo -c`) oder `keiner`.
