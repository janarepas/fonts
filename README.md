# macos_fonts

Personal macOS font collection.

## Directory structure

- fonts/ - Fonts organized by family
- scripts/ - Audit and installation tools
- licenses/ - License information
- reports/ - Audit reports
- fonts-manifest.csv - Font inventory
- .gitignore - Ignored files

## Audit

Run:

    python3 scripts/audit_fonts.py

Detailed metadata audit (requires fontTools):

    python3 scripts/audit_fonts.py --metadata

## Installation

The shell installer uses macOS Bash and does not require Python. It first checks matching filenames with a fast byte-for-byte comparison, and only hashes the installed font library when a new filename needs duplicate detection.


Preview without installing:

    ./scripts/install_fonts.sh --dry-run

Install fonts on macOS:

    ./scripts/install_fonts.sh --install

Fonts are installed into ~/Library/Fonts.
Existing different files will not be overwritten.

## Licensing

Some fonts are commercial, trial, or restricted
to personal use.

Licenses must be verified individually.
Do not redistribute fonts without permission.

## Notes

- 768 font files
- 454 OTF
- 314 TTF
- 11 known exact duplicate pairs

All original font files are preserved.
