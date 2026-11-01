#!/usr/bin/env bash
# Adjust mpv volume by the requested delta, in percent points.

set -euo pipefail

VOLUME_DELTA="${1:?volume delta required}"
SOCKET="/tmp/mpv-socket"

if [[ ! "$VOLUME_DELTA" =~ ^-?[0-9]+$ ]]; then
  tmux display-message "Invalid mpv volume delta: $VOLUME_DELTA"
  exit 1
fi

if [[ ! -S "$SOCKET" ]]; then
  tmux display-message "mpv is not running (socket missing: $SOCKET)"
  exit 0
fi

printf '{"command":["add","volume",%s]}\n' "$VOLUME_DELTA" | socat -u - "$SOCKET"
