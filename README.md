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

Preview without installing:

    python3 scripts/install_fonts.py

Install fonts on macOS:

    python3 scripts/install_fonts.py --install

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
