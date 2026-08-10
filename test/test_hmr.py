#!/usr/bin/env python3
"""Unit tests for shipped hot-reload helpers in bridge.py (real import)."""
import importlib.util
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))

spec = importlib.util.spec_from_file_location("bridge", ROOT / "scripts" / "bridge.py")
bridge = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(bridge)


def test_asset_version_changes_on_edit():
    # Use real ROOT from module — touch a watched file under product tree
    css = bridge.ROOT / "css" / "app.css"
    assert css.is_file(), "css/app.css must exist"
    v1 = bridge.asset_version()
    # append and restore
    original = css.read_bytes()
    try:
        css.write_bytes(original + b"\n/* hmr-test */\n")
        v2 = bridge.asset_version()
        assert v1 != v2, f"version should change after edit: {v1} vs {v2}"
    finally:
        css.write_bytes(original)
    # After restore, version may still differ if mtime advanced — only require change-on-edit
    print("PASS asset_version changes on edit")


def test_hmr_snippet_present():
    assert b"herdr-web-hmr" in bridge.HMR_SNIPPET
    assert b"/__hmr" in bridge.HMR_SNIPPET
    print("PASS HMR snippet wired")


def test_hot_default_env():
    # Module HOT reflects env at import; default path is on unless 0
    assert isinstance(bridge.HOT, bool)
    print("PASS HOT is bool (default on unless env disables)")


if __name__ == "__main__":
    test_hmr_snippet_present()
    test_hot_default_env()
    test_asset_version_changes_on_edit()
    print("all hmr unit tests passed")
