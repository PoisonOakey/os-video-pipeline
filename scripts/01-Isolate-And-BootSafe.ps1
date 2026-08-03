#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Phase 1: Environment Preparation and Network Isolation.
.DESCRIPTION
    Downloads DDU, disables physical network adapters, and reboots into Safe Mode.
    Includes automated transcript logging and fail-safe error handling.
#>

# 1. Force all silent errors to instantly trigger the Catch block
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

function Assert-NativeSuccess {
    param([string]$What)
    if ($LASTEXITCODE -ne 0) { throw "$What failed with exit code $LASTEXITCODE." }
}

# 2. Establish Logging
$DDUFolder = "C:\DDU"
if (-not (Test-Path $DDUFolder)) { New-Item -ItemType Directory -Path $DDUFolder | Out-Null }

$LogPath = "$DDUFolder\Phase1_Log_$(Get-Date -Format 'yyyyMMdd_HHmm').txt"
Start-Transcript -Path $LogPath -Append -Force

# 3. The "Try" Block: Execute the dangerous code
try {
    Write-Information "[+] Phase 1: Deploying infrastructure and fetching DDU..."
    Set-Location -Path $DDUFolder
    
    $DDUExeName = "Display Driver Uninstaller.exe"
    $DDUExe = Get-ChildItem -Path $DDUFolder -Filter $DDUExeName -Recurse -ErrorAction SilentlyContinue |
              Select-Object -First 1

    if (-not $DDUExe) {
        Write-Information "    [-] Downloading payload..."
        $Sfx = Join-Path $DDUFolder "DDU-18.0.7.4.exe"
        curl.exe -fL -o $Sfx "https://www.wagnardsoft.com/DDU/download/DDU%20v18.0.7.4.exe"
        Assert-NativeSuccess "DDU download"

        $Head = [System.IO.File]::ReadAllBytes($Sfx)[0..1]
        if ([char]$Head[0] -ne 'M' -or [char]$Head[1] -ne 'Z') {
            throw "Downloaded file is not a Windows executable (missing MZ header). Got a redirect or error page?"
        }

        Write-Information "    [-] Extracting SFX archive..."
        & $Sfx -y | Out-Null
        Assert-NativeSuccess "DDU SFX extraction"

        $DDUExe = Get-ChildItem -Path $DDUFolder -Filter $DDUExeName -Recurse -ErrorAction SilentlyContinue |
                  Select-Object -First 1
    }

    if (-not $DDUExe) { throw "DDU binary not found under $DDUFolder after extraction." }
    Write-Information "    [-] DDU resolved: $($DDUExe.FullName)"

    Write-Information "[+] Configuring system for Safe Mode boot state..."
    bcdedit /set "{current}" safeboot minimal | Out-Null
    Assert-NativeSuccess "bcdedit safeboot"

    Write-Information "[+] Isolating physical network adapters..."
    Get-NetAdapter -Physical | Where-Object Status -ne 'Disabled' |
        Select-Object -ExpandProperty Name | Set-Content "$DDUFolder\adapters.txt"
    Disable-NetAdapter -Physical -Confirm:$false

    Write-Information "[!] Phase 1 Complete. Restarting into Safe Mode in 5 seconds..."
    Start-Sleep -Seconds 5
    Restart-Computer
}
# 4. The "Catch" Block: If ANYTHING fails above, execution instantly jumps here
catch {
    Write-Information "`n[X] CRITICAL PIPELINE FAILURE"
    Write-Information "Error Details: $($_.Exception.Message)"
    Write-Information "[!] Aborting Safe Mode reboot to prevent system stranding."
    # Failsafe: Attempt to turn Wi-Fi back on in case it failed right after disabling it
    Enable-NetAdapter -Physical -Confirm:$false -ErrorAction SilentlyContinue
    if (Get-NetAdapter -Physical | Where-Object Status -eq 'Disabled') {
        Write-Information "[X] NETWORK STILL DOWN. Run manually: Enable-NetAdapter -Physical -Confirm:`$false"
    }
    bcdedit /deletevalue "{current}" safeboot | Out-Null
}
# 5. The "Finally" Block: This runs no matter what happens
finally {
    Write-Information "[+] Stopping transcript log..."
    Stop-Transcript
}