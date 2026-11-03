# macos_fonts

Personal font collection for macOS and Fedora/Linux.

## Font manager

Run `./install_fonts.sh` from the repository root. On macOS you can also
double-click `Install Fonts.command`, which opens the same script.

Families and variants use a compact grid that adapts to the terminal width.
There is one checkbox per family:

- `[✓]`: fully installed initially; keep or install this family.
- `[ ]`: absent initially; leave absent or remove this family.
- `[~]`: partially installed; leave unchanged, or press Space to install the rest.

Use lowercase `h`/`l` to move left/right and `j`/`k` (or Down/Up) to move
between grid rows. Left/Right arrows change pages from any highlighted cell.
Navigation stops at the first/last page; resizing recalculates the grid.
Long labels are shortened in cells; the highlighted name appears above the grid. Enter opens the highlighted family’s individual font files
(Regular, Bold, Italic, etc.). Space toggles a single variant; at family level
it toggles the whole family. Enter inside the variant list or `b` returns to families.
`/` opens text input (navigation shortcuts are inactive until Enter) and searches the current list, `r` resets search, and `q` cancels all changes.
Selections are preserved across family navigation and search.
Press `s` from either list to review all pending changes, then press `Y` to apply
or `N` to cancel (case insensitive; no Enter required). No changes are made merely
by entering or leaving a family. The checkbox reflects the desired installation
state; mixed families show `[~]`.

All logic lives in the root `install_fonts.sh`; there is no separate action menu.

## Terminal options

Explicit options remain available for scripts and noninteractive use:

    ./install_fonts.sh --install --all
    ./install_fonts.sh --uninstall --all
    ./install_fonts.sh --dry-run --all
    ./install_fonts.sh --uninstall --dry-run --all
    ./install_fonts.sh --install --family="Acumin Pro"

With redirected input and no options, the numbered selection defaults to a safe
preview. Explicit options bypass the unified state editor.

## Destinations and protection

macOS: `~/Library/Fonts`. Linux: `${XDG_DATA_HOME:-$HOME/.local/share}/fonts`.
On Fedora install `fontconfig` if `fc-cache` is missing. Linux refreshes its cache
after changes. The script supports macOS Bash 3.2 and Linux Bash without Python.

Existing different files are never overwritten. Direct command-line removal also asks for a single Y/N key. Removal only deletes matching
filenames with identical content in the user font folder; changed files,
symlinks, system fonts and repository source files are preserved. Status only
checks this target folder, not system fonts or fonts installed under other names.

## Collection and licensing

Fonts are grouped by family in `fonts/`; `fonts-manifest.csv` records inventory.
The collection contains 846 files in 104 families. Some fonts are commercial,
trial or restricted to personal use. Verify licenses individually; do not
redistribute without permission. Source/license fields remain unverified.

## Terminal interface

The interactive manager stays on an alternate terminal screen with a highlighted
current row, bounded scrolling, search, pending-change counts and a fixed shortcut
footer. Confirmation is a separate scrollable Y/N screen. Installation output is
captured instead of flooding the terminal; the result screen shows actual installed
and removed counts. Press V to view the paginated log (J/K to scroll, Q to close).
The terminal and cursor are restored on exit and interruption.

The interactive UI is in English. Navigation updates only changed terminal rows;
family lists and search results are cached until the view or query changes.
Font state is read at startup, then updated in memory when toggled. Resizing the
terminal triggers a layout refresh. Ordinary arrow navigation does not clear or
reload the screen.

