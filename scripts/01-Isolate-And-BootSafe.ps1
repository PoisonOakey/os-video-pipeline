#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Phase 1: Environment Preparation and Network Isolation.
.DESCRIPTION
    Optionally uninstalls DisplayLink for a clean rebuild, then prompts for the escalation
    tier. Declining reboots straight to Phase 3. Accepting downloads DDU, sets the Safe Mode
    boot flag, isolates physical network adapters, and reboots into Safe Mode for Phase 2.
    Includes automated transcript logging and fail-safe error handling.
#>

# 1. Force all silent errors to instantly trigger the Catch block
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

# Refuse to run under WOW64. In the 32-bit host, C:\Windows\System32 redirects to
# SysWOW64, which has no bcdedit.exe, so boot configuration cannot be reached at all.
if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess) {
    throw "This must run in 64-bit PowerShell. You are in the 32-bit (x86) host, where System32 redirects to SysWOW64 and bcdedit.exe is unreachable. Launch 'Windows PowerShell' - not 'Windows PowerShell (x86)' - as Administrator."
}

function Assert-NativeSuccess {
    param([string]$What)
    if ($LASTEXITCODE -ne 0) { throw "$What failed with exit code $LASTEXITCODE." }
}

function Uninstall-IfPresent {
    param([string]$Id, [string[]]$ExtraArgs)
    winget list -e --id $Id | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Information "    [-] $Id not installed - nothing to remove."
        return
    }
    winget uninstall -e --id $Id --silent @ExtraArgs
    Assert-NativeSuccess "winget uninstall $Id"
}

# Resolve System32 binaries by absolute path. A profile that rewrites $env:PATH can
# leave System32 off it, and 'bcdedit' then fails with CommandNotFoundException.
$BcdEdit = Join-Path $env:WINDIR "System32\bcdedit.exe"
if (-not (Test-Path $BcdEdit)) { throw "bcdedit.exe not found at $BcdEdit." }

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

    # Remove DisplayLink BEFORE the reboot. Phase 3 reinstalls it clean.
    # A corrupted-but-present install is the exact case this pipeline exists to fix,
    # and Phase 3's presence check cannot detect corruption - only absence.
    Write-Warning "This will UNINSTALL DisplayLink Graphics and Manager before the purge."
    Write-Warning "Your DisplayLink monitor will go dark until Phase 3 completes. Use the laptop panel for Phase 2."
    $choice = Read-Host "Uninstall DisplayLink for a clean rebuild? (y/N)"
    if ($choice -notmatch "^[yY]") {
        Write-Information "[!] Keeping DisplayLink installed - Phase 3 will skip install and leave the current version in place."
    } else {
        Write-Information "[+] Removing DisplayLink packages for a clean rebuild..."
        Uninstall-IfPresent -Id "DisplayLink.GraphicsDriver"
        Uninstall-IfPresent -Id "9N09F8V8FS02" -ExtraArgs @("--source", "msstore")
    }

    # Tier 2 is opt-in. Reinstalling DisplayLink alone resolves the common case; purging the
    # GPU driver stack is the escalation for when it does not. Only this branch touches boot
    # configuration, so declining keeps the blast radius to a package reinstall.
    Write-Warning "DEEP PURGE wipes the NVIDIA and Intel driver stacks with DDU from Safe Mode."
    Write-Warning "Only do this if reinstalling DisplayLink alone did not fix the display."
    $deepPurge = Read-Host "Run the deep GPU driver purge in Safe Mode? (y/N)"

    if ($deepPurge -notmatch "^[yY]") {
        Write-Information "[!] Skipping deep purge. Boot configuration and network left untouched."
        # Clear any stale record so Phase 3 does not try to restore adapters this run never disabled.
        Remove-Item "$DDUFolder\adapters.txt" -ErrorAction SilentlyContinue
        Write-Information "[!] Phase 1 Complete. Rebooting in 5 seconds - then run 03-Deploy-DisplayLink.ps1."
    } else {
        Write-Information "[+] Configuring system for Safe Mode boot state..."
        & $BcdEdit /set "{current}" safeboot minimal | Out-Null
        Assert-NativeSuccess "bcdedit safeboot"

        Write-Information "[+] Isolating physical network adapters..."
        # Only capture adapters that are actually Up. 'Not Present' adapters (e.g. a Realtek
        # GbE port with no hardware attached) would otherwise be recorded here and then throw
        # in Phase 3 when Enable-NetAdapter is called against them.
        $ActiveAdapters = @(Get-NetAdapter -Physical | Where-Object Status -eq 'Up')
        if (-not $ActiveAdapters) { throw "No physical network adapters are Up - nothing to isolate. Aborting before boot config change." }

        $ActiveAdapters | Select-Object -ExpandProperty Name | Set-Content "$DDUFolder\adapters.txt"
        Write-Information "    [-] Recorded for restore: $($ActiveAdapters.Name -join ', ')"
        $ActiveAdapters | Disable-NetAdapter -Confirm:$false

        Write-Information "[!] Phase 1 Complete. Restarting into Safe Mode in 5 seconds - then run 02-Purge-Drivers.ps1."
    }

    Start-Sleep -Seconds 5
    Restart-Computer
}
# 4. The "Catch" Block: If ANYTHING fails above, execution instantly jumps here
catch {
    Write-Information "`n[X] CRITICAL PIPELINE FAILURE"
    Write-Information "Error Details: $($_.Exception.Message)"
    Write-Information "[!] Aborting Safe Mode reboot to prevent system stranding."
    # Failsafe: Attempt to turn Wi-Fi back on in case it failed right after disabling it
    Get-NetAdapter -Physical | Enable-NetAdapter -Confirm:$false -ErrorAction SilentlyContinue
    if (Get-NetAdapter -Physical | Where-Object Status -eq 'Disabled') {
        Write-Information "[X] NETWORK STILL DOWN. Run manually: Get-NetAdapter -Physical | Enable-NetAdapter -Confirm:`$false"
    }
    & $BcdEdit /deletevalue "{current}" safeboot | Out-Null
}
# 5. The "Finally" Block: This runs no matter what happens
finally {
    Write-Information "[+] Stopping transcript log..."
    Stop-Transcript
}