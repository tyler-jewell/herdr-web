#!/usr/bin/env python3
"""
Static + API bridge for herdr-web (isolatable Herdr plugin product).

POST /api/herdr { "argv": ["herdr", "integration", ...] }
GET  /__hmr  → live-reload version token (file mtime hash of UI assets)
HTML responses inject a tiny poller so asset edits apply without manual refresh.

Hot-reload is ON by default (HERDR_WEB_HOT_RELOAD=0 to disable).
"""
from __future__ import annotations

import hashlib
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
HOT = os.environ.get("HERDR_WEB_HOT_RELOAD", "1") not in ("0", "false", "no")

TARGET_SLUG = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")

# Assets watched for live reload (default on).
WATCH_GLOBS = ("index.html", "css/**/*", "js/**/*")

HMR_SNIPPET = b"""
<script id="herdr-web-hmr">
(function () {
  if (window.__HERDR_WEB_HMR__) return;
  window.__HERDR_WEB_HMR__ = true;
  var last = null;
  function tick() {
    fetch("/__hmr", { cache: "no-store" })
      .then(function (r) { return r.json(); })
      .then(function (j) {
        if (last === null) { last = j.version; return; }
        if (j.version && j.version !== last) {
          last = j.version;
          location.reload();
        }
      })
      .catch(function () {})
      .then(function () { setTimeout(tick, 600); });
  }
  tick();
})();
</script>
"""


def is_target_slug(name: str) -> bool:
    return bool(name and TARGET_SLUG.match(name))


def validate_herdr_argv(argv: list) -> tuple[bool, str | None]:
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

    herdr = shutil.which("herdr") or os.environ.get("HERDR_BIN_PATH")
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


def asset_version() -> str:
    """Hash of mtimes for watched UI assets — changes when agents edit files."""
    h = hashlib.sha1()
    paths: list[Path] = []
    for pattern in WATCH_GLOBS:
        if "**" in pattern:
            base, _, rest = pattern.partition("**/")
            root = ROOT / base.rstrip("/") if base else ROOT
            if root.is_dir():
                for p in root.rglob(rest if rest else "*"):
                    if p.is_file():
                        paths.append(p)
        else:
            p = ROOT / pattern
            if p.is_file():
                paths.append(p)
    for p in sorted(set(paths)):
        try:
            st = p.stat()
            h.update(str(p.relative_to(ROOT)).encode())
            h.update(str(int(st.st_mtime_ns)).encode())
            h.update(str(st.st_size).encode())
        except OSError:
            continue
    return h.hexdigest()[:16]


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

    def do_GET(self) -> None:
        path = urlparse(self.path).path
        if path == "/__hmr":
            self._json(
                200,
                {
                    "ok": True,
                    "hot_reload": HOT,
                    "version": asset_version() if HOT else "off",
                },
            )
            return
        if path in ("/", "/index.html") and HOT:
            self._serve_html_with_hmr()
            return
        return super().do_GET()

    def _serve_html_with_hmr(self) -> None:
        index = ROOT / "index.html"
        try:
            body = index.read_bytes()
        except OSError:
            self.send_error(404, "index.html missing")
            return
        if b"herdr-web-hmr" not in body:
            if b"</body>" in body:
                body = body.replace(b"</body>", HMR_SNIPPET + b"</body>", 1)
            else:
                body = body + HMR_SNIPPET
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)
        print("hot-reload: injected HMR poller into index.html", flush=True)

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
        # Prefer Herdr-injected binary when running as plugin
        if os.environ.get("HERDR_BIN_PATH"):
            os.environ["PATH"] = (
                str(Path(os.environ["HERDR_BIN_PATH"]).parent)
                + os.pathsep
                + os.environ.get("PATH", "")
            )
        result = run_herdr(argv if isinstance(argv, list) else [])
        code = 200 if result.get("ok") else 400
        self._json(code, result)

    def _json(self, code: int, obj: dict) -> None:
        data = json.dumps(obj).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(data)


def main() -> None:
    os.chdir(ROOT)
    server = ThreadingHTTPServer((HOST, PORT), Handler)
    print(
        f"listening on http://{HOST}:{PORT}/  root={ROOT}  hot_reload={HOT}",
        flush=True,
    )
    if HOT:
        print(f"hot-reload: watching UI assets; /__hmr version={asset_version()}", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nbye", flush=True)


if __name__ == "__main__":
    main()
