param(
    [string]$Vivado = 'D:\Xilinx\Vivado\2024.1\bin\vivado.bat'
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
& $Vivado -mode batch -source (Join-Path $scriptDir 'build_board.tcl')
exit $LASTEXITCODE
