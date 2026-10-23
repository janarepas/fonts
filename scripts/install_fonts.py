#!/usr/bin/env python3
"""Preview or safely install root-level fonts into the current user's macOS Fonts directory."""
import argparse
import hashlib
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEST = Path.home() / "Library" / "Fonts"
EXTENSIONS = {".ttf", ".otf"}


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            h.update(block)
    return h.digest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--install", action="store_true", help="Actually copy files (default: dry-run)")
    parser.add_argument("--only", action="append", default=[], metavar="FILENAME",
                        help="Install only named font(s); may be repeated; recommended for licensed subsets")
    args = parser.parse_args()
    if args.install and sys.platform != "darwin":
        parser.error("--install requires macOS")
    files = sorted((p for p in (ROOT / "fonts").rglob("*") if p.is_file() and p.suffix.lower() in EXTENSIONS), key=lambda p: p.name.lower())
    chosen = set(args.only)
    if chosen:
        absent = chosen.difference(p.name for p in files)
        if absent:
            parser.error("unknown fonts: " + ", ".join(sorted(absent)))
        files = [p for p in files if p.name in chosen]
    if args.install:
        DEST.mkdir(parents=True, exist_ok=True)
    counts = {"install": 0, "same": 0, "conflict": 0, "error": 0}
    for path in files:
        target = DEST / path.name
        try:
            if target.is_symlink():
                print(f"CONFLICT (symlink): {target}")
                counts["conflict"] += 1
                continue
            if target.exists():
                if not target.is_file() or sha256(path) != sha256(target):
                    print(f"CONFLICT (different existing file): {target}")
                    counts["conflict"] += 1
                else:
                    print(f"SKIP identical: {path.name}")
                    counts["same"] += 1
                continue
            if args.install:
                # Exclusive-create: never overwrite a file created between checking and copying.
                with path.open("rb") as source, target.open("xb") as sink:
                    for chunk in iter(lambda: source.read(1024 * 1024), b""):
                        sink.write(chunk)
                print(f"INSTALLED: {path.name}")
            else:
                print(f"WOULD INSTALL: {path.name}")
            counts["install"] += 1
        except FileExistsError:
            print(f"CONFLICT (appeared during copy): {target}")
            counts["conflict"] += 1
        except OSError as err:
            print(f"ERROR: {path.name}: {err}")
            counts["error"] += 1
    print(f"Mode: {'INSTALL' if args.install else 'DRY RUN'}; {counts}")
    if counts["conflict"] or counts["error"]:
        sys.exit(1)


if __name__ == "__main__":
    main()
