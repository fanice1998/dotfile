#!/usr/bin/env bash
set -euo pipefail

THEME_DIR="${ALACRITTY_THEME_DIR:-$HOME/.config/alacritty/themes}"
CURRENT="$HOME/.config/alacritty/current.toml"
CONFIG="$HOME/.config/alacritty/alacritty.toml"

apply() {
  local file="$1"
  # 1) 持久化：新視窗也吃得到
  cp "$file" "$CURRENT"
  # 2) 立刻套到現有視窗（含全部）
  if command -v alacritty >/dev/null && [[ -n "${ALACRITTY_SOCKET:-}" || -S "${XDG_RUNTIME_DIR:-/run/user/$UID}/Alacritty-msg.sock" || true ]]; then
    alacritty msg config -w -1 "$(cat "$file")" 2>/dev/null || true
  fi
}

list_themes() {
  find "$THEME_DIR" -maxdepth 1 -name '*.toml' -printf '%f\n' | sed 's/\.toml$//' | sort
}

case "${1:-pick}" in
list) list_themes ;;
set)
  name="${2:?theme name}"
  file="$THEME_DIR/${name}.toml"
  [[ -f "$file" ]] || {
    echo "not found: $name" >&2
    exit 1
  }
  apply "$file"
  echo "theme → $name"
  ;;
pick | "")
  choice="$(list_themes | fzf --prompt='alacritty theme > ' \
    --preview "sed -n '1,80p' '$THEME_DIR/{}.toml'" \
    --bind "ctrl-p:execute-silent(alacritty msg config -w -1 \"\$(cat '$THEME_DIR/{}.toml')\")")"
  [[ -n "$choice" ]] || exit 0
  apply "$THEME_DIR/${choice}.toml"
  echo "theme → $choice"
  ;;
*)
  echo "usage: alacritty-theme [pick|list|set <name>]" >&2
  exit 2
  ;;
esac
