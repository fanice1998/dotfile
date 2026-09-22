#!/usr/bin/env bash
# Multi-select installer for Helix Steel plugins.
# Writes require/config into ~/.config/helix/init.scm and keybindings
# into config.toml (managed blocks).
#
# Usage:
#   ./install-plugins.sh                 interactive menu
#   ./install-plugins.sh --recommended   beginner set
#   ./install-plugins.sh --all
#   ./install-plugins.sh oil forest term
#   ./install-plugins.sh --list

set -euo pipefail

HELIX_CONFIG="${HELIX_CONFIG:-$HOME/.config/helix}"

script_dir() {
  cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd
}

REPO_DIR="$(script_dir)"

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
PLUGIN_CATALOG="$(
  cat <<'EOF'
notify|notify.hx|1|forge|https://github.com/chuwy/notify.hx.git|notify/notify.scm|-|通知彈窗（oil / forest 會自動依賴）
oil|oil.hx|1|forge|https://github.com/Ra77a3l3-jar/oil.hx.git|oil/oil.scm|notify|把目錄當成 buffer，新增 / 重新命名 / 刪除檔案
forest|forest.hx|1|forge|https://github.com/Ra77a3l3-jar/forest.hx.git|forest/forest.scm|notify|側邊檔案樹，類似 nvim-tree / snacks explorer
term|steel-pty|1|forge|https://github.com/mattwparas/steel-pty.git|steel-pty/term.scm|-|編輯器內嵌終端機
watcher|helix-file-watcher|1|forge|https://github.com/mattwparas/helix-file-watcher.git|helix-file-watcher/file-watcher.scm|-|外部改檔時自動重載 buffer
streal|streal.hx|1|forge|https://github.com/gllms/streal.hx.git|streal/streal.scm|-|檔案書籤，用數字快速跳轉
recentf|helix-config|1|forge|https://github.com/mattwparas/helix-config.git|mattwparas-helix-package/cogs/recentf.scm|-|最近開啟檔案（官方擴充包）
flash|flash.hx|0|copy|https://github.com/shybovycha/flash.hx.git|flash.scm|-|單字母跳轉，類似 flash.nvim
trail|trail.hx|0|forge|https://github.com/Ra77a3l3-jar/trail.hx.git|trail/trail.scm|-|最近專案選擇器
zen|zen-mode.hx|0|forge|https://github.com/notnmeyer/zen-mode.hx.git|zen-mode/zen-mode.scm|-|專注模式，置中並隱藏 gutter
scooter|scooter.hx|0|forge|https://github.com/thomasschafer/scooter.hx.git|scooter/scooter.scm|-|互動式尋找取代（會編譯 native library）
showkeys|showkeys.hx|0|forge|https://github.com/HeitorAugustoLN/showkeys.hx.git|showkeys/showkeys.scm|-|畫面上顯示按下的按鍵
scroll|smooth-scroll.hx|0|forge|https://github.com/thomasschafer/smooth-scroll.hx.git|smooth-scroll/smooth-scroll.scm|-|平滑捲動（C-d / C-u）
glyph|glyph.hx|0|forge|https://github.com/Ra77a3l3-jar/glyph.hx.git|-|-|圖示庫（forest 會自動依賴，通常不必單裝）
EOF
)"

plugin_field() {
  local id="$1" field="$2" line
  line="$(printf '%s\n' "$PLUGIN_CATALOG" | awk -F'|' -v id="$id" '$1==id {print; exit}')"
  [ -n "$line" ] || die "未知插件: $id"
  case "$field" in
    id) printf '%s\n' "$line" | cut -d'|' -f1 ;;
    name) printf '%s\n' "$line" | cut -d'|' -f2 ;;
    recommended) printf '%s\n' "$line" | cut -d'|' -f3 ;;
    method) printf '%s\n' "$line" | cut -d'|' -f4 ;;
    git) printf '%s\n' "$line" | cut -d'|' -f5 ;;
    require) printf '%s\n' "$line" | cut -d'|' -f6 ;;
    deps) printf '%s\n' "$line" | cut -d'|' -f7 ;;
    desc) printf '%s\n' "$line" | cut -d'|' -f8- ;;
    *) die "未知欄位: $field" ;;
  esac
}

all_ids() {
  printf '%s\n' "$PLUGIN_CATALOG" | awk -F'|' 'NF && $1 !~ /^#/ {print $1}'
}

recommended_ids() {
  printf '%s\n' "$PLUGIN_CATALOG" | awk -F'|' '$3==1 {print $1}'
}

list_plugins() {
  printf '%-10s %-8s %-22s %s\n' "ID" "建議" "套件" "說明"
  printf '%s\n' "$PLUGIN_CATALOG" | while IFS='|' read -r id name rec _method _git _req _deps desc; do
    [ -n "$id" ] || continue
    local mark="."
    [ "$rec" = "1" ] && mark="是"
    printf '%-10s %-8s %-22s %s\n' "$id" "$mark" "$name" "$desc"
  done
}

usage() {
  cat <<'EOF'
Helix Steel 插件安裝（與 install.sh 分開）。

用法:
  ./install-plugins.sh                 互動選單
  ./install-plugins.sh --recommended   安裝新手建議插件
  ./install-plugins.sh --all           安裝目錄內全部插件
  ./install-plugins.sh oil forest term 只安裝列出的 id
  ./install-plugins.sh --list          列出可選插件

互動多選:
  輸入編號切換勾選、a 只選建議、A 全選、n 清空、d 完成、q 取消
  若有 fzf，也可在選單選「fzf 多選」

建議插件（--recommended）:
  notify, oil, forest, term, watcher, streal, recentf
EOF
}

expand_deps() {
  local -a raw=("$@")
  local -a out=()
  local id dep
  local seen=" "

  add() {
    local x="$1"
    case "$seen" in
      *" $x "*) return 0 ;;
    esac
    seen="$seen$x "
    local deps
    deps="$(plugin_field "$x" deps)"
    if [ -n "$deps" ] && [ "$deps" != "-" ]; then
      local IFS=','
      for dep in $deps; do
        add "$dep"
      done
    fi
    out+=("$x")
  }

  for id in "${raw[@]}"; do
    add "$id"
  done
  printf '%s\n' "${out[@]}"
}

install_one() {
  local id="$1"
  local method giturl name
  method="$(plugin_field "$id" method)"
  giturl="$(plugin_field "$id" git)"
  name="$(plugin_field "$id" name)"
  log "安裝 $name ($id)"

  case "$method" in
    forge)
      have forge || die "找不到 forge。請先執行 ./install.sh helix"
      forge pkg install --git "$giturl"
      ;;
    copy)
      local tmp
      tmp="$(mktemp -d)"
      git clone --depth 1 "$giturl" "$tmp/src"
      mkdir -p "$HELIX_CONFIG"
      # flash.hx ships flash.scm at repo root
      if [ -f "$tmp/src/flash.scm" ]; then
        cp "$tmp/src/flash.scm" "$HELIX_CONFIG/flash.scm"
      else
        rm -rf "$tmp"
        die "$name 找不到要複製的 .scm"
      fi
      rm -rf "$tmp"
      ;;
    *)
      die "未知安裝方式: $method"
      ;;
  esac
}

plugin_init_extra() {
  local id="$1"
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
      cat <<'SCM'
(set-default-shell! "/bin/zsh")
SCM
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
    *)
      ;;
  esac
}

plugin_toml_keys() {
  local -a ids=("$@")
  local id
  local has_oil=0 has_forest=0 has_term=0 has_streal=0
  local has_flash=0 has_trail=0 has_recentf=0 has_scroll=0 has_scooter=0

  for id in "${ids[@]}"; do
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
  fi

  if [ "$has_streal" -eq 1 ]; then
    echo
    echo "[keys.select]"
    echo '"\\" = ":streal-open"'
  fi
}

plugin_scm_block() {
  local -a ids=("$@")
  local id req extra
  echo ";; generated by install-plugins.sh"
  echo ";; selected: ${ids[*]}"
  for id in "${ids[@]}"; do
    req="$(plugin_field "$id" require)"
    [ "$req" = "-" ] && continue
    printf '(require "%s")\n' "$req"
    extra="$(plugin_init_extra "$id")"
    [ -n "$extra" ] && printf '%s' "$extra"
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

write_configs() {
  local -a ids=("$@")
  ensure_init_base
  upsert_block "$HELIX_CONFIG/init.scm" \
    ';; >>> helix-steel-plugins' \
    ';; <<< helix-steel-plugins' \
    "$(plugin_scm_block "${ids[@]}")"
  upsert_block "$HELIX_CONFIG/config.toml" \
    '# >>> helix-steel-plugins' \
    '# <<< helix-steel-plugins' \
    "$(plugin_toml_keys "${ids[@]}")"
  log "已更新 $HELIX_CONFIG/init.scm 與 config.toml"
}

print_plugin_help() {
  local -a ids=("$@")
  local id
  echo
  echo "快捷鍵（已寫入 config.toml）:"
  for id in "${ids[@]}"; do
    case "$id" in
      oil) echo "  -           :oil              檔案管理器" ;;
      forest) echo "  Space e     :forest-open      側邊檔案樹" ;;
      term) echo "  Space t     :open-term        內嵌終端"
            echo "  Space T     :kill-active-terminal  關掉終端" ;;
      streal) echo "  \\           :streal-open      檔案書籤" ;;
      recentf) echo "  Space ,     :recentf-open-files  最近檔案" ;;
      flash) echo "  g /         :flash            單字母跳轉" ;;
      trail) echo "  Space ;     :trail-open       最近專案" ;;
      scooter) echo "  Space R     :scooter          尋找取代" ;;
      scroll) echo "  C-d / C-u   平滑半頁捲動" ;;
      zen) echo "  :zen-mode   專注模式（插件本身也綁 Space z）" ;;
      showkeys) echo "  :showkeys-toggle" ;;
      watcher) echo "  啟動時自動監看外部改檔" ;;
    esac
  done
}

interactive_menu() {
  echo
  echo "Helix Steel 插件"
  echo "  1) 安裝建議插件（新手上手）"
  echo "  2) 自行多選"
  echo "  3) 安裝全部"
  echo "  4) 略過"
  if have fzf; then
    echo "  5) fzf 多選"
  fi
  printf '選擇 [1]: '
  local choice
  read -r choice || true
  choice="${choice:-1}"
  case "$choice" in
    1) mapfile -t SELECTED < <(recommended_ids) ;;
    2) SELECTED=(); checkbox_select ;;
    3) mapfile -t SELECTED < <(all_ids) ;;
    4) SELECTED=(); return 0 ;;
    5)
      have fzf || die "找不到 fzf"
      fzf_select
      ;;
    *)
      die "無效選擇: $choice"
      ;;
  esac
}

checkbox_select() {
  local -a ids=()
  mapfile -t ids < <(all_ids)
  local -A on=()
  local id rec i
  for id in "${ids[@]}"; do
    rec="$(plugin_field "$id" recommended)"
    [ "$rec" = "1" ] && on["$id"]=1
  done

  while true; do
    echo
    echo "空白鍵以外：輸入編號切換、a 建議、A 全部、n 清空、d 完成、q 取消"
    i=1
    for id in "${ids[@]}"; do
      local mark=" "
      [ "${on[$id]:-0}" = "1" ] && mark="x"
      printf '  %2d) [%s] %-10s %s%s\n' \
        "$i" "$mark" "$id" "$(plugin_field "$id" desc)" \
        "$([ "$(plugin_field "$id" recommended)" = 1 ] && echo '  (建議)' || true)"
      i=$((i + 1))
    done
    printf '> '
    local ans
    read -r ans || exit 1
    case "$ans" in
      d | D | "")
        SELECTED=()
        for id in "${ids[@]}"; do
          [ "${on[$id]:-0}" = "1" ] && SELECTED+=("$id")
        done
        return 0
        ;;
      q | Q)
        echo "已取消"
        exit 1
        ;;
      a)
        on=()
        for id in "${ids[@]}"; do
          [ "$(plugin_field "$id" recommended)" = "1" ] && on["$id"]=1
        done
        ;;
      A)
        for id in "${ids[@]}"; do
          on["$id"]=1
        done
        ;;
      n)
        on=()
        ;;
      *)
        local n
        for n in $ans; do
          if [[ "$n" =~ ^[0-9]+$ ]] && [ "$n" -ge 1 ] && [ "$n" -le "${#ids[@]}" ]; then
            id="${ids[$((n - 1))]}"
            if [ "${on[$id]:-0}" = "1" ]; then
              on["$id"]=0
            else
              on["$id"]=1
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
  local line id
  local picks
  picks="$(
    printf '%s\n' "$PLUGIN_CATALOG" | awk -F'|' '{
      rec = ($3==1) ? "[建議] " : "       "
      printf "%s\t%s%s%s\n", $1, rec, $2, "  " $8
    }' | fzf --multi --ansi --delimiter='\t' --with-nth=2.. \
      --header 'Tab 多選，Enter 確認。建議插件已標示。' \
      --prompt 'plugins> ' || true
  )"
  SELECTED=()
  [ -n "$picks" ] || return 0
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    id="${line%%$'\t'*}"
    SELECTED+=("$id")
  done <<<"$picks"
}

install_selected() {
  local -a raw=("$@")
  local -a ids=()
  if [ "${#raw[@]}" -eq 0 ]; then
    log "未選擇插件"
    write_configs
    return 0
  fi
  mapfile -t ids < <(expand_deps "${raw[@]}")
  log "將安裝: ${ids[*]}"
  local id
  local -a failed=()
  for id in "${ids[@]}"; do
    if ! install_one "$id"; then
      failed+=("$id")
    fi
  done
  write_configs "${ids[@]}"
  print_plugin_help "${ids[@]}"
  if [ "${#failed[@]}" -gt 0 ]; then
    echo "以下插件安裝失敗: ${failed[*]}" >&2
    return 1
  fi
}

main() {
  local -a SELECTED=()
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
      --)
        shift
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

  mkdir -p "$HELIX_CONFIG"

  case "$mode" in
    recommended)
      mapfile -t SELECTED < <(recommended_ids)
      ;;
    all)
      mapfile -t SELECTED < <(all_ids)
      ;;
    args)
      SELECTED=("$@")
      local id
      for id in "${SELECTED[@]}"; do
        plugin_field "$id" name >/dev/null
      done
      ;;
    menu)
      if [ -t 0 ]; then
        interactive_menu
      else
        log "非互動模式，改裝建議插件"
        mapfile -t SELECTED < <(recommended_ids)
      fi
      ;;
  esac

  install_selected "${SELECTED[@]+"${SELECTED[@]}"}"
}

main "$@"
