"""Music Player extractor server.

Tiny FastAPI wrapper around yt-dlp for a personal YouTube downloader app.
Binds to 127.0.0.1:8001 only. All POST endpoints require the X-API-Key header.
"""

import json
import os
import subprocess
import time

from fastapi import FastAPI, Header, HTTPException, Query

APP_DIR = os.path.dirname(os.path.abspath(__file__))


def _load_api_key() -> str:
    # Minimal .env parser (no extra dependency). NEVER log the key.
    key = os.environ.get("API_KEY", "")
    env_path = os.path.join(APP_DIR, ".env")
    if os.path.exists(env_path):
        with open(env_path) as f:
            for line in f:
                line = line.strip()
                if line.startswith("API_KEY="):
                    key = line.split("=", 1)[1].strip()
                    break
    return key


API_KEY = _load_api_key()

app = FastAPI(title="Music Player Extractor", version="1.0.0")

# Simple in-memory cache: key -> (expires_at, response_dict).
# Search/trending results change slowly; caching makes repeat loads instant
# and avoids hammering YouTube (which triggers bot-checks/502s).
_CACHE: dict[str, tuple[float, dict]] = {}
_CACHE_TTL = 300  # 5 minutes


def _cache_get(key: str) -> dict | None:
    hit = _CACHE.get(key)
    if hit and hit[0] > time.time():
        return hit[1]
    _CACHE.pop(key, None)
    return None


def _cache_put(key: str, value: dict, ttl: int = _CACHE_TTL):
    _CACHE[key] = (time.time() + ttl, value)
    # keep memory bounded
    if len(_CACHE) > 200:
        oldest = min(_CACHE, key=lambda k: _CACHE[k][0])
        _CACHE.pop(oldest, None)

YDL_BIN = os.path.join(APP_DIR, "venv", "bin", "yt-dlp")
YDL = [YDL_BIN if os.path.exists(YDL_BIN) else "yt-dlp", "--no-warnings", "--no-playlist"]

# The VM's egress IP gets YouTube's "sign in to confirm you're not a bot"
# check on the web player client. The android player client usually passes.
ANDROID_CLIENT = ["--extractor-args", "youtube:player_client=android"]


def _check_key(x_api_key: str | None):
    if not x_api_key or x_api_key != API_KEY:
        raise HTTPException(status_code=401, detail="Unauthorized")


def _run_ydl(args: list[str], timeout: int = 120, retries: int = 1) -> subprocess.CompletedProcess:
    """Run yt-dlp. On non-zero exit, retry a few times — YouTube's bot-check
    on this egress IP is intermittent, and a retry often succeeds."""
    last = None
    for attempt in range(retries):
        proc = subprocess.run(
            YDL + args,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
        if proc.returncode == 0:
            return proc
        last = proc
        if attempt < retries - 1:
            time.sleep(5)
    return last


def _thumbnail(entry: dict) -> str:
    vid = entry.get("id", "")
    thumbs = entry.get("thumbnails") or []
    best = ""
    best_w = -1
    for t in thumbs:
        u = t.get("url")
        if not u:
            continue
        w = t.get("width") or 0
        if w >= best_w:
            best_w = w
            best = u
    if best:
        return best
    return f"https://i.ytimg.com/vi/{vid}/hqdefault.jpg" if vid else ""


def _entry_to_result(entry: dict) -> dict:
    vid = entry.get("id", "")
    return {
        "id": vid,
        "title": entry.get("title") or "",
        "thumbnail": _thumbnail(entry),
        "duration": entry.get("duration"),
        "channel": entry.get("channel") or entry.get("uploader") or "",
        "views": entry.get("view_count") or 0,
        "url": f"https://www.youtube.com/watch?v={vid}" if vid else "",
    }


def _parse_flat_results(stdout: str) -> list[dict]:
    results = []
    for line in stdout.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            entry = json.loads(line)
        except json.JSONDecodeError:
            continue
        if not entry.get("id"):
            continue
        results.append(_entry_to_result(entry))
    return results


@app.get("/health")
def health():
    return {"ok": True}


@app.post("/search")
def search(q: str = Query(..., description="Search query"),
           x_api_key: str | None = Header(default=None, alias="X-API-Key")):
    _check_key(x_api_key)
    ck = f"search:{q.lower().strip()}"
    hit = _cache_get(ck)
    if hit is not None:
        return hit
    proc = _run_ydl(["--flat-playlist", "--dump-json", f"ytsearch10:{q}"], timeout=45, retries=2)
    if proc.returncode != 0:
        raise HTTPException(status_code=502, detail="yt-dlp search failed")
    resp = {"results": _parse_flat_results(proc.stdout)}
    _cache_put(ck, resp)
    return resp


@app.post("/trending")
def trending(country: str | None = Query(default=None, description="ISO country code, e.g. NP"),
             x_api_key: str | None = Header(default=None, alias="X-API-Key")):
    _check_key(x_api_key)
    ck = f"trending:{(country or 'default').upper()}"
    hit = _cache_get(ck)
    if hit is not None:
        return hit
    geo = []
    if country and len(country.strip()) == 2:
        # Bias YouTube's trending feed toward the requested country.
        geo = ["--geo-bypass-country", country.strip().upper()]
    # NOTE (2026-10-13): youtube.com/feed/trending is dead (YouTube removed it,
    # yt-dlp gets "channel/playlist does not exist"). Go straight to search.
    query = "trending music 2026"
    if country and len(country.strip()) == 2:
        query = f"trending music {country.strip().upper()} 2026"
    proc = _run_ydl(
        geo + ["--flat-playlist", "--dump-json", f"ytsearch25:{query}"],
        timeout=45,
        retries=2,
    )
    if proc.returncode != 0:
        raise HTTPException(status_code=502, detail="yt-dlp trending failed")
    resp = {"results": _parse_flat_results(proc.stdout)}
    _cache_put(ck, resp, ttl=600)
    return resp


def _playlist_entry_to_result(entry: dict) -> dict:
    pid = entry.get("id", "")
    return {
        "id": pid,
        "title": entry.get("title") or "",
        "thumbnail": _thumbnail(entry),
        "channel": entry.get("channel") or entry.get("uploader") or "",
        "count": entry.get("playlist_count") or 0,
        "url": f"https://www.youtube.com/playlist?list={pid}" if pid else "",
    }


@app.post("/search_playlists")
def search_playlists(q: str = Query(..., description="Search query"),
                     kind: str = Query(default="playlists", description="playlists or albums"),
                     limit: int = Query(default=10, ge=1, le=25),
                     x_api_key: str | None = Header(default=None, alias="X-API-Key")):
    _check_key(x_api_key)
    # YouTube search "type" filter via the sp parameter
    # (EgIQAw== = playlists, EgIQAQ== = albums), URL-encoded once.
    sp = "EgIQAQ%3D%3D" if kind == "albums" else "EgIQAw%3D%3D"
    from urllib.parse import quote_plus
    url = f"https://www.youtube.com/results?search_query={quote_plus(q)}&sp={sp}"
    proc = _run_ydl(["--flat-playlist", "--dump-json", url], timeout=45, retries=2)
    if proc.returncode != 0:
        raise HTTPException(status_code=502, detail="yt-dlp playlist search failed")
    results = []
    for line in proc.stdout.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            entry = json.loads(line)
        except json.JSONDecodeError:
            continue
        pid = (entry.get("id") or "").strip()
        if not pid:
            continue
        # Flat search entries all arrive as YoutubeTab: channels have UC ids,
        # playlists/mixes/albums have PL/RD/OL ids. Skip channels.
        if pid.startswith("UC"):
            continue
        results.append(_playlist_entry_to_result(entry))
        if len(results) >= limit:
            break
    return {"results": results}


@app.post("/playlist")
def playlist(url: str = Query(..., description="YouTube playlist URL"),
             x_api_key: str | None = Header(default=None, alias="X-API-Key")):
    _check_key(x_api_key)
    # Playlist expansion: same flags as _run_ydl but WITHOUT --no-playlist.
    # Mix/tab playlists are heavy multi-page API fetches and this egress
    # proxy truncates reads intermittently (IncompleteRead), so retry hard.
    ydl = [a for a in YDL if a != "--no-playlist"]
    ydl += ["--retries", "10", "--socket-timeout", "30", "--extractor-retries", "3"]
    last = None
    # Try the android player client first (dodges the web bot-check), then
    # fall back to the default client — sometimes one works while the other
    # is being challenged for this egress IP.
    for client in (ANDROID_CLIENT, []):
        for attempt in range(2):
            proc = subprocess.run(
                ydl + client + ["--flat-playlist", "--dump-json", url],
                capture_output=True, text=True, timeout=300,
            )
            last = proc
            if proc.returncode == 0:
                break
            if attempt == 0:
                time.sleep(10)
        if last is not None and last.returncode == 0:
            break
    if last is None or last.returncode != 0:
        raise HTTPException(status_code=502, detail="yt-dlp playlist fetch failed")
    results = []
    title = ""
    for line in last.stdout.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            entry = json.loads(line)
        except json.JSONDecodeError:
            continue
        if entry.get("_type") == "playlist" or not entry.get("id"):
            continue
        if not title:
            title = entry.get("playlist_title") or entry.get("title") or ""
        results.append(_entry_to_result(entry))
    return {"title": title, "results": results}


@app.post("/formats")
def formats(url: str = Query(..., description="YouTube video URL"),
            x_api_key: str | None = Header(default=None, alias="X-API-Key")):
    _check_key(x_api_key)
    proc = _run_ydl(ANDROID_CLIENT + ["-J", url], timeout=90, retries=3)
    if proc.returncode != 0:
        raise HTTPException(status_code=502, detail="yt-dlp metadata fetch failed")
    try:
        info = json.loads(proc.stdout)
    except json.JSONDecodeError:
        raise HTTPException(status_code=502, detail="invalid yt-dlp JSON output")

    out = []
    for f in info.get("formats") or []:
        if not f.get("format_id"):
            continue
        if not (f.get("url") or f.get("manifest_url")):
            continue
        out.append({
            "format_id": f.get("format_id"),
            "ext": f.get("ext"),
            "resolution": f.get("resolution"),
            "filesize": f.get("filesize") or f.get("filesize_approx"),
            "vcodec": f.get("vcodec"),
            "acodec": f.get("acodec"),
            "note": f.get("format_note"),
        })
    # Prefer mp4 entries first, then cap at ~25.
    out.sort(key=lambda e: 0 if e.get("ext") == "mp4" else 1)
    return {"title": info.get("title") or "", "formats": out[:25]}


@app.post("/stream")
def stream(url: str = Query(..., description="YouTube video URL"),
           format_id: str = Query(default="", description="format_id, 'bestaudio', or empty for best"),
           x_api_key: str | None = Header(default=None, alias="X-API-Key")):
    _check_key(x_api_key)
    sel = format_id.strip() or "best"
    # The android player client (needed to dodge YouTube's bot-check on this
    # network) only exposes progressive formats — no audio-only DASH streams.
    # So `bestaudio` falls back to the best format that contains audio; the
    # app can extract MP3 from it with ffmpeg.
    selectors = [sel]
    if sel == "bestaudio":
        selectors.append("best[acodec!=none]")
    proc = None
    used_sel = sel
    for s in selectors:
        proc = _run_ydl(ANDROID_CLIENT + ["-g", "-f", s, url], timeout=90, retries=3)
        if proc.returncode == 0 and proc.stdout.strip().splitlines():
            used_sel = s
            break
    if proc is None or proc.returncode != 0:
        raise HTTPException(status_code=502, detail="yt-dlp stream URL resolution failed")
    direct = proc.stdout.strip().splitlines()
    if not direct:
        raise HTTPException(status_code=502, detail="no stream URL returned")
    # Extension: ask yt-dlp what it resolved to (cheap, same retry logic).
    ext = "m4a" if used_sel == "bestaudio" else "mp4"
    info_proc = _run_ydl(
        ANDROID_CLIENT + ["--print", "%(ext)s", "-f", used_sel, "--skip-download", url],
        timeout=60, retries=2,
    )
    if info_proc.returncode == 0 and info_proc.stdout.strip():
        ext = info_proc.stdout.strip().splitlines()[0]
    return {"url": direct[0], "ext": ext}
