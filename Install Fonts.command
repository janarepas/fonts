#!/bin/bash
# Finder shortcut only; all menus and operations live in install_fonts.sh.
ROOT="$(cd "$(dirname "$0")" && pwd)" || exit 1
if [[ "$(uname -s)" != Darwin ]]; then
  echo "On Linux run install_fonts.sh."
  exit 1
fi
/bin/bash "$ROOT/install_fonts.sh" "$@"
result=$?
if [[ -t 0 ]]; then
  printf 'Press Enter to close... '
  IFS= read -r ignored || :
fi
exit "$result"
