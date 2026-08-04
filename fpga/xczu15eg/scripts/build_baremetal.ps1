param(
    [string]$Xsct = 'D:\Xilinx\Vitis\2024.1\bin\xsct.bat',
    [string]$VitisRoot = 'D:\Xilinx\Vitis\2024.1'
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$fpgaDir = Split-Path -Parent $scriptDir
$repoRoot = Split-Path -Parent (Split-Path -Parent $fpgaDir)
$buildRoot = [IO.Path]::GetFullPath((Join-Path $fpgaDir 'build'))
$outputDir = [IO.Path]::GetFullPath((Join-Path $buildRoot 'baremetal'))
if (!$outputDir.StartsWith($buildRoot + [IO.Path]::DirectorySeparatorChar,
                          [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to replace software output outside FPGA build root: $outputDir"
}
if (Test-Path -LiteralPath $outputDir) {
    Remove-Item -LiteralPath $outputDir -Recurse -Force
}

& $Xsct (Join-Path $scriptDir 'generate_baremetal.tcl')
$toolchain = Join-Path $VitisRoot 'gnu\aarch64\nt\aarch64-none\bin'
$finalBringup = Join-Path $outputDir 'cimforge_bringup.elf'
$finalFsbl = Join-Path $outputDir 'cimforge_fsbl.elf'
if (!(Test-Path $finalBringup) -or !(Test-Path $finalFsbl)) {
    throw "HSI did not generate the expected bring-up/FSBL ELFs under $outputDir"
}

$readelf = Join-Path $toolchain 'aarch64-none-elf-readelf.exe'
$segments = & $readelf -l $finalBringup
if ($LASTEXITCODE -ne 0 -or !($segments -match 'Entry point 0x[1-9a-fA-F]')) {
    throw "Unable to verify the bring-up ELF load address"
}
$segments | Set-Content -LiteralPath (Join-Path $outputDir 'cimforge_bringup.readelf.txt')
Write-Host "Generated $finalFsbl"
Write-Host "Generated $finalBringup"
