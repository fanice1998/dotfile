#!/usr/bin/env bash
# Multi-select installer for Helix Steel plugins.
# Writes require/config into ~/.config/helix/init.scm and keybindings
# into config.toml (managed blocks).
#
# Default is additive: new ids are merged with the previous ";; selected:"
# line. --replace makes the argument list (or the checkbox) exact.
# Bash 3.2 (macOS /bin/bash) is supported.
#
# Usage:
#   ./install-plugins.sh                 interactive menu
#   ./install-plugins.sh --recommended   beginner set
#   ./install-plugins.sh --all
#   ./install-plugins.sh oil forest term
#   ./install-plugins.sh --replace oil
#   ./install-plugins.sh --list

set -euo pipefail

HELIX_CONFIG="${HELIX_CONFIG:-$HOME/.config/helix}"
REPLACE=0
FORCE=0
DRY_RUN=0
DO_WRITE=1
STEEL_COGS_RESOLVED=""
EXISTING=()
IDS=()
SELECTED=()

script_dir() {
  cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd
}

REPO_DIR="$(script_dir)"

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

if [ -f "$HOME/.cargo/env" ]; then
  # shellcheck disable=SC1091
  . "$HOME/.cargo/env"
fi
case ":${PATH}:" in
  *:"$HOME/.cargo/bin":*) ;;
  *) export PATH="$HOME/.cargo/bin:$PATH" ;;
esac

# id|name|recommended|method|git|require|deps|description
# method: forge | copy
# require: scheme module path, or "-" if none
# deps: comma-separated plugin ids, or "-"
# Package directory is the first path component of require (glyph uses its id).
PLUGIN_CATALOG="$(
  cat <<'EOF'
notify|notify.hx|1|forge|https://github.com/chuwy/notify.hx.git|notify/notify.scm|-|通知彈窗（oil / forest 會自動依賴）
oil|oil.hx|1|forge|https://github.com/Ra77a3l3-jar/oil.hx.git|oil/oil.scm|notify|把目錄當成 buffer，新增 / 重新命名 / 刪除檔案
forest|forest.hx|1|forge|https://github.com/Ra77a3l3-jar/forest.hx.git|forest/forest.scm|notify,glyph|側邊檔案樹，類似 nvim-tree / snacks explorer
term|steel-pty|1|forge|https://github.com/mattwparas/steel-pty.git|steel-pty/term.scm|-|編輯器內嵌終端機
watcher|helix-file-watcher|1|forge|https://github.com/mattwparas/helix-file-watcher.git|helix-file-watcher/file-watcher.scm|-|外部改檔時自動重載 buffer
streal|streal.hx|1|forge|https://github.com/gllms/streal.hx.git|streal/streal.scm|-|檔案書籤，用數字快速跳轉
recentf|helix-config|1|forge|https://github.com/mattwparas/helix-config.git|mattwparas-helix-package/cogs/recentf.scm|-|最近開啟檔案（官方擴充包）
flash|flash.hx|0|copy|https://github.com/shybovycha/flash.hx.git|flash.scm|-|單字母跳轉，類似 flash.nvim
trail|trail.hx|0|forge|https://github.com/Ra77a3l3-jar/trail.hx.git|trail/trail.scm|glyph|最近專案選擇器
zen|zen-mode.hx|0|forge|https://github.com/notnmeyer/zen-mode.hx.git|zen-mode/zen-mode.scm|-|專注模式，置中並隱藏 gutter
scooter|scooter.hx|0|forge|https://github.com/thomasschafer/scooter.hx.git|scooter/scooter.scm|-|互動式尋找取代（會編譯 native library）
showkeys|showkeys.hx|0|forge|https://github.com/HeitorAugustoLN/showkeys.hx.git|showkeys/showkeys.scm|-|畫面上顯示按下的按鍵
scroll|smooth-scroll.hx|0|forge|https://github.com/thomasschafer/smooth-scroll.hx.git|smooth-scroll/smooth-scroll.scm|-|平滑捲動（C-d / C-u）
glyph|glyph.hx|0|forge|https://github.com/Ra77a3l3-jar/glyph.hx.git|-|-|圖示庫（forest / trail 會自動依賴，通常不必單裝）
EOF
)"

plugin_line() {
  awk -F'|' -v id="$1" '$1==id {print; exit}' <<<"$PLUGIN_CATALOG"
}

catalog_has() {
  awk -F'|' -v id="$1" '$1==id {found=1; exit} END {exit !found}' <<<"$PLUGIN_CATALOG"
}

plugin_field() {
  local id="$1" field="$2" line
  line="$(plugin_line "$id")"
  [ -n "$line" ] || die "未知插件: $id"
  case "$field" in
    id) cut -d'|' -f1 <<<"$line" ;;
    name) cut -d'|' -f2 <<<"$line" ;;
    recommended) cut -d'|' -f3 <<<"$line" ;;
    method) cut -d'|' -f4 <<<"$line" ;;
    git) cut -d'|' -f5 <<<"$line" ;;
    require) cut -d'|' -f6 <<<"$line" ;;
    deps) cut -d'|' -f7 <<<"$line" ;;
    desc) cut -d'|' -f8- <<<"$line" ;;
    *) die "未知欄位: $field" ;;
  esac
}

plugin_pkg() {
  local id="$1" req method
  method="$(plugin_field "$id" method)"
  req="$(plugin_field "$id" require)"
  if [ "$method" = "forge" ] && [ "$req" != "-" ] && [ "${req#*/}" != "$req" ]; then
    printf '%s\n' "${req%%/*}"
    return 0
  fi
  printf '%s\n' "$id"
}

steel_cogs_dir() {
  if [ -n "$STEEL_COGS_RESOLVED" ]; then
    printf '%s\n' "$STEEL_COGS_RESOLVED"
    return 0
  fi
  local detected=""
  if [ -n "${STEEL_COGS:-}" ]; then
    detected="$STEEL_COGS"
  elif have forge; then
    detected="$(
      forge list 2>/dev/null | awk '/^Listing packages from: / { sub(/^Listing packages from: /, ""); print; exit }' || true
    )"
  fi
  # forge list prints a trailing space after the directory.
  detected="${detected%"${detected##*[![:space:]]}"}"
  detected="${detected#"${detected%%[![:space:]]*}"}"
  detected="${detected%/}"
  if [ -z "$detected" ]; then
    detected="${STEEL_HOME:-$HOME/.local/share/steel}/cogs"
  fi
  STEEL_COGS_RESOLVED="$detected"
  printf '%s\n' "$STEEL_COGS_RESOLVED"
}

plugin_present() {
  local id="$1" method req dir
  method="$(plugin_field "$id" method)"
  if [ "$method" = "copy" ]; then
    req="$(plugin_field "$id" require)"
    [ -s "$HELIX_CONFIG/$req" ]
    return
  fi
  dir="$(steel_cogs_dir)/$(plugin_pkg "$id")"
  [ -d "$dir" ] && [ -n "$(ls -A "$dir" 2>/dev/null)" ]
}

load_ids() {
  local line
  IDS=()
  while IFS= read -r line || [ -n "${line:-}" ]; do
    [ -n "$line" ] || continue
    IDS+=("$line")
  done
}

all_ids() {
  awk -F'|' 'NF && $1 !~ /^#/ {print $1}' <<<"$PLUGIN_CATALOG"
}

recommended_ids() {
  awk -F'|' '$3==1 {print $1}' <<<"$PLUGIN_CATALOG"
}

list_plugins() {
  printf '%-10s %-8s %-22s %s\n' "ID" "建議" "套件" "說明"
  local id name rec _method _git _req _deps desc mark
  while IFS='|' read -r id name rec _method _git _req _deps desc; do
    [ -n "$id" ] || continue
    mark="-"
    [ "$rec" = "1" ] && mark="是"
    printf '%-10s %-8s %-22s %s\n' "$id" "$mark" "$name" "$desc"
  done <<EOF
$PLUGIN_CATALOG
EOF
}

usage() {
  cat <<'EOF'
Helix Steel 插件安裝（與 install.sh 分開）。

用法:
  ./install-plugins.sh                 互動選單
  ./install-plugins.sh --recommended   安裝新手建議插件（保留已啟用的）
  ./install-plugins.sh --all           安裝目錄內全部插件（保留已啟用的）
  ./install-plugins.sh oil forest term 加裝列出的 id（保留已啟用的）
  ./install-plugins.sh --replace oil   設定改成剛好這些 id
  ./install-plugins.sh --force oil     已安裝的套件也重裝
  ./install-plugins.sh --dry-run --recommended
  ./install-plugins.sh --list          列出可選插件

互動多選:
  輸入編號切換勾選、a 只選建議、A 全選、n 清空、d 完成、q 取消
  勾選完成會以畫面上的結果取代目前設定（依賴會自動加回）
  第一層選單的「略過」與 fzf 沒選到東西，都不會改設定
  若有 fzf，也可在選單選「fzf 多選」（沒選到則不改設定）

預設是合併。已寫進 init.scm 的插件會留著，除非用 --replace 或互動勾選拿掉。
從設定移除不會呼叫 forge uninstall，套件仍留在 cogs。

建議插件（--recommended）:
  notify, oil, forest, term, watcher, streal, recentf
  forest 會再裝 glyph；oil / forest 會再裝 notify。

環境變數:
  HELIX_CONFIG       設定檔目錄（預設 ~/.config/helix）
  STEEL_COGS         forge 套件目錄（預設由 forge list 判斷）
  HELIX_PLUGINS_TTY  設為 1 時，即使 stdin 不是終端機也開啟選單
EOF
}

expand_deps() {
  local -a raw=()
  if [ "$#" -gt 0 ]; then
    raw=("$@")
  fi
  local -a out=()
  local seen=" "

  add_dep() {
    local x="$1" deps dep
    case "$seen" in
      *" $x "*) return 0 ;;
    esac
    seen="$seen$x "
    deps="$(plugin_field "$x" deps)"
    if [ -n "$deps" ] && [ "$deps" != "-" ]; then
      local IFS=','
      for dep in $deps; do
        [ -n "$dep" ] || continue
        add_dep "$dep"
      done
    fi
    out+=("$x")
  }

  local id
  for id in "${raw[@]+"${raw[@]}"}"; do
    add_dep "$id"
  done
  if [ "${#out[@]}" -gt 0 ]; then
    printf '%s\n' "${out[@]}"
  fi
}

install_one() {
  local id="$1"
  local method giturl name
  method="$(plugin_field "$id" method)"
  giturl="$(plugin_field "$id" git)"
  name="$(plugin_field "$id" name)"

  case "$method" in
    forge)
      if [ "$DRY_RUN" -eq 1 ]; then
        if [ "$FORCE" -eq 0 ] && plugin_present "$id"; then
          log "dry-run: 已安裝 $name ($id)，略過"
        elif [ "$FORCE" -eq 1 ]; then
          log "dry-run: forge pkg install --git $giturl --force"
        else
          log "dry-run: forge pkg install --git $giturl"
        fi
        return 0
      fi
      have forge || {
        printf 'error: 找不到 forge。請先執行 ./install.sh helix\n' >&2
        return 1
      }
      if [ "$FORCE" -eq 0 ] && plugin_present "$id"; then
        log "已安裝 $name ($id)，略過（--force 可重裝）"
        return 0
      fi
      log "安裝 $name ($id)"
      if [ "$FORCE" -eq 1 ]; then
        forge pkg install --git "$giturl" --force || return 1
      else
        forge pkg install --git "$giturl" || return 1
      fi
      if ! plugin_present "$id"; then
        warn "forge 結束後在 $(steel_cogs_dir)/$(plugin_pkg "$id") 沒看到 ${name}，仍視為成功"
      fi
      ;;
    copy)
      local req dest tmp
      req="$(plugin_field "$id" require)"
      dest="$HELIX_CONFIG/$req"
      if [ "$DRY_RUN" -eq 1 ]; then
        if [ "$FORCE" -eq 0 ] && [ -s "$dest" ]; then
          log "dry-run: 已安裝 $name ($id)，略過"
        else
          log "dry-run: git clone $giturl -> $dest"
        fi
        return 0
      fi
      if [ "$FORCE" -eq 0 ] && [ -s "$dest" ]; then
        log "已安裝 $name ($id)，略過（--force 可重裝）"
        return 0
      fi
      log "安裝 $name ($id)"
      tmp="$(mktemp -d)" || return 1
      if ! GIT_TERMINAL_PROMPT=0 git clone --depth 1 "$giturl" "$tmp/src"; then
        rm -rf "$tmp"
        return 1
      fi
      mkdir -p "$HELIX_CONFIG"
      if [ -f "$tmp/src/$req" ]; then
        cp "$tmp/src/$req" "$dest" || {
          rm -rf "$tmp"
          return 1
        }
      else
        rm -rf "$tmp"
        printf 'error: %s 找不到 %s\n' "$name" "$req" >&2
        return 1
      fi
      rm -rf "$tmp"
      ;;
    *)
      printf 'error: 未知安裝方式: %s\n' "$method" >&2
      return 1
      ;;
  esac
}

default_shell() {
  if [ -x /bin/zsh ]; then
    printf '%s\n' /bin/zsh
    return 0
  fi
  if have zsh; then
    command -v zsh
    return 0
  fi
  if [ -x /bin/bash ]; then
    printf '%s\n' /bin/bash
    return 0
  fi
  command -v bash 2>/dev/null || printf '%s\n' /bin/sh
}

plugin_init_extra() {
  local id="$1" shell
  case "$id" in
    oil)
      cat <<'SCM'
(oil-configure! #false #false)
SCM
      ;;
    forest)
      cat <<'SCM'
(forest-configure! 'left #:ignore (list ".git" "target" "__pycache__" "node_modules"))
(forest-set-style! 'snacks)
SCM
      ;;
    term)
      shell="$(default_shell)"
      printf '(set-default-shell! "%s")\n' "$shell"
      ;;
    watcher)
      cat <<'SCM'
(spawn-watcher)
SCM
      ;;
    recentf)
      cat <<'SCM'
(recentf-snapshot)
SCM
      ;;
    *) ;;
  esac
}

plugin_toml_keys() {
  local -a ids=()
  if [ "$#" -gt 0 ]; then
    ids=("$@")
  fi
  local id
  local has_oil=0 has_forest=0 has_term=0 has_streal=0
  local has_flash=0 has_trail=0 has_recentf=0 has_scroll=0 has_scooter=0

  for id in "${ids[@]+"${ids[@]}"}"; do
    case "$id" in
      oil) has_oil=1 ;;
      forest) has_forest=1 ;;
      term) has_term=1 ;;
      streal) has_streal=1 ;;
      flash) has_flash=1 ;;
      trail) has_trail=1 ;;
      recentf) has_recentf=1 ;;
      scroll) has_scroll=1 ;;
      scooter) has_scooter=1 ;;
    esac
  done

  echo "# 由 install-plugins.sh 寫入，請用該腳本更新"
  if [ "$has_oil" -eq 1 ] || [ "$has_streal" -eq 1 ] || [ "$has_scroll" -eq 1 ]; then
    echo "[keys.normal]"
    [ "$has_oil" -eq 1 ] && echo '"-" = ":oil"'
    [ "$has_streal" -eq 1 ] && echo '"\\" = ":streal-open"'
    [ "$has_scroll" -eq 1 ] && echo 'C-d = ":half-page-down-smooth"'
    [ "$has_scroll" -eq 1 ] && echo 'C-u = ":half-page-up-smooth"'
    [ "$has_scroll" -eq 1 ] && echo 'pageup = ":page-up-smooth"'
    [ "$has_scroll" -eq 1 ] && echo 'pagedown = ":page-down-smooth"'
  fi

  if [ "$has_forest" -eq 1 ] || [ "$has_term" -eq 1 ] || [ "$has_recentf" -eq 1 ] || [ "$has_trail" -eq 1 ] || [ "$has_scooter" -eq 1 ]; then
    echo
    echo "[keys.normal.space]"
    [ "$has_forest" -eq 1 ] && echo 'e = ":forest-open"'
    [ "$has_term" -eq 1 ] && echo 't = ":open-term"'
    [ "$has_term" -eq 1 ] && echo 'T = ":kill-active-terminal"'
    [ "$has_recentf" -eq 1 ] && echo '"," = ":recentf-open-files"'
    [ "$has_trail" -eq 1 ] && echo '";" = ":trail-open"'
    [ "$has_scooter" -eq 1 ] && echo 'R = ":scooter"'
  fi

  if [ "$has_flash" -eq 1 ]; then
    echo
    echo "[keys.normal.g]"
    echo '"/" = ":flash"'
    echo
    echo "[keys.select.g]"
    echo '"/" = ":flash"'
  fi

  if [ "$has_streal" -eq 1 ]; then
    echo
    echo "[keys.select]"
    echo '"\\" = ":streal-open"'
  fi
}

plugin_scm_block() {
  local -a ids=()
  if [ "$#" -gt 0 ]; then
    ids=("$@")
  fi
  local id req extra
  echo ";; generated by install-plugins.sh"
  if [ "$#" -eq 0 ]; then
    echo ";; selected:"
  else
    echo ";; selected: $*"
  fi
  for id in "${ids[@]+"${ids[@]}"}"; do
    req="$(plugin_field "$id" require)"
    [ "$req" = "-" ] && continue
    printf '(require "%s")\n' "$req"
    extra="$(plugin_init_extra "$id")"
    if [ -n "$extra" ]; then
      printf '%s\n' "$extra"
    fi
    echo
  done
}

upsert_block() {
  local file="$1"
  local start="$2"
  local end="$3"
  local body="$4"
  local tmp bodyfile
  tmp="$(mktemp)"
  bodyfile="$(mktemp)"
  printf '%s\n' "$body" >"$bodyfile"
  mkdir -p "$(dirname -- "$file")"
  if [ ! -f "$file" ]; then
    printf '%s\n%s\n%s\n' "$start" "$body" "$end" >"$file"
    rm -f "$tmp" "$bodyfile"
    return 0
  fi
  if grep -qxF "$start" "$file"; then
    if ! grep -qxF "$end" "$file"; then
      rm -f "$tmp" "$bodyfile"
      die "$file 有起始標記但沒有結束標記，已停止以免截斷檔案"
    fi
    awk -v start="$start" -v end="$end" -v bodyfile="$bodyfile" '
      BEGIN {
        while ((getline line < bodyfile) > 0) {
          body = body line "\n"
        }
        close(bodyfile)
      }
      $0 == start { print; printf "%s", body; skip=1; next }
      $0 == end { skip=0; print; next }
      skip { next }
      { print }
    ' "$file" >"$tmp"
    mv "$tmp" "$file"
  else
    printf '\n%s\n%s\n%s\n' "$start" "$body" "$end" >>"$file"
    rm -f "$tmp"
  fi
  rm -f "$bodyfile"
}

ensure_init_base() {
  local dest="$HELIX_CONFIG/init.scm"
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
  elif ! grep -qxF ';; >>> helix-steel-plugins' "$dest"; then
    printf '\n;; >>> helix-steel-plugins\n;; <<< helix-steel-plugins\n' >>"$dest"
  fi
}

warn_key_tables() {
  local file="$1" hit
  [ -f "$file" ] || return 0
  hit="$(
    awk '
      $0 == "# >>> helix-steel-plugins" { skip=1; next }
      $0 == "# <<< helix-steel-plugins" { skip=0; next }
      skip { next }
      { print }
    ' "$file" | grep -E '^\[keys(\.|])' || true
  )"
  if [ -n "$hit" ]; then
    warn "config.toml 在插件區塊外已有按鍵表，Helix 可能拒絕重複的表："
    printf '%s\n' "$hit" >&2
  fi
}

write_configs() {
  ensure_init_base
  upsert_block "$HELIX_CONFIG/init.scm" \
    ';; >>> helix-steel-plugins' \
    ';; <<< helix-steel-plugins' \
    "$(plugin_scm_block "$@")"
  upsert_block "$HELIX_CONFIG/config.toml" \
    '# >>> helix-steel-plugins' \
    '# <<< helix-steel-plugins' \
    "$(plugin_toml_keys "$@")"
  warn_key_tables "$HELIX_CONFIG/config.toml"
  log "已更新 $HELIX_CONFIG/init.scm 與 config.toml"
}

print_plugin_help() {
  local -a ids=()
  if [ "$#" -gt 0 ]; then
    ids=("$@")
  fi
  local id
  echo
  echo "快捷鍵（已寫入 config.toml）:"
  for id in "${ids[@]+"${ids[@]}"}"; do
    case "$id" in
      oil) echo "  -           :oil              檔案管理器" ;;
      forest) echo "  Space e     :forest-open      側邊檔案樹" ;;
      term)
        echo "  Space t     :open-term        內嵌終端"
        echo "  Space T     :kill-active-terminal  關掉終端"
        ;;
      streal) echo "  \\           :streal-open      檔案書籤" ;;
      recentf) echo "  Space ,     :recentf-open-files  最近檔案" ;;
      flash) echo "  g /         :flash            單字母跳轉" ;;
      trail) echo "  Space ;     :trail-open       最近專案" ;;
      scooter) echo "  Space R     :scooter          尋找取代" ;;
      scroll) echo "  C-d / C-u   平滑半頁捲動" ;;
      zen) echo "  :zen-mode   專注模式（插件本身也綁 Space z）" ;;
      showkeys) echo "  :showkeys-toggle" ;;
      watcher) echo "  啟動時自動監看外部改檔" ;;
      glyph) echo "  glyph       圖示庫（forest / trail 會用到）" ;;
    esac
  done
}

read_existing_selected() {
  EXISTING=()
  local file="$HELIX_CONFIG/init.scm" line id
  [ -f "$file" ] || return 0
  line="$(grep -E '^;; selected:' "$file" | head -n 1 || true)"
  line="${line#;; selected:}"
  for id in $line; do
    if catalog_has "$id"; then
      EXISTING+=("$id")
    else
      warn "略過未知的既有插件 id: $id"
    fi
  done
}

interactive_menu() {
  echo
  echo "Helix Steel 插件"
  echo "  1) 安裝建議插件（保留已經啟用的）"
  echo "  2) 自行多選（完成後以勾選結果為準）"
  echo "  3) 安裝全部（保留已經啟用的）"
  echo "  4) 略過（不改設定）"
  if have fzf; then
    echo "  5) fzf 多選（沒選到則不改設定）"
  fi
  printf '選擇 [1]: '
  local choice
  read -r choice || true
  choice="${choice:-1}"
  case "$choice" in
    1)
      load_ids < <(recommended_ids)
      SELECTED=()
      if [ "${#IDS[@]}" -gt 0 ]; then
        SELECTED=("${IDS[@]}")
      fi
      ;;
    2)
      SELECTED=()
      checkbox_select
      ;;
    3)
      load_ids < <(all_ids)
      SELECTED=()
      if [ "${#IDS[@]}" -gt 0 ]; then
        SELECTED=("${IDS[@]}")
      fi
      ;;
    4)
      DO_WRITE=0
      SELECTED=()
      return 0
      ;;
    5)
      have fzf || die "找不到 fzf"
      fzf_select
      ;;
    *)
      die "無效選擇: $choice"
      ;;
  esac
}

mark_on() {
  case "$on" in
    *" $1 "*) ;;
    *) on="$on$1 " ;;
  esac
}

mark_off() {
  local next=" " x
  for x in $on; do
    [ "$x" = "$1" ] || next="$next$x "
  done
  on="$next"
}

is_on() {
  case "$on" in
    *" $1 "*) return 0 ;;
    *) return 1 ;;
  esac
}

checkbox_select() {
  load_ids < <(all_ids)
  local -a ids=()
  if [ "${#IDS[@]}" -gt 0 ]; then
    ids=("${IDS[@]}")
  fi
  local on=" "
  local id i n mark hint
  local -a seed=()
  read_existing_selected
  if [ "${#EXISTING[@]}" -gt 0 ]; then
    seed=("${EXISTING[@]}")
  else
    load_ids < <(recommended_ids)
    if [ "${#IDS[@]}" -gt 0 ]; then
      seed=("${IDS[@]}")
    fi
  fi
  for id in "${seed[@]+"${seed[@]}"}"; do
    mark_on "$id"
  done
  REPLACE=1

  while true; do
    echo
    echo "輸入編號切換、a 建議、A 全部、n 清空、d 完成、q 取消"
    i=1
    for id in "${ids[@]+"${ids[@]}"}"; do
      mark=" "
      is_on "$id" && mark="x"
      hint=""
      [ "$(plugin_field "$id" recommended)" = "1" ] && hint="  (建議)"
      printf '  %2d) [%s] %-10s %s%s\n' \
        "$i" "$mark" "$id" "$(plugin_field "$id" desc)" "$hint"
      i=$((i + 1))
    done
    printf '> '
    local ans
    read -r ans || exit 1
    case "$ans" in
      d | D | "")
        SELECTED=()
        for id in "${ids[@]+"${ids[@]}"}"; do
          is_on "$id" && SELECTED+=("$id")
        done
        return 0
        ;;
      q | Q)
        echo "已取消"
        exit 1
        ;;
      a)
        on=" "
        for id in "${ids[@]+"${ids[@]}"}"; do
          [ "$(plugin_field "$id" recommended)" = "1" ] && mark_on "$id"
        done
        ;;
      A)
        for id in "${ids[@]+"${ids[@]}"}"; do
          mark_on "$id"
        done
        ;;
      n)
        on=" "
        ;;
      *)
        for n in $ans; do
          case "$n" in
            ''|*[!0-9]*)
              echo "無效編號: $n"
              continue
              ;;
          esac
          n=$((10#$n))
          if [ "$n" -ge 1 ] && [ "$n" -le "${#ids[@]}" ]; then
            id="${ids[$((n - 1))]}"
            if is_on "$id"; then
              mark_off "$id"
            else
              mark_on "$id"
            fi
          else
            echo "無效編號: $n"
          fi
        done
        ;;
    esac
  done
}

fzf_select() {
  local line id picks
  picks="$(
    printf '%s\n' "$PLUGIN_CATALOG" | awk -F'|' '{
      desc = $8
      for (i = 9; i <= NF; i++) desc = desc "|" $i
      rec = ($3 == 1) ? "[建議] " : "       "
      printf "%s\t%s%s  %s\n", $1, rec, $2, desc
    }' | fzf --multi --ansi --delimiter='\t' --with-nth=2.. \
      --header 'Tab 多選，Enter 確認。沒選到則不改設定。' \
      --prompt 'plugins> ' || true
  )"
  if [ -z "$picks" ]; then
    DO_WRITE=0
    SELECTED=()
    log "未選擇插件，不改設定"
    return 0
  fi
  SELECTED=()
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    id="${line%%$'\t'*}"
    SELECTED+=("$id")
  done <<EOF
$picks
EOF
}

install_selected() {
  local -a raw=()
  if [ "$#" -gt 0 ]; then
    raw=("$@")
  fi
  local -a base=()
  local -a combined=()
  if [ "$REPLACE" -eq 0 ]; then
    read_existing_selected
    if [ "${#EXISTING[@]}" -gt 0 ]; then
      base=("${EXISTING[@]}")
    fi
  fi
  if [ "${#base[@]}" -gt 0 ]; then
    combined=("${base[@]}")
  fi
  if [ "${#raw[@]}" -gt 0 ]; then
    combined+=("${raw[@]}")
  fi

  if [ "${#combined[@]}" -eq 0 ]; then
    if [ "$REPLACE" -eq 1 ]; then
      if [ "$DRY_RUN" -eq 1 ]; then
        log "dry-run: 會清空插件區塊"
        return 0
      fi
      log "清空插件設定"
      mkdir -p "$HELIX_CONFIG"
      write_configs
    else
      log "未選擇插件"
    fi
    return 0
  fi

  load_ids < <(expand_deps "${combined[@]}")
  local -a ids=()
  if [ "${#IDS[@]}" -gt 0 ]; then
    ids=("${IDS[@]}")
  fi
  log "目標: ${ids[*]}"
  if [ "$DRY_RUN" -eq 1 ]; then
    local id
    for id in "${ids[@]}"; do
      install_one "$id"
    done
    echo
    echo "dry-run 不會寫入設定。預計的 init.scm 區塊:"
    plugin_scm_block "${ids[@]}"
    return 0
  fi

  log "Steel cogs: $(steel_cogs_dir)"
  mkdir -p "$HELIX_CONFIG"
  local id
  local -a final=() failed=()
  for id in "${ids[@]}"; do
    if install_one "$id"; then
      final+=("$id")
    elif plugin_present "$id"; then
      warn "安裝 $id 失敗，磁碟上仍有套件，設定會保留"
      final+=("$id")
      failed+=("$id")
    else
      failed+=("$id")
    fi
  done

  if [ "$REPLACE" -eq 1 ]; then
    read_existing_selected
    local old seen fid
    for old in "${EXISTING[@]+"${EXISTING[@]}"}"; do
      seen=0
      for fid in "${final[@]+"${final[@]}"}"; do
        [ "$fid" = "$old" ] && seen=1 && break
      done
      if [ "$seen" -eq 0 ]; then
        local skipped_fail=0
        for fid in "${failed[@]+"${failed[@]}"}"; do
          [ "$fid" = "$old" ] && skipped_fail=1 && break
        done
        if [ "$skipped_fail" -eq 0 ]; then
          log "已從設定移除 ${old}（套件仍留在磁碟）"
        fi
      fi
    done
  fi

  if [ "${#final[@]}" -eq 0 ]; then
    if [ "$REPLACE" -eq 1 ]; then
      write_configs
    else
      warn "沒有插件安裝成功，保留原本設定"
    fi
  else
    write_configs "${final[@]}"
    print_plugin_help "${final[@]}"
  fi
  if [ "${#failed[@]}" -gt 0 ]; then
    printf '以下插件安裝失敗: %s\n' "${failed[*]}" >&2
    return 1
  fi
}

main() {
  SELECTED=()
  local mode="menu"

  while [ $# -gt 0 ]; do
    case "$1" in
      -h | --help)
        usage
        exit 0
        ;;
      --list)
        list_plugins
        exit 0
        ;;
      --recommended | --yes)
        mode="recommended"
        shift
        ;;
      --all)
        mode="all"
        shift
        ;;
      --replace)
        REPLACE=1
        shift
        ;;
      --force)
        FORCE=1
        shift
        ;;
      --dry-run)
        DRY_RUN=1
        shift
        ;;
      --)
        shift
        mode="args"
        break
        ;;
      -*)
        die "未知參數: $1"
        ;;
      *)
        mode="args"
        break
        ;;
    esac
  done

  case "$mode" in
    recommended)
      load_ids < <(recommended_ids)
      if [ "${#IDS[@]}" -gt 0 ]; then
        SELECTED=("${IDS[@]}")
      fi
      ;;
    all)
      load_ids < <(all_ids)
      if [ "${#IDS[@]}" -gt 0 ]; then
        SELECTED=("${IDS[@]}")
      fi
      ;;
    args)
      if [ "$#" -gt 0 ]; then
        SELECTED=("$@")
      fi
      local id
      for id in "${SELECTED[@]+"${SELECTED[@]}"}"; do
        plugin_field "$id" name >/dev/null
      done
      ;;
    menu)
      if [ -t 0 ] || [ "${HELIX_PLUGINS_TTY:-0}" = "1" ]; then
        interactive_menu
      else
        log "非互動模式，改裝建議插件"
        load_ids < <(recommended_ids)
        if [ "${#IDS[@]}" -gt 0 ]; then
          SELECTED=("${IDS[@]}")
        fi
      fi
      ;;
  esac

  if [ "$DO_WRITE" -eq 0 ]; then
    log "略過插件，未改設定"
    return 0
  fi

  if [ "${#SELECTED[@]}" -eq 0 ]; then
    install_selected
  else
    install_selected "${SELECTED[@]}"
  fi
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
fi
