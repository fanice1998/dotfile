# Install zjstatus.wasm for this Zellij config (Windows PowerShell 5+ / pwsh).
#
# Usage:
#   .\install.ps1
#   .\install.ps1 -Tag v0.25.0

[CmdletBinding()]
param(
    [string]$Tag = "latest"
)

$ErrorActionPreference = "Stop"

$Repo = "dj95/zjstatus"
$Asset = "zjstatus.wasm"

if ($Tag -eq "latest") {
    $Url = "https://github.com/$Repo/releases/latest/download/$Asset"
} else {
    $Url = "https://github.com/$Repo/releases/download/$Tag/$Asset"
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoPlugins = Join-Path $ScriptDir "plugins"
$HomePlugins = Join-Path $HOME ".config\zellij\plugins"

function Save-Wasm([string]$DestDir) {
    New-Item -ItemType Directory -Force -Path $DestDir | Out-Null
    $dest = Join-Path $DestDir $Asset
    Write-Host "downloading $Url"
    Write-Host "       -> $dest"
    Invoke-WebRequest -Uri $Url -OutFile $dest -UseBasicParsing
    $item = Get-Item $dest
    if ($item.Length -lt 10000) {
        Remove-Item $dest -Force
        throw "download looks too small ($($item.Length) bytes); GitHub may have returned an error page"
    }
    Write-Host "installed $dest ($($item.Length) bytes)"
    return $dest
}

function Copy-IfDifferent([string]$Src, [string]$DestDir) {
    New-Item -ItemType Directory -Force -Path $DestDir | Out-Null
    $dest = Join-Path $DestDir $Asset
    $srcFull = (Resolve-Path $Src).Path
    $destFull = [System.IO.Path]::GetFullPath($dest)
    if ($srcFull -eq $destFull) {
        return
    }
    Copy-Item -Force $Src $dest
    Write-Host "copied -> $dest"
}

Write-Host "OS: $($PSVersionTable.OS) $($env:PROCESSOR_ARCHITECTURE)"
$installed = Save-Wasm $RepoPlugins
Copy-IfDifferent $installed $HomePlugins

$zellij = Get-Command zellij -ErrorAction SilentlyContinue
if ($zellij) {
    $check = & $zellij.Source setup --check 2>$null
    $configDir = ($check | Select-String -Pattern '^\[CONFIG DIR\]: "(.*)"').Matches.Groups[1].Value
    if ($configDir) {
        Copy-IfDifferent $installed (Join-Path $configDir "plugins")
        Write-Host "zellij config dir: $configDir"
    }
}

Write-Host ""
Write-Host "done. start a new zellij session to load zjstatus."
Write-Host "first run: click the bottom bar and press y to grant permissions."
