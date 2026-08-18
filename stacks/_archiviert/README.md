# Archivierte Stacks

Hier liegen Compose-Dateien von Diensten, die **abgeschaltet** wurden. Sie bleiben
versioniert, damit die Konfiguration nachvollziehbar ist — sie laufen aber nicht mehr.

| Dienst | Abgeschaltet | Grund |
|---|---|---|
| `filebrowser` | 18.08.2026 | Betroffen von CVE-2026-32759 (RCE über TUS-Upload, kein Patch verfügbar). Das Projekt wird zum 01.09.2026 archiviert, es wird keine Sicherheitsupdates mehr geben. Der Container hatte die gesamte SSD unter `/srv` eingebunden. Ein Nachfolger wird gesucht. |
| `dashy` | 18.08.2026 | Durch Homepage abgelöst. Image lief ungepinnt auf `:latest` und war neun Monate alt. |

Daten wurden **nicht** gelöscht: `/mnt/usb-hdd/filebrowser-data` (44 KB) liegt unverändert
auf der SSD, ebenso die Docker-Volumes.
