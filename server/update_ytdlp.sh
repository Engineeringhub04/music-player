#!/bin/bash
# Weekly yt-dlp update. Run from cron: see README.
set -e
/home/hatch/workspace/music-player/server/venv/bin/pip install -U yt-dlp
