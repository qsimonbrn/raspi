#!/usr/bin/env python3
"""
Einmaliger Modellvergleich: qwen3.5:9b gegen qwen3.5:4b an einem echten
Transkript, mit genau dem Prompt, den Workflow B spaeter verwendet.

Aufruf:  python3 vergleich.py <video_id>
Liegt bewusst im Repo: der Vergleich soll wiederholbar sein, wenn ein neues
Modell dazukommt oder der Prompt sich aendert.
"""
import json
import sys
import time
import urllib.request

OLLAMA = "http://100.69.172.65:11434"
YTWERK = "http://yt-werk:8722"
MODELLE = ["qwen3.5:9b", "qwen3.5:4b"]

PROMPT = """Du bist ein nüchterner Projektplaner. Aus dem folgenden Video-Transkript
entsteht ein Projektfahrplan für Simon, einen IT-Systemintegrator mit Erfahrung
in Python, n8n, Docker und lokalen LLMs. Er betreibt einen Raspberry Pi 4 (4 GB)
mit Docker und ein MacBook, auf dem Ollama läuft.

Schreibe auf Deutsch, in ganzen Sätzen, ohne Werbesprache und ohne Floskeln.
Erfinde nichts, was nicht im Transkript steht; wo etwas offen bleibt, schreibe,
dass es offen ist.

Gliedere genau so:

## Worum es geht
Zwei bis vier Sätze: was im Video gezeigt wird und was daran für ein eigenes
Projekt taugt.

## Was dabei herauskommen soll
Ein konkretes, überprüfbares Ergebnis in ein bis zwei Sätzen.

## Bausteine
Eine Liste der benötigten Technik, je Zeile ein Baustein mit kurzer Begründung.

## Schritte
Nummerierte Schritte vom Nichts bis zum lauffähigen Ergebnis, je Schritt ein
Satz plus geschätzter Aufwand in Stunden.

## Hürden
Was schiefgehen kann, und woran man es früh merkt.

## Aufwand insgesamt
Eine Zahl in Stunden und ein Satz zur Unsicherheit.

Transkript des Videos "{titel}" von {kanal}:

{transkript}
"""


def hole(video_id: str) -> dict:
    with urllib.request.urlopen(f"{YTWERK}/video/{video_id}", timeout=30) as r:
        return json.load(r)


def frage(modell: str, prompt: str) -> tuple[str, float, dict]:
    nutzlast = {
        "model": modell,
        "prompt": prompt,
        "stream": False,
        "think": False,
        "options": {"temperature": 0.3, "num_ctx": 32768},
    }
    anfrage = urllib.request.Request(
        f"{OLLAMA}/api/generate",
        data=json.dumps(nutzlast).encode(),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    start = time.time()
    with urllib.request.urlopen(anfrage, timeout=1800) as r:
        antwort = json.load(r)
    return antwort.get("response", ""), time.time() - start, antwort


def main() -> None:
    vid = sys.argv[1] if len(sys.argv) > 1 else "NwyrKtBvLzQ"
    daten = hole(vid)
    prompt = PROMPT.format(
        titel=daten["titel"], kanal=daten["kanal"], transkript=daten["transkript"]
    )
    print(f"Video: {daten['titel']} ({daten['zeichen_transkript']} Zeichen)")
    print(f"Prompt: {len(prompt)} Zeichen\n")

    for modell in MODELLE:
        try:
            text, dauer, roh = frage(modell, prompt)
        except Exception as fehler:
            print(f"--- {modell}: FEHLER {type(fehler).__name__}: {str(fehler)[:200]}\n")
            continue
        ziel = f"/eingang/{vid}/_vergleich-{modell.replace(':', '-')}.md"
        with open(ziel, "w", encoding="utf-8") as f:
            f.write(text)
        print(f"--- {modell}")
        print(f"    Dauer:        {dauer:.0f} s")
        print(f"    Eingabetoken: {roh.get('prompt_eval_count')}")
        print(f"    Ausgabetoken: {roh.get('eval_count')}")
        print(f"    Zeichen:      {len(text)}")
        print(f"    Abgelegt:     {ziel}\n")


if __name__ == "__main__":
    main()
