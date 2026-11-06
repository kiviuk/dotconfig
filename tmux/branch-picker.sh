#!/usr/bin/env bash
# Pick a local branch to check out or open a Git worktree in tmux.

set -euo pipefail

TARGET_PANE="${1:?target pane id required}"
TMUX_BIN=/opt/homebrew/bin/tmux
FZF_BIN=/opt/homebrew/bin/fzf
SCRIPT="$HOME/.config/tmux/branch-picker.sh"

worktree_rows() {
  local line path="" branch=""

  while IFS= read -r line; do
    case "$line" in
      "worktree "*)
        path="${line#worktree }"
        branch="(detached)"
        ;;
      "branch refs/heads/"*)
        branch="${line#branch refs/heads/}"
        ;;
      bare)
        path=""
        branch=""
        ;;
      "")
        if [[ -n "$path" ]]; then
          printf 'Worktree\t%s\t%s\n' "$branch" "$path"
        fi
        path=""
        branch=""
        ;;
    esac
  done < <(git worktree list --porcelain)

  if [[ -n "$path" ]]; then
    printf 'Worktree\t%s\t%s\n' "$branch" "$path"
  fi
}

open_worktree() {
  local worktree_path="$1"
  local target_window window_name

  [[ -d "$worktree_path" ]] || return 1
  target_window=$("$TMUX_BIN" display-message -p -t "$TARGET_PANE" '#{window_id}')
  window_name=$(basename "$worktree_path")
  "$TMUX_BIN" new-window -a -t "$target_window" -c "$worktree_path" -n "$window_name"
}

create_or_open_worktree() {
  local branch="$1"
  local existing_path="" row_type row_branch row_path
  local git_common_dir repo_root repo_name worktree_root candidate suffix

  while IFS=$'\t' read -r row_type row_branch row_path; do
    if [[ "$row_type" == "Worktree" && "$row_branch" == "$branch" ]]; then
      existing_path="$row_path"
      break
    fi
  done < <(worktree_rows)

  if [[ -n "$existing_path" ]]; then
    open_worktree "$existing_path"
    return
  fi

  git_common_dir=$(git rev-parse --path-format=absolute --git-common-dir)
  repo_root=$(dirname "$git_common_dir")
  repo_name=$(basename "$repo_root")
  worktree_root="$(dirname "$repo_root")/${repo_name}-worktrees"
  candidate="$worktree_root/$branch"
  suffix=2
  while [[ -e "$candidate" ]]; do
    candidate="$worktree_root/${branch}-${suffix}"
    suffix=$((suffix + 1))
  done

  mkdir -p "$(dirname "$candidate")"
  if ! git worktree add "$candidate" "$branch"; then
    "$TMUX_BIN" display-message -t "$TARGET_PANE" "Failed to create worktree for $branch"
    return 1
  fi
  open_worktree "$candidate"
}

if [[ "${2:-}" == "--popup" ]]; then
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

  selected=$(
    {
      git branch --format='%(refname:short)' |
        while IFS= read -r branch; do
          printf 'Branch\t%s\n' "$branch"
        done
      worktree_rows
    } |
      "$FZF_BIN" \
        --height=100% \
        --reverse \
        --delimiter=$'\t' \
        --prompt='Branch/Worktree> ' \
        --expect=alt-enter \
        --info=inline-right \
        --highlight-line \
        --pointer='▌' \
        --border=sharp \
        --border-label='Branches + Worktrees' \
        --border-label-pos=0 \
        --header='Enter: checkout/open  |  Option+Enter: create/open worktree' \
        --preview='case {1} in Branch) git log --color=always --oneline --decorate -8 {2};; Worktree) git -C {3} log --color=always --oneline --decorate -8 HEAD;; esac' \
        --preview-window=right,50%,wrap,border-sharp \
        --preview-label='Preview' \
        --preview-label-pos=0 \
        --color='bg:#07191e,fg:#b8c5c8,fg+:#dce3e3,bg+:#183139,hl:#d5a53d,hl+:#f1bd58,info:#82979b,prompt:#ed8438,pointer:#ed8438,marker:#e4b648,spinner:#82b5b9,header:#e58a3a,border:#205660,preview-border:#205660,preview-bg:#07191e,label:#e58a3a,gutter:#07191e'
  ) || exit 0

  [[ -n "$selected" ]] || exit 0
  selection_key=enter
  if [[ "$selected" == alt-enter$'\n'* ]]; then
    selection_key=alt-enter
    selected="${selected#*$'\n'}"
  elif [[ "$selected" == $'\n'* ]]; then
    selected="${selected#*$'\n'}"
  fi
  IFS=$'\t' read -r kind name worktree_path <<< "$selected"

  case "$kind" in
    Branch)
      if [[ "$selection_key" == "alt-enter" ]]; then
        create_or_open_worktree "$name"
      else
        git checkout "$name"
      fi
      ;;
    Worktree)
      open_worktree "$worktree_path"
      ;;
  esac
  exit 0
fi

START_DIR=$("$TMUX_BIN" display-message -p -t "$TARGET_PANE" '#{pane_current_path}')
"$TMUX_BIN" display-popup -E -B -w 60% -h 70% -t "$TARGET_PANE" -d "$START_DIR" \
  -s "bg=#07191e,fg=#b8c5c8" \
  "$SCRIPT" "$TARGET_PANE" --popup
