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

# 讓 Go 使用 Go Modules（推薦）
$env.GO111MODULE = "on"
$env.GOPROXY = "https://proxy.golang.org,direct"

# Close welcome message
$env.config.show_banner = false
