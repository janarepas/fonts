#!/usr/bin/env python3
"""Non-destructive inventory and optional metadata audit for macos_fonts."""
import argparse
import hashlib
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EXTENSIONS = {".ttf", ".otf"}


def digest(path):
    h = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def name_value(font, name_id):
    table = font["name"]
    for record in table.names:
        if record.nameID == name_id:
            try:
                return record.toUnicode()
            except Exception:
                continue
    return ""


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--metadata", action="store_true", help="Inspect font names via optional fontTools")
    args = parser.parse_args()
    files = sorted((p for p in (ROOT / "fonts").rglob("*") if p.is_file() and p.suffix.lower() in EXTENSIONS), key=lambda p: p.name.lower())
    groups = defaultdict(list)
    types = defaultdict(int)
    size = 0
    for path in files:
        types[path.suffix.lower()] += 1
        size += path.stat().st_size
        try:
            groups[digest(path)].append(path.name)
        except OSError as err:
            print(f"READ ERROR {path.name}: {err}")
    print(f"Files: {len(files)}; OTF: {types['.otf']}; TTF: {types['.ttf']}; bytes: {size}")
    dupes = [v for v in groups.values() if len(v) > 1]
    print(f"Exact duplicate groups (SHA-256): {len(dupes)}; extra copies: {sum(len(v)-1 for v in dupes)}")
    for items in dupes:
        print("DUPLICATE: " + " | ".join(items))
    for path in files:
        if path.stat().st_size < 10000:
            print(f"REVIEW SMALL FILE: {path.name} ({path.stat().st_size} bytes)")
    if not args.metadata:
        return
    try:
        from fontTools.ttLib import TTFont
    except ImportError:
        parser.error("--metadata requires fontTools (python3 -m pip install fonttools)")
    postscript = defaultdict(list)
    failures = 0
    for path in files:
        try:
            font = TTFont(str(path), lazy=True)
            try:
                family, style, ps, version = (name_value(font, k) for k in (1, 2, 6, 5))
                print(f"META: {path.name} | family={family!r} | style={style!r} | ps={ps!r} | version={version!r}")
                if ps:
                    postscript[ps].append(path.name)
            finally:
                font.close()
        except Exception as err:
            failures += 1
            print(f"INVALID/UNREADABLE: {path.name} | {err}")
    for name, paths in sorted(postscript.items()):
        if len(paths) > 1:
            print(f"POSTSCRIPT NAME COLLISION: {name}: {' | '.join(paths)}")
    print(f"Metadata parse failures: {failures}")


if __name__ == "__main__":
    main()
