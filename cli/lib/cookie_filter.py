"""Cookie domain filter for bh-clone sync.

Default: never sync Google-family login/session cookies (account safety).
"""
from __future__ import annotations

import os
from typing import Iterable

# Suffixes / hosts that carry Google account or tightly coupled sessions.
GOOGLE_FAMILY_SUFFIXES = (
    "google.com",
    "google.cn",
    "google.com.hk",
    "google.co.jp",
    "google.co.uk",
    "google.co.kr",
    "google.de",
    "google.fr",
    "googleapis.com",
    "googleapis.cn",
    "googleusercontent.com",
    "gstatic.com",
    "gmail.com",
    "youtube.com",
    "youtu.be",
    "ytimg.com",
    "ggpht.com",
    "googlevideo.com",
    "withgoogle.com",
    "chrome.com",
    "chromium.org",
    "android.com",
    "blogger.com",
    "blogspot.com",
)

_TRUTHY = frozenset({"1", "true", "yes", "on"})


def _norm(domain: str) -> str:
    return (domain or "").lower().strip().lstrip(".")


def _parse_extra(raw: str | None) -> list[str]:
    if not raw:
        return []
    return [_norm(x) for x in raw.split(",") if _norm(x)]


def _env_truthy(name: str, default: str = "0") -> bool:
    return os.environ.get(name, default).strip().lower() in _TRUTHY


def blocked_suffixes(
    extra: str | None = None,
    *,
    include_google: bool | None = None,
) -> list[str]:
    if include_google is None:
        include_google = _env_truthy("BH_INCLUDE_GOOGLE")
    suffixes: list[str] = []
    if not include_google:
        suffixes.extend(GOOGLE_FAMILY_SUFFIXES)
    if extra is None:
        extra = os.environ.get("BH_EXCLUDE_DOMAINS", "")
    suffixes.extend(_parse_extra(extra))
    seen: set[str] = set()
    out: list[str] = []
    for s in suffixes:
        if s and s not in seen:
            seen.add(s)
            out.append(s)
    return out


def domain_blocked(domain: str, suffixes: Iterable[str] | None = None) -> bool:
    d = _norm(domain)
    if not d:
        return False
    if suffixes is None:
        suffixes = blocked_suffixes()
    for s in suffixes:
        if not s:
            continue
        if d == s or d.endswith("." + s):
            return True
        # Catch bare google.TLD leftovers when google.com is in the blocklist
        if s == "google.com" and (d == "google" or d.startswith("google.")):
            return True
    return False


def filter_cookies(
    cookies: list[dict],
    suffixes: Iterable[str] | None = None,
) -> tuple[list[dict], list[dict]]:
    """Return (kept, dropped)."""
    if suffixes is None:
        suffixes = blocked_suffixes()
    kept: list[dict] = []
    dropped: list[dict] = []
    for c in cookies:
        if domain_blocked(str(c.get("domain", "")), suffixes):
            dropped.append(c)
        else:
            kept.append(c)
    return kept, dropped


def summarize_dropped(dropped: list[dict], limit: int = 12) -> str:
    hosts = sorted(
        {_norm(str(c.get("domain", ""))) for c in dropped if c.get("domain")}
    )
    if not hosts:
        return "none"
    show = hosts[:limit]
    more = f" (+{len(hosts) - limit} hosts)" if len(hosts) > limit else ""
    return ", ".join(show) + more
