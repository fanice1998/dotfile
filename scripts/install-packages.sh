#!/usr/bin/env bash
# 在 macOS、Fedora、Android Termux 上安裝日常套件，項目可勾選。
#
# 用法:
#   ./install-packages.sh                 列出套件，一次輸入多個編號來勾選
#   ./install-packages.sh --list          列出項目與這個平台的安裝方式
#   ./install-packages.sh --default       只裝預設項目
#   ./install-packages.sh --all           安裝這個平台有的全部項目
#   ./install-packages.sh fzf eza fish    只裝指定 id
#   ./install-packages.sh --dry-run --default
#   ./install-packages.sh --force go      已安裝的也重裝
#
# Bash 3.2（macOS /bin/bash）可用。
# 新增項目時改下面的 CATALOG。欄位用 | 分隔:
#   id|群組|預設(1/0)|檢查的指令|mac|fedora|termux|說明
# 預設不含 alacritty、fish、python、go、rust、node、make、cmake。
# 平台欄位:
#   套件名稱（可多個，空白分隔）
#   cask:名稱     只給 macOS，走 brew install --cask
#   -             這個平台用腳本裡的專用安裝（rustup、nvm、官方二進位…）
#   none          這個平台不裝

set -euo pipefail

NODE_MAJOR="${NODE_MAJOR:-24}"
NVM_VERSION="${NVM_VERSION:-v0.40.8}"

DRY_RUN=0
FORCE=0
TOUCHED_RC=0

script_dir() {
  cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd
}

SCRIPT_DIR="$(script_dir)"

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

is_termux() {
  if [ -n "${TERMUX_VERSION:-}" ]; then
    return 0
  fi
  if [ -n "${PREFIX:-}" ] && [ -x "${PREFIX}/bin/pkg" ]; then
    return 0
  fi
  have termux-info && return 0
  return 1
}

is_fedora() {
  if [ -f /etc/fedora-release ]; then
    return 0
  fi
  if [ -f /etc/os-release ] && grep -q '^ID=fedora$' /etc/os-release; then
    return 0
  fi
  return 1
}

# termux | macos | fedora
# Termux 的 uname 是 Linux，要先判斷。
os_kind() {
  if [ -n "${OS_KIND:-}" ]; then
    case "$OS_KIND" in
      macos | fedora | termux)
        printf '%s\n' "$OS_KIND"
        return 0
        ;;
      *)
        die "OS_KIND 只能是 macos、fedora、termux"
        ;;
    esac
  fi
  if is_termux; then
    OS_KIND=termux
  else
    case "$(uname -s 2>/dev/null || echo unknown)" in
      Darwin) OS_KIND=macos ;;
      Linux)
        if is_fedora; then
          OS_KIND=fedora
        else
          die "只支援 macOS、Fedora、Android Termux"
        fi
        ;;
      *)
        die "只支援 macOS、Fedora、Android Termux（目前是 $(uname -s 2>/dev/null || echo unknown)）"
        ;;
    esac
  fi
  printf '%s\n' "$OS_KIND"
}

CATALOG="$(
  cat <<'EOF'
git|base|1|git|git|git|git|版本控制
curl|base|1|curl|curl|curl|curl|下載檔案
wget|base|1|wget|wget|wget|wget|另一個下載工具
unzip|base|1|unzip|unzip|unzip|unzip|解 zip
rsync|base|0|rsync|rsync|rsync|rsync|同步檔案
zsh|shell|1|zsh|zsh|zsh|zsh|目前使用的 shell
fish|shell|0|fish|fish|fish|fish|另一個 shell（repo 裡有設定）
fzf|shell|1|fzf|fzf|fzf|fzf|模糊搜尋（主題選單、fzf-tab）
starship|shell|1|starship|starship|-|starship|跨 shell 提示字元
eza|files|1|eza|eza|eza|eza|取代 ls（fish 的 ls alias）
trash|files|1|trash|trash-cli|trash-cli|-|可復原的刪除（fish 的 rm alias）
ripgrep|files|1|rg|ripgrep|ripgrep|ripgrep|快速搜尋檔案內容
fd|files|1|fd|fd|fd-find|fd|快速找檔案
bat|files|1|bat|bat|bat|bat|帶語法高亮的 cat
jq|files|1|jq|jq|jq|jq|處理 JSON
neovim|edit|1|nvim|neovim|neovim|neovim|編輯器（EDITOR=nvim）
zellij|edit|1|zellij|zellij|-|zellij|終端機工作區
fastfetch|edit|1|fastfetch|fastfetch|fastfetch|fastfetch|系統資訊
lazygit|edit|1|lazygit|lazygit|lazygit|lazygit|git 的終端介面
alacritty|edit|0|alacritty|cask:alacritty|alacritty|none|終端機（repo 裡有設定）
python|lang|0|python3|python|python3 python3-pip|python python-pip|Python 3 與 pip
go|lang|0|go|go|-|golang|Go（Fedora 走 scripts/install_go.sh）
rust|lang|0|rustc|-|-|rust|Rust（macOS / Fedora 用 rustup）
node|lang|0|node|node|-|nodejs|Node.js（Fedora 用 nvm）
make|build|0|make|-|make|make|編譯用 make
cmake|build|0|cmake|cmake|cmake|cmake|編譯用 cmake
compiler|build|0|cc|-|gcc gcc-c++|clang|C/C++ 編譯器
pkg-config|build|0|pkg-config|pkg-config|pkgconf-pkg-config|pkg-config|編譯時找函式庫
EOF
)"

IDS=()
CATS=()
RECS=()
CMDS=()
MACS=()
FEDORAS=()
TERMUXS=()
DESCS=()
SELECTED=()

load_catalog() {
  local id group rec cmd mac fed tx desc
  # read 在最後一行沒有換行時會回傳失敗，但仍有讀到內容。清掉 id，避免 EOF 時重複最後一筆。
  while IFS='|' read -r id group rec cmd mac fed tx desc || [ -n "${id:-}" ]; do
    [ -n "${id:-}" ] || continue
    case "$id" in
      \#*) id="" ; continue ;;
    esac
    IDS+=("$id")
    CATS+=("$group")
    RECS+=("$rec")
    CMDS+=("$cmd")
    MACS+=("$mac")
    FEDORAS+=("$fed")
    TERMUXS+=("$tx")
    DESCS+=("$desc")
    SELECTED+=(0)
    id=""
  done <<EOF
$CATALOG
EOF
}

group_name() {
  case "$1" in
    base) printf '基礎\n' ;;
    shell) printf 'Shell\n' ;;
    files) printf '檔案與搜尋\n' ;;
    edit) printf '編輯器與終端\n' ;;
    lang) printf '語言\n' ;;
    build) printf '編譯\n' ;;
    *) printf '%s\n' "$1" ;;
  esac
}

spec_at() {
  local i="$1"
  case "$OS" in
    macos) printf '%s\n' "${MACS[$i]}" ;;
    fedora) printf '%s\n' "${FEDORAS[$i]}" ;;
    termux) printf '%s\n' "${TERMUXS[$i]}" ;;
  esac
}

is_available() {
  local spec
  spec="$(spec_at "$1")"
  [ -n "$spec" ] && [ "$spec" != "none" ]
}

is_installed() {
  local i="$1"
  case "${IDS[$i]}" in
    python)
      have python3 && { have pip || have pip3; }
      ;;
    rust)
      have rustc && have cargo
      ;;
    compiler)
      have gcc || have clang || have cc
      ;;
    pkg-config)
      have pkg-config || have pkgconf
      ;;
    *)
      have "${CMDS[$i]}"
      ;;
  esac
}

special_label() {
  local id="$1"
  case "$OS:$id" in
    fedora:starship) printf '%s\n' "官方安裝腳本 → ~/.local/bin" ;;
    fedora:zellij) printf '%s\n' "GitHub 最新版 → ~/.local/bin" ;;
    fedora:go) printf '%s\n' "scripts/install_go.sh" ;;
    macos:rust | fedora:rust) printf '%s\n' "rustup" ;;
    fedora:node) printf '%s\n' "nvm install ${NODE_MAJOR}" ;;
    macos:compiler | macos:make) printf '%s\n' "xcode-select --install" ;;
    termux:trash) printf '%s\n' "pip install trash-cli" ;;
    *) printf '%s\n' "專用安裝" ;;
  esac
}

method_label() {
  local i="$1" spec
  spec="$(spec_at "$i")"
  case "$spec" in
    none) printf '%s\n' "（沒有）" ;;
    -) special_label "${IDS[$i]}" ;;
    cask:*) printf '%s\n' "brew --cask ${spec#cask:}" ;;
    *) printf '%s\n' "$spec" ;;
  esac
}

usage() {
  cat <<EOF
在 macOS、Fedora、Android Termux 安裝日常套件。每次只裝你選的項目。

用法:
  ./install-packages.sh                 自己選要裝哪些
  ./install-packages.sh --list          列出 id、狀態、這個平台的裝法
  ./install-packages.sh --default       只裝預設項目裡還沒裝的
  ./install-packages.sh --all           安裝這個平台支援、且還沒裝的全部項目
  ./install-packages.sh fzf eza fish    只裝這些 id
  ./install-packages.sh --dry-run fish  只印出會執行的指令
  ./install-packages.sh --force go      已安裝的也重做

不帶參數時直接列出套件，不需要 fzf。
一次輸入多個編號就會一起勾起，例如 7 20 22 或 7,20,22。
再打一次同一個編號會取消。確認後輸入 d 才開始安裝。

預設（--default，或清單裡輸入 a）不含:
  alacritty、fish、python、go、rust、node、make、cmake
  另外也不含 rsync、compiler、pkg-config。這些在清單裡照樣可以勾。

清單:
  7 20 22     同時勾這三個
  fish go     也可以打 id
  a           改勾預設項目
  A           勾這個平台有的全部項目
  n           清空
  d           開始安裝
  q           取消
  已安裝又被勾到時會略過。要重裝請加上 --force。
  機器上已經有 fzf 時，可以輸入 f 改用方向鍵多選。沒有 fzf 不必用這個。

平台:
  macOS    Homebrew（Alacritty 用 cask）。沒有 brew 會停下並附上安裝網址。
  Fedora   sudo dnf install。starship / zellij / Go / Rust / Node 用下面的方式。
  Termux   pkg install。trash 改走 pip。

跟套件庫不同步、所以另外處理的項目:
  starship   Fedora：官方腳本裝到 ~/.local/bin
  zellij     Fedora：GitHub 最新版（發行版套件較舊）裝到 ~/.local/bin
  go         Fedora：scripts/install_go.sh（官方 tarball）。Mac brew、Termux golang
  rust       macOS / Fedora：rustup。Termux：pkg install rust
  node       Fedora：nvm 安裝 Node ${NODE_MAJOR}。Mac brew、Termux nodejs
  compiler   macOS：Xcode Command Line Tools。Fedora gcc、Termux clang

Helix Steel 不是發行版套件，請用 ../helix/install.sh。
Zellij 狀態列插件請用 ../zellij/install.sh。

環境變數:
  OS_KIND      覆寫平台偵測（macos、fedora、termux），用來預覽別的平台
  NODE_MAJOR   Fedora 上 nvm 要裝的 Node 主版本（預設 ${NODE_MAJOR}）
  NVM_VERSION  nvm 版本（預設 ${NVM_VERSION}）
EOF
}

list_catalog() {
  local i rec state
  printf '平台: %s (%s)\n\n' "$OS" "$(uname -m 2>/dev/null || echo unknown)"
  printf '%-12s %-6s %-8s %s\n' "ID" "預設" "狀態" "這個平台"
  printf '%-12s %-6s %-8s %s\n' "------------" "------" "--------" "----------"
  for i in "${!IDS[@]}"; do
    if [ "${RECS[$i]}" = "1" ]; then
      rec="是"
    else
      rec="-"
    fi
    if ! is_available "$i"; then
      state="沒有"
    elif is_installed "$i"; then
      state="已安裝"
    else
      state="未安裝"
    fi
    printf '%-12s %-6s %-8s %s\n' "${IDS[$i]}" "$rec" "$state" "$(method_label "$i")"
    printf '%-12s %-6s %-8s %s\n' "" "" "" "${DESCS[$i]}"
  done
}

draw_menu() {
  local i mark recmark state last_group=""
  printf '\n平台: %s (%s)\n' "$OS" "$(uname -m 2>/dev/null || echo unknown)"
  printf '星號是預設項目。現在勾到的才會裝。\n'
  printf '已安裝的勾了也會略過，要重裝請加 --force。\n'
  for i in "${!IDS[@]}"; do
    if [ "${CATS[$i]}" != "$last_group" ]; then
      last_group="${CATS[$i]}"
      printf '\n%s\n' "$(group_name "$last_group")"
    fi
    if [ "${SELECTED[$i]}" = "1" ]; then
      mark="x"
    else
      mark=" "
    fi
    if [ "${RECS[$i]}" = "1" ]; then
      recmark="*"
    else
      recmark=" "
    fi
    if ! is_available "$i"; then
      state="此平台沒有"
    elif is_installed "$i"; then
      state="已安裝"
    else
      state="未安裝"
    fi
    printf '  %2d [%s] %s %-12s %s  [%s]\n' \
      "$((i + 1))" "$mark" "$recmark" "${IDS[$i]}" "${DESCS[$i]}" "$state"
  done
  printf '\n'
  print_checked
  printf '一次勾多個：輸入編號，用空白或逗號分開，例如 7 20 22\n'
  printf '再打一次同一個編號會取消。d 開始安裝，q 取消，a 改勾預設，n 清空\n'
  if have fzf; then
    printf '這台已經有 fzf，輸入 f 可改用方向鍵多選\n'
  fi
}

print_checked() {
  local i any=0
  printf '目前勾選:'
  for i in "${!IDS[@]}"; do
    if [ "${SELECTED[$i]}" = "1" ]; then
      printf ' %s' "${IDS[$i]}"
      any=1
    fi
  done
  if [ "$any" -eq 0 ]; then
    printf ' （還沒有）'
  fi
  printf '\n'
}

read_line() {
  local value=""
  if [ -r /dev/tty ]; then
    IFS= read -r value </dev/tty || return 1
  else
    IFS= read -r value || return 1
  fi
  printf '%s\n' "$value"
}

can_prompt() {
  [ -t 0 ] || [ -r /dev/tty ]
}

select_none() {
  local i
  for i in "${!IDS[@]}"; do
    SELECTED[$i]=0
  done
}

select_recommended() {
  local i
  select_none
  for i in "${!IDS[@]}"; do
    if [ "${RECS[$i]}" = "1" ] && is_available "$i"; then
      SELECTED[$i]=1
    fi
  done
}

select_all() {
  local i
  select_none
  for i in "${!IDS[@]}"; do
    if is_available "$i"; then
      SELECTED[$i]=1
    fi
  done
}

select_missing_recommended() {
  local i
  select_none
  for i in "${!IDS[@]}"; do
    if [ "${RECS[$i]}" = "1" ] && is_available "$i" && ! is_installed "$i"; then
      SELECTED[$i]=1
    fi
  done
}

toggle_index() {
  local i="$1"
  if [ "$i" -lt 0 ] || [ "$i" -ge "${#IDS[@]}" ]; then
    warn "沒有編號 $((i + 1))"
    return 0
  fi
  if ! is_available "$i"; then
    warn "${IDS[$i]} 在 $OS 沒有對應安裝方式"
    return 0
  fi
  if [ "${SELECTED[$i]}" = "1" ]; then
    SELECTED[$i]=0
  else
    SELECTED[$i]=1
  fi
}

toggle_token() {
  local tok="$1" i
  case "$tok" in
    '' | *[!0-9]*)
      if ! i="$(index_of "$tok")"; then
        warn "沒有這個項目: $tok"
        return 0
      fi
      toggle_index "$i"
      ;;
    *)
      toggle_index "$((tok - 1))"
      ;;
  esac
}

checkbox_select() {
  local line tok
  select_none
  while true; do
    draw_menu
    printf '> '
    line="$(read_line)" || exit 0
    line=${line//,/ }
    [ -n "$line" ] || continue
    set -f
    for tok in $line; do
      case "$tok" in
        a) select_recommended ;;
        A) select_all ;;
        n) select_none ;;
        d)
          set +f
          return 0
          ;;
        f)
          set +f
          if have fzf; then
            fzf_select
            return 0
          fi
          warn "還沒有 fzf。請用編號勾選，例如 7 20 22"
          ;;
        q | quit | exit)
          set +f
          printf '已取消\n'
          exit 0
          ;;
        *) toggle_token "$tok" ;;
      esac
    done
    set +f
  done
}

fzf_select() {
  local i state mark picks line id
  have fzf || die "找不到 fzf"
  picks="$(
    for i in "${!IDS[@]}"; do
      is_available "$i" || continue
      if is_installed "$i"; then
        state="已安裝"
      else
        state="未安裝"
      fi
      if [ "${RECS[$i]}" = "1" ]; then
        mark="預設"
      else
        mark="    "
      fi
      printf '%s\t%s  %-12s %-8s %s\n' \
        "${IDS[$i]}" "$mark" "${IDS[$i]}" "$state" "${DESCS[$i]}"
    done | fzf --multi --delimiter="$(printf '\t')" --with-nth=2.. \
      --prompt '安裝> ' \
      --header 'Tab 多選，Enter 安裝。沒選到或按 Esc 就取消。'
  )" || true
  if [ -z "$picks" ]; then
    printf '已取消\n'
    exit 0
  fi
  select_none
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    id="${line%%$'\t'*}"
    if i="$(index_of "$id")"; then
      SELECTED[$i]=1
    fi
  done <<EOF
$picks
EOF
}

interactive_menu() {
  checkbox_select
}

index_of() {
  local name="$1" i
  for i in "${!IDS[@]}"; do
    if [ "${IDS[$i]}" = "$name" ]; then
      printf '%s\n' "$i"
      return 0
    fi
  done
  return 1
}

select_names() {
  local name i
  select_none
  for name in "$@"; do
    if ! i="$(index_of "$name")"; then
      die "未知套件: $name（見 --list）"
    fi
    if ! is_available "$i"; then
      die "${name} 在 $OS 沒有對應安裝方式"
    fi
    SELECTED[$i]=1
  done
}

FORMULAS=()
CASKS=()
DNF_PKGS=()
TERMUX_PKGS=()
SPECIAL_IDX=()
SEEN_TOKENS=" "
QUEUED=0
SKIPPED=0
XCODE_DONE=0

add_token() {
  local token="$1"
  case " $SEEN_TOKENS " in
    *" $token "*) return 0 ;;
  esac
  SEEN_TOKENS="$SEEN_TOKENS$token "
  case "$OS" in
    macos)
      case "$token" in
        cask:*) CASKS+=("${token#cask:}") ;;
        *) FORMULAS+=("$token") ;;
      esac
      ;;
    fedora) DNF_PKGS+=("$token") ;;
    termux) TERMUX_PKGS+=("$token") ;;
  esac
}

queue_index() {
  local i="$1" spec token
  if ! is_available "$i"; then
    return 0
  fi
  if [ "$FORCE" -eq 0 ] && is_installed "$i"; then
    log "已安裝 ${IDS[$i]}，略過"
    SKIPPED=$((SKIPPED + 1))
    return 0
  fi
  spec="$(spec_at "$i")"
  if [ "$spec" = "-" ]; then
    SPECIAL_IDX+=("$i")
    QUEUED=$((QUEUED + 1))
    return 0
  fi
  for token in $spec; do
    add_token "$token"
  done
  QUEUED=$((QUEUED + 1))
}

ensure_curl_for_specials() {
  local sidx id need=0 curl_i spec token
  [ "${#SPECIAL_IDX[@]}" -gt 0 ] || return 0
  for sidx in "${SPECIAL_IDX[@]}"; do
    id="${IDS[$sidx]}"
    case "$id" in
      starship | zellij | go | rust | node) need=1 ;;
    esac
  done
  [ "$need" -eq 1 ] || return 0
  have curl && return 0
  curl_i="$(index_of curl)" || die "需要 curl，但清單裡沒有 curl"
  spec="$(spec_at "$curl_i")"
  [ "$spec" != "-" ] && [ "$spec" != "none" ] || die "需要 curl，但 $OS 沒有 curl 套件"
  log "下載安裝需要 curl，一併加入"
  for token in $spec; do
    add_token "$token"
  done
}

as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    if ! have sudo; then
      die "需要 sudo 才能安裝系統套件"
    fi
    sudo "$@"
  fi
}

root_prefix() {
  if [ "$(id -u)" -eq 0 ]; then
    printf ''
  else
    printf 'sudo '
  fi
}

run_pkg_plan() {
  local kind
  kind="$OS"
  case "$kind" in
    macos)
      if [ "${#FORMULAS[@]}" -eq 0 ] && [ "${#CASKS[@]}" -eq 0 ]; then
        return 0
      fi
      if [ "$DRY_RUN" -eq 0 ] && ! have brew; then
        die "找不到 Homebrew。先安裝 https://brew.sh 再執行這個腳本"
      fi
      if [ "${#FORMULAS[@]}" -gt 0 ]; then
        log "brew install ${FORMULAS[*]}"
        if [ "$DRY_RUN" -eq 0 ]; then
          brew install "${FORMULAS[@]}"
        fi
      fi
      if [ "${#CASKS[@]}" -gt 0 ]; then
        log "brew install --cask ${CASKS[*]}"
        if [ "$DRY_RUN" -eq 0 ]; then
          brew install --cask "${CASKS[@]}"
        fi
      fi
      ;;
    fedora)
      if [ "${#DNF_PKGS[@]}" -eq 0 ]; then
        return 0
      fi
      log "$(root_prefix)dnf install -y ${DNF_PKGS[*]}"
      if [ "$DRY_RUN" -eq 0 ]; then
        as_root dnf install -y "${DNF_PKGS[@]}"
      fi
      ;;
    termux)
      if [ "${#TERMUX_PKGS[@]}" -eq 0 ]; then
        return 0
      fi
      if [ "$DRY_RUN" -eq 0 ] && ! have pkg; then
        die "找不到 pkg"
      fi
      log "pkg install -y ${TERMUX_PKGS[*]}"
      if [ "$DRY_RUN" -eq 0 ]; then
        pkg install -y "${TERMUX_PKGS[@]}"
      fi
      ;;
  esac
}

append_rc_once() {
  local file="$1" text="$2" create="${3:-0}"
  if [ -f "$file" ] && grep -qF "$text" "$file" 2>/dev/null; then
    return 0
  fi
  if [ ! -f "$file" ] && [ "$create" -ne 1 ]; then
    return 0
  fi
  if [ "$DRY_RUN" -eq 1 ]; then
    log "dry-run: 會把設定寫進 $file"
    TOUCHED_RC=1
    return 0
  fi
  if [ ! -f "$file" ]; then
    printf '%s\n' "$text" >"$file"
  else
    printf '\n# dotfile install-packages\n%s\n' "$text" >>"$file"
  fi
  log "已寫入 $file"
  TOUCHED_RC=1
}

ensure_local_bin() {
  local line='export PATH="$HOME/.local/bin:$PATH"'
  if [ "$DRY_RUN" -eq 0 ]; then
    mkdir -p "$HOME/.local/bin"
  fi
  case ":${PATH}:" in
    *:"$HOME/.local/bin":*) ;;
    *) export PATH="$HOME/.local/bin:$PATH" ;;
  esac
  # 已有 .local/bin 就不要再寫一行，避免和原本的 PATH 設定重複。
  if [ -f "$HOME/.zshrc" ] && grep -qF '.local/bin' "$HOME/.zshrc"; then
    :
  else
    append_rc_once "$HOME/.zshrc" "$line" 1
  fi
  if [ -f "$HOME/.bashrc" ] && grep -qF '.local/bin' "$HOME/.bashrc"; then
    :
  elif [ -f "$HOME/.bashrc" ]; then
    append_rc_once "$HOME/.bashrc" "$line" 0
  fi
}

ensure_cargo_rc() {
  local line='[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"'
  append_rc_once "$HOME/.zshrc" "$line"
  append_rc_once "$HOME/.bashrc" "$line"
}

ensure_nvm_rc() {
  local file block
  block='export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"'
  for file in "$HOME/.zshrc" "$HOME/.bashrc"; do
    if [ -f "$file" ] && grep -q 'NVM_DIR' "$file" 2>/dev/null; then
      continue
    fi
    if [ "$DRY_RUN" -eq 1 ]; then
      log "dry-run: 會把 nvm 設定寫進 $file"
      TOUCHED_RC=1
      continue
    fi
    if [ ! -f "$file" ]; then
      printf '%s\n' "$block" >"$file"
    else
      printf '\n# dotfile install-packages\n%s\n' "$block" >>"$file"
    fi
    log "已寫入 $file"
    TOUCHED_RC=1
  done
}

install_xcode_clt() {
  if [ "$XCODE_DONE" -eq 1 ]; then
    return 0
  fi
  XCODE_DONE=1
  log "安裝 Xcode Command Line Tools（make / clang）"
  if [ "$DRY_RUN" -eq 1 ]; then
    log "dry-run: xcode-select --install"
    return 0
  fi
  if ! xcode-select --install; then
    warn "若沒有跳出安裝視窗，請在「系統設定」安裝 Command Line Tools，或再執行一次 xcode-select --install"
  fi
}

install_starship() {
  ensure_local_bin
  local -a args=(--yes --bin-dir "$HOME/.local/bin")
  if [ "$FORCE" -eq 1 ]; then
    args+=(--force)
  fi
  log "安裝 starship 到 ~/.local/bin"
  if [ "$DRY_RUN" -eq 1 ]; then
    log "dry-run: curl -fsSL https://starship.rs/install.sh | sh -s -- ${args[*]}"
    return 0
  fi
  curl -fsSL https://starship.rs/install.sh | sh -s -- "${args[@]}"
}

install_zellij_release() {
  local arch triple url tmp bin
  case "$(uname -m)" in
    x86_64 | amd64) triple="x86_64-unknown-linux-musl" ;;
    aarch64 | arm64) triple="aarch64-unknown-linux-musl" ;;
    *) die "沒有對應的 zellij 預編版本：$(uname -m)" ;;
  esac
  url="https://github.com/zellij-org/zellij/releases/latest/download/zellij-${triple}.tar.gz"
  log "安裝 zellij（${triple}）到 ~/.local/bin"
  if [ "$DRY_RUN" -eq 1 ]; then
    log "dry-run: curl -fL $url"
    ensure_local_bin
    return 0
  fi
  ensure_local_bin
  tmp="$(mktemp -d)"
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" EXIT
  curl -fL --retry 3 --retry-delay 1 -o "$tmp/zellij.tar.gz" "$url"
  tar -C "$tmp" -xzf "$tmp/zellij.tar.gz"
  bin="$(find "$tmp" -type f -name zellij -print -quit)"
  [ -n "$bin" ] || die "壓縮檔裡找不到 zellij"
  install -m 755 "$bin" "$HOME/.local/bin/zellij"
  rm -rf "$tmp"
  trap - EXIT
  log "已安裝 $("$HOME/.local/bin/zellij" --version 2>/dev/null || echo zellij)"
}

install_go() {
  local installer="$SCRIPT_DIR/install_go.sh"
  [ -f "$installer" ] || die "找不到 $installer"
  log "用 $installer 安裝最新版 Go"
  if [ "$DRY_RUN" -eq 1 ]; then
    log "dry-run: bash $installer"
    return 0
  fi
  case "$(uname -s)" in
    Linux) ;;
    *) die "install_go.sh 只適用於 Linux" ;;
  esac
  bash "$installer"
}

install_rust() {
  if [ "$DRY_RUN" -eq 1 ]; then
    if have rustup && [ "$FORCE" -eq 1 ]; then
      log "dry-run: rustup update"
    else
      log "dry-run: curl https://sh.rustup.rs | sh -s -- -y"
    fi
    return 0
  fi
  if have rustup && [ "$FORCE" -eq 1 ]; then
    rustup update
    return 0
  fi
  curl --proto '=https' --tlsv1.2 -fsSL https://sh.rustup.rs | sh -s -- -y
  if [ -f "$HOME/.cargo/env" ]; then
    # shellcheck disable=SC1091
    . "$HOME/.cargo/env"
  fi
  ensure_cargo_rc
  have rustc || die "rustup 裝完後仍找不到 rustc。請開新的 shell 再試"
}

install_node() {
  log "用 nvm ${NVM_VERSION} 安裝 Node ${NODE_MAJOR}"
  if [ "$DRY_RUN" -eq 1 ]; then
    if [ ! -s "$HOME/.nvm/nvm.sh" ]; then
      log "dry-run: 安裝 nvm ${NVM_VERSION}"
    fi
    log "dry-run: nvm install ${NODE_MAJOR}"
    return 0
  fi
  if [ ! -s "$HOME/.nvm/nvm.sh" ]; then
    curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | bash
  fi
  ensure_nvm_rc
  # nvm.sh 在 set -u 下會碰到未設定的變數。
  set +u
  # shellcheck disable=SC1091
  . "$HOME/.nvm/nvm.sh"
  nvm install "$NODE_MAJOR"
  set -u
  have node || die "nvm 裝完後仍找不到 node。請開新的 shell 再試"
}

install_trash_pip() {
  log "用 pip 安裝 trash-cli"
  if [ "$DRY_RUN" -eq 1 ]; then
    log "dry-run: pkg install -y python python-pip"
    log "dry-run: pip install trash-cli"
    return 0
  fi
  pkg install -y python python-pip
  if ! pip install trash-cli; then
    pip install --break-system-packages trash-cli
  fi
  have trash || die "pip 裝完後仍找不到 trash。若它在 ~/.local/bin，請把該目錄加進 PATH"
}

run_specials() {
  local sidx id
  [ "${#SPECIAL_IDX[@]}" -gt 0 ] || return 0
  for sidx in "${SPECIAL_IDX[@]}"; do
    id="${IDS[$sidx]}"
    case "$OS:$id" in
      fedora:starship) install_starship ;;
      fedora:zellij) install_zellij_release ;;
      fedora:go) install_go ;;
      macos:rust | fedora:rust) install_rust ;;
      fedora:node) install_node ;;
      macos:compiler | macos:make) install_xcode_clt ;;
      termux:trash) install_trash_pip ;;
      *) die "沒有實作 ${id} 在 $OS 的安裝方式" ;;
    esac
  done
}

install_selected() {
  local i any=0
  FORMULAS=()
  CASKS=()
  DNF_PKGS=()
  TERMUX_PKGS=()
  SPECIAL_IDX=()
  SEEN_TOKENS=" "
  QUEUED=0
  SKIPPED=0

  for i in "${!IDS[@]}"; do
    if [ "${SELECTED[$i]}" = "1" ]; then
      any=1
      queue_index "$i"
    fi
  done
  if [ "$any" -eq 0 ]; then
    log "沒有選擇任何套件"
    return 0
  fi
  ensure_curl_for_specials
  if [ "$QUEUED" -eq 0 ]; then
    log "沒有需要安裝的項目"
    return 0
  fi
  run_pkg_plan
  run_specials
  if [ "$DRY_RUN" -eq 1 ]; then
    log "完成（dry-run，沒有真的安裝）。會處理 ${QUEUED} 項，略過已安裝 ${SKIPPED} 項。"
  else
    log "完成。這次處理 ${QUEUED} 項，略過已安裝 ${SKIPPED} 項。"
  fi
  if [ "$TOUCHED_RC" -eq 1 ]; then
    log "shell 設定有更新。請開一個新的終端機，或 source 你的 ~/.zshrc / ~/.bashrc。"
  fi
}

main() {
  local mode="interactive"
  local -a names=()
  local list_only=0

  # 在子 shell 裡 die 只會結束子 shell，所以平台先在這裡定下來。
  if ! OS="$(os_kind)"; then
    exit 1
  fi

  while [ $# -gt 0 ]; do
    case "$1" in
      -h | --help)
        usage
        exit 0
        ;;
      --list)
        list_only=1
        shift
        ;;
      --default | --recommended)
        mode="default"
        shift
        ;;
      --all)
        mode="all"
        shift
        ;;
      --dry-run)
        DRY_RUN=1
        shift
        ;;
      --force)
        FORCE=1
        shift
        ;;
      --)
        shift
        if [ "$#" -gt 0 ]; then
          names+=("$@")
        fi
        break
        ;;
      -*)
        die "未知參數: $1（見 --help）"
        ;;
      *)
        names+=("$1")
        mode="names"
        shift
        ;;
    esac
  done

  load_catalog
  log "平台: $OS ($(uname -s 2>/dev/null || echo unknown) $(uname -m 2>/dev/null || echo unknown))"

  if [ "$list_only" -eq 1 ]; then
    list_catalog
    return 0
  fi

  if [ "${#names[@]}" -gt 0 ]; then
    select_names "${names[@]}"
  elif [ "$mode" = "default" ]; then
    select_recommended
  elif [ "$mode" = "all" ]; then
    select_all
  elif can_prompt; then
    interactive_menu
  else
    usage
    exit 1
  fi

  install_selected
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
fi
