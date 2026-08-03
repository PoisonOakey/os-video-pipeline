# Changelog

All notable changes to this project will be documented in this file.
Format based on [Keep a Changelog](https://keepachangelog.com/).

## [1.2.0] - 2026-07-30

### Added
- **Phase 1 (Tiered Remediation):** Interactive `y/N` prompt to escalate to the Safe Mode GPU driver purge. Declining skips `bcdedit` and adapter isolation entirely and reboots straight to Phase 3, keeping the blast radius to a package reinstall. Only the escalation branch modifies boot configuration. The default path is the one verified on hardware; the purge is the escalation for when reinstalling DisplayLink alone is not enough.
- **Phase 1 (Clean Rebuild):** Interactive `y/N` prompt to uninstall the DisplayLink packages before the purge, so Phase 3 reinstalls them clean. Phase 3's presence check cannot detect a corrupted-but-installed package - the exact fault this pipeline targets - so without removal it would skip the install entirely. The prompt defaults to No and warns that the DisplayLink monitor stays dark until Phase 3 completes.
- **`TROUBLESHOOTING.md`:** Safe Mode recovery runbook (elevated prompt, `msconfig`, WinRE) plus Symptoms/Root Cause/Resolution entries for each defect found during audit.
- **Phase 1/3 (Adapter State):** Phase 1 records currently-enabled physical adapters to `C:\DDU\adapters.txt`; Phase 3 restores only those, instead of blindly enabling every physical adapter.
- **Phase 1 (Download Integrity):** `MZ` header validation on the downloaded DDU payload to reject error pages saved as `.exe`.
- **Phase 3 (Idempotency):** `Install-IfMissing` presence check so re-runs skip already-installed packages instead of failing on a non-zero winget exit code.
- **Phase 3 (Network Gate):** Replaced a blind 15-second sleep with a 60-second DNS resolution check against `cdn.winget.microsoft.com`.
- **CI:** Pinned `PSScriptAnalyzer` to `1.25.0` for reproducible lint runs.

### Fixed
- **All Phases (Invalid Parameter):** `Enable-NetAdapter -Physical` and `Disable-NetAdapter -Physical` were never valid - `-Physical` exists only on `Get-NetAdapter`. Both cmdlets now take their input from `Get-NetAdapter -Physical` via the pipeline. Present since 0.1.0 and surfaced only on first execution; PSScriptAnalyzer does not validate parameter names against cmdlet definitions.
- **Phase 1/2 (bcdedit Resolution):** `bcdedit` was invoked bare and failed with `CommandNotFoundException` on a host whose PowerShell profile had removed `System32` from `$env:PATH`. Now resolved to an absolute path under `$env:WINDIR` and verified to exist before use.
- **Phase 1 (Safe Mode Reboot):** Fixed a bug where a failed `bcdedit` command would silently ignore the error and reboot the machine into normal mode with network adapters disabled.
- **Phase 1 (DDU Download):** Script now correctly unpacks the DDU self-extracting archive and recursively locates the true executable path, instead of falsely guarding on `C:\DDU\Display Driver Uninstaller.exe`.
- **Phase 2 (Driver Purge):** Fixed a critical path parsing bug (`The term '.\Display' is not recognized`) by invoking DDU via the call operator `&` with a fully resolved path.
- **Phase 3 (DisplayLink Install):** Replaced the invalid `--quiet` flag with `--silent` for `winget` installations. Corrected the DisplayLink winget package ID to `DisplayLink.GraphicsDriver`.
- **Global:** Replaced default `SilentlyContinue` output stream so all console messages are now visible.
- **Global:** Added explicit `#Requires -RunAsAdministrator` flags.
- **Global:** Added strict native exit-code assertions to ensure commands like `winget` and `bcdedit` actually fail the script when they error.

## [1.1.0] - 2026-07-27

### Added
- **CI/CD Pipeline:** Implemented a GitHub Actions workflow to automatically lint PowerShell scripts using `PSScriptAnalyzer` on every push.
- **Documentation:** Appended CI/CD pipeline details to `README.md`.

## [1.0.0] - 2026-07-05

### Changed
- Replaced all `Write-Host` calls with `Write-Information` (PSScriptAnalyzer compliance)
- Restructured repository to industry-standard layout (`scripts/` directory)
- Removed `-v2` suffix from script filenames — Git tracks version history

### Added
- Transcript logging for all 3 phases
- Try/Catch/Finally error handling with fail-safe mechanisms
- Safe Mode boot loop prevention (Phase 2 catch block removes safeboot flag)
- Network adapter failsafe (Phase 1 re-enables adapters on failure)
- Administrator privilege check at script entry
- `.gitignore` for Windows/PowerShell artifacts
- `LICENSE` (MIT)
- `README.md` with full documentation
- `CHANGELOG.md`

## [0.1.0] - 2026-07-04

### Added
- Initial 3-phase remediation pipeline
- Phase 1: DDU download, network isolation, Safe Mode reboot
- Phase 2: Silent NVIDIA + Intel driver purge via DDU
- Phase 3: Network restoration, DisplayLink deployment via Winget
