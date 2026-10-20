#!/usr/bin/env python3
"""Packages the addon/ folder into dist/<name>-<version>.nvda-addon."""

import re
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent
ADDON = ROOT / "addon"


def manifestValue(key):
	match = re.search(rf"^{key}\s*=\s*(.+)$", (ADDON / "manifest.ini").read_text("utf-8"), re.M)
	return match.group(1).strip().strip('"')


def main():
	out = ROOT / "dist" / f"{manifestValue('name')}-{manifestValue('version')}.nvda-addon"
	out.parent.mkdir(exist_ok=True)
	with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as zf:
		for path in sorted(ADDON.rglob("*")):
			if path.is_file() and "__pycache__" not in path.parts:
				zf.write(path, path.relative_to(ADDON).as_posix())
	print(out)


if __name__ == "__main__":
	main()
