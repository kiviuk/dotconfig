#!/usr/bin/env bash
# Open an ephemeral interactive shell in a tmux popup at the target pane's cwd.

set -euo pipefail

TARGET_PANE="${1:?target pane id required}"
TMUX_BIN=/opt/homebrew/bin/tmux
START_DIR=$("$TMUX_BIN" display-message -p -t "$TARGET_PANE" '#{pane_current_path}')
SHELL_BIN=$("$TMUX_BIN" show-option -gqv default-shell)
SHELL_BIN=${SHELL_BIN:-/bin/zsh}

"$TMUX_BIN" display-popup -E -B -w 75% -h 50% -t "$TARGET_PANE" -d "$START_DIR" \
  -s "bg=#011423,fg=#CBE0F0" \
  "$SHELL_BIN" -l
