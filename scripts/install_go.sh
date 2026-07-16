#!/bin/bash
# =============================================
# Go 最新版自動安裝腳本（Linux amd64）
# 使用方式：sudo bash install_go.sh
# =============================================

set -e  # 發生錯誤立即停止

# 1. 檢查是否為 root
if [ "$EUID" -ne 0 ]; then
    echo "❌ 請使用 sudo 執行此腳本！"
    echo "正確用法：sudo bash install_go.sh"
    exit 1
fi

echo "開始安裝最新版 Go ..."

# 2. 取得最新版本（官方端點）
echo "📡 正在取得最新版本號..."
version=$(curl -s https://go.dev/VERSION?m=text | head -1)
echo "✅ 最新版本：$version"

download_url="https://go.dev/dl/${version}.linux-amd64.tar.gz"
filename="${version}.linux-amd64.tar.gz"

# 3. 移除舊版 Go（如果存在）
if command -v go &> /dev/null; then
    current_ver=$(go version | awk '{print $3}')
    echo "⚠️  偵測到已安裝：$current_ver"
    echo "🗑️  正在移除舊版 /usr/local/go ..."
    rm -rf /usr/local/go
fi

# 4. 下載最新版
echo "⬇️  下載中：$download_url"
curl -fLO "$download_url"   # -f 失敗就停止，-L 跟隨重定向，-O 自動命名

# 5. 解壓縮
echo "📦 解壓縮到 /usr/local/go ..."
tar -C /usr/local -xzf "$filename"

# 6. 設定永久 PATH（支援 bash / zsh）
echo "🔧 設定環境變數..."
echo 'export PATH=$PATH:/usr/local/go/bin' >> "$HOME/.bashrc"
if [ -f "$HOME/.zshrc" ]; then
    echo 'export PATH=$PATH:/usr/local/go/bin' >> "$HOME/.zshrc"
fi

# 7. 立即生效（當前 shell）
export PATH=$PATH:/usr/local/go/bin

# 8. 清理下載檔（可選）
rm -f "$filename"

# 9. 最終驗證
echo ""
echo "🎉 安裝完成！"
go version

echo ""
echo "✅ 請重新開啟終端機，或執行：source ~/.bashrc"
echo "   之後就可以直接使用 go 指令了！"
