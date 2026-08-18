# sudo-Regeln

Versionierte Kopien der Dateien aus `/etc/sudoers.d/`. Sie enthalten **keine**
Geheimnisse — nur Rechte und Aufzeichnungseinstellungen.

| Datei | Zweck |
|---|---|
| `010-claude` | Automatisierungskonto: volle Rechte mit vollständiger Sitzungsaufzeichnung |

## Zurückspielen

```bash
sudo visudo -c -f sudoers/010-claude          # immer zuerst pruefen
sudo install -o root -g root -m 440 sudoers/010-claude /etc/sudoers.d/010-claude
```

Eine fehlerhafte Datei unter `/etc/sudoers.d/` kann `sudo` systemweit unbrauchbar machen.
Deshalb **nie** direkt kopieren, sondern immer erst `visudo -c` laufen lassen.

Hintergrund und Begründung des Rechtemodells: `raspi-doku/docs/16-konten-und-rechte.md`.
