#!/usr/bin/env python3
"""Unit tests for Google-family cookie exclusion."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "lib"))
from cookie_filter import domain_blocked, filter_cookies, blocked_suffixes  # noqa: E402


def test_blocks_google_accounts():
    assert domain_blocked(".google.com")
    assert domain_blocked("accounts.google.com")
    assert domain_blocked(".youtube.com")
    assert domain_blocked("mail.google.com")
    assert domain_blocked("googleapis.com")
    assert domain_blocked(".gstatic.com")


def test_keeps_bilibili():
    assert not domain_blocked(".bilibili.com")
    assert not domain_blocked("api.bilibili.com")
    assert not domain_blocked("github.com")


def test_filter_cookies():
    cookies = [
        {"name": "SESSDATA", "domain": ".bilibili.com", "value": "x"},
        {"name": "SID", "domain": ".google.com", "value": "g"},
        {"name": "LOGIN_INFO", "domain": ".youtube.com", "value": "y"},
        {"name": "user", "domain": "github.com", "value": "h"},
    ]
    kept, dropped = filter_cookies(cookies, blocked_suffixes(include_google=False))
    names = {(c["name"], c["domain"]) for c in kept}
    assert ("SESSDATA", ".bilibili.com") in names
    assert ("user", "github.com") in names
    assert ("SID", ".google.com") not in names
    assert len(dropped) == 2


def test_include_google_disables_block():
    s = blocked_suffixes(include_google=True)
    # may still have custom excludes only
    assert not domain_blocked("accounts.google.com", s)


if __name__ == "__main__":
    test_blocks_google_accounts()
    test_keeps_bilibili()
    test_filter_cookies()
    test_include_google_disables_block()
    print("COOKIE_FILTER_OK")
