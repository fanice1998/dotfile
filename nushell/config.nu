# config.nu
#
# Installed by:
# version = "0.113.1"
#
# This file is used to override default Nushell settings, define
# (or import) custom commands, or run any other startup tasks.
# See https://www.nushell.sh/book/configuration.html
#
# Nushell sets "sensible defaults" for most configuration settings,
# so your `config.nu` only needs to override these defaults if desired.
#
# You can open this file in your default editor using:
#     config nu
#
# You can also pretty-print and page through the documentation for configuration
# options using:
#     config nu --doc | nu-highlight | less -R
if $nu.is-interactive {
    fastfetch
}

# ============================================
# Go 環境設定（同時支援 Termux 與一般 Linux）
# ============================================
# Go 環境設定
let is_termux = ($nu.os-info.name == "android")
let home = $nu.home-dir

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
  let system_go_bin = "/usr/local/go/bin"
  if ($system_go_bin | path exists) {
      $env.PATH = ($env.PATH | prepend $system_go_bin)
  }
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
if ("/mnt/c" | path exists) {
  let cleaned_path = (
    $env.PATH
    | where not ($it | str starts-with "/mnt/c")
    | str join ":"
  )
  $env.PATH = $cleaned_path
}
