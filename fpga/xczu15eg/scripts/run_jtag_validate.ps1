param(
    [string]$Xsct = 'D:\Xilinx\Vitis\2024.1\bin\xsct.bat'
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
& $Xsct (Join-Path $scriptDir 'jtag_validate.tcl')
$xsctStatus = $LASTEXITCODE
$logFile = Join-Path (Split-Path -Parent $scriptDir) 'build\board\hw_validation.log'
if ($xsctStatus -ne 0) {
    exit $xsctStatus
}
if (!(Test-Path $logFile) -or !(Select-String -Quiet -Path $logFile -Pattern '^CIMFORGE_HW_VALIDATION_PASS$')) {
    Write-Error "CIMForge hardware validation did not report PASS: $logFile"
    exit 1
}
exit 0
