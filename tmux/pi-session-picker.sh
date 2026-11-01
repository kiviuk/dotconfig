#!/usr/bin/env bash
# Search Pi session logs and resume a selection in a new tmux window.
set -euo pipefail

SESSIONS_DIR="${PI_SESSION_DIR:-$HOME/.pi/agent/sessions}"
SCRIPT_PATH="$(cd -- "$(dirname -- "$0")" && pwd)/$(basename -- "$0")"
printf -v QUOTED_SCRIPT '%q' "$SCRIPT_PATH"

list_sessions() {
  python3 - "$SESSIONS_DIR" "${1:-}" <<'PY'
import json
import os
import re
import subprocess
import sys
from pathlib import Path

root = Path(sys.argv[1]).expanduser()
query = sys.argv[2]
home = str(Path.home())
rows = []
matching_files = None

if query:
    result = subprocess.run(
        [
            "rg", "--files-with-matches", "--fixed-strings", "--ignore-case",
            "--hidden", "--glob", "*.jsonl", "--null", "--", query, str(root),
        ],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    matching_files = {Path(os.fsdecode(path)) for path in result.stdout.split(b"\0") if path}


def clean(value: str) -> str:
    value = re.sub(r"[\x00-\x1f\x7f]", " ", value)
    return re.sub(r"\s+", " ", value).strip()


def last_user_prompt(path: Path) -> str:
    # Read a bounded tail: session logs can be very large, and the most recent
    # user prompt is normally close to EOF.
    try:
        size = path.stat().st_size
        with path.open("rb") as stream:
            stream.seek(max(0, size - 256 * 1024))
            data = stream.read(256 * 1024)
    except OSError:
        return "(prompt unavailable)"

    lines = data.splitlines()
    if size > len(data) and lines:
        lines = lines[1:]  # The first row may be a partial JSON record.

    for raw_line in reversed(lines):
        try:
            record = json.loads(raw_line)
        except (json.JSONDecodeError, UnicodeDecodeError):
            continue
        message = record.get("message", {})
        if record.get("type") != "message" or message.get("role") != "user":
            continue
        content = message.get("content", "")
        if isinstance(content, str):
            prompt = content
        elif isinstance(content, list):
            prompt = " ".join(
                block.get("text", "")
                for block in content
                if isinstance(block, dict) and isinstance(block.get("text"), str)
            )
        else:
            prompt = ""
        prompt = clean(prompt)
        if prompt:
            return prompt[:180] + ("…" if len(prompt) > 180 else "")
    return "(no text prompt found)"


if not root.is_dir():
    sys.exit(0)

for session_file in root.rglob("*.jsonl"):
    if matching_files is not None and session_file not in matching_files:
        continue
    try:
        with session_file.open("r", encoding="utf-8") as stream:
            header = json.loads(stream.readline())
        if header.get("type") != "session":
            continue
        session_id = clean(str(header.get("id") or session_file.stem))
        started = clean(str(header.get("timestamp") or "unknown date"))
        cwd = clean(str(header.get("cwd") or home))
        project = "~" + cwd[len(home):] if cwd == home or cwd.startswith(home + os.sep) else cwd
        prompt = last_user_prompt(session_file)
        # The path and cwd travel with the row for resuming the selected session.
        rows.append((started, project, session_id, prompt, str(session_file), cwd))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError):
        continue

for started, project, session_id, prompt, session_file, cwd in sorted(rows, reverse=True):
    print("\t".join((started, project, session_id, prompt, session_file, cwd)))
PY
}

if [[ "${1:-}" == "--list" ]]; then
  list_sessions "${2:-}"
  exit 0
fi
if [[ "${1:-}" == "--search" ]]; then
  list_sessions "${2:-}"
  exit 0
fi

TARGET_PANE="${1:?target pane id required}"
if [[ "${2:-}" == "--popup" ]]; then
  if ! selected="$(
    list_sessions |
      fzf --height=100% --reverse --no-sort --phony --prompt='Pi sessions> ' \
        --bind="change:reload(sleep 0.15; $QUOTED_SCRIPT --search {q})" \
        --header='Type to search full session logs   Enter: resume   Esc: close' \
        --border=rounded --delimiter=$'\t' --with-nth='1,2,3,4' \
        --preview='printf "Started: %s\\nProject: %s\\nSession ID: %s\\n\\nLast prompt:\\n%s\\n\\nSession file:\\n%s\\nWorking directory:\\n%s\\n" {1} {2} {3} {4} {5} {6}' \
        --preview-window='right:55%:wrap' \
        --color='bg:#07191e fg:#b8c5c8 fg+:#dce3e3 bg+:#183139 hl:#d5a53d hl+:#f1bd58 info:#82979b prompt:#ed8438 pointer:#ed8438 marker:#e4b648 spinner:#82b5b9 header:#e58a3a border:#205660 preview-border:#205660 preview-bg:#07191e label:#e58a3a gutter:#07191e'
  )"; then
    exit 0
  fi

  [[ -n "$selected" ]] || exit 0
  IFS=$'\t' read -r _ session_cwd _ _ session_file _ <<< "$selected"
  [[ -n "$session_file" ]] || exit 0
  [[ -d "$session_cwd" ]] || session_cwd="$HOME"
  PI_BIN="$(command -v pi)"
  printf -v quoted_pi '%q' "$PI_BIN"
  printf -v quoted_session '%q' "$session_file"
  tmux new-window -c "$session_cwd" "$quoted_pi --session $quoted_session"
  exit 0
fi

START_DIR="$(tmux display-message -p -t "$TARGET_PANE" '#{pane_current_path}')"
tmux display-popup -E -w 90% -h 90% -T ' Pi Sessions (fzf) ' \
  -t "$TARGET_PANE" -d "$START_DIR" \
  "$0" "$TARGET_PANE" --popup
