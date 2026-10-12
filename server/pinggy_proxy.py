#!/usr/bin/env python3
"""ProxyCommand for ssh through the hatch egress HTTP proxy.
Usage: ProxyCommand=python3 /path/pinggy_proxy.py %h %p
Reads HTTP(S)_PROXY env (with credentials) and performs HTTP CONNECT,
then shuttles bytes between stdin/stdout and the socket."""
import base64
import os
import socket
import ssl
import sys
import threading
from urllib.parse import urlparse


def main():
    if len(sys.argv) != 3:
        sys.exit(1)
    dest_host, dest_port = sys.argv[1], int(sys.argv[2])
    proxy_url = os.environ.get("HTTPS_PROXY") or os.environ.get("https_proxy") \
        or os.environ.get("HTTP_PROXY") or os.environ.get("http_proxy")
    if not proxy_url:
        sys.exit("no proxy env")
    p = urlparse(proxy_url)
    sock = socket.create_connection((p.hostname, p.port or 3128), timeout=30)
    req = f"CONNECT {dest_host}:{dest_port} HTTP/1.1\r\nHost: {dest_host}:{dest_port}\r\n"
    if p.username:
        creds = f"{p.username}:{p.password or ''}"
        auth = base64.b64encode(creds.encode()).decode()
        req += f"Proxy-Authorization: Basic {auth}\r\n"
    req += "\r\n"
    sock.sendall(req.encode())
    resp = b""
    while b"\r\n\r\n" not in resp:
        chunk = sock.recv(4096)
        if not chunk:
            sys.exit("proxy connect failed: no response")
        resp += chunk
    status = resp.split(b"\r\n", 1)[0]
    if b" 200 " not in status:
        sys.exit(f"proxy connect failed: {status!r}")

    def stdin_to_sock():
        try:
            while True:
                data = os.read(sys.stdin.fileno(), 65536)
                if not data:
                    break
                sock.sendall(data)
        except OSError:
            pass

    def sock_to_stdout():
        try:
            out = os.fdopen(sys.stdout.fileno(), "wb", buffering=0)
            while True:
                data = sock.recv(65536)
                if not data:
                    break
                out.write(data)
                out.flush()
        except OSError:
            pass

    t = threading.Thread(target=stdin_to_sock, daemon=True)
    t.start()
    sock_to_stdout()


if __name__ == "__main__":
    main()
