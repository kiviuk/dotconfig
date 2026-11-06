#!/usr/bin/env bash
# ~/.config/tmux/dict-word.sh
# Fuzzy word search from system dictionary via fzf in a tmux popup.
# On selection, sends the word to the target pane via `tmux send-keys`.
#
# Usage (from tmux keybinding):
#   bind-key -T prefix g run-shell "~/.config/tmux/dict-word.sh '#{pane_id}'"
#
# Mnemonic: g = "get word" / "grep dictionary" / "grab word"

set -euo pipefail

TARGET_PANE="${1:?target pane id required}"
DICT_FILE="/usr/share/dict/words"

# Verify dictionary exists
[[ -r "$DICT_FILE" ]] || {
  tmux display-message "Dictionary not found: $DICT_FILE"
  exit 1
}

# Run fzf inside a tmux popup; on selection, pipe word to send-keys for target pane
tmux popup -E -B -w 60% -h 70% -t "$TARGET_PANE" \
  -s "bg=#07191e,fg=#b8c5c8" \
  "fzf --height=100% --reverse --prompt='Word> ' --info=inline-right \
       --highlight-line --pointer='▌' --border=sharp \
       --border-label='Dictionary' --border-label-pos=0 \
       --color='bg:#07191e,fg:#b8c5c8,fg+:#dce3e3,bg+:#183139,hl:#d5a53d,hl+:#f1bd58,info:#82979b,prompt:#ed8438,pointer:#ed8438,marker:#e4b648,spinner:#82b5b9,header:#e58a3a,border:#205660,preview-border:#205660,preview-bg:#07191e,label:#e58a3a,gutter:#07191e' \
       --preview='echo {}' --preview-window=right,50%,wrap,border-sharp \
       --preview-label='Preview' --preview-label-pos=0 \
       < '$DICT_FILE' | xargs -r tmux send-keys -t '$TARGET_PANE'"