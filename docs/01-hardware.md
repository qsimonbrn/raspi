# 01 — Hardware

*Erfasst: 13.08.2026*

## Rechner

| Merkmal | Wert |
|---|---|
| Modell | Raspberry Pi 4 Model B Rev 1.1 |
| Architektur | aarch64 (64-bit ARM) |
| CPU | Broadcom BCM2711, 4 × Cortex-A72 |
| Arbeitsspeicher | 3,7 GiB nutzbar (4-GB-Modell) |

## Thermik und Stromversorgung

| Messwert | Wert | Bewertung |
|---|---|---|
| Kerntemperatur | 47,7 °C | unauffällig — der Pi 4 drosselt erst ab 80 °C |
| `vcgencmd get_throttled` | `0x0` | **noch nie gedrosselt**, auch nicht historisch |

Der Wert `0x0` ist aussagekräftiger als die Momentantemperatur: Er ist ein Bitfeld, das
seit dem letzten Neustart *jedes* Auftreten von Unterspannung oder thermischer Drosselung
protokolliert. Bei 16 Tagen Uptime bedeutet `0x0`, dass in dieser Zeit weder das Netzteil
eingebrochen ist noch die Kühlung an ihre Grenze kam.

**Bewertung:** Kühlung und Netzteil sind ausreichend dimensioniert. Kein Handlungsbedarf.

## Arbeitsspeicher

| | Gesamt | Belegt | Frei | Cache | Verfügbar |
|---|---|---|---|---|---|
| RAM | 3,7 GiB | 1,3 GiB | 750 MiB | 1,8 GiB | **2,4 GiB** |
| Swap | 512 MiB | 179 MiB | 332 MiB | — | — |

Die 1,8 GiB Cache sind kein Verbrauch, sondern vom Kernel genutzter freier Speicher —
die relevante Zahl ist **verfügbar: 2,4 GiB**. Das System hat reichlich Luft.

Dass 179 MiB Swap belegt sind, ist bei 16 Tagen Uptime normal: Der Kernel lagert
langfristig ungenutzte Speicherseiten aus, auch wenn RAM frei ist.

**Bewertung:** Für den aktuellen Bestand ausreichend. Speicherhungrige Zusatzdienste
(z. B. Nextcloud, Elasticsearch, Grafana-Stack) würden es allerdings eng machen.

## Datenträger

### Übersicht

| Gerät | Modell | Größe | Dateisystem | Mountpoint |
|---|---|---|---|---|
| `mmcblk0` | SD-Karte `SD256` | 238,3 G | — | — |
| ├─ `mmcblk0p1` | | 512 M | vfat | `/boot/firmware` |
| └─ `mmcblk0p2` | | 237,8 G | ext4 | `/` |
| `sda` | **Samsung SSD 870 QVO 1TB** (USB) | 931,5 G | — | — |
| └─ `sda1` | | 931,5 G | ext4 | `/mnt/usb-hdd` |

### Belegung

| Mountpoint | Größe | Belegt | Frei | Auslastung |
|---|---|---|---|---|
| `/` | 235 G | 8,9 G | 214 G | **5 %** |
| `/boot/firmware` | 510 M | 67 M | 444 M | 14 % |
| `/mnt/usb-hdd` | 916 G | 310 G | 560 G | **36 %** |

### Mount-Optionen (`/etc/fstab`)

```
PARTUUID=0245db40-01  /boot/firmware  vfat  defaults          0  2
PARTUUID=0245db40-02  /               ext4  defaults,noatime  0  1
UUID=20949ef8-…       /mnt/usb-hdd    ext4  defaults,nofail   0  0
```

Zwei Details sind richtig gesetzt:

- **`noatime`** auf der Wurzelpartition unterdrückt Zugriffszeit-Schreibvorgänge und
  schont damit die SD-Karte spürbar.
- **`nofail`** bei der SSD verhindert, dass der Pi beim Booten hängenbleibt, falls die
  USB-Platte nicht erkannt wird.

---

## ⚠️ Befund: Wurzeldateisystem auf SD-Karte

| | |
|---|---|
| Karte | `SD256`, 256 GB |
| **Herstellungsdatum** | **02/2023** |
| Enthält | Betriebssystem, Docker-Layer, Pi-hole-Logs, systemd-Journal |

Das Wurzeldateisystem liegt auf der SD-Karte — nicht auf der SSD.

**Warum das ein Risiko ist:** SD-Karten haben eine begrenzte Zahl von Schreibzyklen und
keine nennenswerte Wear-Leveling-Reserve. Dieser Pi schreibt kontinuierlich:
Docker-Container-Layer, Pi-hole-Query-Datenbank, systemd-Journal, Paketverwaltung. Nach
dreieinhalb Jahren Dauerbetrieb ist der Verschleiß relevant. SD-Karten fallen
typischerweise **ohne Vorwarnung** aus — oft bleibt das Dateisystem zunächst lesbar,
Schreibvorgänge scheitern still, und beim nächsten Neustart bootet der Pi nicht mehr.

**Was dagegen spricht, es zu ignorieren:** Eine 1-TB-SSD hängt bereits am USB-Port und ist
zu 64 % leer. Die Voraussetzungen für einen Umzug sind vollständig gegeben.

**Empfehlung:** Wurzeldateisystem auf die SSD umziehen. Der Pi 4 kann per USB booten;
das Firmware-Update dafür ist auf aktuellen Bookworm-Installationen bereits vorhanden.
Details in [09 — Empfehlungen](09-empfehlungen.md).

**Zwischenlösung, falls der Umzug später erfolgen soll:** Ein Image-Abbild der SD-Karte
auf die SSD, damit im Ausfall wenigstens ein Klon existiert.

---

## SMART-Werte der SSD

`smartctl` ist nicht installiert, daher liegen keine Gesundheitsdaten der Samsung-SSD vor.
Da die Platte per USB angebunden ist, benötigt die Abfrage zusätzlich den passenden
Treiber-Parameter (`-d sat`).

**Empfehlung:** `smartmontools` installieren, um Verschleiß und Fehlerzähler der SSD
überwachen zu können. Aufwand: wenige Minuten.
