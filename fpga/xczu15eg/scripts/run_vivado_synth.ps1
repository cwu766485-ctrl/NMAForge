param(
    [string]$Vivado = "vivado"
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
& $Vivado -mode batch -source (Join-Path $scriptDir "synth_ai_accel_ip.tcl")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
