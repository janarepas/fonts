#!/bin/bash
# macos_fonts — non-overwriting macOS and Linux installer.
# Default mode only reports changes. Compatible with macOS Bash 3.2.
set -u

ROOT="$(cd "$(dirname "$0")" && pwd)" || exit 1
SOURCE="$ROOT/fonts"
PLATFORM="$(uname -s)"
case "$PLATFORM" in
  Darwin) TARGET="$HOME/Library/Fonts" ;;
  Linux) TARGET="${XDG_DATA_HOME:-$HOME/.local/share}/fonts" ;;
  *) echo "ERROR: macOS or Linux required" >&2; exit 1 ;;
esac
MODE="--dry-run"
ACTION=install
SELECT_ALL=0
REQUESTED=()
UNIFIED=0
[[ $# -eq 0 ]] && UNIFIED=1
for argument in "$@"; do
  case "$argument" in
    --dry-run) MODE=--dry-run ;;
    --install) MODE=--install; ACTION=install ;;
    --uninstall) MODE=--install; ACTION=uninstall ;;
    --font=*)
      relative="${argument#--font=}"
      case "/$relative/" in *'/../'*|*'/./'*|*'//'*) echo 'Invalid font path' >&2; exit 2 ;; esac
      [[ -f "$SOURCE/$relative" && ! -L "$SOURCE/$relative" ]] || { echo 'Unknown font' >&2; exit 2; }
      REQUESTED[${#REQUESTED[@]}]="$SOURCE/$relative" ;;
    --family=*)
      family_name="${argument#--family=}"
      case "$family_name" in ""|.|..|*/*) echo 'Invalid family' >&2; exit 2 ;; esac
      [[ -d "$SOURCE/$family_name" ]] || { echo 'Unknown family' >&2; exit 2; }
      REQUESTED[${#REQUESTED[@]}]="$SOURCE/$family_name" ;;
    --all) SELECT_ALL=1 ;;
    --select) SELECT_ALL=0 ;;
    --help|-h)
      echo "Usage: $0 [--install|--uninstall] [--dry-run] [--select|--all]"
      echo "Select families by default; --all skips the menu."
      exit 0 ;;
    *) echo "Unknown argument: $argument" >&2; exit 2 ;;
  esac
done
if [[ ! -d "$SOURCE" ]]; then
  echo "ERROR: fonts/ must exist" >&2
  exit 1
fi
variant_menu() {
  local saved_terminal key tail query cursor view parent i j row height start marker label state total enabled title
  local -a files owners original desired visible previous totals selected_counts
  local cache_key dimensions_dirty display_line screen_row new_key
  local columns width dimensions grid_columns cell_width page_size cell column prefix offset
  files=(); owners=(); original=(); desired=(); totals=(); selected_counts=(); previous=()
  for ((i=0; i<${#FAMILIES[@]}; i++)); do
    totals[$i]=0; selected_counts[$i]=0
    while IFS= read -r -d '' font; do
      j=${#files[@]}; files[$j]="$font"; owners[$j]=$i
      state=0
      if [[ -f "$TARGET/${font##*/}" && ! -L "$TARGET/${font##*/}" ]] && cmp -s "$font" "$TARGET/${font##*/}"; then state=1; fi
      original[$j]=$state; desired[$j]=$state
      ((totals[$i]++)); ((selected_counts[$i]+=state))
    done < <(find "${FAMILIES[$i]}" -type f \( -iname '*.ttf' -o -iname '*.otf' -o -iname '*.ttc' \) -print0)
  done
  saved_terminal=$(stty -g) || exit 1
  VARIANT_TERMINAL="$saved_terminal"
  variant_restore() { stty "$VARIANT_TERMINAL"; printf '\033[?25h\033[?1049l'; }
  trap variant_restore EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
  trap 'exit 129' HUP
  stty -echo -icanon min 1 time 0 || exit 1
  printf '\033[?1049h\033[?25l\033[2J'
  ui_put() {
    local position="$1" text="$2"
    if [[ "$text" != *$'\033'* ]]; then text="${text:0:$width}"; fi
    if [[ "${previous[$position]-}" != "$text" ]]; then
      printf '\033[%s;1H\033[2K%s\033[0m' "$position" "$text"
      previous[$position]="$text"
    fi
  }
  dimensions_dirty=1; cache_key=''; pending=0
  trap 'dimensions_dirty=1' WINCH
  local family_cursor=0 family_query=""
  view=families; parent=0; cursor=0; query=""
  while :; do
    new_key="$view:$parent:$query"
    if [[ "$new_key" != "$cache_key" ]]; then
    visible=()
    if [[ "$view" == families ]]; then total=${#FAMILIES[@]}; title='Font families'
    else total=${#files[@]}; title="${FAMILIES[$parent]##*/} — variants"; fi
    for ((i=0; i<total; i++)); do
      if [[ "$view" == families ]]; then label="${FAMILIES[$i]##*/}"
      else
        [[ "${owners[$i]}" != "$parent" ]] && continue
        label="${files[$i]##*/}"
      fi
      if [[ -z "$query" ]] || printf '%s\n' "$label" | grep -Fqi -- "$query"; then visible[${#visible[@]}]=$i; fi
    done
    cache_key="$new_key"
    fi
    ((cursor >= ${#visible[@]})) && cursor=0
    if [[ "$dimensions_dirty" == 1 ]]; then
      dimensions=$(stty size); height=${dimensions%% *}; columns=${dimensions#* }
      [[ "$height" =~ ^[0-9]+$ ]] && ((height>0)) || height=24
      [[ "$columns" =~ ^[0-9]+$ ]] && ((columns>0)) || columns=80
      height=$((height-9)); ((height<1)) && height=1
      # Leave the last terminal column unused to avoid automatic wrapping.
      width=$((columns-1)); ((width<1)) && width=1
      grid_columns=$((width/30)); ((grid_columns<1)) && grid_columns=1
      cell_width=$((width/grid_columns))
      page_size=$((height*grid_columns))
      previous=(); printf '\033[2J'; dimensions_dirty=0
    fi
    start=$((cursor/page_size*page_size))
    ui_put 1 $'\033[1;36m  FONT MANAGER\033[0m  ·  Fedora / macOS'
    printf -v display_line '  %.*s' "$width" "$title"; ui_put 2 "$display_line"
    ui_put 3 '  ────────────────────────────────────────'
    printf -v display_line '  Search: %.*s    Changes: %s' "$((width/2))" "$query" "$pending"
    ui_put 4 "$display_line"
    label=""
    if ((${#visible[@]}>0)); then
      i=${visible[$cursor]}
      if [[ "$view" == families ]]; then label="${FAMILIES[$i]##*/}"
      else label="${files[$i]##*/}"; fi
    fi
    ui_put 5 "  $label"
    for ((screen_row=0; screen_row<height; screen_row++)); do
      display_line=""
      for ((column=0; column<grid_columns; column++)); do
        row=$((start+screen_row*grid_columns+column))
        ((row>=${#visible[@]})) && break
        i=${visible[$row]}; marker=' '
        if [[ "$view" == families ]]; then
          total_in_family=${totals[$i]}; enabled=${selected_counts[$i]}
          if ((total_in_family>0 && enabled==total_in_family)); then marker='✓'
          elif ((enabled>0)); then marker='~'; fi
          label="${FAMILIES[$i]##*/} ($enabled/$total_in_family)"
        else
          [[ "${desired[$i]}" == 1 ]] && marker='✓'
          label="${files[$i]##*/}"
        fi
        # Truncate and pad before adding ANSI styling, which has no cell width.
        cell="[$marker] $label"
        if ((${#cell}>cell_width)); then cell="${cell:0:$((cell_width-1))}…"; fi
        printf -v cell '%-*s' "$cell_width" "$cell"
        if ((row==cursor)); then cell=$'\033[1;30;46m'"$cell"$'\033[0m'; fi
        display_line="$display_line$cell"
      done
      ui_put "$((screen_row+6))" "$display_line"
    done
    if [[ ${#visible[@]} -eq 0 ]]; then ui_put 6 '  No matches.'; fi
    ui_put "$((height+6))" '  hjkl/↑↓ Move  ←→ Page  Space Toggle  Enter Open/Back'
    ui_put "$((height+7))" '  S Save   B Back   / Search   R Reset   Q Quit'
    total=$(((${#visible[@]}+page_size-1)/page_size)); ((total<1)) && total=1
    row=0; ((${#visible[@]}>0)) && row=$((cursor+1))
    printf -v display_line '  %s/%s  Page %s/%s  ✓ Wanted  ~ Partial' "$row" "${#visible[@]}" "$((start/page_size+1))" "$total"
    ui_put "$((height+8))" "$display_line"
    key=""
    # A bounded read allows SIGWINCH to refresh the layout while idle.
    IFS= read -r -s -n 1 -t 1 key
    state=$?
    ((state>128)) && continue
    ((state!=0)) && exit 0
    case "$key" in
      $'\033')
        tail=""; IFS= read -r -s -n 1 -t 1 tail || :
        if [[ "$tail" == '[' || "$tail" == O ]]; then
          tail=""; IFS= read -r -s -n 1 -t 1 tail || :
          case "$tail" in
            A) key=k ;; B) key=j ;; C) key=next ;; D) key=previous ;; *) key=ignored ;;
          esac
        else key=ignored
        fi ;;
    esac
    case "$key" in
      h) ((cursor%grid_columns>0)) && ((cursor--)) ;;
      l) ((cursor%grid_columns+1<grid_columns && cursor+1<${#visible[@]})) && ((cursor++)) ;;
      k) ((cursor>=grid_columns)) && ((cursor-=grid_columns)) ;;
      j)
        if ((cursor+grid_columns<${#visible[@]})); then ((cursor+=grid_columns))
        elif ((cursor/grid_columns<(${#visible[@]}-1)/grid_columns)); then cursor=$((${#visible[@]}-1)); fi ;;
      previous|next)
        # Page movement preserves the cell offset, independent of screen position.
        offset=$((cursor-start))
        if [[ "$key" == previous ]] && ((start>0)); then cursor=$((start-page_size+offset))
        elif [[ "$key" == next ]] && ((start+page_size<${#visible[@]})); then
          cursor=$((start+page_size+offset))
          ((cursor>=${#visible[@]})) && cursor=$((${#visible[@]}-1))
        fi ;;
      ' ')
        [[ ${#visible[@]} -eq 0 ]] && continue
        i=${visible[$cursor]}
        if [[ "$view" == families ]]; then
          state=0
          for ((j=0; j<${#files[@]}; j++)); do
            [[ "${owners[$j]}" == "$i" && "${desired[$j]}" == 0 ]] && state=1
          done
          for ((j=0; j<${#files[@]}; j++)); do [[ "${owners[$j]}" == "$i" ]] && desired[$j]=$state; done
        else desired[$i]=$((1-desired[$i])); fi
        # State aggregates change only on toggles, never while moving the cursor.
        for ((j=0; j<${#FAMILIES[@]}; j++)); do selected_counts[$j]=0; done
        pending=0
        for ((j=0; j<${#files[@]}; j++)); do
          ((selected_counts[${owners[$j]}]+=desired[$j]))
          [[ "${desired[$j]}" != "${original[$j]}" ]] && ((pending++))
        done ;;
      '')
        if [[ "$view" == families ]]; then
          [[ ${#visible[@]} -eq 0 ]] && continue
          family_cursor=$cursor; family_query="$query"
          parent=${visible[$cursor]}; view=variants
          cursor=0; query=""
        else
          view=families; cursor=$family_cursor; query="$family_query"
        fi ;;
      b|B)
        if [[ "$view" == variants ]]; then
          view=families; cursor=$family_cursor; query="$family_query"
        fi ;;
      /)
        printf '\033[%s;1H\033[2K\033[?25hSearch: ' "$((height+8))"; stty "$saved_terminal"
        IFS= read -r query || exit 0
        stty -echo -icanon min 1 time 0; printf '\033[?25l'; previous=(); cursor=0 ;;
      r|R) query=""; cursor=0 ;;
      s|S) break ;;
      q|Q) exit 0 ;;
    esac
  done
  trap - WINCH
  TO_INSTALL=(); TO_REMOVE=()
  for ((i=0; i<${#files[@]}; i++)); do
    if [[ "${desired[$i]}" != "${original[$i]}" ]]; then
      if [[ "${desired[$i]}" == 1 ]]; then TO_INSTALL[${#TO_INSTALL[@]}]="${files[$i]}"
      else TO_REMOVE[${#TO_REMOVE[@]}]="${files[$i]}"; fi
    fi
  done
}

# No external menu utility required; compatible with macOS Bash 3.2.
keyboard_menu() {
  local saved_terminal key tail query cursor i row start height marker count
  local -a matches checked
  saved_terminal=$(stty -g) || exit 1
  menu_restore() {
    stty "$saved_terminal"
    printf '\033[?25h\033[?1049l'
  }
  trap menu_restore EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
  trap 'exit 129' HUP
  stty -echo -icanon min 1 time 0 || exit 1
  printf '\033[?1049h\033[?25l'
  checked=()
  for ((i=0; i<${#FAMILIES[@]}; i++)); do
    checked[$i]=0
    if [[ "$UNIFIED" == 1 ]]; then checked[$i]=${INITIAL[$i]}; fi
  done
  query=""; cursor=0
  while :; do
    matches=()
    count=0
    for ((i=0; i<${#FAMILIES[@]}; i++)); do
      ((count+=checked[$i]))
      if [[ -z "$query" ]] || printf '%s\n' "${FAMILIES[$i]##*/}" | grep -Fqi -- "$query"; then
        matches[${#matches[@]}]=$i
      fi
    done
    (( cursor >= ${#matches[@]} )) && cursor=0
    height=$(stty size); height=${height%% *}
    [[ "$height" =~ ^[0-9]+$ ]] || height=24
    height=$((height-7)); (( height < 1 )) && height=1
    start=$((cursor / height * height))
    printf '\033[H\033[2J'
    printf 'Font manager — Space: toggle desired installation state\n'
    printf 'Up/Down: move | Space: toggle | Enter: apply | q: cancel\n'
    printf '/: search | r: reset search | a: select visible | n: clear visible | q: cancel\n'
    printf 'Search: %s | [✓] keep/install, [ ] absent/remove, [~] partial\n\n' "$query"
    for ((row=start; row<${#matches[@]} && row<start+height; row++)); do
      i=${matches[$row]}; marker=' '
      [[ "${checked[$i]}" == 1 ]] && marker='✓'
      [[ "${checked[$i]}" == -1 ]] && marker='~'
      (( row == cursor )) && printf '\033[7m'
      printf '[%s] %s (%s)' "$marker" "${FAMILIES[$i]##*/}" "${STATUSES[$i]}"
      printf '\033[0m\n'
    done
    [[ ${#matches[@]} -eq 0 ]] && printf 'No matching families. Press / to search again, or r to reset.\n'
    key=""
    IFS= read -r -s -n 1 key || exit 0
    case "$key" in
      $'\033')
        tail=""; IFS= read -r -s -n 1 -t 1 tail || :
        if [[ "$tail" == '[' || "$tail" == O ]]; then
          tail=""; IFS= read -r -s -n 1 -t 1 tail || :
          case "$tail" in
            A) (( cursor > 0 )) && ((cursor--)) ;;
            B) (( cursor+1 < ${#matches[@]} )) && ((cursor++)) ;;
          esac
        fi ;;
      ' ')
        if [[ ${#matches[@]} -gt 0 ]]; then
          i=${matches[$cursor]}; if [[ "${checked[$i]}" == 1 ]]; then checked[$i]=0; else checked[$i]=1; fi
        fi ;;
      '')
        if [[ "$UNIFIED" == 1 ]]; then
          TO_INSTALL=(); TO_REMOVE=()
          for ((i=0; i<${#FAMILIES[@]}; i++)); do
            if [[ "${checked[$i]}" != "${INITIAL[$i]}" ]]; then
              if [[ "${checked[$i]}" == 1 ]]; then
                TO_INSTALL[${#TO_INSTALL[@]}]="${FAMILIES[$i]}"
              elif [[ "${MATCHED[$i]}" -gt 0 ]]; then
                TO_REMOVE[${#TO_REMOVE[@]}]="${FAMILIES[$i]}"
              fi
            fi
          done
          break
        fi
        SELECTED=()
        for ((i=0; i<${#FAMILIES[@]}; i++)); do
          if [[ "${checked[$i]}" == 1 ]]; then SELECTED[${#SELECTED[@]}]="${FAMILIES[$i]}"; fi
        done
        if [[ ${#SELECTED[@]} -gt 0 ]]; then break; fi ;;
      /)
        printf '\033[?25h\nSearch (Enter to apply): '
        stty "$saved_terminal"
        IFS= read -r query || exit 0
        stty -echo -icanon min 1 time 0
        printf '\033[?25l'; cursor=0 ;;

      r|R) query=""; cursor=0 ;;
      a|A|n|N)
        for i in "${matches[@]}"; do
          case "$key" in a|A) checked[$i]=1 ;; *) checked[$i]=0 ;; esac
        done ;;
      q|Q) exit 0 ;;
    esac
  done
  menu_restore
  trap - EXIT INT TERM HUP
}

# Indexed arrays and read loops also work with macOS Bash 3.2.
SELECTED=()
if [[ ${#REQUESTED[@]} -gt 0 ]]; then
  SELECTED=("${REQUESTED[@]}")
elif [[ "$SELECT_ALL" == 1 ]]; then
  SELECTED=("$SOURCE")
else
  FAMILIES=()
  while IFS= read -r family; do
    FAMILIES[${#FAMILIES[@]}]="$family"
  done < <(find "$SOURCE" -mindepth 1 -maxdepth 1 -type d | LC_ALL=C sort)
  if [[ ${#FAMILIES[@]} -eq 0 ]]; then
    echo "ERROR: no font family folders found" >&2
    exit 1
  fi
  # Status describes identical files in this installer's user font directory.
  STATUSES=()
  MATCHED=()
  COUNTS=()
  INITIAL=()
  for family in "${FAMILIES[@]}"; do
    count=0; matched=0; conflicts_found=0
    while IFS= read -r -d '' font; do
      ((count++))
      destination="$TARGET/${font##*/}"
      if [[ -f "$destination" && ! -L "$destination" ]] && cmp -s "$font" "$destination"; then
        ((matched++))
      elif [[ -e "$destination" || -L "$destination" ]]; then
        ((conflicts_found++))
      fi
    done < <(find "$family" -type f \( -iname '*.ttf' -o -iname '*.otf' -o -iname '*.ttc' \) -print0)
    status="not installed"
    if (( count == 0 )); then status="no font files"
    elif (( matched == count )); then status="installed"
    elif (( matched > 0 )); then status="partially installed"
    fi
    initial=0
    if (( count > 0 && matched == count )); then initial=1
    elif (( matched > 0 )); then initial=-1
    fi
    INITIAL[${#INITIAL[@]}]=$initial
    COUNTS[${#COUNTS[@]}]=$count
    MATCHED[${#MATCHED[@]}]=$matched
    STATUSES[${#STATUSES[@]}]="$matched/$count identical, $conflicts_found conflicts"
  done
  if [[ -t 0 && -t 1 && "${TERM:-dumb}" != dumb ]]; then
    if [[ "$UNIFIED" == 1 ]]; then variant_menu; else keyboard_menu; fi
    if [[ "$UNIFIED" == 1 ]]; then
      UI_LOG=$(mktemp "${TMPDIR:-/tmp}/font-manager.XXXXXXXX") || exit 1
      unified_cleanup() {
        rm -f "$UI_LOG"
        variant_restore
      }
      trap unified_cleanup EXIT
      if [[ ${#TO_INSTALL[@]} -eq 0 && ${#TO_REMOVE[@]} -eq 0 ]]; then
        printf '\033[H\033[2J\033[1;36m  FONT MANAGER\033[0m\n\n  No changes requested.\n\n  Any key: close'
        IFS= read -r -s -n 1 ignored || :
        exit 0
      fi
      changes=()
      for family in "${TO_INSTALL[@]}"; do changes[${#changes[@]}]="+ ${family##*/}"; done
      for family in "${TO_REMOVE[@]}"; do changes[${#changes[@]}]="− ${family##*/}"; done
      page=0
      while :; do
        size=$(stty size); rows=${size%% *}; columns=${size#* }
        [[ "$rows" =~ ^[0-9]+$ ]] || rows=24
        [[ "$columns" =~ ^[0-9]+$ ]] || columns=80
        limit=$((rows-8)); ((limit<1)) && limit=1
        printf '\033[H\033[2J\033[1;36m  REVIEW CHANGES\033[0m\n\n'
        printf '  Install: %s    Remove: %s\n\n' "${#TO_INSTALL[@]}" "${#TO_REMOVE[@]}"
        for ((line=page; line<${#changes[@]} && line<page+limit; line++)); do
          printf '  %.*s\n' "$((columns-4))" "${changes[$line]}"
        done
        printf '\033[%s;1H  ↑↓ Scroll  ←→ Page  Y Apply  N Cancel' "$((rows-2))"
        confirmation=""; IFS= read -r -s -n 1 confirmation || exit 0
        case "$confirmation" in
          y|Y) break ;;
          n|N|q|Q) exit 0 ;;
          $'\033')
            tail=""; IFS= read -r -s -n 1 -t 1 tail || :
            if [[ "$tail" == '[' || "$tail" == O ]]; then
              tail=""; IFS= read -r -s -n 1 -t 1 tail || :
              case "$tail" in A) ((page>0)) && ((page--)) ;; B) ((page+limit<${#changes[@]})) && ((page++)) ;;
                C) page=$((page+limit)); ((page>=${#changes[@]})) && page=$(((${#changes[@]}-1)/limit*limit)) ;;
                D) page=$((page-limit)); ((page<0)) && page=0 ;;
              esac
            fi ;;
        esac
      done
      printf '\033[H\033[2J\033[1;36m  APPLYING CHANGES\033[0m\n\n  Please wait…\n'
      result=0
      if [[ ${#TO_INSTALL[@]} -gt 0 ]]; then
        args=(--install)
        for family in "${TO_INSTALL[@]}"; do args[${#args[@]}]="--font=${family#"$SOURCE/"}"; done
        /bin/bash "$ROOT/install_fonts.sh" "${args[@]}" >> "$UI_LOG" 2>&1 || result=1
      fi
      if [[ ${#TO_REMOVE[@]} -gt 0 ]]; then
        args=(--uninstall)
        for family in "${TO_REMOVE[@]}"; do args[${#args[@]}]="--font=${family#"$SOURCE/"}"; done
        /bin/bash "$ROOT/install_fonts.sh" "${args[@]}" <<< Y >> "$UI_LOG" 2>&1 || result=1
      fi
      installed_count=$(awk '/^INSTALLED:/ {n++} END {print n+0}' "$UI_LOG")
      removed_count=$(awk '/^REMOVED:/ {n++} END {print n+0}' "$UI_LOG")
      printf '\033[H\033[2J\033[1;36m  RESULT\033[0m\n\n'
      if [[ "$result" == 0 ]]; then printf '  ✓ Changes completed.\n'
      else printf '  ! Some changes failed.\n'; fi
      printf '\n  Installed: %s    Removed: %s\n' "$installed_count" "$removed_count"
      printf '\n  V: detailed log    Any other key: close'
      key=""; IFS= read -r -s -n 1 key || :
      if [[ "$key" == v || "$key" == V ]]; then
        # A bounded, scrollable log screen avoids dumping output into the terminal.
        page=0
        log_lines=$(wc -l < "$UI_LOG")
        while :; do
          printf '\033[H\033[2J\033[1;36m  DETAILED LOG\033[0m\n\n'
          sed -n "$((page+1)),$((page+limit))p" "$UI_LOG" | cut -c "1-$((columns-2))"
          printf '\033[%s;1H  J/K Scroll    Q Close' "$((rows-2))"
          key=""; IFS= read -r -s -n 1 key || break
          case "$key" in j|J) ((page+limit<log_lines)) && ((page++)) ;; k|K) ((page>0)) && ((page--)) ;; *) break ;; esac
        done
      fi
      exit "$result"
    fi
  else
  query=""
  while :; do
    echo "Choose font families (all styles in each selected family):"
    VISIBLE=()
    for ((i=0; i<${#FAMILIES[@]}; i++)); do
      label="${FAMILIES[$i]##*/}"
      if [[ -z "$query" ]] || printf '%s\n' "$label" | grep -Fqi -- "$query"; then
        printf '%3d) %s [%s]\n' "$((i+1))" "$label" "${STATUSES[$i]}"
        VISIBLE[${#VISIBLE[@]}]="${FAMILIES[$i]}"
      fi
    done
    [[ ${#VISIBLE[@]} -eq 0 ]] && echo "No matching families."
    printf 'Numbers (1,3), /text to search, / to reset, all (entire collection), q to cancel: '
    IFS= read -r answer || { echo; echo "Selection cancelled"; exit 0; }
    case "$answer" in
      q|Q) echo "Selection cancelled"; exit 0 ;;
      all|ALL) SELECTED=("$SOURCE"); break ;;
      /*) query="${answer#/}"; continue ;;
    esac
    answer="${answer//,/ }"
    valid=1
    SELECTED=()
    # Parse without pathname expansion or evaluating user input as shell code.
    while IFS= read -r number; do
      [[ -z "$number" ]] && continue
      case "$number" in
        *[!0-9]*|?????*) valid=0; break ;;
      esac
      index=$((10#$number))
      if (( index < 1 || index > ${#FAMILIES[@]} )); then
        valid=0; break
      fi
      candidate="${FAMILIES[$((index-1))]}"
      visible=0
      for shown in "${VISIBLE[@]}"; do
        [[ "$shown" == "$candidate" ]] && visible=1
      done
      if [[ "$visible" == 0 ]]; then valid=0; break; fi
      found=0
      for chosen in "${SELECTED[@]}"; do
        [[ "$chosen" == "$candidate" ]] && found=1
      done
      if [[ "$found" == 0 ]]; then
        SELECTED[${#SELECTED[@]}]="$candidate"
      fi
    done < <(printf '%s\n' "$answer" | tr ' \t' '\n\n')
    if [[ "$valid" == 1 && ${#SELECTED[@]} -gt 0 ]]; then break; fi
    echo "Invalid selection; enter listed numbers, all, or q."
  done
  fi
  echo "Selected:"
  for chosen in "${SELECTED[@]}"; do
    printf '  %s\n' "${chosen##*/}"
  done
fi

if [[ "$MODE" == "--install" ]]; then
  if [[ "$PLATFORM" == "Linux" ]] && ! command -v fc-cache >/dev/null 2>&1; then
    echo "ERROR: fc-cache required; on Fedora install the fontconfig package" >&2
    exit 1
  fi
  if [[ "$ACTION" == install ]]; then mkdir -p "$TARGET" || exit 1; fi
fi

# Removal is scoped to selected source names and byte-identical user files.
if [[ "$ACTION" == uninstall ]]; then
  REMOVE=()
  scanned=0; skipped=0
  while IFS= read -r -d '' file; do
    ((scanned++))
    dest="$TARGET/${file##*/}"
    if [[ -f "$dest" && ! -L "$dest" ]] && cmp -s "$file" "$dest"; then
      REMOVE[${#REMOVE[@]}]="$file"
      printf 'WOULD REMOVE: %s\n' "$dest"
    else
      ((skipped++))
    fi
  done < <(find "${SELECTED[@]}" -type f \( -iname '*.ttf' -o -iname '*.otf' -o -iname '*.ttc' \) -print0)
  printf 'Scanned: %s | Removable: %s | Missing/different/symlink: %s\n' "$scanned" "${#REMOVE[@]}" "$skipped"
  if [[ "$MODE" == --dry-run || ${#REMOVE[@]} -eq 0 ]]; then exit 0; fi
  printf 'Remove these %s font files? [Y/N]: ' "${#REMOVE[@]}"
  IFS= read -r -n 1 confirmation || exit 0
  echo
  if [[ "$confirmation" != Y && "$confirmation" != y ]]; then echo 'Removal cancelled'; exit 0; fi
  removed=0; errors=0
  for file in "${REMOVE[@]}"; do
    dest="$TARGET/${file##*/}"
    # Recheck immediately before deletion; never remove symlinks or changed files.
    if [[ -f "$dest" && ! -L "$dest" ]] && cmp -s "$file" "$dest" && rm -- "$dest"; then
      ((removed++)); printf 'REMOVED: %s\n' "$dest"
    else
      ((errors++)); printf 'SKIPPED changed file or removal error: %s\n' "$dest" >&2
    fi
  done
  if [[ "$PLATFORM" == Linux && "$removed" -gt 0 ]]; then
    fc-cache -f "$TARGET" || ((errors++))
  fi
  printf 'Removed: %s | Errors: %s\n' "$removed" "$errors"
  (( errors == 0 ))
  exit $?
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
  if [[ "$PLATFORM" == "Linux" ]]; then
    output=$(sha256sum "$1") || return 1
  else
    output=$(shasum -a 256 "$1") || return 1
  fi
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
done < <(find "${SELECTED[@]}" -type f \( -iname '*.ttf' -o -iname '*.otf' -o -iname '*.ttc' \) -print0)

echo "--------------------------------"
if [[ "$PLATFORM" == "Linux" && "$MODE" == "--install" && "$installed" -gt 0 ]]; then
  if ! fc-cache -f "$TARGET"; then
    echo "ERROR refreshing font cache" >&2
    ((errors++))
  fi
fi

echo "SUMMARY"
echo "Scanned:           $total"
echo "Already installed: $identical"
echo "Duplicate content: $duplicates"
echo "Would install:     $planned"
echo "Installed:         $installed"
echo "Conflicts:         $conflicts"
echo "Errors:            $errors"
(( conflicts == 0 && errors == 0 ))
