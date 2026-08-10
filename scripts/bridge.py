#!/usr/bin/env python3
"""
Minimal static + API bridge for herdr-web.

POST /api/herdr { "argv": ["herdr", "integration", ...] }
Only pure integration primitives. Target catalog is NOT hard-coded —
slug shape only; herdr CLI rejects unknown targets (live discovery).
"""
from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(os.environ.get("HERDR_WEB_ROOT", Path(__file__).resolve().parent.parent))
HOST = os.environ.get("HERDR_WEB_HOST", "127.0.0.1")
PORT = int(os.environ.get("HERDR_WEB_PORT", "8765"))

TARGET_SLUG = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")


def is_target_slug(name: str) -> bool:
    return bool(name and TARGET_SLUG.match(name))


def validate_herdr_argv(argv: list) -> tuple[bool, str | None]:
    """Shape-only validation — no frozen target inventory."""
    if not argv or not isinstance(argv, list):
        return False, "empty argv"
    if argv[0] != "herdr":
        return False, "only herdr is allowed"
    if len(argv) < 3 or argv[1] != "integration":
        return False, "only herdr integration … is allowed"
    sub = argv[2]
    if sub == "status":
        if len(argv) == 3:
            return True, None
        if len(argv) == 4 and argv[3] == "--outdated-only":
            return True, None
        return False, "invalid status args"
    if sub == "install" and len(argv) == 4 and argv[3] == "--help":
        return True, None
    if sub in ("install", "uninstall"):
        if len(argv) != 4:
            return False, "install/uninstall need exactly one target"
        if not is_target_slug(argv[3]):
            return False, f"invalid target slug: {argv[3]}"
        return True, None
    return False, f"unknown integration subcommand: {sub}"


def run_herdr(argv: list) -> dict:
    ok, err = validate_herdr_argv(argv)
    if not ok:
        return {"ok": False, "error": err, "argv": argv}

    herdr = shutil.which("herdr")
    if not herdr:
        return {"ok": False, "error": "herdr not found on PATH", "argv": argv}

    cmd = [herdr] + list(argv[1:])
    try:
        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=120,
            env=os.environ.copy(),
        )
    except subprocess.TimeoutExpired:
        return {
            "ok": False,
            "error": "herdr timed out",
            "argv": argv,
            "command": " ".join(cmd),
        }
    except OSError as exc:
        return {"ok": False, "error": str(exc), "argv": argv}

    return {
        "ok": True,
        "argv": argv,
        "command": " ".join(cmd),
        "exitCode": proc.returncode,
        "stdout": proc.stdout,
        "stderr": proc.stderr,
    }


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(ROOT), **kwargs)

    def log_message(self, fmt: str, *args) -> None:
        sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % args))

    def do_OPTIONS(self) -> None:
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def do_POST(self) -> None:
        path = urlparse(self.path).path
        if path != "/api/herdr":
            self.send_error(404, "only POST /api/herdr")
            return
        length = int(self.headers.get("Content-Length", "0") or 0)
        raw = self.rfile.read(length) if length else b"{}"
        try:
            body = json.loads(raw.decode("utf-8") or "{}")
        except json.JSONDecodeError:
            self._json(400, {"ok": False, "error": "invalid JSON"})
            return
        argv = body.get("argv")
        result = run_herdr(argv if isinstance(argv, list) else [])
        code = 200 if result.get("ok") else 400
        self._json(code, result)

    def _json(self, code: int, obj: dict) -> None:
        data = json.dumps(obj).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(data)


def main() -> None:
    os.chdir(ROOT)
    server = ThreadingHTTPServer((HOST, PORT), Handler)
    print(f"listening on http://{HOST}:{PORT}/  root={ROOT}", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nbye", flush=True)


if __name__ == "__main__":
    main()
