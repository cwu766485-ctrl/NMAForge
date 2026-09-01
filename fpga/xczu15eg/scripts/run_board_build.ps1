param([string]$Vivado = $env:VIVADO)

if (!$Vivado) {
    $Vivado = (Get-Command vivado -ErrorAction Stop).Source
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
& $Vivado -mode batch -source (Join-Path $scriptDir 'build_board.tcl')
exit $LASTEXITCODE
