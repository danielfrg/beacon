#!/usr/bin/env python3
"""Tiny stand-in for a Frigate server, for simulator runs. Stdlib only.

Serves /api/config, /api/<camera>/latest.<ext> (a generated image that changes
over time) and accepts PUT /api/camera/<camera>/set/<feature>.
Real Frigate serves JPEG; stdlib has no JPEG encoder, so this serves PNG.
"""
import argparse, colorsys, json, struct, time, zlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import unquote, urlparse

CONFIG = json.loads((Path(__file__).parent / "fixtures" / "config.json").read_text())


def png(width, height, rgb_for_row):
    raw = b"".join(b"\x00" + bytes(rgb_for_row(y)) * width for y in range(height))

    def chunk(kind, data):
        body = kind + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body))

    return (b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw))
            + chunk(b"IEND", b""))


def frame(camera):
    hue = (sum(map(ord, camera)) % 100) / 100
    phase = (time.time() % 10) / 10

    def row(y):
        r, g, b = colorsys.hsv_to_rgb((hue + phase) % 1, 0.6, 0.35 + 0.5 * y / 180)
        return int(r * 255), int(g * 255), int(b * 255)

    return png(16, 9, row)


class Handler(BaseHTTPRequestHandler):
    fail_toggles = False

    def _send(self, code, body=b"", ctype="application/json"):
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        parts = [unquote(p) for p in urlparse(self.path).path.strip("/").split("/")]
        if parts == ["api", "config"]:
            return self._send(200, json.dumps(CONFIG).encode())
        if len(parts) == 3 and parts[0] == "api" and parts[2].startswith("latest."):
            if parts[1] in CONFIG["cameras"]:
                return self._send(200, frame(parts[1]), "image/png")
        self._send(404, b"{}")

    def do_PUT(self):
        parts = [unquote(p) for p in urlparse(self.path).path.strip("/").split("/")]
        self.rfile.read(int(self.headers.get("Content-Length", 0)))
        if self.fail_toggles:
            return self._send(500, b'{"success":false}')
        if len(parts) >= 5 and parts[:2] == ["api", "camera"] and parts[3] == "set":
            return self._send(200, b'{"success":true}')
        self._send(404, b"{}")

    def log_message(self, fmt, *args):
        pass


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=5000)
    ap.add_argument("--fail-toggles", action="store_true")
    a = ap.parse_args()
    Handler.fail_toggles = a.fail_toggles
    print(f"mock frigate on http://127.0.0.1:{a.port}")
    ThreadingHTTPServer(("127.0.0.1", a.port), Handler).serve_forever()
