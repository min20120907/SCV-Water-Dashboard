#!/usr/bin/env python3
"""Static file server for the built Flutter web app.

Two things the stdlib default gets wrong for Flutter web:

1. Single-threaded: a Flutter app fires hundreds of parallel module requests on
   load, and a single-threaded server serialises them. First paint can take
   minutes. ThreadingHTTPServer fixes this.
2. Missing COOP/COEP: canvaskit's threaded (skwasm) build wants
   SharedArrayBuffer, which browsers only expose to cross-origin-isolated
   documents. These headers make the page cross-origin isolated.

Cross-origin isolation then forbids loading subresources without CORP, which is
why web/canvaskit/ must be served from this origin (see web/index.html) rather
than from gstatic.com.
"""
from __future__ import annotations

import argparse
import os
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer


class FlutterHandler(SimpleHTTPRequestHandler):
    extensions_map = {
        **SimpleHTTPRequestHandler.extensions_map,
        ".js": "text/javascript",
        ".mjs": "text/javascript",
        ".wasm": "application/wasm",
        ".json": "application/json",
        ".symbols": "text/plain",
    }

    def end_headers(self):
        # Required for SharedArrayBuffer / skwasm.
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        # The service worker must never serve a stale app after a redeploy.
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def end_headers_override(self):  # pragma: no cover - clarity only
        pass

    def log_message(self, fmt, *args):
        if "404" in (fmt % args):
            super().log_message(fmt, *args)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=8899)
    ap.add_argument("--bind", default="0.0.0.0")
    ap.add_argument("--dir", default=".")
    args = ap.parse_args()

    os.chdir(args.dir)
    handler = partial(FlutterHandler, directory=args.dir)
    server = ThreadingHTTPServer((args.bind, args.port), handler)
    server.daemon_threads = True
    print(f"serving {args.dir} on http://{args.bind}:{args.port}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
