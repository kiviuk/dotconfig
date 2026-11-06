#!/usr/bin/env bash
set -euo pipefail

TMUX_BIN=/opt/homebrew/bin/tmux
client=${LAZYGIT_TMUX_CLIENT:-}
pane=${LAZYGIT_TMUX_PANE:-${TMUX_PANE:-}}
if [[ -z "$client" ]]; then
  client=$("$TMUX_BIN" display-message -p '#{client_name}' 2>/dev/null || true)
fi
if [[ -z "$pane" && -n "$client" ]]; then
  pane=$("$TMUX_BIN" display-message -p -c "$client" '#{pane_id}' 2>/dev/null || true)
fi

status() {
  printf '%s\n' "$1"
}

if [[ -z "$client" ]]; then
  printf '%s\n' "LazyGit popup client is unavailable."
  exit 0
fi
if [[ ! "$pane" =~ ^%[0-9]+$ ]]; then
  status "LazyGit popup target pane is unavailable."
  exit 0
fi

repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || {
  status "review_local needs a Git repository."
  exit 0
}

git_dir=$(git -C "$repo_root" rev-parse --absolute-git-dir)
pending_file="$git_dir/LAZYGIT_PENDING_COMMIT"
message_file=$(mktemp "${TMPDIR:-/tmp}/lazygit-review.XXXXXX")
error_file=$(mktemp "${TMPDIR:-/tmp}/lazygit-review-error.XXXXXX")
trap 'unlink "$message_file" "$error_file" 2>/dev/null || true' EXIT

status "Running review_local..."
(cd "$repo_root" && zsh -c 'source "$HOME/.zalias" >/dev/null 2>&1 || true; review_local') >"$message_file" 2>"$error_file" || true

if [[ ! -s "$message_file" ]]; then
  detail=$(head -n 1 "$error_file" | tr '\n' ' ' | cut -c1-100)
  status "review_local returned no message: ${detail:-no error text}"
  exit 0
fi

IFS= read -r summary < "$message_file" || true
if [[ -z "$summary" ]]; then
  status "review_local returned no commit subject."
  exit 0
fi

awk 'NR == 1 { printf "%s", $0; next } NR == 2 && $0 == "" { next } { printf "\n%s", $0 } END { printf "\n" }' \
  "$message_file" > "$pending_file"

status "Opening LazyGit commit form..."
inject="sleep 4; /opt/homebrew/bin/tmux send-keys -c '$client' -K 2; sleep 0.2; /opt/homebrew/bin/tmux send-keys -c '$client' -K c; sleep 0.4; /opt/homebrew/bin/tmux send-keys -c '$client' -K Tab"
"$TMUX_BIN" run-shell -b -t "$pane" "$inject"
