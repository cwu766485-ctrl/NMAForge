param([string]$Vivado = $env:VIVADO)

if (!$Vivado) {
    $Vivado = (Get-Command vivado -ErrorAction Stop).Source
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$fpgaDir = Split-Path -Parent $scriptDir
$log = Join-Path $fpgaDir 'build\board\ila_validation.log'
& $Vivado -mode batch -source (Join-Path $scriptDir 'verify_ila.tcl')
$vivadoStatus = $LASTEXITCODE
$passed = (Test-Path $log) -and
    (Select-String -Quiet -Path $log -Pattern '^CIMFORGE_ILA_VALIDATION_PASS$')
if ($vivadoStatus -ne 0 -or !$passed) {
    Write-Error "CIMForge ILA validation failed; inspect $log"
    exit 1
}
exit 0
