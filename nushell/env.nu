# env.nu
#
# Installed by:
# version = "0.113.1"
#
# Previously, environment variables were typically configured in `env.nu`.
# In general, most configuration can and should be performed in `config.nu`
# or one of the autoload directories.
#
# This file is generated for backwards compatibility for now.
# It is loaded before config.nu and login.nu
#
# See https://www.nushell.sh/book/configuration.html
#
# Also see `help config env` for more options.
#
# You can remove these comments if you want or leave
# them for future reference.

# EDITOR
$env.EDITOR = "hx"
$env.VISUAL = "hx"

# ============================================
# Go 環境設定（同時支援 Termux 與一般 Linux）
# ============================================
# Go 環境設定
let is_termux = ($nu.os-info.name == "android")
let home = $nu.home-path

# --- GOPATH 設定 ---
$env.GOPATH = ($home | path join "go")

# --- GOROOT ---
if $is_termux {
  let termux_usr = "/data/data/com.termux/files/usr"
  $env.GOROOT = ($termux_usr | path join "lib" "go")

  let termux_go_bin = ($termux_usr | path join "bin")
  if ($termux_go_bin | path exists) {
    $env.PATH = ($env.PATH | prepend $termux_go_bin)
  }
} else {
  $env.PATH = ($env.PATH | append '/usr/local/go/bin')
}

# --- $GOPATH/bin ---
let go_bin = ($env.GOPATH | path join "bin")
if ($go_bin | path exists) {
  $env.PATH = ($env.PATH | prepend $go_bin)
}

# 讓 Go 使用 Go Modules（推薦）
$env.GO111MODULE = "on"
$env.GOPROXY = "https://proxy.golang.org,direct"

# Close welcome message
$env.config.show_banner = false

# remove windows path for wsl
$env.PATH = (
  $env.PATH |
  where { |p|
    not ($p | str starts-with "/mnt/c") |
    uniq
  }
)
