"""
Einmalige Erstsortierung des Paperless-Bestands.
Aufruf:  docker exec -i paperless python3 manage.py shell < kategorisieren.py
"""
import re, datetime
from collections import Counter
from django.utils import timezone
from documents.models import Document, Tag, DocumentType, Correspondent

GEBURTSTAG = "11.11.2000"   # steht in jedem Arztbrief und darf kein Dokumentdatum werden

# --- Stammdaten anlegen ------------------------------------------------------
for n in ["Arztbrief", "Laborbefund", "Verdienstabrechnung", "Bussgeldbescheid"]:
    DocumentType.objects.get_or_create(name=n)

TAGFARBEN = {
    "Gesundheit": "#27ae60", "Auto": "#2980b9", "Arbeit": "#8e44ad",
    "Finanzen": "#d35400", "Versicherung": "#16a085", "Einkauf": "#7f8c8d",
    "Pruefen": "#c0392b",
}
for n, c in TAGFARBEN.items():
    Tag.objects.get_or_create(name=n, defaults={"color": c})

# --- Zuordnung:  id -> (Titel, Korrespondent, Dokumenttyp, [Tags]) -----------
Z = {
 7:  ("Notfallambulanz Aufnahme", "Asklepios Suedpfalzkliniken", "Arztbrief", ["Gesundheit"]),
 9:  ("Darlehen 9284438 Anschreiben", "Bausparkasse Schwaebisch Hall", "Vertrag", ["Finanzen"]),
 10: ("Laborwerte", "Aerztliches Gemeinschaftslabor Karlsruhe", "Laborbefund", ["Gesundheit"]),
 11: ("Bussgeldbescheid", "Landratsamt Karlsruhe", "Bussgeldbescheid", ["Auto"]),
 12: ("Radiologischer Befund", "Radiologie Vorderpfalz", "Arztbrief", ["Gesundheit"]),
 13: ("Laborbefund", "Aerztliches Gemeinschaftslabor Karlsruhe", "Laborbefund", ["Gesundheit"]),
 14: ("Darlehen 9284438 Auszahlungsvoraussetzungen", "Bausparkasse Schwaebisch Hall", "Vertrag", ["Finanzen"]),
 15: ("Seitenfragment ohne Zuordnung", None, None, ["Pruefen"]),
 16: ("Austrittsunterlagen", "netgo GmbH", "Bescheinigung", ["Arbeit"]),
 17: ("Radiologie Standortuebersicht", "Radiologie Vorderpfalz", "Arztbrief", ["Gesundheit"]),
 18: ("Zahlungsaufforderung Italien", "Nivi S.p.A.", "Bussgeldbescheid", ["Auto"]),
 19: ("Arztbrief Notaufnahme", "GRN Klinik Schwetzingen", "Arztbrief", ["Gesundheit"]),
 20: ("Mautabrechnung Italien", "Nivi S.p.A.", "Rechnung", ["Auto"]),
 21: ("Kardiologie Anschreiben", "GRN Klinik Schwetzingen", "Arztbrief", ["Gesundheit"]),
 23: ("Ambulanter Arztbrief", "GRN Klinik Schwetzingen", "Arztbrief", ["Gesundheit"]),
 24: ("Verdienstabrechnung", "netgo GmbH", "Verdienstabrechnung", ["Arbeit", "Finanzen"]),
 25: ("Arztbrief Fussverletzung", "Asklepios Suedpfalzkliniken", "Arztbrief", ["Gesundheit"]),
 26: ("Laborbefund", "Aerztliches Gemeinschaftslabor Karlsruhe", "Laborbefund", ["Gesundheit"]),
 27: ("Bussgeldbescheid Anlage Datenschutz", "Landratsamt Karlsruhe", "Bussgeldbescheid", ["Auto"]),
 32: ("Unlesbarer Scan", None, None, ["Pruefen"]),
 33: ("Rechnung 60416", "Japan Hobby Store Yorokonde", "Rechnung", ["Einkauf"]),
 35: ("Versicherungsschreiben", "BGV Badische Versicherungen", "Versicherung", ["Versicherung", "Auto"]),
 36: ("Notfallambulanz Aufnahme", "Asklepios Suedpfalzkliniken", "Arztbrief", ["Gesundheit"]),
 38: ("Arztbrief Notaufnahme", "GRN Klinik Schwetzingen", "Arztbrief", ["Gesundheit"]),
 39: ("Schreiben der Stadt", "Stadt Philippsburg", "Behoerdenpost", []),
 41: ("Laborbefund", "Aerztliches Gemeinschaftslabor Karlsruhe", "Laborbefund", ["Gesundheit"]),
}

DATUM = re.compile(r"\b(\d{2})[./](\d{2})[./](20\d{2})\b")

def bestes_datum(text):
    """Plausibelstes Dokumentdatum aus dem Text -- ohne das Geburtsdatum."""
    treffer = []
    for t, m, j in DATUM.findall(text or ""):
        s = "%s.%s.%s" % (t, m, j)
        if s == GEBURTSTAG:
            continue
        try:
            d = datetime.date(int(j), int(m), int(t))
        except ValueError:
            continue
        if datetime.date(2015, 1, 1) <= d <= datetime.date.today():
            treffer.append(d)
    if not treffer:
        return None
    # haeufigstes Datum gewinnt, bei Gleichstand das frueheste
    zaehler = Counter(treffer)
    hoechste = max(zaehler.values())
    return min(d for d, n in zaehler.items() if n == hoechste)

geaendert = datum_neu = 0
for d in Document.objects.order_by("id"):
    if d.id not in Z:
        continue
    titel, korr, typ, tags = Z[d.id]

    d.title = titel
    if korr:
        d.correspondent = Correspondent.objects.get_or_create(name=korr)[0]
    if typ:
        d.document_type = DocumentType.objects.get_or_create(name=typ)[0]

    # Datum reparieren, wo das Geburtsdatum gelandet ist
    if d.created.year < 2015:
        neu = bestes_datum(d.content)
        if neu:
            d.created = timezone.make_aware(datetime.datetime.combine(neu, datetime.time(12, 0)))
            datum_neu += 1

    d.save()

    d.tags.clear()
    for t in tags:
        d.tags.add(Tag.objects.get(name=t))
    geaendert += 1

# Posteingang-Tag nur dort belassen, wo noch etwas zu pruefen ist
inbox = Tag.objects.filter(is_inbox_tag=True).first()
if inbox:
    for d in Document.objects.exclude(tags__name="Pruefen"):
        d.tags.remove(inbox)

print("Zugeordnet:", geaendert)
print("Datum korrigiert:", datum_neu)
print("Noch im Posteingang:", Document.objects.filter(tags=inbox).count() if inbox else 0)
