#!/usr/bin/env bash
# Install Helix with Steel plugins (mattwparas/helix, branch steel-event-system).
# Config directory: ~/.config/helix
#
# Usage:
#   ./install.sh                  full install, then plugin menu
#   ./install.sh --recommended    full install + beginner plugins
#   ./install.sh helix            Helix + Steel only
#   ./install.sh plugins          plugin menu (Helix already installed)
#   ./install.sh plugins --recommended
#   ./install.sh --help
#
# Bash 3.2 (macOS /bin/bash) is enough. Plugin flags are forwarded to
# install-plugins.sh.

set -euo pipefail

HELIX_REPO="${HELIX_REPO:-https://github.com/mattwparas/helix.git}"
HELIX_BRANCH="${HELIX_BRANCH:-steel-event-system}"
HELIX_SRC="${HELIX_SRC:-$HOME/src/helix}"
HELIX_CONFIG="${HELIX_CONFIG:-$HOME/.config/helix}"
# Persist compile artifacts so interrupted builds can resume.
export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-$HOME/.cache/cargo-helix-steel}"

script_dir() {
  cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd
}

REPO_DIR="$(script_dir)"
PLUGIN_SCRIPT="$REPO_DIR/install-plugins.sh"

have() {
  command -v "$1" >/dev/null 2>&1
}

log() {
  printf '==> %s\n' "$*"
}

warn() {
  printf '警告: %s\n' "$*" >&2
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
安裝 Helix Steel（帶插件系統的 fork）並把設定放在 ~/.config/helix。

用法:
  ./install.sh                     編譯 Helix Steel，接著開啟插件選單
  ./install.sh --recommended       編譯 Helix Steel，並安裝新手建議插件
  ./install.sh helix               只安裝 Helix Steel（略過插件）
  ./install.sh plugins             只跑插件多選（需已安裝 forge）
  ./install.sh plugins --recommended
  ./install.sh plugins --list
  ./install.sh --skip-build        略過編譯，只處理設定檔與插件

環境變數:
  HELIX_SRC          原始碼目錄（預設 ~/src/helix）
  HELIX_CONFIG       設定檔目錄（預設 ~/.config/helix）
  HELIX_REPO         git remote
  HELIX_BRANCH       git branch（預設 steel-event-system）
  HELIX_FORCE_RESET  設為 1 才允許捨棄 HELIX_SRC 上尚未推送的 commit

編譯完成後，~/.cargo/bin/hx 需要排在 PATH 前面（腳本會寫進 shell 設定）。
若系統另有一份 hx（Homebrew、/usr/bin/hx），開新的 shell 後才會用到 Steel 版。
插件參數見: ./install-plugins.sh --help
EOF
}

abs_path() {
  local target="$1"
  if readlink -f "$target" >/dev/null 2>&1; then
    readlink -f "$target"
    return 0
  fi
  if have python3; then
    python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$target"
    return 0
  fi
  (
    cd -P -- "$(dirname -- "$target")"
    printf '%s/%s\n' "$(pwd)" "$(basename -- "$target")"
  )
}

ensure_cargo_env() {
  if [ -f "$HOME/.cargo/env" ]; then
    # shellcheck disable=SC1091
    . "$HOME/.cargo/env"
  fi
  case ":${PATH}:" in
    *:"$HOME/.cargo/bin":*) ;;
    *) export PATH="$HOME/.cargo/bin:$PATH" ;;
  esac
}

ensure_rust() {
  ensure_cargo_env
  if have rustc && have cargo; then
    log "Rust: $(rustc --version)"
    return 0
  fi
  have curl || die "需要 curl 才能安裝 rustup"
  log "安裝 rustup（Rust 工具鏈）"
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  # shellcheck disable=SC1091
  . "$HOME/.cargo/env"
  have rustc || die "rustup 安裝後仍找不到 rustc"
}

ensure_shell_path() {
  local marker='# helix-steel / rustup'
  local line='[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"'
  local runtime_line="export HELIX_RUNTIME=\"\${HELIX_RUNTIME:-$HELIX_SRC/runtime}\""

  append_once() {
    local file="$1"
    local text="$2"
    [ -f "$file" ] || return 0
    grep -qF "$text" "$file" 2>/dev/null && return 0
    printf '\n%s\n%s\n' "$marker" "$text" >>"$file"
    log "已寫入 $file"
  }

  if [ -f "$HOME/.zshrc" ]; then
    append_once "$HOME/.zshrc" "$line"
    append_once "$HOME/.zshrc" "$runtime_line"
  fi
  if [ -f "$HOME/.bashrc" ]; then
    append_once "$HOME/.bashrc" "$line"
    append_once "$HOME/.bashrc" "$runtime_line"
  fi

  local fish_cfg="$HOME/.config/fish/config.fish"
  if [ -f "$fish_cfg" ] && ! grep -qF '.cargo/bin' "$fish_cfg"; then
    cat >>"$fish_cfg" <<'FISH'

# helix-steel / rustup
if test -d $HOME/.cargo/bin
    fish_add_path $HOME/.cargo/bin
end
FISH
    log "已寫入 $fish_cfg"
  fi
  if [ -f "$fish_cfg" ] && ! grep -qF 'HELIX_RUNTIME' "$fish_cfg"; then
    cat >>"$fish_cfg" <<EOF

# helix-steel runtime
if not set -q HELIX_RUNTIME
    set -gx HELIX_RUNTIME "$HELIX_SRC/runtime"
end
EOF
    log "已寫入 $fish_cfg (HELIX_RUNTIME)"
  fi
}

need_cmd() {
  local cmd="$1"
  local hint="$2"
  have "$cmd" || die "找不到 ${cmd}。${hint}"
}

ensure_build_deps() {
  need_cmd git "請先安裝 git"
  if ! have gcc && ! have clang && ! have cc; then
    die "找不到 C 編譯器。macOS: xcode-select --install；Fedora: sudo dnf install gcc gcc-c++；Debian: sudo apt-get install build-essential"
  fi
  if ! have g++ && ! have clang++ && ! have c++; then
    die "找不到 C++ 編譯器（g++ 或 clang++）"
  fi
  if ! have cmake; then
    log "找不到 cmake（steel-pty 等 native 插件可能需要）"
    case "$(uname -s 2>/dev/null || echo unknown)" in
      Darwin)
        log "可執行: brew install cmake"
        ;;
      Linux)
        if have dnf; then
          log "可執行: sudo dnf install -y cmake"
        elif have apt-get; then
          log "可執行: sudo apt-get install -y cmake build-essential"
        fi
        ;;
    esac
  fi
}

clone_helix() {
  mkdir -p "$(dirname -- "$HELIX_SRC")"
  if [ -d "$HELIX_SRC/.git" ]; then
    if ! git -C "$HELIX_SRC" diff --quiet || ! git -C "$HELIX_SRC" diff --cached --quiet; then
      die "$HELIX_SRC 有未提交的修改，已停止更新（避免 git reset 清掉變更）"
    fi
    log "更新 Helix 原始碼 $HELIX_SRC"
    # Do not pass --depth here. A depth-1 fetch drops the parent of the new
    # tip, so a shallow repo that is merely behind looks like it has local commits.
    GIT_TERMINAL_PROMPT=0 git -C "$HELIX_SRC" fetch origin "$HELIX_BRANCH" \
      || die "無法 fetch origin/$HELIX_BRANCH"
    local tip="HEAD"
    if git -C "$HELIX_SRC" show-ref --verify --quiet "refs/heads/$HELIX_BRANCH"; then
      tip="$HELIX_BRANCH"
    fi
    if [ "${HELIX_FORCE_RESET:-0}" = "1" ] || git -C "$HELIX_SRC" merge-base --is-ancestor "$tip" "origin/$HELIX_BRANCH"; then
      git -C "$HELIX_SRC" checkout -B "$HELIX_BRANCH" "origin/$HELIX_BRANCH"
    else
      die "分支 $HELIX_BRANCH 有尚未推送的 commit，或和 origin 歷史已分叉。要捨棄並對齊 origin，請設定 HELIX_FORCE_RESET=1"
    fi
    log "已對齊 origin/$HELIX_BRANCH"
  elif [ -e "$HELIX_SRC" ]; then
    if [ -d "$HELIX_SRC" ] && [ -z "$(ls -A "$HELIX_SRC")" ]; then
      rmdir "$HELIX_SRC"
    else
      die "$HELIX_SRC 已存在且不是 git 專案"
    fi
    log "clone $HELIX_REPO ($HELIX_BRANCH) -> $HELIX_SRC"
    GIT_TERMINAL_PROMPT=0 git clone --branch "$HELIX_BRANCH" --single-branch --depth 1 \
      "$HELIX_REPO" "$HELIX_SRC"
  else
    log "clone $HELIX_REPO ($HELIX_BRANCH) -> $HELIX_SRC"
    GIT_TERMINAL_PROMPT=0 git clone --branch "$HELIX_BRANCH" --single-branch --depth 1 \
      "$HELIX_REPO" "$HELIX_SRC"
  fi
}

build_helix_steel() {
  ensure_cargo_env
  mkdir -p "$CARGO_TARGET_DIR"
  log "編譯 Helix Steel（steel + forge + hx，時間可能較長）"
  log "CARGO_TARGET_DIR=$CARGO_TARGET_DIR"
  (
    cd "$HELIX_SRC"
    cargo xtask steel
  )
  ensure_cargo_env
  have forge || die "cargo xtask steel 結束後仍找不到 forge，請確認 ~/.cargo/bin 在 PATH"
  [ -x "$HOME/.cargo/bin/hx" ] || die "找不到 ~/.cargo/bin/hx"
  log "hx: $("$HOME/.cargo/bin/hx" --version 2>/dev/null || true)"
  log "forge: $(command -v forge)"
}

ensure_config_dir() {
  mkdir -p "$(dirname -- "$HELIX_CONFIG")"
  local repo_real dest
  repo_real="$(abs_path "$REPO_DIR")"
  if [ -L "$HELIX_CONFIG" ]; then
    dest="$(abs_path "$HELIX_CONFIG")"
    if [ "$dest" != "$repo_real" ]; then
      warn "$HELIX_CONFIG 目前指向 ${dest}（預期 ${repo_real}）"
    else
      log "設定檔: $HELIX_CONFIG -> $repo_real"
    fi
    return 0
  fi
  if [ -d "$HELIX_CONFIG" ]; then
    dest="$(abs_path "$HELIX_CONFIG")"
    if [ "$dest" = "$repo_real" ]; then
      log "設定檔目錄就是這個 repo: $HELIX_CONFIG"
      return 0
    fi
    local bak="$HELIX_CONFIG.bak.$(date +%Y%m%d%H%M%S)"
    log "既有 ${HELIX_CONFIG}，備份為 ${bak} 後改成 symlink"
    mv "$HELIX_CONFIG" "$bak"
    ln -sfn "$repo_real" "$HELIX_CONFIG"
    return 0
  fi
  if [ -e "$HELIX_CONFIG" ]; then
    die "$HELIX_CONFIG 已存在且不是目錄"
  fi
  ln -sfn "$repo_real" "$HELIX_CONFIG"
  log "建立 symlink $HELIX_CONFIG -> $repo_real"
}

ensure_runtime() {
  local runtime_src="$HELIX_SRC/runtime"
  local runtime_link="$REPO_DIR/runtime"
  [ -d "$runtime_src" ] || die "找不到 ${runtime_src}，請先編譯 Helix"
  if [ -e "$runtime_link" ] && [ ! -L "$runtime_link" ]; then
    die "$runtime_link 已存在且不是 symlink"
  fi
  ln -sfn "$runtime_src" "$runtime_link"
  log "runtime: $runtime_link -> $runtime_src"
  export HELIX_RUNTIME="$runtime_src"
}

ensure_helix_scm() {
  local dest="$REPO_DIR/helix.scm"
  if [ -s "$dest" ] && grep -q 'open-helix-scm' "$dest"; then
    log "保留既有 helix.scm"
    return 0
  fi
  if [ -s "$dest" ]; then
    cp "$dest" "$dest.bak.$(date +%Y%m%d%H%M%S)"
  fi
  cat >"$dest" <<'SCM'
(require "helix/editor.scm")
(require (prefix-in helix. "helix/commands.scm"))
(require (prefix-in helix.static. "helix/static.scm"))

(provide shell git-add open-helix-scm open-init-scm)

(define (current-path)
  (let* ([focus (editor-focus)]
         [focus-doc-id (editor->doc-id focus)])
    (editor-document->path focus-doc-id)))

;;@doc
;; Run a shell command. Use % as the current file path.
(define (shell . args)
  (helix.run-shell-command
   (string-join
    (map (lambda (x)
           (if (equal? x "%")
               (current-path)
               x))
         args)
    " ")))

;;@doc
;; git add the current file
(define (git-add)
  (shell "git" "add" "%"))

;;@doc
;; Open helix.scm
(define (open-helix-scm)
  (helix.open (helix.static.get-helix-scm-path)))

;;@doc
;; Open init.scm
(define (open-init-scm)
  (helix.open (helix.static.get-init-scm-path)))
SCM
  log "寫入 $dest"
}

ensure_init_scm_base() {
  local dest="$REPO_DIR/init.scm"
  if [ ! -s "$dest" ]; then
    cat >"$dest" <<'SCM'
(require "helix/configuration.scm")
(require (prefix-in helix. "helix/commands.scm"))

(define-lsp "steel-language-server" (command "steel-language-server") (args '()))
(define-language "scheme"
                 (language-servers '("steel-language-server")))

;; >>> helix-steel-plugins
;; <<< helix-steel-plugins
SCM
    log "寫入 $dest"
    return 0
  fi
  if ! grep -qxF ';; >>> helix-steel-plugins' "$dest"; then
    printf '\n;; >>> helix-steel-plugins\n;; <<< helix-steel-plugins\n' >>"$dest"
    log "已在 $dest 加上插件區塊"
  else
    log "保留既有 init.scm"
  fi
}

print_done() {
  local cargo_hx="$HOME/.cargo/bin/hx"
  local path_hx
  path_hx="$(command -v hx 2>/dev/null || true)"
  cat <<EOF

完成。

  hx:            ${path_hx:-$cargo_hx}
  版本:          $("$cargo_hx" --version 2>/dev/null || echo unknown)
  forge:         $(command -v forge 2>/dev/null || echo missing)
  設定檔:        $HELIX_CONFIG
  原始碼:        $HELIX_SRC
  HELIX_RUNTIME: ${HELIX_RUNTIME:-$HELIX_SRC/runtime}

請開一個新的 shell（或執行: source ~/.cargo/env）讓 ~/.cargo/bin 的 hx 生效。
插件指令見: $PLUGIN_SCRIPT --help
EOF
  if [ -n "$path_hx" ] && [ "$path_hx" != "$cargo_hx" ] && [ -x "$cargo_hx" ]; then
    warn "PATH 上的 hx 是 ${path_hx}，Steel 版在 ${cargo_hx}。新 shell 載入 cargo env 後才會切過去。"
  fi
}

run_plugins() {
  [ -x "$PLUGIN_SCRIPT" ] || chmod +x "$PLUGIN_SCRIPT"
  "$PLUGIN_SCRIPT" "$@"
}

plugins_need_forge() {
  local arg
  local dry=0
  local installs=0
  if [ "$#" -eq 0 ]; then
    return 0
  fi
  for arg in "$@"; do
    case "$arg" in
      --dry-run) dry=1 ;;
      -h | --help | --list) ;;
      *) installs=1 ;;
    esac
  done
  if [ "$dry" -eq 1 ] || [ "$installs" -eq 0 ]; then
    return 1
  fi
  return 0
}

main() {
  local mode="full"
  local -a plugin_args=()
  local skip_build=0

  while [ $# -gt 0 ]; do
    case "$1" in
      -h | --help)
        usage
        exit 0
        ;;
      helix)
        mode="helix"
        shift
        ;;
      plugins)
        mode="plugins"
        shift
        if [ "$#" -gt 0 ]; then
          plugin_args+=("$@")
        fi
        break
        ;;
      --recommended | --all | --yes | --replace | --force | --dry-run)
        plugin_args+=("$1")
        shift
        ;;
      --list)
        mode="plugins"
        plugin_args+=("$1")
        shift
        ;;
      --skip-build)
        skip_build=1
        shift
        ;;
      --helix-only)
        mode="helix"
        shift
        ;;
      --plugins-only)
        mode="plugins"
        shift
        ;;
      *)
        die "未知參數: $1（見 --help）"
        ;;
    esac
  done

  if [ "$mode" = "plugins" ]; then
    if plugins_need_forge "${plugin_args[@]+"${plugin_args[@]}"}"; then
      ensure_cargo_env
      have forge || die "找不到 forge。請先執行 ./install.sh helix"
      ensure_config_dir
    fi
    run_plugins "${plugin_args[@]+"${plugin_args[@]}"}"
    return 0
  fi

  log "OS: $(uname -s 2>/dev/null || echo unknown) $(uname -m 2>/dev/null || echo unknown)"
  ensure_rust
  ensure_shell_path
  ensure_build_deps
  if [ "$skip_build" -eq 0 ]; then
    clone_helix
    build_helix_steel
  else
    log "略過編譯（--skip-build）"
    ensure_cargo_env
    have forge || die "--skip-build 但找不到 forge"
    [ -d "$HELIX_SRC/runtime" ] || die "--skip-build 但找不到 $HELIX_SRC/runtime"
  fi
  ensure_config_dir
  ensure_runtime
  ensure_helix_scm
  ensure_init_scm_base

  if [ "$mode" = "helix" ]; then
    print_done
    return 0
  fi

  run_plugins "${plugin_args[@]+"${plugin_args[@]}"}"
  print_done
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
fi
