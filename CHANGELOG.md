# Changelog

All notable changes to this project will be documented in this file.
Format based on [Keep a Changelog](https://keepachangelog.com/).

## [1.2.0] - 2026-07-30

### Fixed
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
