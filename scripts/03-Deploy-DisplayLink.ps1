#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Phase 3: Network Restoration and DisplayLink Deployment.
.DESCRIPTION
    Re-enables network adapters and deploys DisplayLink drivers via Winget.
#>

# 1. Force all silent errors to instantly trigger the Catch block
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

# Refuse to run under WOW64, for consistency with Phases 1 and 2 and to keep winget
# operating against the same 64-bit view of the system.
if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess) {
    throw "This must run in 64-bit PowerShell. Launch 'Windows PowerShell' - not 'Windows PowerShell (x86)' - as Administrator."
}

function Assert-NativeSuccess {
    param([string]$What)
    if ($LASTEXITCODE -ne 0) { throw "$What failed with exit code $LASTEXITCODE." }
}

function Install-IfMissing {
    param([string]$Id, [string[]]$ExtraArgs)
    winget list -e --id $Id | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Information "    [-] $Id already present - skipping."
        return
    }
    winget install -e --id $Id --accept-package-agreements --accept-source-agreements --silent @ExtraArgs
    Assert-NativeSuccess "winget install $Id"
}

$DDUFolder = "C:\DDU"
$LogPath = "$DDUFolder\Phase3_Log.txt"
Start-Transcript -Path $LogPath -Append -Force

# 2. The "Try" Block: Execute the dangerous code
try {
    Write-Information "[+] Phase 3: Standard mode restored. Re-establishing physical network links..."
    # Best-effort restore: a missing or renamed adapter must not abort the stage before
    # DisplayLink is reinstalled. The DNS gate below is the real connectivity assertion.
    $saved = Get-Content "$DDUFolder\adapters.txt" -ErrorAction SilentlyContinue
    if ($saved) { Enable-NetAdapter -Name $saved -Confirm:$false -ErrorAction SilentlyContinue }
    else { Get-NetAdapter -Physical | Enable-NetAdapter -Confirm:$false -ErrorAction SilentlyContinue }

    Write-Information "    [-] Waiting for network..."
    $deadline = (Get-Date).AddSeconds(60)
    while ($true) {
        # Using Resolve-DnsName to prove we have both network and DNS resolution to Microsoft's CDN
        $dnsResult = Resolve-DnsName cdn.winget.microsoft.com -ErrorAction SilentlyContinue
        if ($dnsResult) { break }
        
        if ((Get-Date) -gt $deadline) { throw "No network connectivity after 60s - cannot reach winget sources." }
        Start-Sleep -Seconds 3
    }

    Write-Information "[+] Deploying DisplayLink Core Driver..."
    Install-IfMissing -Id "DisplayLink.GraphicsDriver"

    Write-Information "[+] Deploying DisplayLink Manager from MS Store..."
    Install-IfMissing -Id "9N09F8V8FS02" -ExtraArgs @("--source", "msstore")

    Write-Information "[!] Remediation pipeline complete. Plug in the DisplayLink adapter."
}
# 3. The "Catch" Block: If ANYTHING fails above, execution instantly jumps here
catch {
    Write-Information "`n[X] CRITICAL PIPELINE FAILURE"
    Write-Information "Error Details: $($_.Exception.Message)"
    Write-Information "[!] Manual intervention required for package deployment."
}
# 4. The "Finally" Block: This runs no matter what happens
finally {
    Write-Information "[+] Stopping transcript log..."
    Stop-Transcript
}
