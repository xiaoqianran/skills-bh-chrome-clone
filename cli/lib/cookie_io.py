"""Pure helpers for CDP cookie export/inject (no browser dependency).

Used by sync harness snippets and unit tests. Never prints secret values.
"""
from __future__ import annotations

import json
import os
import stat
from pathlib import Path
from typing import Any

from cookie_filter import domain_blocked, filter_cookies, summarize_dropped


def cdp_cookie_to_item(c: dict[str, Any]) -> dict[str, Any]:
    """Normalize a CDP Network.Cookie into Storage.setCookies shape."""
    item: dict[str, Any] = {
        "name": c["name"],
        "value": c["value"],
        "domain": c.get("domain", ""),
        "path": c.get("path", "/"),
        "secure": bool(c.get("secure", False)),
        "httpOnly": bool(c.get("httpOnly", False)),
        "expires": c.get("expires", -1),
    }
    ss = c.get("sameSite")
    if ss:
        item["sameSite"] = ss
    return item


def normalize_cdp_cookies(raw: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return [cdp_cookie_to_item(c) for c in raw]


def export_summary(kept: list[dict], dropped: list[dict]) -> dict[str, Any]:
    """Non-secret summary for logs."""
    zhihu = [c for c in kept if "zhihu" in str(c.get("domain", "")).lower()]
    bili = [c for c in kept if "bilibili" in str(c.get("domain", "")).lower()]
    auth = sorted(
        {
            c["name"]
            for c in bili
            if c.get("name") in ("SESSDATA", "DedeUserID", "bili_jct")
        }
    )
    google_dropped = sum(
        1
        for c in dropped
        if any(
            x in str(c.get("domain", "")).lower()
            for x in ("google", "youtube", "gmail")
        )
    )
    return {
        "kept": len(kept),
        "dropped": len(dropped),
        "google_family_ish_dropped": google_dropped,
        "dropped_hosts": summarize_dropped(dropped),
        "zhihu": len(zhihu),
        "has_z_c0": any(c.get("name") == "z_c0" for c in zhihu),
        "bilibili": len(bili),
        "bilibili_auth": auth,
    }


def write_cookie_dump(
    cookies: list[dict[str, Any]],
    path: Path | str | None = None,
    *,
    filter_google: bool = True,
) -> tuple[list[dict], list[dict], Path]:
    """Filter (optional) and write cookies JSON with mode 0600.

    Returns (kept, dropped, path).
    """
    cookie_path = Path(
        path
        or os.environ.get(
            "BH_COOKIE_FILE",
            str(Path.home() / ".config/browser-harness/main-cookies.json"),
        )
    )
    cookie_path.parent.mkdir(parents=True, exist_ok=True)

    if filter_google:
        kept, dropped = filter_cookies(cookies)
    else:
        kept, dropped = list(cookies), []

    # Safety: never write blocked domains when filter is on
    if filter_google and any(domain_blocked(str(c.get("domain", ""))) for c in kept):
        raise RuntimeError("safety check failed: blocked domain still in kept set")

    cookie_path.write_text(json.dumps(kept, ensure_ascii=False), encoding="utf-8")
    cookie_path.chmod(stat.S_IRUSR | stat.S_IWUSR)  # 0o600
    return kept, dropped, cookie_path


def load_cookie_dump(path: Path | str | None = None) -> list[dict[str, Any]]:
    cookie_path = Path(
        path
        or os.environ.get(
            "BH_COOKIE_FILE",
            str(Path.home() / ".config/browser-harness/main-cookies.json"),
        )
    )
    return json.loads(cookie_path.read_text(encoding="utf-8"))


def cookies_for_inject(path: Path | str | None = None) -> tuple[list[dict], list[dict]]:
    """Load dump and re-filter before inject (defense in depth)."""
    cookies = load_cookie_dump(path)
    return filter_cookies(cookies)


def domain_counts(cookies: list[dict], needle: str) -> tuple[int, bool]:
    """Return (count matching domain needle, has z_c0 if needle is zhihu-related)."""
    n = needle.lower()
    matched = [c for c in cookies if n in str(c.get("domain", "")).lower()]
    has_zc0 = any(c.get("name") == "z_c0" for c in matched)
    return len(matched), has_zc0
