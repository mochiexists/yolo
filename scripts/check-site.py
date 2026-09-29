#!/usr/bin/env python3
"""Static site check for cloud sessions (python3 stdlib only).

For every git-tracked .html page under SITE_ROOT:
  - exactly one <title> (SVG <title> elements are ignored)
  - a <meta name="description"> with content
  - every same-origin href/src resolves to a tracked file
    (clean URLs: /x -> x, x.html or x/index.html; trailing slashes,
    #fragments and ?queries are handled; mailto:, tel:, javascript:,
    data: and external hosts are ignored)

Known pre-existing failures live in scripts/check-site.baseline, one per
line, optionally followed by "# reason": either a failure exactly as
printed (without "FAIL ") or a bare page path to skip every failure on it.

Usage: python3 scripts/check-site.py
Exit status: 0 when clean (apart from the baseline), 1 otherwise.
"""

from __future__ import annotations

import shutil
import subprocess
import sys
import tempfile
from html.parser import HTMLParser
from pathlib import Path, PurePosixPath
from urllib.parse import unquote, urlsplit

REPO_ROOT = Path(__file__).resolve().parent.parent
# Directory (relative to the repo root) that is served as the site.
SITE_ROOT = ""
# Tracked .html files under these prefixes (relative to SITE_ROOT) are not pages.
EXCLUDED_PREFIXES: tuple[str, ...] = ()
# Hosts that count as same-origin when a link is written as an absolute URL.
SAME_ORIGIN_HOSTS: tuple[str, ...] = ("mochiexists.com", "www.mochiexists.com", "mochiexists.github.io")
# URL path the site is served under (GitHub project pages), e.g. "/yolo/".
BASE_PATH = "/yolo/"
# Optional generator that must leave tracked files unchanged, e.g. ("node", "build.js").
BUILD_COMMAND: tuple[str, ...] = ()

BASELINE_FILE = REPO_ROOT / "scripts" / "check-site.baseline"
IGNORED_SCHEMES = {"mailto", "tel", "javascript", "data", "sms", "blob", "about"}
LINK_ATTRS = {
    "a": ("href",),
    "area": ("href",),
    "link": ("href",),
    "script": ("src",),
    "img": ("src",),
    "iframe": ("src",),
    "source": ("src",),
    "video": ("src", "poster"),
    "audio": ("src",),
    "track": ("src",),
    "embed": ("src",),
}
# <link rel> values whose href is a hint, not a resource of this site.
IGNORED_LINK_RELS = {"preconnect", "dns-prefetch"}


class PageParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.title_count = 0
        self.has_description = False
        self.urls: list[str] = []
        self._svg_depth = 0

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        attr_map = {name: (value or "") for name, value in attrs}
        if tag == "svg":
            self._svg_depth += 1
        if tag == "title" and self._svg_depth == 0:
            self.title_count += 1
        if tag == "meta" and attr_map.get("name", "").lower() == "description":
            self.has_description = bool(attr_map.get("content", "").strip())
        if tag == "link":
            rels = set(attr_map.get("rel", "").lower().split())
            if rels & IGNORED_LINK_RELS:
                return
        for attr in LINK_ATTRS.get(tag, ()):
            value = attr_map.get(attr, "").strip()
            if value:
                self.urls.append(value)

    def handle_startendtag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        self.handle_starttag(tag, attrs)
        if tag == "svg":
            self._svg_depth -= 1

    def handle_endtag(self, tag: str) -> None:
        if tag == "svg" and self._svg_depth > 0:
            self._svg_depth -= 1


def tracked_files() -> set[str]:
    output = subprocess.run(
        ["git", "ls-files", "-z"], cwd=REPO_ROOT, check=True, capture_output=True, text=True
    ).stdout
    prefix = f"{SITE_ROOT.rstrip('/')}/" if SITE_ROOT else ""
    return {path[len(prefix):] for path in output.split("\0") if path and path.startswith(prefix)}


def target_path(url: str, page: str) -> str | None:
    """Site-relative path a same-origin URL points at, or None to skip it."""
    parts = urlsplit(url)
    if parts.scheme and parts.scheme.lower() in IGNORED_SCHEMES:
        return None
    if parts.scheme or parts.netloc:
        if parts.netloc.lower() not in SAME_ORIGIN_HOSTS:
            return None
    path = unquote(parts.path)
    if not path:
        return None  # pure #fragment or ?query: same page
    if path.startswith("/"):
        base = BASE_PATH.rstrip("/")
        if base:
            if path != base and not path.startswith(f"{base}/"):
                return None  # outside BASE_PATH: served by another site
            path = path[len(base):] or "/"
        joined = PurePosixPath(path.lstrip("/"))
    else:
        joined = PurePosixPath(page).parent / path
    normalized: list[str] = []
    for part in joined.parts:
        if part == "..":
            if normalized:
                normalized.pop()
        elif part != ".":
            normalized.append(part)
    resolved = "/".join(normalized)
    if path.endswith("/") and resolved:
        resolved += "/"
    return resolved


def resolves(target: str, files: set[str]) -> bool:
    if target in ("", "/"):
        return "index.html" in files
    if target.endswith("/"):
        return f"{target}index.html" in files
    return any(c in files for c in (target, f"{target}.html", f"{target}/index.html"))


def load_baseline() -> set[str]:
    if not BASELINE_FILE.exists():
        return set()
    entries = set()
    for line in BASELINE_FILE.read_text(encoding="utf-8").splitlines():
        entry = line.split("#", 1)[0].strip()
        if entry:
            entries.add(entry)
    return entries


def check_build(failures: list[str]) -> None:
    """Run BUILD_COMMAND on a scratch copy and flag tracked files it would change.

    The working tree is never touched, so hand edits to generated files survive.
    """
    if not BUILD_COMMAND:
        return
    listed = subprocess.run(
        ["git", "ls-files", "-z"], cwd=REPO_ROOT, check=True, capture_output=True, text=True
    ).stdout
    paths = [p for p in listed.split("\0") if p and (REPO_ROOT / p).is_file()]
    with tempfile.TemporaryDirectory() as scratch:
        scratch_root = Path(scratch)
        for rel in paths:
            destination = scratch_root / rel
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(REPO_ROOT / rel, destination)
        subprocess.run(BUILD_COMMAND, cwd=scratch_root, check=True, stdout=subprocess.DEVNULL)
        command = " ".join(BUILD_COMMAND)
        for rel in paths:
            if (scratch_root / rel).read_bytes() != (REPO_ROOT / rel).read_bytes():
                failures.append(f"{rel}: stale, `{command}` regenerates it differently")


def main() -> int:
    failures: list[str] = []
    check_build(failures)
    files = tracked_files()
    pages = sorted(
        f for f in files if f.endswith(".html") and not f.startswith(EXCLUDED_PREFIXES)
    )
    site_dir = REPO_ROOT / SITE_ROOT
    for page in pages:
        parser = PageParser()
        parser.feed((site_dir / page).read_text(encoding="utf-8", errors="replace"))
        if parser.title_count != 1:
            failures.append(f"{page}: expected 1 <title>, found {parser.title_count}")
        if not parser.has_description:
            failures.append(f"{page}: missing meta description")
        for url in parser.urls:
            target = target_path(url, page)
            if target is not None and not resolves(target, files):
                failures.append(f"{page}: broken link -> {url}")

    baseline = load_baseline()
    failures = list(dict.fromkeys(failures))
    failing_pages = {f.split(": ", 1)[0] for f in failures}
    unexpected = [f for f in failures if f not in baseline and f.split(": ", 1)[0] not in baseline]
    stale = sorted(e for e in baseline if e not in failures and e not in failing_pages)
    for entry in stale:
        print(f"note: baseline entry no longer fails, remove it: {entry}")
    for failure in unexpected:
        print(f"FAIL {failure}")
    baselined = len(failures) - len(unexpected)
    print(f"check-site: {len(pages)} pages, {len(unexpected)} failures, {baselined} baselined")
    return 1 if unexpected else 0


if __name__ == "__main__":
    sys.exit(main())
