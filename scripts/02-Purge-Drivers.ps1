#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Phase 2: Dual-GPU Driver Purge.
.DESCRIPTION
    Executes a silent DDU wipe for NVIDIA and Intel within Safe Mode.
    Includes automated transcript logging and a fail-safe to prevent Safe Mode boot loops.
#>

# 1. Force all silent errors to instantly trigger the Catch block
$ErrorActionPreference = 'Stop'

# Refuse to run under WOW64. In the 32-bit host, C:\Windows\System32 redirects to
# SysWOW64, which has no bcdedit.exe, so boot configuration cannot be reached at all.
if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess) {
    throw "This must run in 64-bit PowerShell. You are in the 32-bit (x86) host, where System32 redirects to SysWOW64 and bcdedit.exe is unreachable. Launch 'Windows PowerShell' - not 'Windows PowerShell (x86)' - as Administrator."
}

function Assert-NativeSuccess {
    param([string]$What)
    if ($LASTEXITCODE -ne 0) { throw "$What failed with exit code $LASTEXITCODE." }
}

# Resolve System32 binaries by absolute path. A profile that rewrites $env:PATH can
# leave System32 off it, and 'bcdedit' then fails with CommandNotFoundException.
$BcdEdit = Join-Path $env:WINDIR "System32\bcdedit.exe"
if (-not (Test-Path $BcdEdit)) { throw "bcdedit.exe not found at $BcdEdit." }

$DDUFolder = "C:\DDU"
$LogPath = "$DDUFolder\Phase2_Log.txt"
Start-Transcript -Path $LogPath -Append -Force

# 2. The "Try" Block: Execute the dangerous code
try {
    if (-not (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SafeBoot\Option" -ErrorAction SilentlyContinue)) {
        throw "Safe Mode environment not detected. Aborting purge to protect live system."
    }

    Write-Host "[+] Phase 2: Safe Mode confirmed. Initiating silent DDU purge..."

    $DDUExe = Get-ChildItem -Path $DDUFolder -Filter "Display Driver Uninstaller.exe" -Recurse -ErrorAction SilentlyContinue |
              Select-Object -First 1
    if (-not $DDUExe) { throw "DDU not found under $DDUFolder - did Phase 1 finish extracting?" }

    # DDU is a GUI application (PE subsystem 2). The call operator does not wait for GUI
    # processes and never sets $LASTEXITCODE, so '& $DDUExe ...' returned instantly with a
    # null exit code while the purge ran on detached in the background - which would have
    # let this script reboot the machine mid-purge. Start-Process -Wait is required.
    Write-Host "    [-] Evicting NVIDIA driver allocations..."
    $nvidia = Start-Process -FilePath $DDUExe.FullName -ArgumentList '-silent','-nvidiaspecific','-cleannorestart' -Wait -PassThru
    Write-Host "    [-] DDU NVIDIA exit code: $($nvidia.ExitCode)"
    if ($nvidia.ExitCode -ne 0) { throw "DDU NVIDIA purge failed with exit code $($nvidia.ExitCode)." }

    Write-Host "    [-] Evicting Intel Graphics driver allocations..."
    $intel = Start-Process -FilePath $DDUExe.FullName -ArgumentList '-silent','-intelspecific','-cleannorestart' -Wait -PassThru
    Write-Host "    [-] DDU Intel exit code: $($intel.ExitCode)"
    if ($intel.ExitCode -ne 0) { throw "DDU Intel purge failed with exit code $($intel.ExitCode)." }

    Write-Host "[+] Dismantling Safe Mode configuration flag..."
    & $BcdEdit /deletevalue "{current}" safeboot | Out-Null
    Assert-NativeSuccess "bcdedit deletevalue"

    Write-Host "[!] Purge phase complete. Reverting to standard operating environment..."
    Start-Sleep -Seconds 3
    Restart-Computer
}
# 3. The "Catch" Block: If ANYTHING fails above, execution instantly jumps here
catch {
    Write-Host "`n[X] CRITICAL PIPELINE FAILURE"
    Write-Host "Error Details: $($_.Exception.Message)"
    Write-Host "[!] Applying emergency Boot Configuration fix to prevent Safe Mode trap..."
    # Failsafe: If DDU crashes, remove the safeboot flag anyway so the user isn't stuck forever.
    & $BcdEdit /deletevalue "{current}" safeboot | Out-Null
    Write-Host "[!] Safe Mode flag cleared. REBOOT MANUALLY to return to normal Windows."

    # Failsafe: restore the adapters Phase 1 disabled, so a failed purge does not leave the
    # operator without network. Phase 3 does this on the success path; this covers the rest.
    $saved = Get-Content "$DDUFolder\adapters.txt" -ErrorAction SilentlyContinue
    if ($saved) {
        Enable-NetAdapter -Name $saved -Confirm:$false -ErrorAction SilentlyContinue
        Write-Host "[!] Attempted to re-enable: $($saved -join ', ')"
    } else {
        Get-NetAdapter -Physical | Enable-NetAdapter -Confirm:$false -ErrorAction SilentlyContinue
    }
}
# 4. The "Finally" Block: This runs no matter what happens
finally {
    Write-Host "[+] Stopping transcript log..."
    Stop-Transcript
}
