#!/bin/bash
# macos_fonts — fast, non-overwriting macOS installer.
# Default mode only reports changes. Compatible with macOS Bash 3.2.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)" || exit 1
SOURCE="$ROOT/fonts"
TARGET="$HOME/Library/Fonts"
MODE="${1:---dry-run}"

case "$MODE" in
  --dry-run|--install) ;;
  *) echo "Usage: $0 [--dry-run|--install]" >&2; exit 2 ;;
esac
if [[ "$(uname -s)" != "Darwin" || ! -d "$SOURCE" ]]; then
  echo "ERROR: macOS required and fonts/ must exist" >&2
  exit 1
fi
if [[ "$MODE" == "--install" ]]; then
  mkdir -p "$TARGET" || exit 1
fi

HASHES=""
TEMPFILE=""
cleanup() {
  if [[ -n "$TEMPFILE" ]]; then rm -f "$TEMPFILE"; fi
  if [[ -n "$HASHES" ]]; then rm -f "$HASHES"; fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP

hash_file() {
  local output
  output=$(shasum -a 256 "$1") || return 1
  printf '%s\n' "$output" | cut -d ' ' -f 1
}

# A full installed-font index is created only if there is a new filename.
# Existing names take the fast byte-for-byte comparison path (cmp).
ensure_index() {
  local candidate digest
  if [[ -n "$HASHES" ]]; then return 0; fi
  HASHES=$(mktemp "${TMPDIR:-/tmp}/font-hashes.XXXXXXXX") || return 1
  if [[ -d "$TARGET" ]]; then
    while IFS= read -r -d '' candidate; do
      digest=$(hash_file "$candidate") || {
        echo "ERROR hashing installed font: $candidate" >&2
        ((errors++))
        continue
      }
      printf '%s\n' "$digest" >> "$HASHES"
    done < <(find "$TARGET" -maxdepth 1 -type f \( -iname '*.ttf' -o -iname '*.otf' -o -iname '*.ttc' \) -print0)
  fi
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

while IFS= read -r -d '' file; do
  ((total++))
  name=$(basename "$file")
  dest="$TARGET/$name"

  if [[ -e "$dest" || -L "$dest" ]]; then
    if [[ -f "$dest" && ! -L "$dest" ]]; then
      if cmp -s "$file" "$dest"; then
        ((identical++))
      else
        echo "CONFLICT different existing file: $name"
        ((conflicts++))
      fi
    else
      echo "CONFLICT existing path: $name"
      ((conflicts++))
    fi
    continue
  fi

  if ! ensure_index; then
    echo "ERROR creating duplicate index" >&2
    ((errors++))
    break
  fi

  digest=$(hash_file "$file") || {
    echo "ERROR hashing: $name" >&2
    ((errors++))
    continue
  }

  if grep -Fqx "$digest" "$HASHES"; then
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

  # Stage a complete, verified copy on the destination filesystem.
  TEMPFILE=$(mktemp "$TARGET/.font-install.XXXXXXXX") || {
    echo "ERROR temporary file: $name" >&2
    ((errors++))
    continue
  }

  if ! cp "$file" "$TEMPFILE"; then
    echo "ERROR copying: $name" >&2
    ((errors++))
    rm -f "$TEMPFILE"; TEMPFILE=""
    continue
  fi
  copied_hash=$(hash_file "$TEMPFILE")
  if [[ "$copied_hash" != "$digest" ]]; then
    echo "ERROR verifying copied data: $name" >&2
    ((errors++))
    rm -f "$TEMPFILE"; TEMPFILE=""
    continue
  fi
  if ! chmod 644 "$TEMPFILE"; then
    echo "ERROR setting permissions: $name" >&2
    ((errors++))
    rm -f "$TEMPFILE"; TEMPFILE=""
    continue
  fi

  # Hard-link creates the destination atomically and fails if it already exists.
  if ln "$TEMPFILE" "$dest" 2>/dev/null; then
    rm -f "$TEMPFILE"; TEMPFILE=""
    printf '%s\n' "$digest" >> "$HASHES"
    ((installed++))
    echo "INSTALLED: $name"
  else
    echo "CONFLICT or ERROR publishing: $name"
    ((conflicts++))
    rm -f "$TEMPFILE"; TEMPFILE=""
  fi
done < <(find "$SOURCE" -type f \( -iname '*.ttf' -o -iname '*.otf' -o -iname '*.ttc' \) -print0)

echo "--------------------------------"
echo "SUMMARY"
echo "Scanned:           $total"
echo "Already installed: $identical"
echo "Duplicate content: $duplicates"
echo "Would install:     $planned"
echo "Installed:         $installed"
echo "Conflicts:         $conflicts"
echo "Errors:            $errors"
(( conflicts == 0 && errors == 0 ))
