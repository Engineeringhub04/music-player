# Music Player — extractor server

Personal-use only. FastAPI wrapper around yt-dlp that the Flutter "Music Player"
app calls for search / trending / formats / direct stream URLs.

## Auth

Every POST endpoint requires header:

```
X-API-Key: <key from server/.env>
```

Wrong or missing key → `401`. `/health` needs no key.

## Endpoints

| Method | Path | Params | Returns |
|---|---|---|---|
| GET | `/health` | — | `{"ok": true}` |
| POST | `/search` | `q` | `{"results": [{id,title,thumbnail,duration,channel,views,url}]}` (up to 10) |
| POST | `/trending` | — | same schema as `/search` (YouTube trending feed, with search fallback) |
| POST | `/formats` | `url` | `{"title", "formats": [{format_id,ext,resolution,filesize,vcodec,acodec,note}]}` (≤25, mp4 preferred) |
| POST | `/stream` | `url`, `format_id` | `{"url": "<direct URL>", "ext": "<ext>"}` — `format_id` empty → `best`; `bestaudio` → best format containing audio (see note) |

## Run manually

```bash
cd ~/workspace/music-player/server
python3 -m venv venv            # one-time
./venv/bin/pip install -r requirements.txt
./venv/bin/python -m uvicorn main:app --host 127.0.0.1 --port 8001
```

Note: yt-dlp needs the egress proxy env vars (`https_proxy` etc.) to reach
YouTube from this VM.

## Service

Installed as a **system** unit (this environment runs as root; the
`music-player-extractor.service` file in this repo is the user-unit template
for a normal single-user machine):

```bash
systemctl status music-player-extractor
systemctl restart music-player-extractor
journalctl -u music-player-extractor -n 50
```

The installed unit at `/etc/systemd/system/music-player-extractor.service`
loads proxy credentials via `EnvironmentFile=` from `server/.proxy.env`
(0600, gitignored — never commit it).

## Weekly yt-dlp update

Systemd timer (no cron daemon on this VM):

```bash
systemctl list-timers ytdlp-update.timer
```

Runs `/home/hatch/workspace/music-player/server/update_ytdlp.sh`
every Sunday 04:00 UTC (`ytdlp-update.service` + `ytdlp-update.timer`).

## Notes

- Binds `127.0.0.1:8001` only. The phone app reaches it through whatever
  tunnel/port-forward the user sets up on their side — not handled here.
- The API key lives only in `server/.env` and is never logged.
- YouTube bot-check: this VM's egress IP gets "Sign in to confirm you're not
  a bot" on the web player client, so `/formats` and `/stream` use the
  `android` player client with 3x retry. The android client only exposes
  progressive formats (e.g. 360p mp4, format 18) — no audio-only DASH
  streams — so `bestaudio` falls back to the best format containing audio and
  the app should extract MP3 from it with ffmpeg if needed.
  `/search` and `/trending` are unaffected (different API path, no bot-check).
