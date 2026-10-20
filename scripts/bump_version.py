#!/usr/bin/env python3
"""Bump versionName and versionCode in app/build.gradle.kts.

Usage: bump_version.py [patch|minor|major|X.Y.Z] [--dry-run] [--file PATH]
With no version argument, prints the current version.
"""
import argparse
import re
import sys

NAME = re.compile(r'(versionName\s*=\s*")(\d+)\.(\d+)\.(\d+)(")')
CODE = re.compile(r'(versionCode\s*=\s*)(\d+)')


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("part", nargs="?")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--file", default="app/build.gradle.kts")
    args = ap.parse_args()

    text = open(args.file).read()
    name, code = NAME.search(text), CODE.search(text)
    if not name or not code:
        sys.exit(f"versionName/versionCode not found in {args.file}")
    major, minor, patch = (int(name.group(i)) for i in (2, 3, 4))
    old = f"{major}.{minor}.{patch}"

    if args.part is None:
        print(f"{old} (code {code.group(2)})")
        return 0
    if args.part == "patch":
        new = f"{major}.{minor}.{patch + 1}"
    elif args.part == "minor":
        new = f"{major}.{minor + 1}.0"
    elif args.part == "major":
        new = f"{major + 1}.0.0"
    elif re.fullmatch(r"\d+\.\d+\.\d+", args.part):
        new = args.part
    else:
        sys.exit(f"bad version part: {args.part}")
    new_code = int(code.group(2)) + 1

    print(f"{old} -> {new}, versionCode {code.group(2)} -> {new_code}")
    if not args.dry_run:
        text = NAME.sub(lambda m: f'{m.group(1)}{new}{m.group(5)}', text, count=1)
        text = CODE.sub(lambda m: f'{m.group(1)}{new_code}', text, count=1)
        open(args.file, "w").write(text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
