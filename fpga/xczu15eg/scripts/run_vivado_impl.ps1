param(
    [string]$Vivado = 'D:\Xilinx\Vivado\2024.1\bin\vivado.bat'
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

& $Vivado -mode batch -source (Join-Path $scriptDir 'synth_ai_accel_ip.tcl')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& $Vivado -mode batch -source (Join-Path $scriptDir 'implement_ai_accel_ip.tcl')
exit $LASTEXITCODE
