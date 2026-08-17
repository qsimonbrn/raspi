# 13 — Paperless-ngx

*Eingerichtet: 13.08.2026 · Aktualisiert: 16.08.2026 · **Version 3.0.5***

Dokumentenarchiv mit Texterkennung. Dieses Kapitel beschreibt, wie die Einrichtung
funktioniert, wie Dokumente hineinkommen und was bewusst so und nicht anders
konfiguriert wurde.

---

## 1. Was Paperless macht

Aus einem Stapel PDFs wird ein durchsuchbares Archiv. Der Ablauf pro Dokument:

1. **Einwurf** — eine Datei landet im Ordner `consume`
2. **Texterkennung** — OCR liest den Text aus dem Scan
3. **Archivfassung** — es entsteht eine zweite PDF mit hinterlegtem Textlayer,
   in der sich suchen und markieren lässt
4. **Zuordnung** — Titel, Datum, Korrespondent und Tags werden erkannt oder gelernt
5. **Ablage** — Original und Archivfassung wandern nach `media`, der Einwurf-Ordner
   wird geleert

Das Original wird **nie verändert**. Die Archivfassung ist eine zusätzliche Datei.

## 2. Zugang

| | |
|---|---|
| Weboberfläche | `http://192.168.178.80:8000` |
| Benutzer | `admin` |
| Einwurf über Netzwerk | `smb://192.168.178.80/scans` |

> ⚠️ **Erste Aufgabe:** Das Administratorpasswort in der Weboberfläche ändern
> (*Einstellungen → Benutzer → admin*). Es stand bis zur Einrichtung auf einem
> Beispielwert und ist in der Versionsgeschichte des Compose-Repositories nachlesbar.

---

## 3. Dokumente einwerfen

### Über die Netzwerkfreigabe (der übliche Weg)

Im Finder unter *Gehe zu → Mit Server verbinden*:

```
smb://192.168.178.80/scans
```

Datei hineinziehen — fertig. Paperless sieht alle 15 Sekunden nach, wartet fünf
Sekunden bis die Datei nicht mehr wächst, liest sie ein und **entfernt sie danach aus
dem Ordner**. Ein leerer Ordner bedeutet also: alles verarbeitet.

Ein Scanner, der auf ein Netzlaufwerk speichern kann, wird direkt auf diese Freigabe
gerichtet.

### Unterordner werden zu Tags

`PAPERLESS_CONSUMER_SUBDIRS_AS_TAGS` ist aktiv. Legst du eine Datei unter
`scans/Versicherung/` ab, bekommt das Dokument automatisch den Tag `Versicherung`.
Das ist der schnellste Weg, beim Einscannen schon grob vorzusortieren.

### Über die Weboberfläche

Datei per Drag-and-drop auf die Oberfläche ziehen. Gleicher Ablauf, nur ohne
Netzlaufwerk.

### Warum gepollt statt auf Ereignisse gehorcht wird

Standardmäßig nutzt Paperless `inotify` und reagiert sofort. Bei Schreibzugriffen über
Samba kann das Ereignis aber ausgelöst werden, während die Datei noch übertragen wird —
Paperless liest dann ein halbes PDF ein. Deshalb:

```
PAPERLESS_CONSUMER_POLLING_INTERVAL: 15   alle 15 Sekunden nachsehen
PAPERLESS_CONSUMER_STABILITY_DELAY: 5     5 Sekunden Ruhe abwarten
```

> Beide Variablen hießen bis v2 `CONSUMER_POLLING` und `CONSUMER_POLLING_DELAY`.
> `CONSUMER_POLLING_RETRY_COUNT` ist in v3 ersatzlos entfallen — die Anwendung
> verfolgt jetzt selbst, ob eine Datei ihre Größe noch ändert.

Der Preis sind bis zu 20 Sekunden Verzögerung. Der Gewinn ist, dass keine halben
Dokumente im Archiv landen.

### macOS-Beiwerk

Der Finder legt beim Kopieren `._`-Dateien und `.DS_Store` an. Ohne Gegenmaßnahme
versucht Paperless, sie als Dokumente einzulesen. Die Samba-Freigabe blendet sie über
`veto files` aus, sie erreichen den Ordner also gar nicht erst.

---

## 4. Der Arbeitsablauf im Alltag

Der Kern von Paperless ist eine Schleife aus vier Schritten. Wer sie einhält, hat ein
gepflegtes Archiv; wer sie überspringt, hat einen Haufen unsortierter PDFs mit Suchfunktion.

```
   Scannen / Speichern
           ↓
   in  smb://192.168.178.80/scans  legen
           ↓
   Paperless liest ein  →  Dokument bekommt automatisch den Tag "Posteingang"
           ↓
   In der Oberflaeche unter "Posteingang" durchsehen:
   Titel pruefen · Korrespondent setzen · Dokumenttyp waehlen · Tags vergeben
           ↓
   Tag "Posteingang" entfernen  →  Dokument ist abgelegt
```

### Der Posteingang

Jedes neu eingelesene Dokument bekommt automatisch den Tag **`Posteingang`**. Er ist der
einzige Tag, der eine technische Funktion hat: Er markiert „noch nicht durchgesehen".

In der Oberfläche gibt es dafür links den Punkt **Posteingang**. Was dort liegt, wartet
auf dich. Ist die Liste leer, ist alles abgelegt.

**Das ist bewusst ein manueller Schritt.** Die automatische Erkennung wird gut, aber sie
wird nie perfekt — und ein falsch abgelegtes Dokument findest du in fünf Jahren nicht
wieder. Zehn Sekunden pro Dokument beim Durchsehen sind der Preis dafür, dass das Archiv
verlässlich bleibt.

### Wie oft?

Einmal pro Woche reicht. Der Posteingang darf sich füllen — er ist eine Warteschlange,
kein Alarm.

### Struktur: Korrespondent, Dokumenttyp, Tag

Paperless kennt drei Ordnungsebenen. Sie sauber auseinanderzuhalten, ist der wichtigste
Punkt überhaupt:

| Ebene | Antwortet auf | Beispiele |
|---|---|---|
| **Korrespondent** | *Von wem?* | Stadtwerke Musterstadt, Finanzamt, HUK-Coburg, Vermieter |
| **Dokumenttyp** | *Was ist es?* | Rechnung, Vertrag, Kontoauszug, Bescheinigung |
| **Tag** | *Wozu gehört es?* | Wohnung, Auto, Steuer 2026, Gesundheit |

Ein Dokument hat **genau einen** Korrespondenten und **genau einen** Dokumenttyp, aber
beliebig viele Tags. Die Stromrechnung ist also: Korrespondent *Stadtwerke*, Typ
*Rechnung*, Tags *Wohnung* und *Steuer 2026*.

**Bereits angelegt** wurden acht gängige Dokumenttypen: Rechnung, Vertrag, Behördenpost,
Kontoauszug, Versicherung, Quittung, Bescheinigung, Kündigung. Umbenennen und Löschen
ist jederzeit möglich.

**Tags bleiben bewusst dir überlassen** — sie hängen davon ab, wie du denkst. Eine
Empfehlung aus der Praxis: **zehn bis fünfzehn Tags, nicht mehr.** Tags nach Lebensbereich
(*Wohnung*, *Auto*, *Arbeit*, *Gesundheit*) funktionieren besser als Tags nach Thema, weil
das Thema meist schon im Dokumenttyp oder Korrespondenten steckt. Doppelt zu erfassen,
was ohnehin da ist, macht die Suche nicht besser — nur die Pflege aufwendiger.

### Vorsortieren beim Einwerfen

Weil Unterordner zu Tags werden, kannst du dir Arbeit sparen:

```
scans/Auto/tuev-2026.pdf        →  Dokument bekommt Tag "Auto"
scans/Steuer 2026/spende.pdf    →  Dokument bekommt Tag "Steuer 2026"
```

Die Unterordner werden bei Bedarf automatisch angelegt und der Tag bei Bedarf ebenso.

### Dokumente wiederfinden

Die Suche oben durchsucht **den erkannten Text**, nicht nur Titel und Tags. Die Suche
nach `Zählernummer` findet also auch eine Rechnung, in der das Wort nur im Kleingedruckten
steht.

Nützliche Suchbefehle:

| Eingabe | Findet |
|---|---|
| `stadtwerke` | überall — Text, Titel, Korrespondent |
| `correspondent:stadtwerke` | nur diesen Absender |
| `type:rechnung created:[2026 to 2027]` | Rechnungen aus 2026 |
| `tag:auto` | alles mit diesem Tag |
| `"jährliche abrechnung"` | exakte Wortfolge |
| `is:inbox` | alles im Posteingang |

Filter lassen sich links auch anklicken und als **gespeicherte Ansicht** sichern — etwa
„Alle Rechnungen dieses Jahres" fest in der Seitenleiste.

### Vom Handy

Es gibt keine offizielle App, aber die Oberfläche ist für Mobilgeräte gebaut. Im Browser
`http://192.168.178.80:8000` aufrufen und zum Homescreen hinzufügen — verhält sich dann
wie eine App. Von unterwegs geht das über Tailscale — entweder über dieselbe Adresse
`http://192.168.178.80:8000` (dank Subnetz-Router) oder über `http://100.108.219.87:8000`.

Für iOS und Android gibt es zusätzlich Apps aus der Community (etwa *Swift Paperless* und
*Paperless Mobile*), die sich mit derselben Adresse und einem API-Token verbinden.

---

## 5. Konfiguration im Einzelnen

Alle Werte stehen in `docker-stacks/paperless/docker-compose.yml`. Geheimnisse liegen
in `.env` und sind über `.gitignore` ausgeschlossen.

### Sprache und Erkennung

| Einstellung | Wert | Begründung |
|---|---|---|
| `PAPERLESS_OCR_LANGUAGE` | `deu+eng` | Deutsche Post und englische Online-Rechnungen |
| `PAPERLESS_OCR_MODE` | `auto` | PDFs, die bereits Text enthalten, werden nicht erneut erkannt — spart auf einem Pi sehr viel Zeit. Hieß bis v2 `skip`; den Wert gibt es nicht mehr |
| `PAPERLESS_ARCHIVE_FILE_GENERATION` | `always` | Es wird immer eine Archivfassung erzeugt. Ersetzt `OCR_SKIP_ARCHIVE_FILE: never` — v3 hat Texterkennung und Archivdatei entkoppelt |
| `PAPERLESS_OCR_DESKEW` | `true` | Schief eingelegte Seiten werden geradegerückt |
| `PAPERLESS_OCR_ROTATE_PAGES` | `true` | Falsch herum eingezogene Seiten werden gedreht |
| `PAPERLESS_OCR_CLEAN` | `clean` | Scanflecken werden vor der Erkennung entfernt |
| `PAPERLESS_FILENAME_DATE_ORDER` | `DMY` | `03.05.2026` ist der 3. Mai, nicht der 5. März |

Ein reiner Text-Scan braucht auf diesem Pi rund **60 Sekunden pro Seite** — gemessen beim
Einrichtungstest. Digitale PDFs mit vorhandenem Textlayer sind durch `OCR_MODE: auto` in
wenigen Sekunden durch.

### Ablagestruktur

```
PAPERLESS_FILENAME_FORMAT: {{ created_year }}/{{ correspondent }}/{{ created }}_{{ title }}
```

Ergibt im Medienverzeichnis:

```
media/documents/originals/2026/Stadtwerke/2026-08-13_Jahresabrechnung.pdf
```

Das ist bewusst so gewählt: Die Dateien bleiben auch dann auffindbar und sortiert, wenn
Paperless einmal nicht läuft. Ein Archiv, das nur über seine eigene Oberfläche zugänglich
ist, wäre eine Abhängigkeit, die man nicht braucht.

### Leistung auf dem Raspberry Pi

| Einstellung | Wert |
|---|---|
| `PAPERLESS_TASK_WORKERS` | 2 |
| `PAPERLESS_THREADS_PER_WORKER` | 2 |
| `PAPERLESS_WEBSERVER_WORKERS` | 2 |

Vier Kerne, 3,7 GiB RAM — zwei Worker mit je zwei Threads lasten die CPU aus, ohne
Pi-hole und den übrigen Diensten den Speicher zu nehmen. Höhere Werte bringen auf dieser
Hardware nichts, weil OCR speicher- und nicht kerngebunden ist.

### ⚠️ Duplex-Scans: Rückseiten werden zu leeren Dokumenten

Scannt der Scanner beidseitig, entsteht für jede leere Rückseite ein eigenes
Dokument ohne Inhalt. Beim ersten Durchlauf am 13.08.2026 waren das **14 von 40**.

Die Texterkennung arbeitet dabei korrekt — die Seiten sind nachweislich leer
(0,00 % dunkle Fläche bei der Prüfung). Im Protokoll erscheint dazu
`[tesseract] Error during processing` zusammen mit `Too few characters`. Das ist
kein Fehler, sondern die Lagebestimmung, die auf einer leeren Seite naturgemäß
nichts findet.

**Zwei Wege dagegen:**

1. **Am Scanner** die Leerseitenerkennung aktivieren (heißt je nach Gerät
   „Blank Page Removal", „Leerseiten überspringen" oder „Skip Blank Page"). Das ist
   die saubere Lösung — die Seiten entstehen gar nicht erst.
2. **Nachträglich in Paperless**: Leere Dokumente tragen den Tag `Leerseite`.
   Danach filtern, alle auswählen, löschen. Der Papierkorb hält sie 30 Tage vor.

### ⚠️ Datum aus dem Dateinamen: bewusst abgeschaltet

`PAPERLESS_FILENAME_DATE_ORDER` ist **nicht** gesetzt — und das ist Absicht.

Bei der Einrichtung stand die Variable versehentlich auf `DMY`. Scanner-Dateinamen
wie `doc00451220260813032623_020` bestehen aus langen Ziffernketten, aus denen der
Parser sinnlose Daten ableitet: Zehn Dokumente landeten auf dem **10.11.2000**.

Ohne die Variable durchsucht Paperless nur den erkannten **Inhalt** nach einem Datum
(`PAPERLESS_DATE_ORDER: DMY`) — und findet dort das tatsächliche Rechnungs- oder
Briefdatum. Die zehn falschen Daten wurden nachträglich aus dem Inhalt neu abgeleitet.

### Papierkorb

`PAPERLESS_EMPTY_TRASH_DELAY: 30` — gelöschte Dokumente bleiben 30 Tage
wiederherstellbar, bevor sie endgültig verschwinden.

---

## 6. Automatische Zuordnung

Paperless bringt einen eigenen Klassifikator mit (scikit-learn, kein LLM). Er lernt aus
den Dokumenten, die du selbst zugeordnet hast, und schlägt danach Korrespondent,
Dokumenttyp und Tags von allein vor.

```
PAPERLESS_TRAIN_TASK_CRON: "5 */2 * * *"    lernt alle zwei Stunden nach
```

**Praktisches Vorgehen:** Die ersten 20 bis 30 Dokumente von Hand zuordnen. Danach trifft
der Klassifikator die meisten Fälle selbst. Er wird umso besser, je konsistenter die
ersten Zuordnungen sind — es lohnt sich, am Anfang kurz über die Tag-Struktur
nachzudenken, statt sie wachsen zu lassen.

Zusätzlich gibt es **Zuordnungsregeln** in der Oberfläche
(*Verwaltung → Korrespondenten / Dokumenttypen*): Enthält der Text „Stadtwerke", setze
Korrespondent „Stadtwerke Musterstadt". Solche Regeln greifen sofort und sicher, ohne
Lernphase — für wiederkehrende Absender die bessere Wahl als der Klassifikator.

### Zu KI-Erweiterungen

Es gibt Zusatzdienste, die statt des eingebauten Klassifikators ein Sprachmodell
verwenden — **paperless-ai** und **paperless-gpt**. Sie erzeugen Titel, Tags und
Zusammenfassungen und beherrschen Vision-OCR für schwierige Scans.

Zwei Einschränkungen für dieses Setup:

- **Lokal auf dem Pi ist kein Sprachmodell möglich.** Bei 3,7 GiB RAM neben Paperless,
  PostgreSQL und Pi-hole reicht es nicht, und ein Pi 4 hätte für ein brauchbares Modell
  Minuten pro Dokument.
- **Eine Cloud-Anbindung (OpenAI o. ä.) schickt den Inhalt jedes Dokuments an einen
  Dritten.** Bei Behördenpost, Verträgen und Rechnungen ist das eine bewusste
  Entscheidung, keine Nebensache.

Der gangbare Mittelweg wäre **Ollama auf dem Mac** — dort ist es bereits installiert.
paperless-ai auf dem Pi könnte darauf zugreifen; die Dokumente bleiben im Haus, und die
Zuordnung läuft, wenn der Mac an ist.

**Empfehlung:** erst ohne. Der eingebaute Klassifikator ist für einen Haushalt mit einigen
hundert Dokumenten meist ausreichend, und ohne eigene Dokumente lässt sich gar nicht
beurteilen, ob er es nicht tut. Wenn die Zuordnung nach 50 bis 100 Dokumenten nicht
überzeugt, ist paperless-ai gegen Ollama auf dem Mac der nächste Schritt.

---

## 7. Sicherung

Paperless wird vom täglichen Backup erfasst — siehe [12 — Backup](12-backup.md).

**Wichtig zu verstehen:** Gesichert wird nicht das Datenverzeichnis, sondern der
Export von `document_exporter` plus ein `pg_dump`. Grund: Tags, Korrespondenten,
Dokumenttypen und der erkannte Text liegen in PostgreSQL, nicht in den Dateien. Eine
reine Dateikopie ergäbe Dokumente ohne jede Ordnungsstruktur.

Wiederherstellung Schritt für Schritt in [12 — Backup, Abschnitt 7](12-backup.md#7-wiederherstellung).

---

## 8. Betrieb

```bash
# Läuft alles?
docker ps --filter name=paperless

# Was passiert gerade?
docker logs -f paperless

# Wurde ein Dokument verarbeitet?
docker logs paperless 2>&1 | grep -i consum | tail

# Anzahl Dokumente
docker exec paperless-paperless-db-1 \
  psql -U paperless -d paperless -tAc "select count(*) from documents_document;"

# Nach Konfigurationsänderung
cd ~/docker-stacks/paperless && docker compose up -d
```

### Wenn ein Dokument nicht eingelesen wird

1. Liegt es noch im Ordner? `ls /mnt/usb-hdd/paperless/consume/`
2. Was sagt das Protokoll? `docker logs paperless 2>&1 | tail -30`
3. Häufigste Ursachen: passwortgeschütztes PDF, beschädigte Datei, oder ein Dateiformat
   ohne Unterstützung
4. Doppelte Dokumente werden absichtlich verworfen
   (`PAPERLESS_CONSUMER_DELETE_DUPLICATES: true`)

---

## 9. Aufbau des Stacks

| Container | Aufgabe |
|---|---|
| `paperless` | Weboberfläche, OCR, Worker |
| `paperless-paperless-db-1` | PostgreSQL 15 — Metadaten, Tags, erkannter Text |
| `paperless-paperless-redis-1` | Redis — Warteschlange der Verarbeitungsaufträge |

| Verzeichnis auf dem Pi | Inhalt |
|---|---|
| `/mnt/usb-hdd/paperless/consume` | Einwurf (= Samba-Freigabe `scans`) |
| `/mnt/usb-hdd/paperless/media` | Originale, Archivfassungen, Vorschaubilder |
| `/mnt/usb-hdd/paperless/data` | Suchindex, Klassifikator |
| `/mnt/usb-hdd/paperless/export` | Ziel von `document_exporter` (Backup) |

Die Container starten in Abhängigkeit voneinander: Paperless wartet über
`condition: service_healthy`, bis PostgreSQL wirklich Verbindungen annimmt — nicht nur,
bis der Container läuft.

---

## 10. Prüfung bei der Einrichtung

Der komplette Weg wurde am 13.08.2026 mit einem Testdokument durchlaufen:

| Schritt | Ergebnis |
|---|---|
| Datei im Einwurf-Ordner erkannt | ✅ nach 15 s |
| Texterkennung | ✅ Text vollständig ausgelesen |
| Ablage nach Namensschema | ✅ `2026/2026-08-13_testrechnung.pdf` |
| Archivfassung und Vorschaubild | ✅ erzeugt |
| Einwurf-Ordner geleert | ✅ |
| Verarbeitungsdauer | 62 Sekunden für eine Seite |

Das Testdokument wurde anschließend wieder entfernt — das Archiv startet leer.

---

## Update auf Version 3 (16.08.2026)

### Der Pfad

Ein direkter Sprung von 2.15.3 auf `:latest` wäre gescheitert. Die Migrationsanleitung
ist eindeutig: *„Upgrading to Paperless-ngx v3 can only be performed from version
2.20.15."* Gefahren wurde deshalb in zwei Stufen, mit Log-Prüfung dazwischen:

```
2.15.3  →  2.20.15 (27.04.2026)  →  3.0.5 (01.08.2026)
```

Dazu wurden `postgres` auf `15.19` und `redis` auf `7.4` gepinnt. Details zum
Collation-Konflikt, der dabei auftrat, in [Kapitel 05](05-docker.md).

### Was in der Compose-Datei umgeschrieben werden musste

| Bis v2 | Ab v3 | Verhalten |
|---|---|---|
| `PAPERLESS_CONSUMER_POLLING` | `PAPERLESS_CONSUMER_POLLING_INTERVAL` | unverändert |
| `PAPERLESS_CONSUMER_POLLING_DELAY` | `PAPERLESS_CONSUMER_STABILITY_DELAY` | unverändert |
| `PAPERLESS_CONSUMER_POLLING_RETRY_COUNT` | *entfällt* | v3 verfolgt Dateistabilität selbst |
| `PAPERLESS_OCR_MODE: skip` | `PAPERLESS_OCR_MODE: auto` | `skip` existiert nicht mehr |
| `PAPERLESS_OCR_SKIP_ARCHIVE_FILE: never` | `PAPERLESS_ARCHIVE_FILE_GENERATION: always` | unverändert |
| — | `PAPERLESS_DBENGINE: postgresql` | **ab v3 Pflicht** |

Die letzte Zeile ist die gefährlichste. Fehlt `PAPERLESS_DBENGINE`, fällt Paperless
stillschweigend auf SQLite zurück und startet mit einem **leeren Archiv**. Die Daten
in PostgreSQL bleiben unangetastet, sind aber nicht mehr sichtbar — es sieht aus wie
Totalverlust, ist aber nur eine fehlende Zeile.

`PAPERLESS_SECRET_KEY` ist ab v3 ebenfalls Pflicht und stand hier bereits in der `.env`.

### Weitere Verhaltensänderungen in v3

- **Dubletten sind jetzt standardmäßig erlaubt.** `PAPERLESS_CONSUMER_DELETE_DUPLICATES`
  steht hier weiterhin auf `true`, damit der Scanner beim zweiten Einwurf desselben
  Blattes nichts anlegt.
- **Verschlüsselung von Dokumenten und Vorschaubildern** wird nicht mehr unterstützt.
  Hier nie verwendet.
- **Die Aufgaben-Historie** wurde beim Update geleert.
- **Der Suchindex** wurde automatisch neu gebaut.
- Das Feld `created` ist von `datetime` auf `date` gewechselt — relevant für eigene
  Skripte, die die API oder das Django-Modell nutzen.

### Backup vor dem Update

Angelegt unter `/mnt/usb-hdd/backup/2026-08-16-vor-update/` und geprüft:

| Teil | Umfang | Prüfung |
|---|---|---|
| `db/*.dump` (Custom-Format) | 855 KB | `pg_restore -l` liest 643 Objekte |
| `db/*.sql` (Klartext) | 3,0 MB | 67 `CREATE TABLE` |
| `export/documents/` | 15 MB | 80 Dateien, `manifest.json` mit 26 Dokumenten |
| `compose/` | 108 KB | 8 Compose-Dateien und beide `.env`, Rechte `go-rwx` |

Die Differenz zwischen 41 Dokumenten in der Datenbank und 26 im Export ist erklärt:
15 liegen im Papierkorb, die exportiert `document_exporter` nicht. Der `pg_dump`
enthält sie.

### Ergebnis

Nach dem Update: 26 aktive Dokumente, 15 im Papierkorb, 10 Tags, 11 Korrespondenten —
alles unverändert. Keine `ERROR`-Zeile im Log, HTTP 302 auf `:8000`.

### ⚠️ Nachtrag: `document_exporter` erfasst ab v3 auch den Papierkorb

Beim Testen der Backup-Automatisierung am selben Abend brach der Export ab:

```
FileNotFoundError: [Errno 2] No such file or directory:
'/usr/src/paperless/media/documents/originals/2026/2026-08-13_testrechnung.pdf'
```

Ursache: Bis Version 2 exportierte `document_exporter` nur aktive Dokumente. Ab
v3 läuft er auch über den Papierkorb. Zu Dokument 1 — einem Testdokument aus der
Einrichtung, am 13.08.2026 gelöscht — existierte die Datei nicht mehr. Der Export
bricht daran ab, **nachdem** er bereits einen Teil kopiert hat, und es gibt kein
Flag zum Überspringen.

Das ist kein Randproblem: Damit war das Paperless-Backup zwischen dem Update und
der Bereinigung nicht lauffähig, ohne dass irgendetwas Alarm geschlagen hätte. Der
turnusmäßige restic-Lauf sichert die Dateien zwar weiterhin, aber der Export mit
`manifest.json` — die Metadaten-Rückfallebene — fehlte.

**Behoben** durch Leeren des Papierkorbs (16.08.2026). Bestand seither: 26 aktive
Dokumente, 0 im Papierkorb.

**Vorabprüfung vor jedem Export:**

```bash
docker exec paperless python3 -c "
import django, os
os.environ.setdefault('DJANGO_SETTINGS_MODULE','paperless.settings')
django.setup()
from documents.models import Document
qs = Document.global_objects.all() if hasattr(Document,'global_objects') else Document.objects.all()
print([d.pk for d in qs if not os.path.exists(d.source_path)])
"
```

Kommt hier etwas anderes als `[]` zurück, scheitert der Export. Betrifft es nur
Papierkorb-Einträge: Papierkorb leeren. Fehlt einem **aktiven** Dokument die Datei,
ist das ein eigener Vorfall.

Die Skill `docker-updates` prüft das vor jedem Backup automatisch.
