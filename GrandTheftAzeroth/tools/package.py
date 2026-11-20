#!/usr/bin/env python3
"""Build out/GrandTheftAzeroth-<version>.zip from the committed addon files (tools/ excluded)."""
import re
import subprocess
import sys
import zipfile
from pathlib import Path

ADDON = Path(__file__).resolve().parent.parent
REPO = ADDON.parent
OUT = REPO / "out"

toc = (ADDON / "GrandTheftAzeroth.toc").read_text()
version = re.search(r"^## Version: (\S+)", toc, re.M).group(1)

dirty = subprocess.run(["git", "status", "--porcelain", "--", str(ADDON)], cwd=REPO, capture_output=True, text=True).stdout.strip()
if dirty and "--allow-dirty" not in sys.argv:
    sys.exit("uncommitted changes in the addon; commit first or pass --allow-dirty:\n" + dirty)

files = subprocess.run(["git", "ls-files", "--", str(ADDON)], cwd=REPO, capture_output=True, text=True, check=True).stdout.split()
if "--allow-dirty" in sys.argv:
    files = sorted({str(p.relative_to(REPO)) for p in ADDON.rglob("*") if p.is_file()})

OUT.mkdir(exist_ok=True)
target = OUT / f"GrandTheftAzeroth-{version}.zip"
count = 0
with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED) as z:
    for rel in files:
        if rel.startswith("GrandTheftAzeroth/tools/") or "__pycache__" in rel:
            continue
        z.write(REPO / rel, rel)
        count += 1
print(f"{target} ({count} files, {target.stat().st_size // 1024} KB)")
