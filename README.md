# macos_fonts

Personal macOS font archive. **Private use is not proof of a redistribution license.** Before sharing or using a font commercially, verify its original license and keep proof of purchase/source.

## Current layout

Fonts are stored at repository root as `.otf` and `.ttf` files. They have **not** been moved or deleted. On 2026-10-23 the root contained 768 font files (454 OTF, 314 TTF); a Git blob SHA check found 11 identical-content pairs. This is a repository-inventory check, not a full font validation or license audit.

## Setup

Clone this repository privately onto macOS. Python 3 is required; optional [fontTools](https://github.com/fonttools/fonttools) provides metadata inspection.

```sh
python3 scripts/audit_fonts.py
python3 -m pip install --user fonttools  # optional; use a virtual environment if preferred
python3 scripts/audit_fonts.py --metadata
python3 scripts/install_fonts.py         # preview ONLY: no files written
python3 scripts/install_fonts.py --install # copy into ~/Library/Fonts
```

The installer only selects `.otf`/`.ttf` files at the repository root. It skips identical installed files, refuses to overwrite different installed files with the same filename, and reports every planned or completed action. It does **not** certify licenses, font validity or internal PostScript-name uniqueness. **Review licenses and run the audit first.** For individually licensed fonts, install only those you have rights to use.

## Audit

`audit_fonts.py` reports a summary, SHA-256 duplicate-content groups and suspiciously small font files. `--metadata` reads family/style/PostScript names and versions (if fontTools is installed), detects repeated PostScript names and records parse errors. Neither script modifies the repository.

## Licenses and provenance

`fonts-manifest.csv` is a template for the font provenance/licensing inventory, not a statement that any file is cleared for redistribution. Populate source, license, usage rights, and verification status before sharing. Keep invoices or EULAs in a safe private location. Commercial and trial fonts may impose restrictions even in a private repository.

## Roadmap

- Verify provenance and licensing of every font
- Review internal font names, versions and conflicting families
- Inspect exact duplicates; only then consider removing copies
- Organize by family after checking install-script compatibility
- Add CI checks after recording a trusted baseline

No font binaries were changed as part of this documentation/tooling update.
