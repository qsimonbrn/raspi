#!/usr/bin/env python3
"""
Erzeugt die beiden Workbench-Workflows und spielt sie ueber die n8n-API ein.

Die Workflows werden hier im Repo beschrieben und nicht in der Oberflaeche
zusammengeklickt: so sind sie versioniert, nachvollziehbar und nach einem
Datenverlust in einer Minute wieder da.

    python3 workflows-einspielen.py                      # anlegen/aktualisieren
    python3 workflows-einspielen.py --takt "* * * * *"   # Testtakt
    python3 workflows-einspielen.py --aktivieren

Der Schluessel steht in .n8n-api-key daneben und wird nie ausgegeben.
"""
from __future__ import annotations

import argparse
import json
import sys
import urllib.error
import urllib.request
from pathlib import Path

N8N = "http://100.108.219.87:5678/api/v1"
SCHLUESSEL = (Path(__file__).parent / ".n8n-api-key").read_text().strip()

PLAYLIST_ID = "PLScL2m9be3F8"
MODELL = "qwen3.5:4b"
OLLAMA = "http://100.69.172.65:11434"
YTWERK = "http://yt-werk:8722"

TAKT_A = "0 8-22 * * *"
TAKT_B = "20 8-22 * * *"


def api(pfad: str, methode: str = "GET", daten: dict | None = None) -> dict:
    anfrage = urllib.request.Request(
        f"{N8N}{pfad}",
        data=json.dumps(daten).encode() if daten is not None else None,
        headers={"X-N8N-API-KEY": SCHLUESSEL, "Content-Type": "application/json"},
        method=methode,
    )
    try:
        with urllib.request.urlopen(anfrage, timeout=60) as antwort:
            roh = antwort.read()
            return json.loads(roh) if roh else {}
    except urllib.error.HTTPError as fehler:
        print(f"FEHLER {fehler.code} bei {methode} {pfad}: {fehler.read().decode()[:800]}")
        raise


def knoten(name, typ, version, position, parameter, extra=None) -> dict:
    k = {
        "parameters": parameter,
        "name": name,
        "type": typ,
        "typeVersion": version,
        "position": position,
    }
    if extra:
        k.update(extra)
    return k


def kette(*namen) -> dict:
    """Verbindet die Knoten der Reihe nach."""
    verbindungen = {}
    for a, b in zip(namen, namen[1:]):
        verbindungen[a] = {"main": [[{"node": b, "type": "main", "index": 0}]]}
    return verbindungen


def http(url, methode="GET", koerper=None, timeout=120000, weiter_bei_fehler=False):
    p = {"url": url, "options": {"timeout": timeout}}
    if methode != "GET":
        p["method"] = methode
    if koerper:
        p.update({"sendBody": True, "specifyBody": "json", "jsonBody": koerper})
    extra = {"onError": "continueRegularOutput"} if weiter_bei_fehler else None
    return p, extra


# --- Workflow A: Einsammeln --------------------------------------------------


def workflow_a(takt: str) -> dict:
    p_holen, _ = http(f"{YTWERK}/holen", "POST",
                      "={{ JSON.stringify({ video_id: $json.video_id }) }}", 300000)
    p_liste, _ = http("=" + YTWERK + "/playlist/{{ $json.playlist_id }}")

    knoten_liste = [
        knoten("Takt", "n8n-nodes-base.scheduleTrigger", 1.2, [0, 0],
               {"rule": {"interval": [{"field": "cronExpression", "expression": takt}]}}),
        knoten("Playlist festlegen", "n8n-nodes-base.set", 3.4, [200, 0],
               {"assignments": {"assignments": [
                   {"id": "pl", "name": "playlist_id", "value": PLAYLIST_ID, "type": "string"}]},
                "options": {}}),
        knoten("Playlist lesen", "n8n-nodes-base.httpRequest", 4.2, [400, 0], p_liste),
        knoten("Videos einzeln", "n8n-nodes-base.splitOut", 1, [600, 0],
               {"fieldToSplitOut": "videos", "options": {}}),
        knoten("Video holen", "n8n-nodes-base.httpRequest", 4.2, [800, 0], p_holen),
        knoten("Nur neue", "n8n-nodes-base.filter", 2, [1000, 0],
               {"conditions": {
                   "options": {"caseSensitive": True, "leftValue": "",
                               "typeValidation": "strict", "version": 2},
                   "conditions": [{"id": "neu", "leftValue": "={{ $json.uebersprungen }}",
                                   "rightValue": "",
                                   "operator": {"type": "boolean", "operation": "false",
                                                "singleValue": True}}],
                   "combinator": "and"}, "options": {}}),
        knoten("Eingesammelt", "n8n-nodes-base.noOp", 1, [1200, 0], {}),
    ]
    return {
        "name": "Workbench A -- Einsammeln",
        "nodes": knoten_liste,
        "connections": kette("Takt", "Playlist festlegen", "Playlist lesen",
                             "Videos einzeln", "Video holen", "Nur neue", "Eingesammelt"),
        "settings": {"executionOrder": "v1", "executionTimeout": 1800,
                     "saveDataErrorExecution": "all", "saveDataSuccessExecution": "all"},
    }


# --- Workflow B: Ausarbeiten -------------------------------------------------

PROMPT_JS = r"""
const d = $json;
const fahrplan = `Du bist ein nüchterner Projektplaner. Aus dem folgenden Video-Transkript
entsteht ein Projektfahrplan für Simon, einen IT-Systemintegrator mit Erfahrung
in Python, n8n, Docker und lokalen LLMs. Er betreibt einen Raspberry Pi 4 (4 GB)
mit Docker und ein MacBook, auf dem Ollama läuft.

Schreibe auf Deutsch, in ganzen Sätzen, ohne Werbesprache und ohne Floskeln.
Erfinde nichts, was nicht im Transkript steht; wo etwas offen bleibt, schreibe,
dass es offen ist.

Gliedere genau so:

## Worum es geht
Zwei bis vier Sätze: was im Video gezeigt wird und was daran für ein eigenes Projekt taugt.

## Was dabei herauskommen soll
Ein konkretes, überprüfbares Ergebnis in ein bis zwei Sätzen.

## Bausteine
Eine Liste der benötigten Technik, je Zeile ein Baustein mit kurzer Begründung.

## Schritte
Nummerierte Schritte vom Nichts bis zum lauffähigen Ergebnis, je Schritt ein Satz
plus geschätzter Aufwand in Stunden.

## Hürden
Was schiefgehen kann, und woran man es früh merkt.

## Aufwand insgesamt
Eine Zahl in Stunden und ein Satz zur Unsicherheit.

Transkript des Videos "${d.titel}" von ${d.kanal}:

${d.transkript}
`;

const kurz = `Fasse das folgende Video-Transkript in GENAU EINEM deutschen Satz zusammen,
höchstens 200 Zeichen, ohne Einleitung, ohne Anführungszeichen. Der Satz muss die
Notiz ersetzen können, wenn nur zu entscheiden ist, ob sie relevant ist.

Transkript des Videos "${d.titel}" von ${d.kanal}:

${d.transkript}
`;

return { json: { ...d, prompt_fahrplan: fahrplan, prompt_kurz: kurz } };
"""

NOTIZEN_JS = r"""
const q = $('Video mit Transkript').item.json;
const fahrplanText = ($('Fahrplan erzeugen').item.json.response || '').trim();
let zusammenfassung = ($json.response || '').trim().split('\n')[0]
  .replace(/^["'\s]+|["'\s]+$/g, '').slice(0, 200);
if (!zusammenfassung) zusammenfassung = `Videonotiz zu "${q.titel}" von ${q.kanal}.`;

const heute = new Date().toISOString().slice(0, 10);
const kanalSlug = q.kanal_slug || 'unbekannt';
// Bis zu fuenf Woerter aus dem Titel: der Dateiname ist der Link und muss in
// einem Jahr noch verraten, was drinsteht -- ohne endlos lang zu werden.
const stichwort = (q.titel_slug || 'video').split('-').slice(0, 5).join('-') || 'video';

// Frontmatter nach der Vault-Konvention aus CLAUDE.md. Der Parser in
// index-bauen.py vertraegt nur Buchstaben und Unterstrich in Feldnamen --
// deshalb video_id und nicht video-id. Werte werden gequotet.
const z = (t) => JSON.stringify(String(t == null ? '' : t));

const quelleName = `quelle-yt-${kanalSlug}-${stichwort}.md`;
const fahrplanName = `fahrplan-${stichwort}.md`;
const quelleLink = quelleName.replace(/\.md$/, '');
const fahrplanLink = fahrplanName.replace(/\.md$/, '');

const quelle = `---
titel: ${z(q.titel)}
typ: quelle
status: keim
zusammenfassung: ${z(zusammenfassung)}
erstellt: ${heute}
aktualisiert: ${heute}
tags: [typ/quelle, thema/automatisierung, projekt/workbench]
quelle: ${z(q.url)}
verwandt: ["[[${fahrplanLink}]]"]
video_id: ${q.video_id}
kanal: ${z(q.kanal)}
veroeffentlicht: ${q.hochgeladen || ''}
dauer_min: ${Math.round((q.dauer_s || 0) / 60)}
---

# ${q.titel}

${zusammenfassung}

## Fundstelle

- Video: ${q.url}
- Kanal: ${q.kanal}
- Veröffentlicht: ${q.hochgeladen || 'unbekannt'}
- Untertitelspur: ${q.sprache_untertitel}${q.untertitel_automatisch ? ' (automatisch erzeugt)' : ' (manuell)'}
- Transkript: \`_anhaenge/yt/${q.video_id}/transkript.txt\` (${q.zeichen_transkript} Zeichen)

## Abgeleitet

- [[${fahrplanLink}]]

> [!info] Maschinell erzeugt
> Diese Notiz stammt aus der Workbench. Die Zusammenfassung schrieb ein lokales
> Modell, nicht Simon. Eine Wissensnotiz daraus zu machen bleibt Handarbeit --
> eine Quellennotiz ohne abgeleitete Wissensnotiz ist unverdaut.
`;

const fahrplan = `---
titel: ${z('Fahrplan: ' + q.titel)}
typ: projekt
status: keim
zusammenfassung: ${z('Projektvorschlag aus einem Video von ' + q.kanal + ': ' + zusammenfassung)}
erstellt: ${heute}
aktualisiert: ${heute}
tags: [status/vorschlag, projekt/workbench, thema/automatisierung]
quelle: ${z(q.url)}
verwandt: ["[[${quelleLink}]]"]
video_id: ${q.video_id}
---

# Fahrplan: ${q.titel}

> [!warning] Vorschlag, nicht beschlossen
> Erzeugt von der Workbench aus [[${quelleLink}]]. Beim Annehmen eine Ebene
> höher nach \`10_Projekte/\` verschieben und \`status/vorschlag\` durch einen
> echten Status ersetzen.

${fahrplanText}
`;

const ablage = {
  video_id: q.video_id,
  erzeugt: new Date().toISOString(),
  dateien: [
    { datei: fahrplanName, ziel: '10_Projekte/_fahrplaene/' },
    { datei: quelleName, ziel: '40_Quellen/' },
    { datei: 'transkript.txt', ziel: `_anhaenge/yt/${q.video_id}/` },
    { datei: 'transkript-zeit.txt', ziel: `_anhaenge/yt/${q.video_id}/` },
    { datei: 'metadaten.json', ziel: `_anhaenge/yt/${q.video_id}/` },
    { datei: 'untertitel.vtt', ziel: `_anhaenge/yt/${q.video_id}/` }
  ]
};

return { json: {
  video_id: q.video_id,
  titel: q.titel,
  quelle_name: quelleName, quelle_inhalt: quelle,
  fahrplan_name: fahrplanName, fahrplan_inhalt: fahrplan,
  ablage_inhalt: JSON.stringify(ablage, null, 2)
} };
"""


def workflow_b(takt: str) -> dict:
    p_tags, e_tags = http(f"{OLLAMA}/api/tags", timeout=8000, weiter_bei_fehler=True)
    p_offen, _ = http(f"{YTWERK}/offen")
    p_video, _ = http("=" + YTWERK + "/video/{{ $json.video_id }}")
    p_fahrplan, _ = http(
        f"{OLLAMA}/api/generate", "POST",
        "={{ JSON.stringify({ model: '" + MODELL + "', prompt: $json.prompt_fahrplan,"
        " stream: false, think: false, options: { temperature: 0.3, num_ctx: 32768 } }) }}",
        1800000)
    p_kurz, _ = http(
        f"{OLLAMA}/api/generate", "POST",
        "={{ JSON.stringify({ model: '" + MODELL + "',"
        " prompt: $('Prompt bauen').item.json.prompt_kurz,"
        " stream: false, think: false, options: { temperature: 0.2, num_ctx: 32768 } }) }}",
        1800000)

    def ablegen(feld_name, feld_inhalt):
        return http(f"{YTWERK}/ablegen", "POST",
                    "={{ JSON.stringify({ video_id: $('Notizen bauen').item.json.video_id,"
                    f" dateiname: $('Notizen bauen').item.json.{feld_name},"
                    f" inhalt: $('Notizen bauen').item.json.{feld_inhalt} }}) }}}}", 60000)[0]

    knoten_liste = [
        knoten("Takt", "n8n-nodes-base.scheduleTrigger", 1.2, [0, 0],
               {"rule": {"interval": [{"field": "cronExpression", "expression": takt}]}}),
        knoten("Ollama fragen", "n8n-nodes-base.httpRequest", 4.2, [200, 0], p_tags, e_tags),
        knoten("Antwortet Ollama", "n8n-nodes-base.if", 2, [400, 0],
               {"conditions": {
                   "options": {"caseSensitive": True, "leftValue": "",
                               "typeValidation": "loose", "version": 2},
                   "conditions": [{"id": "da", "leftValue": "={{ $json.models }}",
                                   "rightValue": "",
                                   "operator": {"type": "array", "operation": "exists",
                                                "singleValue": True}}],
                   "combinator": "and"}, "options": {}}),
        knoten("Offene Videos", "n8n-nodes-base.httpRequest", 4.2, [600, 0], p_offen),
        knoten("Videos einzeln", "n8n-nodes-base.splitOut", 1, [800, 0],
               {"fieldToSplitOut": "videos", "options": {}}),
        knoten("Hat Transkript", "n8n-nodes-base.filter", 2, [1000, 0],
               {"conditions": {
                   "options": {"caseSensitive": True, "leftValue": "",
                               "typeValidation": "strict", "version": 2},
                   "conditions": [{"id": "tr", "leftValue": "={{ $json.hat_transkript }}",
                                   "rightValue": "",
                                   "operator": {"type": "boolean", "operation": "true",
                                                "singleValue": True}}],
                   "combinator": "and"}, "options": {}}),
        knoten("Video mit Transkript", "n8n-nodes-base.httpRequest", 4.2, [1200, 0], p_video),
        knoten("Prompt bauen", "n8n-nodes-base.code", 2, [1400, 0],
               {"mode": "runOnceForEachItem", "jsCode": PROMPT_JS}),
        knoten("Fahrplan erzeugen", "n8n-nodes-base.httpRequest", 4.2, [1600, 0], p_fahrplan),
        knoten("Zusammenfassung erzeugen", "n8n-nodes-base.httpRequest", 4.2, [1800, 0], p_kurz),
        knoten("Notizen bauen", "n8n-nodes-base.code", 2, [2000, 0],
               {"mode": "runOnceForEachItem", "jsCode": NOTIZEN_JS}),
        knoten("Fahrplan ablegen", "n8n-nodes-base.httpRequest", 4.2, [2200, 0],
               ablegen("fahrplan_name", "fahrplan_inhalt")),
        knoten("Quellennotiz ablegen", "n8n-nodes-base.httpRequest", 4.2, [2400, 0],
               ablegen("quelle_name", "quelle_inhalt")),
        knoten("Ablageplan schreiben", "n8n-nodes-base.httpRequest", 4.2, [2600, 0],
               http(f"{YTWERK}/ablegen", "POST",
                    "={{ JSON.stringify({ video_id: $('Notizen bauen').item.json.video_id,"
                    " dateiname: 'ablage.json',"
                    " inhalt: $('Notizen bauen').item.json.ablage_inhalt }) }}", 60000)[0]),
        knoten("Als verarbeitet merken", "n8n-nodes-base.httpRequest", 4.2, [2800, 0],
               http(f"{YTWERK}/verarbeitet", "POST",
                    "={{ JSON.stringify({ video_id: $('Notizen bauen').item.json.video_id,"
                    " notiz: 'Fahrplan erzeugt' }) }}", 60000)[0]),
    ]

    verbindungen = kette("Offene Videos", "Videos einzeln", "Hat Transkript",
                         "Video mit Transkript", "Prompt bauen", "Fahrplan erzeugen",
                         "Zusammenfassung erzeugen", "Notizen bauen", "Fahrplan ablegen",
                         "Quellennotiz ablegen", "Ablageplan schreiben",
                         "Als verarbeitet merken")
    verbindungen["Takt"] = {"main": [[{"node": "Ollama fragen", "type": "main", "index": 0}]]}
    verbindungen["Ollama fragen"] = {
        "main": [[{"node": "Antwortet Ollama", "type": "main", "index": 0}]]}
    # Nur der Ja-Ausgang geht weiter. Kein Nein-Zweig: schweigt der Mac, endet
    # der Lauf still, und die Eintraege bleiben bis zum naechsten Takt liegen.
    verbindungen["Antwortet Ollama"] = {
        "main": [[{"node": "Offene Videos", "type": "main", "index": 0}], []]}

    return {
        "name": "Workbench B -- Ausarbeiten",
        "nodes": knoten_liste,
        "connections": verbindungen,
        "settings": {"executionOrder": "v1", "executionTimeout": 3600,
                     "saveDataErrorExecution": "all", "saveDataSuccessExecution": "all"},
    }


# --- Einspielen --------------------------------------------------------------


def einspielen(entwurf: dict) -> str:
    vorhanden = {w["name"]: w["id"] for w in api("/workflows")["data"]}
    name = entwurf["name"]
    if name in vorhanden:
        kennung = vorhanden[name]
        api(f"/workflows/{kennung}", "PUT", entwurf)
        print(f"aktualisiert: {name} ({kennung})")
    else:
        kennung = api("/workflows", "POST", entwurf)["id"]
        print(f"angelegt:     {name} ({kennung})")
    return kennung


def main() -> None:
    zerleger = argparse.ArgumentParser()
    zerleger.add_argument("--takt", help="Cron fuer BEIDE Workflows, z.B. '* * * * *'")
    zerleger.add_argument("--nur", choices=["a", "b"], help="nur einen einspielen")
    zerleger.add_argument("--aktivieren", action="store_true")
    zerleger.add_argument("--deaktivieren", action="store_true")
    argumente = zerleger.parse_args()

    aufgaben = []
    if argumente.nur in (None, "a"):
        aufgaben.append(workflow_a(argumente.takt or TAKT_A))
    if argumente.nur in (None, "b"):
        aufgaben.append(workflow_b(argumente.takt or TAKT_B))

    for entwurf in aufgaben:
        kennung = einspielen(entwurf)
        if argumente.aktivieren:
            api(f"/workflows/{kennung}/activate", "POST", {})
            print("  aktiviert")
        if argumente.deaktivieren:
            api(f"/workflows/{kennung}/deactivate", "POST", {})
            print("  deaktiviert")


if __name__ == "__main__":
    sys.exit(main())
