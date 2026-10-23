# macos_fonts

Personal macOS font collection.

## Directory structure

- fonts/ - Fonts organized by family
- scripts/ - Shell installer
- licenses/ - License information
- reports/ - Audit reports
- fonts-manifest.csv - Font inventory
- .gitignore - Ignored files

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

## Naming and inventory

Fonts are grouped by readable family names. Filenames follow internal PostScript names; variable fonts use a --VF suffix. Distinct copies with colliding names retain a SHA256 suffix. Selected checksum fields and internal names/style metadata were repaired locally; originals are preserved in a separate backup.

- 857 font files in 104 family folders
- 396 OTF, 460 TTF, 1 TTC (2 faces)
- Trial fonts and Rasley Heights PERSONAL USE excluded from the collection
- fonts-manifest.csv tracks the current paths and original Git blob identities

Licensing and source fields remain unverified until supporting documents are checked.
