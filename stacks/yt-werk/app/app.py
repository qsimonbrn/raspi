#!/usr/bin/env python3
"""
yt-werk -- holt Playlist-Eintraege, Metadaten und Transkripte von YouTube.

Warum es diesen Dienst gibt: n8n soll Videos zu Projektfahrplaenen verarbeiten,
aber das n8n-Image bringt weder Python noch yt-dlp mit, und die YouTube Data
API v3 liefert keine Untertitel fremder Videos ("captions.download" geht nur
als Kanaleigentuemer). Also uebernimmt dieser kleine Dienst das Beschaffen und
n8n nur noch das Orchestrieren.

Der Dienst veroeffentlicht KEINEN Port auf dem Host. Er haengt mit n8n im
Docker-Netz "werkbank" und ist ausschliesslich unter http://yt-werk:8722
erreichbar -- damit ist pi-guard nicht beteiligt.

Ablage je Video unter $EINGANG/<video_id>/:
    metadaten.json        ausgewaehlte Felder, nicht die volle info.json
    transkript.txt        Fliesstext, bereinigt und entdoppelt
    transkript-zeit.txt   derselbe Text mit Zeitmarken alle 60 Sekunden
    untertitel.vtt        Rohdatei, falls die Aufbereitung je nachgebessert wird
"""

from __future__ import annotations

import fcntl
import json
import os
import re
import shutil
import tempfile
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import yt_dlp
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

EINGANG = Path(os.environ.get("EINGANG", "/eingang"))
VERARBEITET = EINGANG / ".verarbeitet"

# Rueckfall, wenn das Video keine Sprache meldet. Die eigentliche Reihenfolge
# baut _sprachwunsch() -- Original zuerst.
SPRACH_WUNSCH = ("de", "de-DE", "de-orig", "en", "en-US", "en-GB", "en-orig")

VIDEO_ID = re.compile(r"^[A-Za-z0-9_-]{11}$")
PLAYLIST_ID = re.compile(r"^[A-Za-z0-9_-]{2,64}$")

app = FastAPI(title="yt-werk", version="1.0.0")


# --- Hilfsmittel -------------------------------------------------------------


def _slug(text: str, maxlen: int = 60) -> str:
    """Dateinamentauglicher Bezeichner, passend zur Vault-Konvention."""
    ersatz = {"ä": "ae", "ö": "oe", "ü": "ue", "Ä": "ae", "Ö": "oe", "Ü": "ue", "ß": "ss"}
    for a, b in ersatz.items():
        text = text.replace(a, b)
    text = text.lower()
    text = re.sub(r"[^a-z0-9]+", "-", text)
    return text.strip("-")[:maxlen].strip("-") or "ohne-titel"


def _vtt_lesen(pfad: Path) -> tuple[list[tuple[float, str]], str]:
    """
    Zerlegt eine VTT-Datei in (Sekunde, Text)-Paare.

    Automatische Untertitel wiederholen die vorige Zeile in jedem Block, damit
    der Text im Video mitlaeuft. Ohne Entdopplung steht am Ende jeder Satz
    zwei- bis dreimal da -- das blaeht den Prompt auf und verwirrt das Modell.
    """
    roh = pfad.read_text(encoding="utf-8", errors="replace")
    bloecke: list[tuple[float, str]] = []
    aktuelle_zeit = 0.0

    for zeile in roh.splitlines():
        zeile = zeile.strip()
        if not zeile or zeile.startswith(("WEBVTT", "NOTE", "Kind:", "Language:", "STYLE")):
            continue
        if "-->" in zeile:
            start = zeile.split("-->")[0].strip()
            teile = start.replace(",", ".").split(":")
            try:
                if len(teile) == 3:
                    aktuelle_zeit = int(teile[0]) * 3600 + int(teile[1]) * 60 + float(teile[2])
                elif len(teile) == 2:
                    aktuelle_zeit = int(teile[0]) * 60 + float(teile[1])
            except ValueError:
                pass
            continue
        if zeile.isdigit():
            continue

        text = re.sub(r"<[^>]+>", "", zeile)
        text = text.replace("&nbsp;", " ").replace("&amp;", "&")
        text = text.replace("&lt;", "<").replace("&gt;", ">").replace("&#39;", "'")
        text = re.sub(r"\s+", " ", text).strip()
        if text:
            bloecke.append((aktuelle_zeit, text))

    # Entdoppeln: gleiche Zeile direkt hintereinander, oder die neue Zeile
    # setzt die vorige nur fort (typisches Rollverhalten der Auto-Untertitel).
    sauber: list[tuple[float, str]] = []
    for zeit, text in bloecke:
        if sauber:
            vorher = sauber[-1][1]
            if text == vorher:
                continue
            if text.startswith(vorher):
                sauber[-1] = (sauber[-1][0], text)
                continue
            if vorher.endswith(text):
                continue
        sauber.append((zeit, text))

    fliesstext = " ".join(t for _, t in sauber)
    fliesstext = re.sub(r"\s+", " ", fliesstext).strip()
    # Nach Satzende umbrechen, damit die Datei im Vault lesbar bleibt.
    fliesstext = re.sub(r"(?<=[.!?]) (?=[A-ZÄÖÜ])", "\n", fliesstext)
    return sauber, fliesstext


def _mit_zeitmarken(bloecke: list[tuple[float, str]], abstand: int = 60) -> str:
    """Derselbe Text, alle 60 Sekunden eine [mm:ss]-Marke zum Zitieren."""
    zeilen: list[str] = []
    naechste = 0.0
    puffer: list[str] = []
    for zeit, text in bloecke:
        if zeit >= naechste:
            if puffer:
                zeilen.append(" ".join(puffer))
                puffer = []
            zeilen.append(f"\n[{int(zeit) // 60:02d}:{int(zeit) % 60:02d}]")
            naechste = zeit + abstand
        puffer.append(text)
    if puffer:
        zeilen.append(" ".join(puffer))
    return "\n".join(zeilen).strip()


def _sprachwunsch(info: dict[str, Any]) -> tuple[str, ...]:
    """
    Reihenfolge der gewuenschten Untertitelsprachen -- Originalspur zuerst.

    YouTube bietet zu einem englischen Video rund 150 automatisch UEBERSETZTE
    Faecher an, darunter "de". Nimmt man das, verarbeitet das Modell die
    Maschinenuebersetzung einer Maschinentranskription; Namen und Fachbegriffe
    leiden sichtbar. Die unuebersetzte Spur heisst bei yt-dlp "<sprache>-orig".
    Das Modell kann Englisch lesen und trotzdem einen deutschen Fahrplan
    schreiben -- also lieber die beste Quelle als die bequemste Sprache.
    """
    orig = (info.get("language") or "").split("-")[0]
    wunsch: list[str] = []
    if orig:
        wunsch += [f"{orig}-orig", orig]
    wunsch += [s for s in SPRACH_WUNSCH if s not in wunsch]
    return tuple(wunsch)


def _untertitel_waehlen(info: dict[str, Any]) -> tuple[str | None, bool]:
    """Liefert (Sprachkennung, automatisch?) nach der Wunschreihenfolge."""
    manuell = info.get("subtitles") or {}
    automatisch = info.get("automatic_captions") or {}
    SPRACH_WUNSCH_AKTUELL = _sprachwunsch(info)
    for sprache in SPRACH_WUNSCH_AKTUELL:
        if sprache in manuell:
            return sprache, False
    for sprache in SPRACH_WUNSCH_AKTUELL:
        if sprache in automatisch:
            return sprache, True
    # Nichts aus der Wunschliste: irgendein manueller Untertitel ist immer
    # noch besser als gar keiner.
    if manuell:
        return sorted(manuell)[0], False
    if automatisch:
        return sorted(automatisch)[0], True
    return None, False


def _untertitel_laden(info: dict[str, Any], sprache: str, automatisch: bool,
                      versuche: int = 3) -> str | None:
    """
    Laedt GENAU EINE Untertiteldatei ueber ihre bereits bekannte URL.

    Zuvor liess sich yt-dlp die Untertitel selbst herunterladen. Das quittiert
    YouTube mit "HTTP 429 Too Many Requests", weil ein Sprachmuster wie "de.*"
    auf die automatisch uebersetzten Faecher passt -- yt-dlp fragt dann
    dutzende Dateien in Folge an. Ein einzelner gezielter Abruf laeuft durch.
    """
    quelle = (info.get("automatic_captions") if automatisch else info.get("subtitles")) or {}
    eintraege = quelle.get(sprache) or []
    kandidaten = [e for e in eintraege if e.get("ext") == "vtt"] or list(eintraege)

    for eintrag in kandidaten[:2]:
        adresse = eintrag.get("url")
        if not adresse:
            continue
        for versuch in range(versuche):
            try:
                anfrage = urllib.request.Request(
                    adresse, headers={"User-Agent": "Mozilla/5.0 (yt-werk)"}
                )
                with urllib.request.urlopen(anfrage, timeout=30) as antwort:
                    return antwort.read().decode("utf-8", errors="replace")
            except urllib.error.HTTPError as fehler:
                if fehler.code == 429 and versuch + 1 < versuche:
                    time.sleep(4 * (versuch + 1))
                    continue
                break
            except Exception:
                break
    return None


# --- Modelle -----------------------------------------------------------------


class HolenAnfrage(BaseModel):
    video_id: str = Field(..., description="Die elfstellige YouTube-Video-ID")
    neu_holen: bool = Field(False, description="Vorhandenen Ordner ueberschreiben")


class AblegenAnfrage(BaseModel):
    video_id: str
    dateiname: str = Field(..., description="Nur Name, kein Pfad, .md oder .txt")
    inhalt: str


class VerarbeitetAnfrage(BaseModel):
    video_id: str
    notiz: str = Field("", description="Freitext, landet hinter dem Datum")


# --- Endpunkte ---------------------------------------------------------------


@app.get("/health")
def health() -> dict[str, Any]:
    return {
        "status": "ok",
        "yt_dlp": yt_dlp.version.__version__,
        "eingang": str(EINGANG),
        "eingang_beschreibbar": os.access(EINGANG, os.W_OK),
    }


@app.get("/playlist/{playlist_id}")
def playlist(playlist_id: str) -> dict[str, Any]:
    """Listet eine Playlist auf, ohne die einzelnen Videos zu laden."""
    if not PLAYLIST_ID.match(playlist_id):
        raise HTTPException(400, "unplausible Playlist-ID")

    opts = {
        "quiet": True,
        "no_warnings": True,
        "extract_flat": "in_playlist",
        "skip_download": True,
        "socket_timeout": 30,
        "retries": 3,
    }
    url = f"https://www.youtube.com/playlist?list={playlist_id}"
    try:
        with yt_dlp.YoutubeDL(opts) as ydl:
            info = ydl.extract_info(url, download=False)
    except Exception as fehler:  # yt-dlp wirft sehr verschiedene Typen
        raise HTTPException(502, f"Playlist nicht lesbar: {fehler}") from fehler

    videos = []
    for eintrag in info.get("entries") or []:
        if not eintrag or not eintrag.get("id"):
            continue
        videos.append(
            {
                "video_id": eintrag["id"],
                "titel": eintrag.get("title") or "",
                "kanal": eintrag.get("channel") or eintrag.get("uploader") or "",
                "dauer_s": eintrag.get("duration"),
                "url": f"https://www.youtube.com/watch?v={eintrag['id']}",
            }
        )
    return {
        "playlist_id": playlist_id,
        "titel": info.get("title") or "",
        "anzahl": len(videos),
        "videos": videos,
    }


@app.post("/holen")
def holen(anfrage: HolenAnfrage) -> dict[str, Any]:
    """Laedt Metadaten und Untertitel eines Videos in den Eingang."""
    vid = anfrage.video_id.strip()
    if not VIDEO_ID.match(vid):
        raise HTTPException(400, "unplausible Video-ID")

    ziel = EINGANG / vid
    if ziel.exists() and not anfrage.neu_holen:
        return {"video_id": vid, "ordner": str(ziel), "uebersprungen": True,
                "grund": "Ordner existiert bereits"}

    # Erst in ein temporaeres Verzeichnis, dann umhaengen. Ein abgebrochener
    # Download darf keinen halben Ordner hinterlassen, den n8n fuer fertig haelt.
    with tempfile.TemporaryDirectory(dir=str(EINGANG), prefix=".tmp-") as tmp:
        tmpd = Path(tmp)
        opts = {
            "quiet": True,
            "no_warnings": True,
            "skip_download": True,
            "socket_timeout": 30,
            "retries": 3,
        }
        url = f"https://www.youtube.com/watch?v={vid}"
        try:
            with yt_dlp.YoutubeDL(opts) as ydl:
                info = ydl.extract_info(url, download=False)
        except Exception as fehler:
            raise HTTPException(502, f"Video nicht abrufbar: {fehler}") from fehler

        sprache, automatisch = _untertitel_waehlen(info)
        vtt = None
        if sprache:
            roh = _untertitel_laden(info, sprache, automatisch)
            if roh:
                vtt = tmpd / "untertitel.vtt"
                vtt.write_text(roh, encoding="utf-8")

        bloecke: list[tuple[float, str]] = []
        fliesstext = ""
        if vtt and vtt.exists():
            bloecke, fliesstext = _vtt_lesen(vtt)

        titel = info.get("title") or ""
        kanal = info.get("channel") or info.get("uploader") or ""
        hochgeladen = info.get("upload_date") or ""
        if len(hochgeladen) == 8:
            hochgeladen = f"{hochgeladen[:4]}-{hochgeladen[4:6]}-{hochgeladen[6:]}"

        metadaten = {
            "video_id": vid,
            "titel": titel,
            "kanal": kanal,
            "kanal_id": info.get("channel_id") or "",
            "hochgeladen": hochgeladen,
            "dauer_s": info.get("duration"),
            "url": url,
            "beschreibung": (info.get("description") or "")[:8000],
            "schlagworte": (info.get("tags") or [])[:30],
            "sprache_untertitel": sprache or "",
            "untertitel_automatisch": automatisch,
            "hat_transkript": bool(fliesstext),
            "zeichen_transkript": len(fliesstext),
            "slug": f"{_slug(kanal, 24)}-{_slug(titel, 40)}".strip("-"),
            # Getrennt mitgefuehrt, weil der Workflow daraus Dateinamen baut
            # und ein Slug am Bindestrich nicht zuverlaessig zu trennen ist:
            # "just-rayen-i-built-..." zerfaellt sonst nach "just".
            "kanal_slug": _slug(kanal, 24),
            "titel_slug": _slug(titel, 45),
            "geholt_am": datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds"),
            "geholt_von": f"yt-werk/{app.version} yt-dlp/{yt_dlp.version.__version__}",
        }

        (tmpd / "metadaten.json").write_text(
            json.dumps(metadaten, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )
        if fliesstext:
            (tmpd / "transkript.txt").write_text(fliesstext + "\n", encoding="utf-8")
            (tmpd / "transkript-zeit.txt").write_text(
                _mit_zeitmarken(bloecke) + "\n", encoding="utf-8"
            )

        if ziel.exists():
            shutil.rmtree(ziel)
        tmpd.rename(ziel)
        # rename() entzieht dem TemporaryDirectory sein Verzeichnis; damit das
        # Aufraeumen beim Verlassen nicht stolpert, legen wir es neu an.
        tmpd.mkdir(exist_ok=True)

    ziel.chmod(0o2750)
    return {
        "video_id": vid,
        "ordner": str(ziel),
        "uebersprungen": False,
        **{k: metadaten[k] for k in
           ("titel", "kanal", "hochgeladen", "dauer_s", "slug",
            "hat_transkript", "zeichen_transkript",
            "sprache_untertitel", "untertitel_automatisch")},
    }


@app.post("/ablegen")
def ablegen(anfrage: AblegenAnfrage) -> dict[str, Any]:
    """
    Schreibt eine fertige Notiz in den Ordner des Videos.

    n8n koennte die Datei auch selbst schreiben -- es hat den Eingang
    gemountet --, aber der Dateiknoten arbeitet mit Binaerdaten und macht den
    Workflow unnoetig sperrig. So bleibt das Schreiben an einer Stelle.
    """
    vid = anfrage.video_id.strip()
    if not VIDEO_ID.match(vid):
        raise HTTPException(400, "unplausible Video-ID")
    name = anfrage.dateiname.strip()
    if not re.fullmatch(r"[A-Za-z0-9._-]{1,80}\.(md|txt|json)", name) or name.startswith("."):
        raise HTTPException(400, "unzulaessiger Dateiname")

    ordner = EINGANG / vid
    if not ordner.is_dir():
        raise HTTPException(404, "nicht im Eingang")

    ziel = ordner / name
    # Erst daneben schreiben, dann umhaengen: ein abgebrochener Schreibvorgang
    # darf keine halbe Notiz hinterlassen, die der Mac abends mitnimmt.
    vorlaeufig = ordner / f".{name}.neu"
    vorlaeufig.write_text(anfrage.inhalt, encoding="utf-8")
    vorlaeufig.replace(ziel)
    return {"video_id": vid, "datei": str(ziel), "zeichen": len(anfrage.inhalt)}


@app.get("/verarbeitet")
def verarbeitet_lesen() -> dict[str, Any]:
    """Die Liste bereits abgelegter Videos -- eine Zeile je Video-ID."""
    if not VERARBEITET.exists():
        return {"anzahl": 0, "video_ids": []}
    ids = []
    for zeile in VERARBEITET.read_text(encoding="utf-8", errors="replace").splitlines():
        zeile = zeile.strip()
        if zeile and not zeile.startswith("#"):
            ids.append(zeile.split()[0])
    return {"anzahl": len(ids), "video_ids": ids}


@app.get("/offen")
def offen() -> dict[str, Any]:
    """
    Alle abgelegten Videos, die noch nicht ausgearbeitet wurden.

    Damit muss Workflow B kein Verzeichnis durchsuchen und keine Liste
    abgleichen -- er bekommt fertig, was zu tun ist.
    """
    erledigt = set(verarbeitet_lesen()["video_ids"])
    eintraege = []
    for ordner in sorted(EINGANG.iterdir()):
        if not ordner.is_dir() or ordner.name.startswith("."):
            continue
        if ordner.name in erledigt:
            continue
        meta = ordner / "metadaten.json"
        if not meta.exists():
            continue
        try:
            daten = json.loads(meta.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            continue
        eintraege.append(
            {k: daten.get(k) for k in
             ("video_id", "titel", "kanal", "hochgeladen", "dauer_s", "url",
              "slug", "kanal_slug", "titel_slug",
              "hat_transkript", "zeichen_transkript")}
        )
    return {"anzahl": len(eintraege), "videos": eintraege}


@app.get("/video/{video_id}")
def video(video_id: str, mit_zeit: bool = False) -> dict[str, Any]:
    """Metadaten und Transkript eines abgelegten Videos in einem Rutsch."""
    if not VIDEO_ID.match(video_id):
        raise HTTPException(400, "unplausible Video-ID")
    ordner = EINGANG / video_id
    meta = ordner / "metadaten.json"
    if not meta.exists():
        raise HTTPException(404, "nicht im Eingang")

    daten = json.loads(meta.read_text(encoding="utf-8"))
    datei = ordner / ("transkript-zeit.txt" if mit_zeit else "transkript.txt")
    daten["transkript"] = datei.read_text(encoding="utf-8") if datei.exists() else ""
    return daten


@app.post("/verarbeitet")
def verarbeitet_eintragen(anfrage: VerarbeitetAnfrage) -> dict[str, Any]:
    """
    Haengt eine Video-ID an die Liste an -- erst NACH erfolgreicher Ablage
    aufzurufen. Mit Dateisperre, damit zwei gleichzeitige Laeufe sich nicht
    gegenseitig ueberschreiben.
    """
    vid = anfrage.video_id.strip()
    if not VIDEO_ID.match(vid):
        raise HTTPException(400, "unplausible Video-ID")

    datum = datetime.now(timezone.utc).astimezone().strftime("%Y-%m-%d %H:%M")
    zeile = f"{vid}\t{datum}"
    if anfrage.notiz:
        zeile += f"\t{anfrage.notiz.strip()[:200]}"

    VERARBEITET.touch(exist_ok=True)
    with VERARBEITET.open("r+", encoding="utf-8") as f:
        fcntl.flock(f, fcntl.LOCK_EX)
        inhalt = f.read()
        vorhanden = any(z.split("\t")[0].strip() == vid for z in inhalt.splitlines())
        if not vorhanden:
            if inhalt and not inhalt.endswith("\n"):
                f.write("\n")
            f.write(zeile + "\n")
        f.flush()
        os.fsync(f.fileno())
        fcntl.flock(f, fcntl.LOCK_UN)
    return {"video_id": vid, "eingetragen": not vorhanden}


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8722, log_level="info")
