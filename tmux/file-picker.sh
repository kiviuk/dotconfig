#!/usr/bin/env bash
# Fuzzy-select a file from the target pane's current directory and insert it
# at the current command-line cursor.

set -euo pipefail

TARGET_PANE="${1:?target pane id required}"

if [[ "${2:-}" == "--popup" ]]; then
  # Sort newest-first by modification time; NUL delimiters preserve unusual paths.
  if ! IFS= read -r -d '' selected < <(
    fd --type f --hidden --no-ignore --exclude .git --print0 . |
      python3 -c '
import os, sys
entries = []
for path in sys.stdin.buffer.read().split(b"\0"):
    if path:
        parent_parts = path.split(b"/")[:-1]
        if any(
            part == b"__pycache__"
            or (part.startswith(b".") and part not in (b".", b".."))
            for part in parent_parts
        ):
            continue
        try:
            entries.append((os.stat(path).st_mtime_ns, path))
        except OSError:
            pass
entries.sort(key=lambda entry: entry[0], reverse=True)
sys.stdout.buffer.write(b"".join(path + b"\0" for _, path in entries))
' |
      fzf --read0 --print0 --no-sort --height=100% --reverse --prompt='File> ' --info=inline-right \
        --highlight-line --pointer='▌' --border=sharp \
        --border-label='Files' --border-label-pos=0 \
        --color='bg:#07191e,fg:#b8c5c8,fg+:#dce3e3,bg+:#183139,hl:#d5a53d,hl+:#f1bd58,info:#82979b,prompt:#ed8438,pointer:#ed8438,marker:#e4b648,spinner:#82b5b9,header:#e58a3a,border:#205660,preview-border:#205660,preview-bg:#07191e,label:#e58a3a,gutter:#07191e' \
        --preview 'bat --color=always --theme=OneHalfDark --style=numbers --line-range=:500 -- {}' \
        --preview-window=right,50%,wrap,border-sharp \
        --preview-label='Preview' --preview-label-pos=0
  ); then
    exit 0 # fzf was cancelled (or no file was selected)
  fi

  # Insert valid shell syntax, so spaces and special characters remain one path.
  printf -v quoted_path '%q' "$selected"
  tmux send-keys -l -t "$TARGET_PANE" "$quoted_path"
  exit 0
fi

START_DIR="$(tmux display-message -p -t "$TARGET_PANE" '#{pane_current_path}')"
tmux display-popup -E -B -w 80% -h 80% -t "$TARGET_PANE" -d "$START_DIR" \
  -s "bg=#07191e,fg=#b8c5c8" \
  "$0" "$TARGET_PANE" --popup
