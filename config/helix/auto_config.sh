#!/bin/bash

# ==================================
#         LSP 安裝腳本
# ==================================

# 檢查權限 (Linux/macOS)
# if [[ "$OSTYPE" == "linux-gnu"* || "$OSTYPE" == "darwin"* ]]; then
#     if [[ $EUID -ne 0 ]]; then
#         echo "此腳本需要管理員權限來安裝全域套件。"
#         echo "將使用 sudo 執行安裝指令。"
#     fi
# fi
rust_use=1
go_use=1
nodejs_use=1
python_use=1

# 檢查指令是否存在並提供安裝提示
check_command() {
    local cmd="$1"
    local install_hint="$2"
    if ! command -v $cmd >/dev/null; then
        echo "錯誤: 未找到指令 '$cmd'。"
        echo "請先安裝 '$cmd' ($install_hint)，然後再運行此腳本。"
        exit 1
    fi
}

# 下載檔案的函數
download_file() {
    local url="$1"
    local dest_path="$2"
    echo "-> 正在下載 $url 到 $dest_path..."
    if command -v curl &> /dev/null; then
        curl -sSLo "$dest_path" "$url"
    elif command -v wget &> /dev/null; then
        wget -qO "$dest_path" "$url"
    else
        echo "錯誤: 未找到 'curl' 或 'wget' 指令。無法下載配置文件。"
        return 1
    fi

    if [ $? -eq 0 ]; then
        echo "-> 下載成功！"
        return 0
    else
        echo "錯誤: 下載失敗！請檢查 URL 或網路連線。"
        return 1
    fi
}

echo "正在檢查必要的套件管理工具..."
# Check use rust
if [ $rust_use -eq 1 ]; then
    check_command rustup "參考 Rust 官方網站安裝：https://www.rust-lang.org/tools/install"
    check_command cargo "通常隨 rustup 一起安裝"
fi

# Check use go
if [ $go_use -eq 1 ]; then
    check_command go "參考 Go 官方網站安裝：https://go.dev/dl/"
fi

# Check use node.js
if [ $nodejs_use -eq 1 ]; then
    check_command npm "參考 Node.js 官方網站安裝：https://nodejs.org/"
    check_command node "參考 Node.js 官方網站安裝：https://nodejs.org/"
fi

# Check use python
if [ $python_use -eq 1 ]; then
    check_command pip "通常隨 Python 一起安裝"
fi

check_command curl "參考 https://curl.se/ 下載"
check_command wget "參考 https://www.gnu.org/software/wget/ 下載"

# 針對 npm 和 pip 檢查 sudo 權限下的 PATH 問題
check_sudo_path() {
    local cmd="$1"
    local test_cmd="$2"
    echo "-> 檢查 '$cmd' 在 sudo 權限下是否可用..."
    if [[ "$OSTYPE" == "linux-gnu"* || "$OSTYPE" == "darwin"* ]]; then
        if ! sudo -n "$test_cmd" &> /dev/null; then
            echo "警告: 'sudo $cmd' 似乎無法找到 '$cmd' 指令。"
            echo "這通常是因為 sudo 的 PATH 環境變數不包含 npm/pip 的安裝路徑。"
            echo "請確認您的 sudoers 配置 (例如 /etc/sudoers 或 /etc/sudoers.d/ 中的文件) 包含 npm/pip 的全域安裝路徑。"
            echo "例如，對於 npm，通常是 /usr/local/bin 或 ~/.npm-global/bin。"
            echo "腳本將嘗試使用 'which $cmd' 找到的完整路徑來執行，但如果 sudoers 限制過嚴，可能仍然會失敗。"
        else
            echo "-> '$cmd' 在 sudo 權限下可用。"
        fi
    fi
}

if [ $nodejs_use -eq 1 ]; then
    check_sudo_path npm "npm -v"
    check_sudo_path node "node -v"
fi

if [ $python_use -eq 1]; then
    check_sudo_path pip "pip -V"
fi

echo "開始安裝 LSP 和相關工具..."

# 安裝 Rust 工具
if [ $rust_use -eq 1 ]; then
    echo "-> 安裝 Rust linter: clippy..."
    rustup component add clippy
    echo "-> Rust linter: clippy 安裝成功！"
fi

# 安裝 Go LSP
if [ $go_use -eq 1 ]; then
    echo "-> 安裝 Go LSP: gopls..."
    go install golang.org/x/tools/gopls@latest
    echo "-> Go LSP: gopls 安裝成功！"
fi

# 安裝 Python LSP
if [ $python_use -eq 1 && nodejs_use -eq 1 ]; then
    echo "-> 安裝 Python LSP: pyright..."
    if [[ "$OSTYPE" == "linux-gnu"* || "$OSTYPE" == "darwin"* ]]; then
        NPM_PATH=$(which npm)
        NODE_PATH=$(which node)

        if [[ -z "$NPM_PATH" ]]; then
            echo "錯誤: 無法找到 npm 的路徑，請檢查您的 PATH 環境變數。"
            exit 1
        fi
        if [[ -z "$NODE_PATH" ]]; then
            echo "錯誤: 無法找到 node 的路徑，請檢查您的 PATH 環境變數。"
            exit 1
        fi

        echo "嘗試以當前用戶權限安裝 pyright..."
        "$NPM_PATH" install -g pyright
        if [ $? -eq 0 ]; then
            echo "-> Python LSP: pyright 安裝成功！(無需 sudo)"
        else
            echo "嘗試以當前用戶權限安裝 pyright 失敗，嘗試使用 sudo..."
            sudo env PATH="$PATH:$(dirname "$NODE_PATH")" "$NPM_PATH" install -g pyright
            if [ $? -eq 0 ]; then
                echo "-> Python LSP: pyright 安裝成功！(已使用 sudo)"
            else
                echo "錯誤: 無法安裝 Python LSP: pyright。請檢查 npm 和 node 的安裝及 sudo 權限。"
                exit 1
            fi
        fi
    elif [[ "$OSTYPE" == "msys" ]]; then
        npm install -g pyright
        echo "-> Python LSP: pyright 安裝成功！"
    fi
fi

# 安裝 JavaScript/HTML/CSS LSP
if [ $nodejs_use -eq 1]; then
    echo "-> 安裝 JavaScript/HTML/CSS LSP..."
    if [[ "$OSTYPE" == "linux-gnu"* || "$OSTYPE" == "darwin"* ]]; then
        NPM_PATH=$(which npm)
        NODE_PATH=$(which node)

        if [[ -z "$NPM_PATH" ]]; then
            echo "錯誤: 無法找到 npm 的路徑，請檢查您的 PATH 環境變數。"
            exit 1
        fi
        if [[ -z "$NODE_PATH" ]]; then
            echo "錯誤: 無法找到 node 的路徑，請檢查您的 PATH 環境變數。"
            exit 1
        fi

        echo "嘗試以當前用戶權限安裝 JavaScript/HTML/CSS LSP..."
        "$NPM_PATH" install -g typescript-language-server vscode-html-languageserver-bin vscode-css-languageserver-bin
        if [ $? -eq 0 ]; then
            echo "-> JavaScript/HTML/CSS LSP 安裝成功！(無需 sudo)"
        else
            echo "嘗試以當前用戶權限安裝 JavaScript/HTML/CSS LSP 失敗，嘗試使用 sudo..."
            sudo env PATH="$PATH:$(dirname "$NODE_PATH")" "$NPM_PATH" install -g typescript-language-server vscode-html-languageserver-bin vscode-css-languageserver-bin
            if [ $? -eq 0 ]; then
                echo "-> JavaScript/HTML/CSS LSP 安裝成功！(已使用 sudo)"
            else
                echo "錯誤: 無法安裝 JavaScript/HTML/CSS LSP。請檢查 npm 和 node 的安裝及 sudo 權限。"
                exit 1
            fi
        fi
    elif [[ "$OSTYPE" == "msys" ]]; then
        npm install -g typescript-language-server
        npm install -g vscode-html-languageserver-bin
        npm install -g vscode-css-languageserver-bin
        echo "-> JavaScript/HTML/CSS LSP 安裝成功！"
    fi
fi

# --- 自動建立 Helix 配置檔案 ---
echo "正在自動建立 Helix 配置檔案..."

# 確定 Helix 配置目錄
HELIX_CONFIG_DIR=""
if [[ "$OSTYPE" == "linux-gnu"* || "$OSTYPE" == "darwin"* ]]; then
    HELIX_CONFIG_DIR="$HOME/.config/helix"
elif [[ "$OSTYPE" == "msys" ]]; then
    HELIX_CONFIG_DIR="$APPDATA/helix"
fi

mkdir -p "$HELIX_CONFIG_DIR"

# 下載 config.toml
CONFIG_TOML_URL="https://raw.githubusercontent.com/fanice1998/setup/main/helix/config.toml"
download_file "$CONFIG_TOML_URL" "$HELIX_CONFIG_DIR/config.toml"

# 下載 languages.toml
LANGUAGES_TOML_URL="https://raw.githubusercontent.com/fanice1998/setup/main/helix/languages.toml"
download_file "$LANGUAGES_TOML_URL" "$HELIX_CONFIG_DIR/languages.toml"

# 創建 themes 目錄並下載 transparent.toml
echo "-> 創建 Helix themes 目錄並下載 transparent.toml..."
mkdir -p "$HELIX_CONFIG_DIR/themes"
THEME_TOML_URL="https://raw.githubusercontent.com/fanice1998/setup/main/helix/themes/transparent.toml"
download_file "$THEME_TOML_URL" "$HELIX_CONFIG_DIR/themes/transparent.toml"

# 更新 config.toml 以使用 transparent 主題
echo "-> 更新 config.toml 以使用 transparent 主題..."
if [[ -f "$HELIX_CONFIG_DIR/config.toml" ]]; then
    # 檢查是否已有 theme 設置
    if grep -q '^theme = ' "$HELIX_CONFIG_DIR/config.toml"; then
        # 使用 sed 替換現有的 theme 設置
        sed -i'' -e 's/^theme = .*/theme = "transparent"/' "$HELIX_CONFIG_DIR/config.toml"
    else
        # 如果沒有 theme 設置，追加一行
        echo 'theme = "transparent"' >> "$HELIX_CONFIG_DIR/config.toml"
    fi
else
    echo 'theme = "transparent"' > "$HELIX_CONFIG_DIR/config.toml"
fi

echo "所有 LSP 已安裝完成，且 Helix 配置檔案與 transparent 主題已自動建立！"
echo "您現在可以啟動 Helix 編輯器來體驗透明背景與其他功能。"
echo "請確保您的終端（如 iTerm2）已啟用透明背景（Preferences > Profiles > Window > Transparency）。"
