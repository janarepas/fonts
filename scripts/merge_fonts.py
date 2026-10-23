#!/usr/bin/env python3

from pathlib import Path
from collections import defaultdict
import hashlib
import csv
import shutil
import sys
import re

SOURCE = Path.home() / "Library/Fonts"
ROOT = Path.home() / "Developer/macos_fonts"
TARGET = ROOT / "fonts"
REPORT = ROOT / "reports/merge-preview.csv"
EXT = {".otf", ".ttf", ".ttc"}

APPLY = "--apply" in sys.argv

def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

def family(name):
    clean = re.sub(
        r"^fonnts\.com-", "", name, flags=re.I
    )
    stem = Path(clean).stem

    # Meglévő betűcsaládok felismerése
    families = {
        "JetBrainsMono": "JetBrainsMono",
        "Montserrat": "Montserrat",
        "Bookmania": "Bookmania",
        "SharpGrotesk": "SharpGrotesk",
        "Proxima": "ProximaNova",
        "Futura": "Futura",
        "Dharma": "Dharma",
        "Recoleta": "Recoleta",
        "ALDI": "ALDI-SUED",
        "FAIRE": "LumaSans-Trial",
        "FiraSans": "FiraSans",
        "FiraCode": "FiraCode",
        "Meslo": "Meslo",
        "Manrope": "Manrope",
        "Gunar": "Gunar",
        "Bauhaus": "Bauhaus",
        "EBGaramond": "EBGaramond",
        "Reload": "Reload",
        "Acumin": "AcuminPro",
        "NotoSans": "NotoSans",
    }

    for prefix, folder in families.items():
        if stem.lower().startswith(prefix.lower()):
            return folder

    first = re.split(r"[-_ ]", stem)[0]
    return re.sub(
        r"[^A-Za-z0-9_-]", "", first
    ) or "Other"

def font_files(directory):
    return sorted(
        (p for p in directory.rglob("*")
         if p.is_file()
         and not p.is_symlink()
         and ".git" not in p.parts
         and p.suffix.lower() in EXT),
        key=lambda p: str(p)
    )

def main():
    if not SOURCE.is_dir() or not TARGET.is_dir():
        sys.exit("Hiányzó forrás- vagy célkönyvtár")

    existing = font_files(TARGET)
    incoming = font_files(SOURCE)

    known_hashes = set()
    known_names = defaultdict(list)

    for p in existing:
        known_hashes.add(sha256(p))
        known_names[p.name.casefold()].append(p)

    rows = []
    counts = defaultdict(int)

    for src in incoming:
        digest = sha256(src)
        dest = TARGET / family(src.name) / src.name

        if digest in known_hashes:
            status = "identical"
        elif src.name.casefold() in known_names:
            status = "name_conflict"
        elif dest.exists():
            status = "destination_conflict"
        else:
            status = "new"

        if status == "new" and APPLY:
            dest.parent.mkdir(parents=True, exist_ok=True)

            # Nem írunk felül meglévő fájlt.
            try:
                with src.open("rb") as input_file:
                    with dest.open("xb") as output_file:
                        shutil.copyfileobj(
                            input_file, output_file
                        )
                if sha256(dest) != digest:
                    raise RuntimeError(
                        f"Másolási ellenőrzési hiba: {dest}"
                    )
                status = "copied"
                known_hashes.add(digest)
                known_names[src.name.casefold()].append(dest)
            except FileExistsError:
                status = "destination_conflict"

        rows.append([
            str(src.relative_to(SOURCE)),
            str(dest.relative_to(ROOT)),
            digest,
            status
        ])
        counts[status] += 1

    REPORT.parent.mkdir(exist_ok=True)

    with REPORT.open("w", newline="") as f:
        writer = csv.writer(f, lineterminator="\n")
        writer.writerow([
            "source", "destination", "sha256", "status"
        ])
        writer.writerows(rows)

    print(f"Mód: {'MÁSOLÁS' if APPLY else 'ELŐNÉZET'}")
    print(f"Repóban: {len(existing)} font")
    print(f"Fonts könyvtárban: {len(incoming)} font")
    for key, value in sorted(counts.items()):
        print(f"{key}: {value}")
    print(f"Jelentés: {REPORT}")

if __name__ == "__main__":
    main()
