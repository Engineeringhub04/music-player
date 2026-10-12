#!/usr/bin/env python3
"""Prefix-stripping reverse proxy for the extractor API behind cloudflared.

cloudflared ingress rule:  path /extractor/* -> http://127.0.0.1:8002
This proxy strips the /extractor prefix and forwards to the FastAPI
extractor on 127.0.0.1:8001, preserving method, headers and body.
"""
import http.client
from http.server import BaseHTTPRequestHandler, HTTPServer

LISTEN = ("127.0.0.1", 8002)
BACKEND = ("127.0.0.1", 8001)
PREFIX = "/extractor"

HOP_BY_HOP = {
    "connection", "keep-alive", "proxy-authenticate", "proxy-authorization",
    "te", "trailer", "transfer-encoding", "upgrade",
}


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def _forward(self):
        path = self.path
        if path == PREFIX:
            path = "/"
        elif path.startswith(PREFIX + "/"):
            path = path[len(PREFIX):]
        else:
            self.send_error(404)
            return
        length = int(self.headers.get("Content-Length", 0) or 0)
        body = self.rfile.read(length) if length else None
        fwd_headers = {
            k: v for k, v in self.headers.items()
            if k.lower() not in HOP_BY_HOP
        }
        fwd_headers["Host"] = f"{BACKEND[0]}:{BACKEND[1]}"
        fwd_headers["Connection"] = "close"
        conn = http.client.HTTPConnection(BACKEND[0], BACKEND[1], timeout=180)
        try:
            conn.request(self.command, path, body=body, headers=fwd_headers)
            resp = conn.getresponse()
            resp_body = resp.read()
            self.send_response(resp.status)
            for k, v in resp.getheaders():
                if k.lower() not in HOP_BY_HOP and k.lower() != "content-length":
                    self.send_header(k, v)
            self.send_header("Content-Length", str(len(resp_body)))
            self.send_header("Connection", "close")
            self.end_headers()
            self.wfile.write(resp_body)
        except OSError as e:
            self.send_error(502, f"backend unreachable: {e}")
        finally:
            conn.close()

    do_GET = _forward
    do_POST = _forward
    do_PUT = _forward
    do_DELETE = _forward
    do_PATCH = _forward
    do_HEAD = _forward
    do_OPTIONS = _forward

    def log_message(self, *args):
        pass


if __name__ == "__main__":
    HTTPServer(LISTEN, Handler).serve_forever()
