param(
    [ValidateSet("smoke", "ip", "bitstream", "program")]
    [string]$Target = "smoke",
    [string]$Part = "xc7a100tfgg484-2",
    [string]$Bitstream = "",
    [string]$HwServerUrl = "localhost:3121",
    [string]$VivadoPath = ""
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$env:FPGA_PART = $Part

$vivadoExe = $null
if (-not [string]::IsNullOrWhiteSpace($VivadoPath)) {
    $vivadoExe = $VivadoPath
} elseif (Get-Command vivado -ErrorAction SilentlyContinue) {
    $vivadoExe = (Get-Command vivado -ErrorAction Stop).Source
} elseif ($env:VIVADO_HOME -and (Test-Path (Join-Path $env:VIVADO_HOME "bin\vivado.bat"))) {
    $vivadoExe = Join-Path $env:VIVADO_HOME "bin\vivado.bat"
} else {
    $knownVivadoPaths = @(
        "D:\Xilinx\Vivado\2024.1\bin\vivado.bat",
        "C:\Xilinx\Vivado\2024.1\bin\vivado.bat"
    )
    $vivadoExe = $knownVivadoPaths | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}

if (-not $vivadoExe -or -not (Test-Path -LiteralPath $vivadoExe)) {
    throw "Vivado executable was not found. Use -VivadoPath 'D:\Xilinx\Vivado\2024.1\bin\vivado.bat' or start a Vivado-enabled shell (settings64.bat)."
}

function Invoke-VivadoBatch([string]$TclScript) {
    & $vivadoExe -mode batch -source $TclScript
    if ($LASTEXITCODE -ne 0) {
        throw "Vivado failed with exit code $LASTEXITCODE. Review the batch log above."
    }
}

if ($Target -eq "ip") {
    Invoke-VivadoBatch (Join-Path $scriptDir "synth_ai_accel_ip.tcl")
} elseif ($Target -eq "bitstream") {
    Invoke-VivadoBatch (Join-Path $scriptDir "build_smoke_bitstream.tcl")
} elseif ($Target -eq "program") {
    if ([string]::IsNullOrWhiteSpace($Bitstream)) {
        $Bitstream = Join-Path $scriptDir "..\build\smoke_bitstream\fpga_ai_accel_smoke_top.bit"
    }
    $resolvedBitstream = (Resolve-Path -LiteralPath $Bitstream -ErrorAction Stop).Path
    $env:FPGA_BITSTREAM = $resolvedBitstream
    $env:VIVADO_HW_SERVER_URL = $HwServerUrl
    Invoke-VivadoBatch (Join-Path $scriptDir "program_smoke_bitstream.tcl")
} else {
    Invoke-VivadoBatch (Join-Path $scriptDir "synth_smoke_top.tcl")
}
