#!/usr/bin/env bash
# Seek forward by the requested number of seconds in the running mpv instance.

set -euo pipefail

SEEK_SECONDS="${1:?seek seconds required}"
SOCKET="/tmp/mpv-socket"

if [[ ! "$SEEK_SECONDS" =~ ^[1-9][0-9]*$ ]]; then
  tmux display-message "Invalid mpv seek value: $SEEK_SECONDS"
  exit 1
fi

if [[ ! -S "$SOCKET" ]]; then
  tmux display-message "mpv is not running (socket missing: $SOCKET)"
  exit 0
fi

printf '{"command":["seek",%s]}\n' "$SEEK_SECONDS" | socat -u - "$SOCKET"
