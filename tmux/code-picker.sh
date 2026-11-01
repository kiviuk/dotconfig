#!/usr/bin/env bash
# Fuzzy-search source lines in the target pane's current directory.
# Preview the selected line with surrounding source and paste path:line into the pane.

set -euo pipefail

TARGET_PANE="${1:?target pane id required}"

if [[ "${2:-}" == "--popup" ]]; then
  if ! selection="$(
    # Use fzf exit status if it exits before rg finishes.
    set +o pipefail
    rg --line-number --no-heading --color=never --smart-case -- '' |
      fzf --height=100% --reverse --prompt='Code> ' --border=rounded --delimiter ':' \
        --color='
          bg:#07191e fg:#b8c5c8 fg+:#dce3e3
          bg+:#183139 hl:#d5a53d hl+:#f1bd58
          info:#82979b prompt:#ed8438 pointer:#ed8438
          marker:#e4b648 spinner:#82b5b9 header:#e58a3a
          border:#205660 preview-border:#205660 preview-bg:#07191e
          label:#e58a3a gutter:#07191e
        ' \
        --preview 'bat --style=numbers --color=always --highlight-line {2} {1} 2>/dev/null || sed -n "{2}p" {1}' \
        --preview-window 'up:60%:+{2}/2'
  )"; then
    exit 0 # fzf was cancelled
  fi

  if [[ "$selection" =~ ^(.*):([0-9]+): ]]; then
    file="${BASH_REMATCH[1]}"
    line="${BASH_REMATCH[2]}"
  else
    exit 0
  fi

  tmux send-keys -l -t "$TARGET_PANE" "$file:$line"
  exit 0
fi

START_DIR="$(tmux display-message -p -t "$TARGET_PANE" '#{pane_current_path}')"
tmux display-popup -E -w 90% -h 90% -T ' Code (fzf) ' \
  -t "$TARGET_PANE" -d "$START_DIR" \
  "$0" "$TARGET_PANE" --popup
