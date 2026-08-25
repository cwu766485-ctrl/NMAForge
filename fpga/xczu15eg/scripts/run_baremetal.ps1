param(
    [string]$Xsct = $env:XSCT,
    [string]$Port = 'COM11',
    [int]$Baud = 115200,
    [int]$TimeoutSeconds = 90
)

if (!$Xsct) {
    $Xsct = (Get-Command xsct -ErrorAction Stop).Source
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$fpgaDir = Split-Path -Parent $scriptDir
$uartLog = Join-Path $fpgaDir 'build\board\baremetal_uart.log'
$jtagLog = Join-Path $fpgaDir 'build\board\baremetal_jtag.log'

$serialJob = Start-Job -ArgumentList $Port,$Baud,$TimeoutSeconds -ScriptBlock {
    param($PortName, $BaudRate, $Timeout)
    $serial = [IO.Ports.SerialPort]::new(
        $PortName, $BaudRate, [IO.Ports.Parity]::None, 8, [IO.Ports.StopBits]::One)
    $serial.ReadTimeout = 500
    $serial.NewLine = "`n"
    try {
        $serial.Open()
        $deadline = [DateTime]::UtcNow.AddSeconds($Timeout)
        while ([DateTime]::UtcNow -lt $deadline) {
            try {
                $line = $serial.ReadLine().TrimEnd("`r")
                Write-Output $line
                if ($line -match '^(PASS|FAIL):') { break }
            } catch [TimeoutException] {
            }
        }
    } finally {
        if ($serial.IsOpen) { $serial.Close() }
        $serial.Dispose()
    }
}
Start-Sleep -Milliseconds 500

& $Xsct (Join-Path $scriptDir 'jtag_run_baremetal.tcl')
$xsctStatus = $LASTEXITCODE
$jtagFailedEarly = (Test-Path $jtagLog) -and
    (Select-String -Quiet -Path $jtagLog -Pattern '^CIMFORGE_BAREMETAL_FAIL=')
if ($jtagFailedEarly) {
    Stop-Job -Job $serialJob
} else {
    Wait-Job -Job $serialJob -Timeout $TimeoutSeconds | Out-Null
}
$serialOutput = @(Receive-Job -Job $serialJob)
Remove-Job -Job $serialJob -Force
$serialOutput | Set-Content -LiteralPath $uartLog
$serialOutput | ForEach-Object { Write-Host $_ }

$jtagPassed = (Test-Path $jtagLog) -and
    (Select-String -Quiet -Path $jtagLog -Pattern '^CIMFORGE_BAREMETAL_PASS$')
$uartPassed = $serialOutput -match '^PASS: version/DDR DMA/CMDQ/VDOT/completion/IRQ all verified$'
if ($xsctStatus -ne 0 -or !$jtagPassed -or !$uartPassed) {
    Write-Error "CIMForge bare-metal validation failed; inspect $jtagLog and $uartLog"
    exit 1
}
exit 0
