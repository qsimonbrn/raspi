"""insta-triage — Sichten und Sortieren der eigenen Instagram-Abos.

Die App liest ausschliesslich vorbereitete JSON-Dateien ein. Sie hat keinen
Zugang zu Instagram und fuehrt selbst kein Entfolgen aus; sie fuehrt Listen.

Kommandozeile:
    python app.py import   # /data/import/*.json einlesen
    python app.py pics     # Profilbilder von der CDN holen
    python app.py serve    # Weboberflaeche (Standard)
"""

import io
import json
import os
import threading
import re
import sqlite3
import sys
import datetime
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor

import httpx
from contextlib import redirect_stdout
from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

DATA = Path(os.environ.get("DATA_DIR", "/data"))
DB_PATH = DATA / "triage.db"
PICS = DATA / "pics"
IMPORT_DIR = DATA / "import"
STATIC = Path(__file__).parent / "static"

KATEGORIEN = [
    "unklar", "person", "memes", "cosplay", "anime", "musik", "creator",
    "gaming", "adult", "kunst", "marke", "essen", "sport", "reisen", "tech",
]
ENTSCHEIDUNGEN = ["offen", "behalten", "entfolgen", "migrieren"]

SCHEMA = """
CREATE TABLE IF NOT EXISTS accounts (
  username      TEXT PRIMARY KEY,
  pk            TEXT,
  full_name     TEXT    DEFAULT '',
  followed_at   TEXT,
  jahr          INTEGER,
  follows_back  INTEGER DEFAULT 0,
  close_friend  INTEGER DEFAULT 0,
  is_private    INTEGER DEFAULT 0,
  is_verified   INTEGER DEFAULT 0,
  pic_url       TEXT    DEFAULT '',
  pic_file      TEXT    DEFAULT '',
  kategorie     TEXT    DEFAULT 'unklar',
  entscheidung  TEXT    DEFAULT 'offen',
  erledigt_haupt  INTEGER DEFAULT 0,
  erledigt_zweit  INTEGER DEFAULT 0,
  notiz         TEXT    DEFAULT '',
  geaendert_am  TEXT    DEFAULT ''
);
CREATE INDEX IF NOT EXISTS idx_ent ON accounts(entscheidung);
CREATE INDEX IF NOT EXISTS idx_kat ON accounts(kategorie);
"""


def db():
    c = sqlite3.connect(DB_PATH, timeout=15)
    c.row_factory = sqlite3.Row
    c.execute("PRAGMA journal_mode=WAL")
    return c


def init():
    for d in (PICS, IMPORT_DIR):
        d.mkdir(parents=True, exist_ok=True)
    with db() as c:
        c.executescript(SCHEMA)


def jetzt():
    return datetime.datetime.now().isoformat(timespec="seconds")


# --------------------------------------------------------------------------
# Import
# --------------------------------------------------------------------------

def _uname(eintrag):
    sld = (eintrag.get("string_list_data") or [{}])[0]
    return (eintrag.get("title")
            or sld.get("value")
            or sld.get("href", "").rstrip("/").split("/")[-1])


def _label_namen(daten):
    """blocked/close_friends/restricted-Format -> {username: name}"""
    out = {}
    for e in daten:
        lv = {x["label"]: x["value"] for x in e.get("label_values", [])}
        u = lv.get("Benutzername") or lv.get("Username")
        if u:
            out[u] = lv.get("Name", "")
    return out


def importiere():
    init()
    dateien = sorted(IMPORT_DIR.glob("*.json"))
    if not dateien:
        print(f"Keine JSON-Dateien in {IMPORT_DIR}")
        return

    following, followers, close, profile = {}, set(), {}, {}

    for p in dateien:
        name = p.name.lower()
        try:
            daten = json.loads(p.read_text(encoding="utf-8"))
        except Exception as e:
            print(f"  ! {p.name}: nicht lesbar ({e})")
            continue

        if isinstance(daten, dict) and "relationships_following" in daten:
            for e in daten["relationships_following"]:
                ts = (e.get("string_list_data") or [{}])[0].get("timestamp")
                following[_uname(e)] = ts
            print(f"  + {p.name}: {len(daten['relationships_following'])} Abos")

        elif isinstance(daten, list) and daten and "username" in daten[0]:
            for e in daten:
                profile[e["username"]] = e
            print(f"  + {p.name}: {len(daten)} Profile (Namen und Bilder)")

        elif isinstance(daten, list) and daten and "label_values" in daten[0]:
            if "close_friend" in name:
                close = _label_namen(daten)
                print(f"  + {p.name}: {len(close)} enge Freunde")
            else:
                print(f"  - {p.name}: uebersprungen (nicht benoetigt)")

        elif isinstance(daten, list) and daten and "string_list_data" in daten[0]:
            if "follower" in name:
                followers = {_uname(e) for e in daten}
                print(f"  + {p.name}: {len(followers)} Follower")
            else:
                print(f"  - {p.name}: uebersprungen (nicht benoetigt)")
        else:
            print(f"  - {p.name}: unbekanntes Format, uebersprungen")

    if not following and not profile:
        print("Weder Abo-Liste noch Profildaten gefunden — nichts zu tun.")
        return

    # Profildaten allein reichen auch, falls der Export fehlt
    alle = set(following) | set(profile)
    neu = geaendert = 0
    with db() as c:
        vorhanden = {r["username"] for r in c.execute("SELECT username FROM accounts")}
        for u in sorted(alle):
            ts = following.get(u)
            datum = (datetime.datetime.utcfromtimestamp(ts).strftime("%Y-%m-%d")
                     if ts else None)
            jahr = int(datum[:4]) if datum else None
            pr = profile.get(u, {})
            felder = {
                "pk": str(pr.get("pk", "")) or None,
                "full_name": pr.get("full_name") or None,
                "is_private": int(bool(pr.get("is_private"))) if pr else None,
                "is_verified": int(bool(pr.get("is_verified"))) if pr else None,
                "pic_url": pr.get("pic") or pr.get("profile_pic_url") or None,
                "followed_at": datum,
                "jahr": jahr,
                "follows_back": int(u in followers) if followers else None,
                "close_friend": int(u in close) if close else None,
            }
            felder = {k: v for k, v in felder.items() if v is not None}
            if u in vorhanden:
                if felder:
                    setzt = ", ".join(f"{k}=?" for k in felder)
                    c.execute(f"UPDATE accounts SET {setzt} WHERE username=?",
                              (*felder.values(), u))
                    geaendert += 1
            else:
                felder["username"] = u
                felder["geaendert_am"] = jetzt()
                spalten = ", ".join(felder)
                frage = ", ".join("?" * len(felder))
                c.execute(f"INSERT INTO accounts ({spalten}) VALUES ({frage})",
                          tuple(felder.values()))
                neu += 1

        # Abos, die im neuen Export fehlen, bleiben stehen — aber sichtbar
        if following:
            weg = vorhanden - alle
            if weg:
                print(f"  ! {len(weg)} Accounts stehen in der Datenbank, "
                      f"aber nicht mehr im Export (entfolgt oder geloescht)")

    print(f"Fertig: {neu} neu, {geaendert} aktualisiert.")
    _stand()


def _stand():
    with db() as c:
        n = c.execute("SELECT COUNT(*) FROM accounts").fetchone()[0]
        mit_bild = c.execute("SELECT COUNT(*) FROM accounts WHERE pic_file<>''").fetchone()[0]
        mit_name = c.execute("SELECT COUNT(*) FROM accounts WHERE full_name<>''").fetchone()[0]
    print(f"Datenbank: {n} Accounts, {mit_name} mit Klarnamen, {mit_bild} mit Bild.")


# --------------------------------------------------------------------------
# Profilbilder
# --------------------------------------------------------------------------

def _hole_bild(klient, username, url):
    ziel = PICS / f"{re.sub(r'[^A-Za-z0-9_.-]', '_', username)}.jpg"
    if ziel.exists() and ziel.stat().st_size > 0:
        return username, ziel.name, None
    try:
        r = klient.get(url, timeout=20)
        if r.status_code != 200 or not r.content:
            return username, None, f"HTTP {r.status_code}"
        ziel.write_bytes(r.content)
        return username, ziel.name, None
    except Exception as e:
        return username, None, str(e)


def hole_bilder():
    init()
    with db() as c:
        offen = c.execute(
            "SELECT username, pic_url FROM accounts "
            "WHERE pic_url<>'' AND (pic_file='' OR pic_file IS NULL)"
        ).fetchall()
    if not offen:
        print("Keine Bilder offen.")
        return
    print(f"{len(offen)} Bilder zu holen …")
    kopf = {"User-Agent": "Mozilla/5.0"}
    ok = fehler = 0
    with httpx.Client(headers=kopf, follow_redirects=True) as klient:
        with ThreadPoolExecutor(max_workers=5) as pool:
            ergebnisse = pool.map(
                lambda r: _hole_bild(klient, r["username"], r["pic_url"]), offen)
            with db() as c:
                for i, (u, datei, err) in enumerate(ergebnisse, 1):
                    if datei:
                        c.execute("UPDATE accounts SET pic_file=? WHERE username=?",
                                  (datei, u))
                        ok += 1
                    else:
                        fehler += 1
                        if fehler <= 5:
                            print(f"  ! {u}: {err}")
                    if i % 200 == 0:
                        print(f"  {i} / {len(offen)}")
    print(f"Fertig: {ok} geladen, {fehler} fehlgeschlagen.")


# --------------------------------------------------------------------------
# Web
# --------------------------------------------------------------------------

app = FastAPI(title="insta-triage", docs_url=None, redoc_url=None)


class Markierung(BaseModel):
    usernames: list[str]
    entscheidung: str | None = None
    kategorie: str | None = None
    notiz: str | None = None


class Erledigt(BaseModel):
    usernames: list[str]
    feld: str  # erledigt_haupt | erledigt_zweit
    wert: int = 1


@app.get("/api/stats")
def stats():
    with db() as c:
        gesamt = c.execute("SELECT COUNT(*) FROM accounts").fetchone()[0]
        nach_ent = {r[0]: r[1] for r in c.execute(
            "SELECT entscheidung, COUNT(*) FROM accounts GROUP BY entscheidung")}
        nach_kat = {r[0]: r[1] for r in c.execute(
            "SELECT kategorie, COUNT(*) FROM accounts GROUP BY kategorie ORDER BY 2 DESC")}
        offen_haupt = c.execute(
            "SELECT COUNT(*) FROM accounts WHERE entscheidung IN ('entfolgen','migrieren') "
            "AND erledigt_haupt=0").fetchone()[0]
        offen_zweit = c.execute(
            "SELECT COUNT(*) FROM accounts WHERE entscheidung='migrieren' "
            "AND erledigt_zweit=0").fetchone()[0]
    return {"gesamt": gesamt, "entscheidungen": nach_ent, "kategorien": nach_kat,
            "offen_haupt": offen_haupt, "offen_zweit": offen_zweit,
            "alle_kategorien": KATEGORIEN}


@app.get("/api/accounts")
def accounts(kategorie: str = "", entscheidung: str = "", q: str = "",
             follows_back: str = "", jahr: str = "", sort: str = "followed_at",
             limit: int = 500, offset: int = 0):
    wo, args = [], []
    if kategorie:
        wo.append("kategorie=?"); args.append(kategorie)
    if entscheidung:
        wo.append("entscheidung=?"); args.append(entscheidung)
    if follows_back in ("0", "1"):
        wo.append("follows_back=?"); args.append(int(follows_back))
    if jahr:
        wo.append("jahr=?"); args.append(int(jahr))
    if q:
        wo.append("(username LIKE ? OR full_name LIKE ?)")
        args += [f"%{q}%", f"%{q}%"]
    sortier = {"followed_at": "followed_at ASC", "neu": "followed_at DESC",
               "username": "username ASC"}.get(sort, "followed_at ASC")
    sql = "SELECT * FROM accounts"
    if wo:
        sql += " WHERE " + " AND ".join(wo)
    sql += f" ORDER BY {sortier} LIMIT ? OFFSET ?"
    args += [limit, offset]
    with db() as c:
        zeilen = [dict(r) for r in c.execute(sql, args)]
        gesamt = c.execute(
            "SELECT COUNT(*) FROM accounts" + (" WHERE " + " AND ".join(wo) if wo else ""),
            args[:-2]).fetchone()[0]
    return {"gesamt": gesamt, "accounts": zeilen}


@app.post("/api/markieren")
def markieren(m: Markierung):
    if m.entscheidung and m.entscheidung not in ENTSCHEIDUNGEN:
        raise HTTPException(400, "unbekannte Entscheidung")
    if m.kategorie and m.kategorie not in KATEGORIEN:
        raise HTTPException(400, "unbekannte Kategorie")
    setzt, args = [], []
    if m.entscheidung:
        setzt.append("entscheidung=?"); args.append(m.entscheidung)
    if m.kategorie:
        setzt.append("kategorie=?"); args.append(m.kategorie)
    if m.notiz is not None:
        setzt.append("notiz=?"); args.append(m.notiz)
    if not setzt:
        raise HTTPException(400, "nichts zu setzen")
    setzt.append("geaendert_am=?"); args.append(jetzt())
    with db() as c:
        for u in m.usernames:
            c.execute(f"UPDATE accounts SET {', '.join(setzt)} WHERE username=?",
                      (*args, u))
    return {"ok": True, "betroffen": len(m.usernames)}


@app.post("/api/erledigt")
def erledigt(e: Erledigt):
    if e.feld not in ("erledigt_haupt", "erledigt_zweit"):
        raise HTTPException(400, "unbekanntes Feld")
    with db() as c:
        for u in e.usernames:
            c.execute(f"UPDATE accounts SET {e.feld}=?, geaendert_am=? WHERE username=?",
                      (e.wert, jetzt(), u))
    return {"ok": True}


@app.get("/api/arbeitsliste")
def arbeitsliste(schritt: str = "haupt", limit: int = 100):
    """Tagesliste: was als naechstes von Hand zu tun ist."""
    if schritt == "haupt":
        sql = ("SELECT username, full_name, kategorie, entscheidung FROM accounts "
               "WHERE entscheidung IN ('entfolgen','migrieren') AND erledigt_haupt=0 "
               "ORDER BY entscheidung, followed_at LIMIT ?")
    elif schritt == "zweit":
        sql = ("SELECT username, full_name, kategorie, entscheidung FROM accounts "
               "WHERE entscheidung='migrieren' AND erledigt_zweit=0 "
               "ORDER BY followed_at LIMIT ?")
    else:
        raise HTTPException(400, "schritt muss haupt oder zweit sein")
    with db() as c:
        zeilen = [dict(r) for r in c.execute(sql, (limit,))]
    return {"schritt": schritt, "anzahl": len(zeilen), "accounts": zeilen}


@app.get("/pics/{datei}")
def bild(datei: str):
    p = PICS / datei
    if not p.is_file() or ".." in datei or "/" in datei:
        raise HTTPException(404)
    return FileResponse(p, media_type="image/jpeg",
                        headers={"Cache-Control": "public, max-age=604800"})


@app.post("/api/upload")
async def upload(dateien: list[UploadFile] = File(...)):
    """JSON-Dateien entgegennehmen und sofort einlesen."""
    init()
    namen = []
    for f in dateien:
        ziel = IMPORT_DIR / Path(f.filename or "unbenannt.json").name
        ziel.write_bytes(await f.read())
        namen.append(ziel.name)
    puffer = io.StringIO()
    with redirect_stdout(puffer):
        importiere()
    return {"dateien": namen, "log": puffer.getvalue()}


@app.post("/api/bilder")
def bilder_holen():
    """Profilbilder im Hintergrund von der CDN holen."""
    def lauf():
        puffer = io.StringIO()
        with redirect_stdout(puffer):
            try:
                hole_bilder()
            except Exception as e:
                print("Abbruch:", e)
        (DATA / "bilder.log").write_text(puffer.getvalue())
    threading.Thread(target=lauf, daemon=True).start()
    return {"gestartet": True}


@app.get("/api/bilder/log")
def bilder_log():
    d = DATA / "bilder.log"
    with db() as c:
        offen = c.execute("SELECT COUNT(*) FROM accounts "
                          "WHERE pic_url<>'' AND (pic_file='' OR pic_file IS NULL)").fetchone()[0]
        fertig = c.execute("SELECT COUNT(*) FROM accounts WHERE pic_file<>''").fetchone()[0]
    return {"log": d.read_text() if d.exists() else "", "offen": offen, "geladen": fertig}


@app.get("/")
def index():
    return FileResponse(STATIC / "index.html")


app.mount("/static", StaticFiles(directory=STATIC), name="static")


if __name__ == "__main__":
    befehl = sys.argv[1] if len(sys.argv) > 1 else "serve"
    if befehl == "import":
        importiere()
    elif befehl == "pics":
        hole_bilder()
    elif befehl == "stand":
        _stand()
    elif befehl == "serve":
        import uvicorn
        init()
        uvicorn.run(app, host="0.0.0.0", port=8080, log_level="info")
    else:
        print(__doc__)
        sys.exit(1)
