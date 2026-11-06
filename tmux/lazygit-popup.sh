#!/usr/bin/env bash
# Open LazyGit in a tmux popup rooted at the target pane's working directory.

set -euo pipefail

TARGET_PANE="${1:?target pane id required}"
TMUX_BIN=/opt/homebrew/bin/tmux
LAZYGIT_BIN=/opt/homebrew/bin/lazygit
START_DIR=$("$TMUX_BIN" display-message -p -t "$TARGET_PANE" '#{pane_current_path}')

if ! git -C "$START_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  "$TMUX_BIN" display-message -t "$TARGET_PANE" 'LazyGit: current pane is outside a Git worktree'
  exit 0
fi

"$TMUX_BIN" display-popup -E -B -w 100% -h 80% -t "$TARGET_PANE" -d "$START_DIR" \
  -s "bg=#07191e,fg=#b8c5c8" \
  "$LAZYGIT_BIN"
