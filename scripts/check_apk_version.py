#!/usr/bin/env python3
"""Check a release APK before it is published.

Usage: check_apk_version.py APK [--file PATH] [--cert SHA256]

1. The APK's embedded versionName/versionCode (aapt2 dump badging, not the filename) must match
   app/build.gradle.kts.
2. If --cert (or $RELEASE_CERT_SHA256) is given, the APK must be signed by exactly that certificate
   (apksigner verify), so a build signed with the wrong key is never published.

Tools are found via $AAPT2 / $APKSIGNER or the newest build-tools under $ANDROID_HOME / $ANDROID_SDK_ROOT.
"""
import argparse
import glob
import os
import re
import subprocess
import sys


def find_tool(name: str, env: str) -> str:
    if os.environ.get(env):
        return os.environ[env]
    for root in (os.environ.get("ANDROID_HOME"), os.environ.get("ANDROID_SDK_ROOT")):
        if root:
            found = sorted(
                glob.glob(os.path.join(root, "build-tools", "*", name)),
                key=lambda p: [int(x) if x.isdigit() else 0 for x in re.split(r"[.\-]", p.split(os.sep)[-2])],
            )
            if found:
                return found[-1]
    sys.exit(f"{name} not found: set {env} or ANDROID_HOME")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("apk")
    ap.add_argument("--file", default="app/build.gradle.kts")
    ap.add_argument("--cert", default=os.environ.get("RELEASE_CERT_SHA256"))
    args = ap.parse_args()

    text = open(args.file).read()
    name = re.search(r'versionName\s*=\s*"([^"]+)"', text)
    code = re.search(r'versionCode\s*=\s*(\d+)', text)
    if not name or not code:
        sys.exit(f"versionName/versionCode not found in {args.file}")
    want = (name.group(1), code.group(1))

    out = subprocess.run(
        [find_tool("aapt2", "AAPT2"), "dump", "badging", args.apk], capture_output=True, text=True, check=True
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

    if args.cert:
        res = subprocess.run(
            [find_tool("apksigner", "APKSIGNER"), "verify", "--print-certs", args.apk],
            capture_output=True, text=True,
        )
        certs = re.findall(r"certificate SHA-256 digest: ([0-9a-fA-F]+)", res.stdout)
        if res.returncode != 0 or not certs:
            sys.exit(f"{args.apk}: signature check failed\n{res.stderr or res.stdout}")
        want_cert = args.cert.replace(":", "").lower()
        if [c.lower() for c in certs] != [want_cert]:
            sys.exit(
                f"{args.apk} is signed with {certs[0][:16]}... but the release key is "
                f"{want_cert[:16]}... Wrong keystore? Check KEYSTORE in env.mk."
            )
        print(f"OK: signed with the release key ({want_cert[:16]}...)")
    else:
        print("note: RELEASE_CERT_SHA256 not set, signing key not verified")
    return 0


if __name__ == "__main__":
    sys.exit(main())
