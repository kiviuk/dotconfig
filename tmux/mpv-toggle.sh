#!/usr/bin/env bash
# Toggle playback in the mpv instance controlled by ~/.zalias's `p` alias.

set -euo pipefail

SOCKET="/tmp/mpv-socket"

if [[ ! -S "$SOCKET" ]]; then
  tmux display-message "mpv is not running (socket missing: $SOCKET)"
  exit 0
fi

printf '%s\n' '{"command":["cycle","pause"]}' | socat -u - "$SOCKET"
