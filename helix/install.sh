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

set -euo pipefail

HELIX_REPO="${HELIX_REPO:-https://github.com/mattwparas/helix.git}"
HELIX_BRANCH="${HELIX_BRANCH:-steel-event-system}"
HELIX_SRC="${HELIX_SRC:-$HOME/src/helix}"
HELIX_CONFIG="${HELIX_CONFIG:-$HOME/.config/helix}"
# Persist compile artifacts so interrupted builds can resume.
export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-$HOME/.cache/cargo-helix-steel}"

script_dir() {
  cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd
}

REPO_DIR="$(script_dir)"
PLUGIN_SCRIPT="$REPO_DIR/install-plugins.sh"

have() {
  command -v "$1" >/dev/null 2>&1
}

log() {
  printf '==> %s\n' "$*"
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
  ./install.sh --skip-build        略過編譯，只處理設定檔與插件

環境變數:
  HELIX_SRC      原始碼目錄（預設 ~/src/helix）
  HELIX_CONFIG   設定檔目錄（預設 ~/.config/helix）
  HELIX_REPO     git remote
  HELIX_BRANCH   git branch（預設 steel-event-system）

編譯完成後，~/.cargo/bin/hx 會覆蓋系統套件的 hx（PATH 前面）。
Fedora 套件仍在 /usr/bin/hx，可直接呼叫。
EOF
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
}

need_cmd() {
  local cmd="$1"
  local hint="$2"
  have "$cmd" || die "找不到 $cmd。$hint"
}

ensure_build_deps() {
  need_cmd git "請先安裝 git"
  need_cmd gcc "請先安裝 gcc / gcc-c++"
  need_cmd g++ "請先安裝 gcc-c++"
  if ! have cmake; then
    log "找不到 cmake（部分 native 插件例如 steel-pty 可能需要）"
    if have sudo && sudo -n true 2>/dev/null; then
      sudo dnf install -y cmake || true
    else
      log "若之後編譯插件失敗，請執行: sudo dnf install -y cmake"
    fi
  fi
}

clone_helix() {
  mkdir -p "$(dirname -- "$HELIX_SRC")"
  if [ -d "$HELIX_SRC/.git" ]; then
    log "更新 Helix 原始碼 $HELIX_SRC"
    git -C "$HELIX_SRC" fetch --depth 1 origin "$HELIX_BRANCH"
    git -C "$HELIX_SRC" checkout "$HELIX_BRANCH"
    git -C "$HELIX_SRC" reset --hard "origin/$HELIX_BRANCH"
  else
    log "clone $HELIX_REPO ($HELIX_BRANCH) -> $HELIX_SRC"
    git clone --branch "$HELIX_BRANCH" --single-branch --depth 1 \
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
  mkdir -p "$HOME/.config"
  if [ -L "$HELIX_CONFIG" ]; then
    local dest
    dest="$(readlink -f "$HELIX_CONFIG" 2>/dev/null || readlink "$HELIX_CONFIG")"
    if [ "$dest" != "$REPO_DIR" ]; then
      log "注意: $HELIX_CONFIG 目前指向 $dest（預期 $REPO_DIR）"
    else
      log "設定檔: $HELIX_CONFIG -> $REPO_DIR"
    fi
  elif [ -d "$HELIX_CONFIG" ]; then
    local cfg_real repo_real
    cfg_real="$(cd "$HELIX_CONFIG" && pwd)"
    repo_real="$REPO_DIR"
    if [ "$cfg_real" = "$repo_real" ]; then
      log "設定檔目錄就是這個 repo: $HELIX_CONFIG"
    else
      local bak="$HELIX_CONFIG.bak.$(date +%Y%m%d%H%M%S)"
      log "既有 $HELIX_CONFIG，備份為 $bak 後改成 symlink"
      mv "$HELIX_CONFIG" "$bak"
      ln -sfn "$REPO_DIR" "$HELIX_CONFIG"
    fi
  elif [ -e "$HELIX_CONFIG" ]; then
    die "$HELIX_CONFIG 已存在且不是目錄"
  else
    ln -sfn "$REPO_DIR" "$HELIX_CONFIG"
    log "建立 symlink $HELIX_CONFIG -> $REPO_DIR"
  fi
}

ensure_runtime() {
  local runtime_src="$HELIX_SRC/runtime"
  local runtime_link="$REPO_DIR/runtime"
  [ -d "$runtime_src" ] || die "找不到 $runtime_src，請先編譯 Helix"
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
  if [ -s "$dest" ]; then
    log "保留既有 init.scm"
    return 0
  fi
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
}

print_done() {
  cat <<EOF

完成。

  hx:            $(command -v hx 2>/dev/null || echo "$HOME/.cargo/bin/hx")
  版本:          $("$HOME/.cargo/bin/hx" --version 2>/dev/null || echo unknown)
  forge:         $(command -v forge 2>/dev/null || echo missing)
  設定檔:        $HELIX_CONFIG
  原始碼:        $HELIX_SRC
  HELIX_RUNTIME: ${HELIX_RUNTIME:-$HELIX_SRC/runtime}

請開一個新的 shell（或執行: source ~/.cargo/env）讓 ~/.cargo/bin 的 hx 生效。
插件指令見: $PLUGIN_SCRIPT --help
EOF
}

run_plugins() {
  [ -x "$PLUGIN_SCRIPT" ] || chmod +x "$PLUGIN_SCRIPT"
  "$PLUGIN_SCRIPT" "$@"
}

main() {
  local mode="full"
  local plugin_args=()
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
        plugin_args+=("$@")
        break
        ;;
      --recommended | --all | --yes)
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
    ensure_cargo_env
    have forge || die "找不到 forge。請先執行 ./install.sh helix"
    ensure_config_dir
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

main "$@"
