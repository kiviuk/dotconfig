#!/usr/bin/env bash
# Toggle Bluetooth between off and the configured Q45 connection.

set -euo pipefail

POWERED="$(blueutil -p)"

if [[ "$POWERED" == "1" ]]; then
  blueutil -p 0
  tmux display-message "Bluetooth off"
else
  blueutil -p 1
  sleep 1
  BluetoothConnector E8-EE-CC-BB-3C-99 --notify
fi
