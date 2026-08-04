# Troubleshooting Guide

This document covers known failure modes and recovery procedures for the remediation pipeline.

## 🚨 Critical Recovery: Stuck in Safe Mode

If a script fails catastrophically or you reboot before Phase 2 completes, your machine may be stuck in a Safe Mode boot loop.

**Symptoms:**
- The computer repeatedly boots into Safe Mode.
- Network adapters may be disabled.
- The PowerShell scripts immediately fail or crash.

**Root Cause:**
The `bcdedit` safeboot flag was set during Phase 1, but Phase 2 (which removes the flag) failed to execute or was aborted.

**Resolution (in order of preference):**

1. **Manual Command Line (Preferred):**
   - Open an elevated command prompt (Run as Administrator).
   - Execute: `bcdedit /deletevalue "{current}" safeboot`
   - Restart the computer.

2. **System Configuration (GUI Fallback):**
   - Press `Win + R`, type `msconfig`, and press Enter.
   - Navigate to the **Boot** tab.
   - Under Boot options, uncheck **Safe boot**.
   - Click OK and restart when prompted.

3. **Windows Recovery Environment (WinRE):**
   - If you cannot log into Windows at all, hold Shift while clicking Restart on the login screen.
   - Navigate to **Troubleshoot** > **Advanced options** > **Command Prompt**.
   - Execute: `bcdedit /deletevalue {default} safeboot` *(Note: WinRE uses `{default}` instead of `{current}` because it targets your main Windows installation, whereas `{current}` refers to the WinRE environment itself).*
   - Restart the computer.

---

## Known Script Defects & Solutions

### Error: `The term '.\Display' is not recognized`
**Audit Finding:** Phase 2 would output an error about `.\Display` not being recognized as a cmdlet, function, or script file. DDU would not run.
**Root Cause:** The script invoked `.\Display Driver Uninstaller.exe` without quotes or the call operator `&`, causing PowerShell to treat the spaces as argument separators.
**Resolution:** Use the updated v1.2.0 Phase 2 script, which resolves the absolute path to DDU and invokes it correctly via `&`.

### Error: Invisible Console Output, and Empty Transcripts
**Audit Finding:** The console stayed blank while the script ran. Once that was addressed, a second and worse symptom remained: the transcripts under `C:\DDU` contained warnings and native command output but none of the script's own `[+]` progress lines - including `[X] CRITICAL PIPELINE FAILURE`.
**Root Cause:** Two consequences of one change. v1.0.0 replaced every `Write-Host` with `Write-Information` to satisfy the `PSAvoidUsingWriteHost` analyzer rule. First, `$InformationPreference` defaults to `SilentlyContinue`, so nothing printed. Second, `Start-Transcript` in PowerShell 5.1 does not capture the information stream at all. Measured on 5.1.26100.8972 from a non-interactive script:

| Cmdlet | Captured in transcript |
|---|---|
| `Write-Information` | No |
| `Write-Host` | Yes |
| `Write-Warning` | Yes |

**Resolution:** Reverted to `Write-Host` in v1.2.0. `PSScriptAnalyzerSettings.psd1` excludes `PSAvoidUsingWriteHost` with the reasoning recorded inline. The rule is aimed at reusable modules where host output breaks composability; these are operator-facing runbooks whose output must reach both a console and the transcript. Transcripts are the only evidence a run happened - their absence is what proved this repository had shipped code that was never executed.

### Error: `bcdedit is not recognized` / `bcdedit.exe not found at C:\WINDOWS\System32\bcdedit.exe`
**Audit Finding:** Phase 1 aborted at the boot configuration step. The second form is stranger - the script reported the file missing at a path where it plainly exists.
**Root Cause:** The script was running in **Windows PowerShell (x86)**. Under WOW64, `C:\Windows\System32` transparently redirects to `SysWOW64`, which contains no `bcdedit.exe`. Measured on the same host:

| | 64-bit host | 32-bit host |
|---|---|---|
| `Test-Path System32\bcdedit.exe` | True | False |
| `bcdedit` resolvable on PATH | Yes | No |

**Resolution:** All three phases now refuse to start under WOW64 with an actionable message, and resolve `bcdedit` by absolute path under `$env:WINDIR` rather than relying on `$env:PATH`. Launch **Windows PowerShell**, not **Windows PowerShell (x86)**, as Administrator.

### Error: `DDU NVIDIA purge failed with exit code .`
**Audit Finding:** Phase 2 aborted immediately with an empty exit code - not a number. The purge had in fact succeeded: the NVIDIA driver was gone afterwards.
**Root Cause:** DDU is a GUI application (PE subsystem 2). PowerShell's call operator does not wait for GUI processes and never sets `$LASTEXITCODE`, so `& $DDUExe ...` returned instantly against a null value. The reported failure was false, and the real hazard was worse: had the assertion not thrown, the script would have continued to `bcdedit` and rebooted the machine while DDU was still purging drivers in the background.
**Resolution:** Both DDU invocations use `Start-Process -Wait -PassThru` and check the real `ExitCode`.

### Issue: `Enable-NetAdapter -Physical` fails with `A parameter cannot be found that matches parameter name 'Physical'`
**Audit Finding:** Phase 1's failsafe and Phase 3's fallback both threw on this. Present since 0.1.0.
**Root Cause:** `-Physical` exists only on `Get-NetAdapter`. Neither `Enable-NetAdapter` nor `Disable-NetAdapter` accepts it, confirmed against cmdlet metadata. Since the original Phase 1 used `Disable-NetAdapter -Physical`, the pipeline could never have completed even before any v1.2.0 changes.
**Resolution:** Both cmdlets now take pipeline input from `Get-NetAdapter -Physical`. Note that PSScriptAnalyzer does not validate parameter names against cmdlet definitions, which is why this passed CI for two releases.

### Error: `Argument name was not recognized: '--quiet'`
**Audit Finding:** Phase 3 would fail to install DisplayLink drivers. `winget` would return an error about an unrecognized argument.
**Root Cause:** `--quiet` is not a valid flag for the `winget install` command.
**Resolution:** Use the updated Phase 3 script, which uses the correct `--silent` flag.

### Issue: Rebooting into Normal Mode with No Network
**Audit Finding:** After running Phase 1, the machine could reboot into normal Windows instead of Safe Mode, but all Wi-Fi/Ethernet adapters would be disabled.
**Root Cause:** The `bcdedit /set` command failed (often due to missing privileges). Because PowerShell's `$ErrorActionPreference = 'Stop'` does not catch native EXE exit codes, the script would continue executing, disable the network, and reboot normally.
**Resolution:** The v1.2.0 scripts include a manual `Assert-NativeSuccess` check that halts the script immediately if `bcdedit` returns a non-zero exit code, before the network adapters are touched.
