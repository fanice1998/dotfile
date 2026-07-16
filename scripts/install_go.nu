#!/usr/sbin/nu
# =============================================
# Go 最新版自動安裝腳本（Linux amd64）
# 使用方式：sudo bash install_go.sh
# =============================================

# 1. 檢查是否有 sudo 權限
if  (groups | split row " " | ("sudo" in $in) or ("wheel" in $in) | $in != true) {
    print "❌ 請使用具備 sudo 權限執行此腳本！"
    exit 1
}

print "開始安裝最新版 Go ..."

# 2. 取得最新版本（官方端點）
print "📡 正在取得最新版本號..."
let version = (http get https://go.dev/VERSION?m=text | head -1)
print $"✅ 最新版本： ($version)"

let fileName = $"($version).linux-amd64.tar.gz"
let downloadUrl = $"https://go.dev/dl/($fileName)"

# 3. 移除舊版 Go（如果存在）
let result = (do -i { command go version } e>| complete)
if $result.exit_code == 0 or ('/usr/local/go' | path exists ) {
    let currentVer  = (do -i { /usr/local/go/bin/go version | awk '{print $3}' })
    
    echo $"⚠️  偵測到已安裝： ($currentVer)"
    echo "🗑️  正在移除舊版 /usr/local/go..."
    sudo rm -rf /usr/local/go
}

# 4. 下載最新版
print $"⬇️  下載中： ($downloadUrl)"
http get --raw $downloadUrl | save -pf $fileName
# -f 失敗就停止，-L 跟隨重定向，-O 自動命名

# 5. 解壓縮
echo "📦 解壓縮到 /usr/local/go..."
sudo tar -C /usr/local -xzf $fileName

# 6. 設定永久 PATH（支援 bash / zsh）
let nuConfig = $nu.env-path
echo "🔧 設定環境變數..."
let content = "\n\$env.PATH = \(\$env.PATH \| append '/usr/local/go/bin'\)"
if ($nuConfig | path exists) {
    $content | save --append $nuConfig
} else {
    print $"Not found nushell config ($nuConfig)"
    exit 1
}

# 7. 清理下載檔（可選）
rm -f ($fileName)

# 8. 最終驗證
print ""
print "🎉 安裝完成！"
go version

print ""
print $"✅ 請重新開啟終端機，或執行：source ($nuConfig)"
print "   之後就可以直接使用 go 指令了！"
