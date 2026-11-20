#!/usr/bin/env python3
"""CurseForge upload helper. The API token is read from a file and never printed.

  curseforge.py versions --token-file F            list WoW game versions matching 1.60 / Forever
  curseforge.py upload --token-file F --project ID --zip Z --game-version ID [--release-type beta]
"""
import argparse
import json
import re
import sys
import urllib.request
import uuid
from pathlib import Path

API = "https://wow.curseforge.com/api"
ADDON = Path(__file__).resolve().parent.parent


def request(path, token, data=None, content_type=None):
    req = urllib.request.Request(API + path, data=data, method="POST" if data else "GET")
    req.add_header("X-Api-Token", token)
    req.add_header("User-Agent", "gta-addon-uploader")
    if content_type:
        req.add_header("Content-Type", content_type)
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return json.loads(r.read() or b"null")
    except urllib.error.HTTPError as e:
        sys.exit(f"HTTP {e.code} on {path}: {e.read().decode(errors='replace')[:500]}")


def versions(token):
    types = {t["id"]: t["name"] for t in request("/game/version-types", token)}
    for v in request("/game/versions", token):
        tname = types.get(v.get("gameVersionTypeID"), "?")
        if v["name"].startswith("1.60") or "forever" in tname.lower():
            print(f"id={v['id']:<6} name={v['name']:<10} type={tname}")


def latest_changelog():
    text = (ADDON / "CHANGELOG.md").read_text()
    parts = re.split(r"^## ", text, flags=re.M)
    return "## " + parts[1].strip() if len(parts) > 1 else text


def upload(token, project, zip_path, game_version, release_type, display_name):
    zip_path = Path(zip_path)
    meta = {
        "changelog": latest_changelog(),
        "changelogType": "markdown",
        "displayName": display_name or zip_path.stem,
        "gameVersions": [int(game_version)],
        "releaseType": release_type,
    }
    boundary = uuid.uuid4().hex
    body = b"".join([
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"metadata\"\r\n\r\n".encode(),
        json.dumps(meta).encode(),
        f"\r\n--{boundary}\r\nContent-Disposition: form-data; name=\"file\"; filename=\"{zip_path.name}\"\r\nContent-Type: application/zip\r\n\r\n".encode(),
        zip_path.read_bytes(),
        f"\r\n--{boundary}--\r\n".encode(),
    ])
    res = request(f"/projects/{int(project)}/upload-file", token, body, f"multipart/form-data; boundary={boundary}")
    print("uploaded, file id:", res.get("id") if isinstance(res, dict) else res)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("action", choices=["versions", "upload"])
    p.add_argument("--token-file", required=True)
    p.add_argument("--project")
    p.add_argument("--zip")
    p.add_argument("--game-version")
    p.add_argument("--release-type", default="beta", choices=["alpha", "beta", "release"])
    p.add_argument("--display-name")
    a = p.parse_args()
    token = Path(a.token_file).read_text().strip()
    if a.action == "versions":
        versions(token)
    else:
        if not (a.project and a.zip and a.game_version):
            sys.exit("upload needs --project, --zip and --game-version")
        upload(token, a.project, a.zip, a.game_version, a.release_type, a.display_name)


if __name__ == "__main__":
    main()
