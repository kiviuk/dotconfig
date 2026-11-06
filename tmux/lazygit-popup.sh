#!/usr/bin/env bash
# Open LazyGit in a tmux popup rooted at the target pane's working directory.

set -euo pipefail

TARGET_PANE="${1:?target pane id required}"
TARGET_CLIENT="${2:?target client name required}"
TMUX_BIN=/opt/homebrew/bin/tmux
LAZYGIT_BIN=/opt/homebrew/bin/lazygit
START_DIR=$("$TMUX_BIN" display-message -p -t "$TARGET_PANE" '#{pane_current_path}')

if ! git -C "$START_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  "$TMUX_BIN" display-message -t "$TARGET_PANE" 'LazyGit: current pane is outside a Git worktree'
  exit 0
fi

"$TMUX_BIN" display-popup -E -B -w 80% -h 80% -t "$TARGET_PANE" -c "$TARGET_CLIENT" \
  -e "LAZYGIT_TMUX_CLIENT=$TARGET_CLIENT" -e "LAZYGIT_TMUX_PANE=$TARGET_PANE" \
  -d "$START_DIR" \
  -s "bg=#011423,fg=#CBE0F0" \
  "$LAZYGIT_BIN"
