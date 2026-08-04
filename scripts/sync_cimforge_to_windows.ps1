<#
.SYNOPSIS
    Synchronize the Linux CIMForge checkout to the Windows E: checkout.

.DESCRIPTION
    Intended to run in Windows PowerShell. It copies source, documents, scripts
    and .git metadata from a WSL distribution to E:\workspace\chip\CIMForge.
    It never mirrors/deletes destination-only files. Generated Vivado/Vitis
    outputs are excluded because they are reproducible and can be very large.
#>
[CmdletBinding()]
param(
    [string]$Distro = 'Rocky8.10',
    [string]$Source = '',
    [string]$Destination = 'E:\workspace\chip\CIMForge',
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
if (-not $Source) {
    $Source = "\\wsl$\$Distro\home\ray\ic\CIMForge"
}
if (-not (Test-Path -LiteralPath $Source)) {
    throw "找不到 WSL 源目录：$Source。请确认已执行 wsl -d $Distro，或用 -Source 指定路径。"
}
New-Item -ItemType Directory -Force -Path $Destination | Out-Null

$excludeDirs = @('.srcs', 'build', 'tmp', '.runs', 'simv.daidir', 'csrc')
$excludeFiles = @('*.log', '*.jou', '*.str', '*.7z', '*.zip', '*.tar', '*.tar.gz', '*.dcp', '*.bit')
$args = @($Source, $Destination, '/E', '/COPY:DAT', '/DCOPY:DAT', '/R:1', '/W:1', '/XJ', '/FFT')
foreach ($dir in $excludeDirs) { $args += '/XD'; $args += (Join-Path $Source $dir) }
foreach ($file in $excludeFiles) { $args += '/XF'; $args += $file }
if ($DryRun) { $args += '/L' }

Write-Host "同步源：$Source"
Write-Host "同步目标：$Destination"
Write-Host "保留目标独有文件；排除生成目录和大文件。"
& robocopy @args
$code = $LASTEXITCODE
if ($code -gt 7) { throw "robocopy 失败，退出码：$code" }
Write-Host "同步完成，robocopy 退出码：$code（0-7 均表示成功或有可接受差异）。"
