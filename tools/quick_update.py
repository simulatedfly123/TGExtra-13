#!/usr/bin/env python3
"""Build the tweak on GitHub Actions (tweak.yml) and swap it into an existing IPA.

Push your tweak changes first, then:
    python tools/quick_update.py --ipa build/ph.telegra.Telegraph-13.0-TGExtra-1.3.0.ipa

Needs the GitHub CLI (gh) logged in. Takes ~5-7 minutes instead of rebuilding Telegram.
"""
import argparse
import glob
import os
import shutil
import subprocess
import sys
import tempfile
import time
from datetime import datetime, timezone

HERE = os.path.dirname(os.path.abspath(__file__))


def find_gh():
    gh = shutil.which("gh")
    if gh:
        return gh
    default = r"C:\Program Files\GitHub CLI\gh.exe"
    if os.path.exists(default):
        return default
    raise SystemExit("gh not found: install it with `winget install --id GitHub.cli -e`")


def gh(*args, retries=5):
    for attempt in range(retries):
        res = subprocess.run([GH, *args], capture_output=True, text=True, encoding="utf-8")
        if res.returncode == 0:
            return res.stdout.strip()
        if attempt == retries - 1:
            raise SystemExit(f"gh {' '.join(args)} failed:\n{res.stderr}")
        time.sleep(10)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--ipa", required=True, help="IPA that already has TGExtra injected")
    ap.add_argument("-o", "--output", help="default: <ipa name>-updated-<time>.ipa next to the input")
    ap.add_argument("--repo", help="owner/name, default: the repo of the current checkout")
    ap.add_argument("--ref", default="main")
    args = ap.parse_args()

    repo = args.repo or gh("repo", "view", "--json", "nameWithOwner", "--jq", ".nameWithOwner")
    # small margin for clock skew between this machine and GitHub
    started = datetime.fromtimestamp(time.time() - 60, timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    gh("workflow", "run", "tweak.yml", "--repo", repo, "--ref", args.ref)
    print(f"Started tweak.yml on {repo}@{args.ref}, waiting for the run...")

    run_id = None
    for _ in range(30):
        time.sleep(5)
        out = gh("run", "list", "--repo", repo, "--workflow", "tweak.yml", "--limit", "5",
                 "--json", "databaseId,createdAt", "--jq", f'.[] | select(.createdAt >= "{started}") | .databaseId')
        if out:
            run_id = out.splitlines()[-1]
            break
    if run_id is None:
        raise SystemExit("could not find the started run")
    print(f"Run: https://github.com/{repo}/actions/runs/{run_id}")

    while True:
        status = gh("run", "view", run_id, "--repo", repo, "--json", "status,conclusion", "--jq", '.status + " " + .conclusion')
        if status.startswith("completed"):
            break
        time.sleep(30)
    if status != "completed success":
        raise SystemExit(f"build failed ({status}), see: gh run view {run_id} --repo {repo} --log-failed")

    tmp = tempfile.mkdtemp(prefix="tgextra-")
    gh("run", "download", run_id, "--repo", repo, "--name", "tgextra-deb", "--dir", tmp)
    debs = glob.glob(os.path.join(tmp, "*_iphoneos-arm.deb"))
    if not debs:
        raise SystemExit(f"no rootful .deb in the artifact ({os.listdir(tmp)})")

    output = args.output or os.path.splitext(args.ipa)[0] + datetime.now().strftime("-updated-%Y%m%d-%H%M.ipa")
    subprocess.run([sys.executable, os.path.join(HERE, "update_ipa.py"), "--ipa", args.ipa, "--deb", debs[0], "-o", output], check=True)
    shutil.copy(debs[0], os.path.dirname(os.path.abspath(output)))
    shutil.rmtree(tmp, ignore_errors=True)


GH = find_gh()

if __name__ == "__main__":
    main()
