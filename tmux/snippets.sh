#!/usr/bin/env bash
set -euo pipefail

FILE="${TMUX_SNIPPETS_FILE:-$HOME/.config/tmux/snippets.txt}"
TMUX_BIN=/opt/homebrew/bin/tmux
FZF_BIN=/opt/homebrew/bin/fzf

if [[ "${TMUX_SNIPPETS_POPUP:-0}" == 1 ]]; then
  : "${TMUX_SNIPPETS_OUTPUT:?TMUX_SNIPPETS_OUTPUT is required}"
  "$FZF_BIN" \
    --reverse \
    --prompt="🛸 " \
    --info=inline-right \
    --highlight-line \
    --pointer="▌" \
    --border=sharp \
    --border-label="Snippets" \
    --border-label-pos=0 \
    --preview='printf "%s\n" {}' \
    --preview-window=right,50%,wrap,border-sharp \
    --preview-label="Preview" \
    --preview-label-pos=0 \
    --color='bg:#011423,fg:#CBE0F0,fg+:#EAF6FF,bg+:#15334B,hl:#0FC5ED,hl+:#24EAF7,info:#7FAAC2,prompt:#0FC5ED,pointer:#24EAF7,marker:#A277FF,spinner:#7FAAC2,header:#A277FF,border:#214969,preview-border:#214969,preview-bg:#011423,label:#0FC5ED,gutter:#011423' \
    < "$FILE" > "$TMUX_SNIPPETS_OUTPUT"
  exit 0
fi

pane="$1"   # tmux pane_id passed from the keybind
SCRIPT="$HOME/.config/tmux/snippets.sh"
output=$(mktemp "${TMPDIR:-/tmp}/tmux-snippet.XXXXXX")
trap 'rm -f "$output"' EXIT

if ! "$TMUX_BIN" display-popup -E -B -w 60% -h 70% -t "$pane" \
  -s "bg=#011423,fg=#CBE0F0" \
  -e "TMUX_SNIPPETS_POPUP=1" \
  -e "TMUX_SNIPPETS_FILE=$FILE" \
  -e "TMUX_SNIPPETS_OUTPUT=$output" \
  "$SCRIPT"; then
  exit 0
fi

[[ -s "$output" ]] || exit 0
sel=$(<"$output")

# Paste into the originating pane. load-buffer/paste-buffer inserts the
# literal text (like a bracketed paste) instead of re-parsing it as
# keystrokes, so quotes/backticks/semicolons in a snippet are safe and
# nothing gets auto-submitted — you review before hitting Enter yourself.
printf '%b' "$sel" | "$TMUX_BIN" load-buffer -
"$TMUX_BIN" paste-buffer -t "$pane"

# Optional: also mirror it to the macOS system clipboard.
printf '%b' "$sel" | /usr/bin/pbcopy
