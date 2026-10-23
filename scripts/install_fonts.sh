#!/bin/bash

set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="$ROOT/fonts"
TARGET="$HOME/Library/Fonts"
MODE="${1:---dry-run}"

case "$MODE" in
    --dry-run|--install) ;;
    *)
        echo "Usage: $0 [--dry-run|--install]"
        exit 2
        ;;
esac

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "ERROR: macOS required"
    exit 1
fi

if [[ ! -d "$SOURCE" ]]; then
    echo "ERROR: fonts directory missing"
    exit 1
fi

if [[ "$MODE" == "--install" ]]; then
    mkdir -p "$TARGET" || exit 1
fi

HASHES=$(mktemp "${TMPDIR:-/tmp}/font-hashes.XXXXXX") || exit 1
TEMPFILE=""

cleanup() {
    [[ -z "$TEMPFILE" ]] || rm -f -- "$TEMPFILE"
    rm -f -- "$HASHES"
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP

hash_file() {
    local output
    output=$(shasum -a 256 -- "$1") || return 1
    printf '%s\n' "${output%% *}"
}

total=0
installed=0
identical=0
duplicates=0
conflicts=0
errors=0
planned=0

echo "macos_fonts installer"
echo "Source: $SOURCE"
echo "Target: $TARGET"
echo "Mode: $MODE"
echo "--------------------------------"

# Index installed fonts by content.
if [[ -d "$TARGET" ]]; then
    while IFS= read -r -d '' file; do
        digest=$(hash_file "$file") || {
            echo "ERROR reading: $file"
            ((errors++))
            continue
        }
        printf '%s\n' "$digest" >> "$HASHES"
    done < <(
        find "$TARGET" -maxdepth 1 -type f \
            \( -iname '*.ttf' -o \
               -iname '*.otf' -o \
               -iname '*.ttc' \) -print0
    )
fi

# Read source filenames safely, including spaces.
while IFS= read -r -d '' file; do
    ((total++))

    name="${file##*/}"
    dest="$TARGET/$name"

    digest=$(hash_file "$file") || {
        echo "ERROR reading: $name"
        ((errors++))
        continue
    }

    # Existing target with the same filename.
    if [[ -e "$dest" || -L "$dest" ]]; then
        if [[ -f "$dest" && ! -L "$dest" ]]; then
            old_hash=$(hash_file "$dest") || {
                echo "ERROR reading existing: $name"
                ((errors++))
                continue
            }

            if [[ "$digest" == "$old_hash" ]]; then
                ((identical++))
            else
                echo "CONFLICT: $name"
                ((conflicts++))
            fi
        else
            echo "CONFLICT: $name"
            ((conflicts++))
        fi
        continue
    fi

    # Same content under another filename.
    if grep -Fqx -- "$digest" "$HASHES"; then
        echo "DUPLICATE CONTENT: $name"
        ((duplicates++))
        continue
    fi

    if [[ "$MODE" == "--dry-run" ]]; then
        echo "WOULD INSTALL: $name"
        ((planned++))
        printf '%s\n' "$digest" >> "$HASHES"
        continue
    fi

    # Temporary file in the destination filesystem.
    TEMPFILE=$(mktemp "$TARGET/.font-install.XXXXXXXX") || {
        echo "ERROR creating temporary file: $name"
        ((errors++))
        continue
    }

    if ! cp -- "$file" "$TEMPFILE"; then
        echo "ERROR copying: $name"
        ((errors++))
        rm -f -- "$TEMPFILE"
        TEMPFILE=""
        continue
    fi

    copied_hash=$(hash_file "$TEMPFILE")

    if [[ "$digest" != "$copied_hash" ]]; then
        echo "ERROR verifying: $name"
        ((errors++))
        rm -f -- "$TEMPFILE"
        TEMPFILE=""
        continue
    fi

    chmod 644 "$TEMPFILE" || {
        echo "ERROR setting permissions: $name"
        ((errors++))
        rm -f -- "$TEMPFILE"
        TEMPFILE=""
        continue
    }

    # Atomic no-overwrite publication on the same filesystem.
    if ln -- "$TEMPFILE" "$dest" 2>/dev/null; then
        rm -f -- "$TEMPFILE"
        TEMPFILE=""
        printf '%s\n' "$digest" >> "$HASHES"
        ((installed++))
        echo "INSTALLED: $name"
    else
        echo "CONFLICT or ERROR publishing: $name"
        ((conflicts++))
        rm -f -- "$TEMPFILE"
        TEMPFILE=""
    fi

done < <(
    find "$SOURCE" -type f \
        \( -iname '*.ttf' -o \
           -iname '*.otf' -o \
           -iname '*.ttc' \) -print0
)

echo "--------------------------------"
echo "SUMMARY"
echo "Scanned:           $total"
echo "Already installed: $identical"
echo "Duplicate content: $duplicates"
echo "Would install:     $planned"
echo "Installed:         $installed"
echo "Conflicts:         $conflicts"
echo "Errors:            $errors"

if (( conflicts > 0 || errors > 0 )); then
    exit 1
fi
