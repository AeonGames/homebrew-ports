#!/usr/bin/env python3
"""Update Formula/skia-aeongui.rb to latest stable Skia milestone.

Usage:
  python3 scripts/update-skia-formula.py
  python3 scripts/update-skia-formula.py --check
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import urllib.request
from pathlib import Path

CHROMIUMDASH_URL = "https://chromiumdash.appspot.com/fetch_releases?channel=Stable&platform=Mac"
SKIA_REMOTE = "https://skia.googlesource.com/skia"
FORMULA_PATH = Path(__file__).resolve().parents[1] / "Formula" / "skia-aeongui.rb"


def fetch_json(url: str) -> object:
    with urllib.request.urlopen(url, timeout=30) as response:
        return json.load(response)


def latest_stable_milestone() -> int:
    releases = fetch_json(CHROMIUMDASH_URL)
    if not isinstance(releases, list) or not releases:
        raise RuntimeError("Could not parse ChromiumDash stable release response")
    milestone = releases[0].get("milestone")
    if not isinstance(milestone, int):
        raise RuntimeError("Stable milestone not found in ChromiumDash response")
    return milestone


def skia_branch_head_commit(milestone: int) -> str | None:
    ref = f"refs/heads/chrome/m{milestone}"
    result = subprocess.run(["git", "ls-remote", SKIA_REMOTE, ref], capture_output=True, text=True, check=False)
    line = result.stdout.strip()
    return line.split()[0] if line else None


def resolve_latest_skia_milestone(start: int, floor: int = 120) -> int:
    for milestone in range(start, floor - 1, -1):
        if skia_branch_head_commit(milestone):
            return milestone
    raise RuntimeError(f"No Skia chrome/m* branch found in range [{floor}, {start}]")


def replace_once(text: str, pattern: str, replacement: str, label: str) -> str:
    updated, count = re.subn(pattern, replacement, text, count=1, flags=re.MULTILINE)
    if count != 1:
        raise RuntimeError(f"Failed to update {label}; pattern not found exactly once")
    return updated


def update_formula_content(content: str, milestone: int, commit: str) -> str:
    stable_url = (
        f'  url "https://skia.googlesource.com/skia.git", '
        f'branch: "chrome/m{milestone}", revision: "{commit}"'
    )

    content = replace_once(
        content,
        r'^\s*url\s+"https://skia\.googlesource\.com/skia(?:\.git)?"(?:,\s*branch:\s*"chrome/m\d+")?(?:,\s*revision:\s*"[0-9a-f]{40}")?\s*$',
        stable_url,
        "url",
    )
    content = replace_once(
        content,
        r'^\s*version\s+"[^"]+"\s*$',
        f'  version "{milestone}-g{commit[:12]}"',
        "version",
    )
    content = replace_once(
        content,
        r"This formula is pinned to Skia stable chrome/m\d+\.",
        f"This formula is pinned to Skia stable chrome/m{milestone}.",
        "caveat milestone text",
    )
    return content


def main() -> int:
    parser = argparse.ArgumentParser(description="Pin skia-aeongui formula to latest stable Skia milestone")
    parser.add_argument("--check", action="store_true", help="Exit non-zero if formula is outdated")
    args = parser.parse_args()

    if not FORMULA_PATH.exists():
        raise RuntimeError(f"Formula not found: {FORMULA_PATH}")

    chrome_milestone = latest_stable_milestone()
    skia_milestone = resolve_latest_skia_milestone(chrome_milestone)
    commit = skia_branch_head_commit(skia_milestone)
    if not commit:
        raise RuntimeError(f"Could not resolve commit for chrome/m{skia_milestone}")

    original = FORMULA_PATH.read_text(encoding="utf-8")
    updated = update_formula_content(original, skia_milestone, commit)

    if args.check:
        if original != updated:
            print(
                f"Formula is outdated. Latest stable pin: chrome/m{skia_milestone} commit={commit}",
                file=sys.stderr,
            )
            return 1
        print(f"Formula is up to date at chrome/m{skia_milestone} commit={commit}")
        return 0

    if original == updated:
        print(f"No changes needed. Formula already pinned to chrome/m{skia_milestone}.")
        return 0

    FORMULA_PATH.write_text(updated, encoding="utf-8")
    print(f"Updated {FORMULA_PATH} to chrome/m{skia_milestone} commit={commit}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"error: {exc}", file=sys.stderr)
        raise SystemExit(2)
