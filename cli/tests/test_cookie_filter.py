#!/usr/bin/env python3
"""Unit tests for Google-family cookie exclusion and cookie_io."""
from __future__ import annotations

import json
import os
import stat
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "lib"))

from cookie_filter import (  # noqa: E402
    blocked_suffixes,
    domain_blocked,
    filter_cookies,
    summarize_dropped,
)
from cookie_io import (  # noqa: E402
    cdp_cookie_to_item,
    cookies_for_inject,
    domain_counts,
    export_summary,
    normalize_cdp_cookies,
    write_cookie_dump,
)


def test_blocks_google_accounts():
    assert domain_blocked(".google.com")
    assert domain_blocked("accounts.google.com")
    assert domain_blocked(".youtube.com")
    assert domain_blocked("mail.google.com")
    assert domain_blocked("googleapis.com")
    assert domain_blocked(".gstatic.com")
    assert domain_blocked("google.co.uk")
    assert domain_blocked("www.youtube.com")


def test_keeps_non_google():
    assert not domain_blocked(".bilibili.com")
    assert not domain_blocked("api.bilibili.com")
    assert not domain_blocked("github.com")
    assert not domain_blocked(".zhihu.com")
    assert not domain_blocked("www.zhihu.com")
    assert not domain_blocked("grok.com")


def test_filter_cookies():
    cookies = [
        {"name": "SESSDATA", "domain": ".bilibili.com", "value": "x"},
        {"name": "SID", "domain": ".google.com", "value": "g"},
        {"name": "LOGIN_INFO", "domain": ".youtube.com", "value": "y"},
        {"name": "user", "domain": "github.com", "value": "h"},
        {"name": "z_c0", "domain": ".zhihu.com", "value": "z"},
    ]
    kept, dropped = filter_cookies(cookies, blocked_suffixes(include_google=False))
    names = {(c["name"], c["domain"]) for c in kept}
    assert ("SESSDATA", ".bilibili.com") in names
    assert ("user", "github.com") in names
    assert ("z_c0", ".zhihu.com") in names
    assert ("SID", ".google.com") not in names
    assert len(dropped) == 2


def test_include_google_disables_block():
    s = blocked_suffixes(include_google=True)
    assert not domain_blocked("accounts.google.com", s)


def test_extra_exclude_domains():
    s = blocked_suffixes(extra="zhihu.com,example.com", include_google=False)
    assert domain_blocked(".zhihu.com", s)
    assert domain_blocked("www.example.com", s)
    assert not domain_blocked("github.com", s)


def test_summarize_dropped():
    dropped = [
        {"domain": ".google.com"},
        {"domain": ".youtube.com"},
        {"domain": ".google.com"},
    ]
    s = summarize_dropped(dropped)
    assert "google.com" in s
    assert "youtube.com" in s
    assert summarize_dropped([]) == "none"


def test_cdp_normalize():
    raw = [
        {
            "name": "a",
            "value": "1",
            "domain": ".zhihu.com",
            "path": "/",
            "secure": True,
            "httpOnly": True,
            "expires": 1.5,
            "sameSite": "None",
        }
    ]
    items = normalize_cdp_cookies(raw)
    assert items[0]["sameSite"] == "None"
    assert items[0]["secure"] is True
    item = cdp_cookie_to_item({"name": "b", "value": "2"})
    assert item["path"] == "/"
    assert "sameSite" not in item


def test_write_cookie_dump_mode_and_filter(tmp_path: Path | None = None):
    base = Path(tempfile.mkdtemp()) if tmp_path is None else tmp_path
    path = base / "cookies.json"
    cookies = [
        {"name": "z_c0", "domain": ".zhihu.com", "value": "secret"},
        {"name": "SID", "domain": ".google.com", "value": "gsecret"},
    ]
    kept, dropped, out = write_cookie_dump(cookies, path, filter_google=True)
    assert out == path
    assert len(kept) == 1
    assert kept[0]["name"] == "z_c0"
    assert len(dropped) == 1
    mode = stat.S_IMODE(path.stat().st_mode)
    assert mode == 0o600
    data = json.loads(path.read_text())
    assert data[0]["name"] == "z_c0"
    # must not write google
    assert all("google" not in c.get("domain", "") for c in data)


def test_export_summary_and_domain_counts():
    kept = [
        {"name": "z_c0", "domain": ".zhihu.com"},
        {"name": "SESSDATA", "domain": ".bilibili.com"},
        {"name": "DedeUserID", "domain": ".bilibili.com"},
    ]
    dropped = [{"name": "SID", "domain": ".google.com"}]
    s = export_summary(kept, dropped)
    assert s["zhihu"] == 1
    assert s["has_z_c0"] is True
    assert s["bilibili"] == 2
    assert "SESSDATA" in s["bilibili_auth"]
    n, has = domain_counts(kept, "zhihu")
    assert n == 1 and has is True


def test_cookies_for_inject_refilters(tmp_path: Path | None = None):
    base = Path(tempfile.mkdtemp()) if tmp_path is None else tmp_path
    path = base / "c.json"
    # Write unfiltered (simulate bad dump), then re-filter on inject
    path.write_text(
        json.dumps(
            [
                {"name": "ok", "domain": ".zhihu.com", "value": "1"},
                {"name": "SID", "domain": ".google.com", "value": "2"},
            ]
        ),
        encoding="utf-8",
    )
    os.environ["BH_COOKIE_FILE"] = str(path)
    try:
        kept, dropped = cookies_for_inject(path)
        assert len(kept) == 1
        assert kept[0]["name"] == "ok"
        assert len(dropped) == 1
    finally:
        os.environ.pop("BH_COOKIE_FILE", None)


if __name__ == "__main__":
    test_blocks_google_accounts()
    test_keeps_non_google()
    test_filter_cookies()
    test_include_google_disables_block()
    test_extra_exclude_domains()
    test_summarize_dropped()
    test_cdp_normalize()
    test_write_cookie_dump_mode_and_filter()
    test_export_summary_and_domain_counts()
    test_cookies_for_inject_refilters()
    print("COOKIE_FILTER_OK")
