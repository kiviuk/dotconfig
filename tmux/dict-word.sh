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
  -s "bg=#011423,fg=#CBE0F0" \
  "fzf --height=100% --reverse --prompt='Word> ' --info=inline-right \
       --highlight-line --pointer='▌' --border=sharp \
       --border-label='Dictionary' --border-label-pos=0 \
       --color='bg:#011423,fg:#CBE0F0,fg+:#EAF6FF,bg+:#15334B,hl:#0FC5ED,hl+:#24EAF7,info:#7FAAC2,prompt:#0FC5ED,pointer:#24EAF7,marker:#A277FF,spinner:#7FAAC2,header:#A277FF,border:#214969,preview-border:#214969,preview-bg:#011423,label:#0FC5ED,gutter:#011423' \
       --preview='echo {}' --preview-window=right,50%,wrap,border-sharp \
       --preview-label='Preview' --preview-label-pos=0 \
       < '$DICT_FILE' | xargs -r tmux send-keys -t '$TARGET_PANE'"