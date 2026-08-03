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

### Error: Invisible Console Output
**Audit Finding:** When running the scripts, the console would be completely blank despite the script running for several seconds. No progress would be shown.
**Root Cause:** The default `$InformationPreference` in PowerShell 5.1 is `SilentlyContinue`. All `Write-Information` calls are suppressed.
**Resolution:** The v1.2.0 scripts explicitly set `$InformationPreference = 'Continue'` at the top of each file.

### Error: `Argument name was not recognized: '--quiet'`
**Audit Finding:** Phase 3 would fail to install DisplayLink drivers. `winget` would return an error about an unrecognized argument.
**Root Cause:** `--quiet` is not a valid flag for the `winget install` command.
**Resolution:** Use the updated Phase 3 script, which uses the correct `--silent` flag.

### Issue: Rebooting into Normal Mode with No Network
**Audit Finding:** After running Phase 1, the machine could reboot into normal Windows instead of Safe Mode, but all Wi-Fi/Ethernet adapters would be disabled.
**Root Cause:** The `bcdedit /set` command failed (often due to missing privileges). Because PowerShell's `$ErrorActionPreference = 'Stop'` does not catch native EXE exit codes, the script would continue executing, disable the network, and reboot normally.
**Resolution:** The v1.2.0 scripts include a manual `Assert-NativeSuccess` check that halts the script immediately if `bcdedit` returns a non-zero exit code, before the network adapters are touched.
