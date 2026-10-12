#!/bin/bash
# Music Player extractor - 5-min auto-restart checker.
# Checks: extractor server (8001), edge relay (7844), cloudflared tunnel.
# Restarts anything that's down. Logs to /tmp/mp-checker.log

LOG=/tmp/mp-checker.log
ts() { date '+%F %T'; }

# 1. Extractor server on 8001
if ! curl -s -m 10 -o /dev/null http://127.0.0.1:8001/health 2>/dev/null; then
    echo "$(ts) RESTART extractor server" >> $LOG
    cd /home/hatch/workspace/music-player/server
    setsid nohup ./venv/bin/python -m uvicorn main:app --host 127.0.0.1 --port 8001 \
        > /tmp/uvicorn-extractor.log 2>&1 < /dev/null &
    disown 2>/dev/null
    sleep 8
fi

# 2. Edge relay on 127.0.0.1:7844 (forwards cloudflared -> Cloudflare edge via egress proxy)
if ! ps -eo args | grep -q "[e]dge_relay.py"; then
    echo "$(ts) RESTART edge_relay" >> $LOG
    setsid nohup python3 /home/hatch/workspace/fb-comment-autoreply/edge_relay.py \
        region2.v2.argotunnel.com,region1.v2.argotunnel.com 7844 \
        > /tmp/edge-relay.log 2>&1 < /dev/null &
    disown 2>/dev/null
    sleep 3
fi

# 3. cloudflared tunnel (token-based, via mount-namespace hosts override)
if ! ps -eo args | grep -q "[c]loudflared.*run --token"; then
    echo "$(ts) RESTART cloudflared tunnel" >> $LOG
    TOKEN=$(cat /home/hatch/.cloudflare/tunnel_token)
    setsid unshare -m bash -c \
        'mount --bind /home/hatch/.cloudflare/hosts.with-edge /etc/hosts && exec cloudflared tunnel --protocol http2 --edge region1.v2.argotunnel.com:7844 --edge region2.v2.argotunnel.com:7844 run --token "$0"' \
        "$TOKEN" > /tmp/cloudflared-token.log 2>&1 < /dev/null &
    disown 2>/dev/null
    sleep 15
fi

# 4. Public URL sanity check (informational only)
PUB=$(curl -s -m 25 -o /dev/null -w "%{http_code}" https://musicextractor.kishanraut.com.np/health 2>/dev/null)
if [ "$PUB" != "200" ]; then
    echo "$(ts) WARN public URL status=$PUB" >> $LOG
fi
