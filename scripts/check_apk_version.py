#!/usr/bin/env python3
"""Check that an APK's embedded versionName/versionCode match app/build.gradle.kts.

Usage: check_apk_version.py APK [--file PATH]
Reads the version from the APK itself (aapt2 dump badging), not from its filename.
Finds aapt2 via $AAPT2 or the newest build-tools under $ANDROID_HOME / $ANDROID_SDK_ROOT.
"""
import argparse
import glob
import os
import re
import subprocess
import sys


def find_aapt2() -> str:
    if os.environ.get("AAPT2"):
        return os.environ["AAPT2"]
    for root in (os.environ.get("ANDROID_HOME"), os.environ.get("ANDROID_SDK_ROOT")):
        if root:
            found = sorted(
                glob.glob(os.path.join(root, "build-tools", "*", "aapt2")),
                key=lambda p: [int(x) if x.isdigit() else 0 for x in re.split(r"[.\-]", p.split(os.sep)[-2])],
            )
            if found:
                return found[-1]
    sys.exit("aapt2 not found: set AAPT2 or ANDROID_HOME")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("apk")
    ap.add_argument("--file", default="app/build.gradle.kts")
    args = ap.parse_args()

    text = open(args.file).read()
    name = re.search(r'versionName\s*=\s*"([^"]+)"', text)
    code = re.search(r'versionCode\s*=\s*(\d+)', text)
    if not name or not code:
        sys.exit(f"versionName/versionCode not found in {args.file}")
    want = (name.group(1), code.group(1))

    out = subprocess.run(
        [find_aapt2(), "dump", "badging", args.apk], capture_output=True, text=True, check=True
    ).stdout
    m = re.search(r"versionCode='(\d+)' versionName='([^']*)'", out)
    if not m:
        sys.exit(f"could not read the version from {args.apk}")
    got = (m.group(2), m.group(1))

    if got != want:
        sys.exit(
            f"{args.apk} is version {got[0]} (code {got[1]}) but {args.file} says "
            f"{want[0]} (code {want[1]}). Stale APK? Run `make release` again."
        )
    print(f"OK: {os.path.basename(args.apk)} is {want[0]} (code {want[1]})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
