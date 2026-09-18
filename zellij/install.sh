#!/usr/bin/env sh
# Install zjstatus.wasm for this Zellij config.
# Works on Linux, macOS, WSL, and Git Bash.
#
# Usage:
#   ./install.sh              # latest release
#   ./install.sh v0.25.0      # pin a tag
#   ./install.sh --help

set -eu

REPO="dj95/zjstatus"
ASSET="zjstatus.wasm"
TAG="${1:-latest}"

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  cat <<'EOF'
Install zjstatus.wasm into this Zellij config.

Usage:
  ./install.sh              download the latest GitHub release
  ./install.sh v0.25.0      download a specific tag

The wasm is written to:
  <this-repo>/plugins/zjstatus.wasm
  $HOME/.config/zellij/plugins/zjstatus.wasm   (if that path is different)
  the [CONFIG DIR] from `zellij setup --check` (if zellij is on PATH)

config.kdl expects:
  file:~/.config/zellij/plugins/zjstatus.wasm

After install, start a new session. The first time, focus the bar and press y
to grant plugin permissions.
EOF
  exit 0
fi

script_dir() {
  # POSIX-friendly absolute directory of this script (no readlink -f).
  CDPATH= cd -- "$(dirname -- "$0")" && pwd
}

have() {
  command -v "$1" >/dev/null 2>&1
}

download() {
  url=$1
  dest=$2
  if have curl; then
    curl -fsSL --retry 3 --retry-delay 1 -o "$dest" "$url"
  elif have wget; then
    wget -q -O "$dest" "$url"
  else
    echo "error: need curl or wget" >&2
    exit 1
  fi
}

copy_if_different() {
  src=$1
  dest_dir=$2
  dest="$dest_dir/$ASSET"
  case "$dest_dir" in
    "$src_dir") return 0 ;;
  esac
  mkdir -p "$dest_dir"
  if [ -f "$dest" ] && cmp -s "$src" "$dest" 2>/dev/null; then
    return 0
  fi
  cp "$src" "$dest"
  echo "copied -> $dest"
}

if [ "$TAG" = "latest" ]; then
  url="https://github.com/${REPO}/releases/latest/download/${ASSET}"
else
  url="https://github.com/${REPO}/releases/download/${TAG}/${ASSET}"
fi

src_dir="$(script_dir)/plugins"
mkdir -p "$src_dir"
tmp="$src_dir/${ASSET}.tmp"

echo "OS: $(uname -s 2>/dev/null || echo unknown) $(uname -m 2>/dev/null || echo unknown)"
echo "downloading $url"
download "$url" "$tmp"

size=$(wc -c < "$tmp" | tr -d ' ')
if [ "$size" -lt 10000 ]; then
  echo "error: download looks too small ($size bytes); GitHub may have returned an error page" >&2
  rm -f "$tmp"
  exit 1
fi

mv "$tmp" "$src_dir/$ASSET"
echo "installed $src_dir/$ASSET ($size bytes)"

home_plugins="${HOME}/.config/zellij/plugins"
copy_if_different "$src_dir/$ASSET" "$home_plugins"

if have zellij; then
  config_dir=$(zellij setup --check 2>/dev/null | sed -n 's/^\[CONFIG DIR\]: "\(.*\)"/\1/p' | head -n 1)
  if [ -n "$config_dir" ]; then
    copy_if_different "$src_dir/$ASSET" "$config_dir/plugins"
    echo "zellij config dir: $config_dir"
  fi
fi

echo
echo "done. start a new zellij session to load zjstatus."
echo "first run: click the bottom bar and press y to grant permissions."
