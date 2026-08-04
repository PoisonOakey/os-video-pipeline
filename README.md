# DisplayLink Remediation Automation

> An OS-level automation suite to resolve degraded video output, pixelation, and bandwidth throttling when bypassing physical GPU bottlenecks via DisplayLink hardware.

---

## 🚀 What I Built

An automated script that fixes display issues by safely removing corrupted graphics drivers and setting up a fresh, clean connection for USB monitors.

---

## 🛑 The Problem

- **No direct video output:** My laptop's USB-C port doesn't support video directly.
- **Adapter needed:** Connecting a monitor requires a DisplayLink adapter to send video over standard USB.
- **Software glitches:** Old drivers often corrupt this connection, making the video blocky, pixelated, or completely unusable.

```text
[Intel iGPU] ──(Direct Traces)──> [HDMI 1.4 Port] ──> [Monitor]
[Intel iGPU] ──(Direct Traces)──> [USB-C Port] ✖ [Signal Terminated]
```

<img width="1024" height="559" alt="articwimds" src="https://github.com/user-attachments/assets/34bf3727-9313-45cb-8734-f1db923f9dca" />

---



## 🧠 Key Engineering Decisions

| Area | Detail |
|---|---|
| **State Segregation** | Execution is strictly segregated into three distinct phases across boot cycles to contain the blast radius of driver manipulation. |
| **Boot-State Manipulation** | Programmatically alters `bcdedit` boot configurations to force Windows into Safe Mode for deep-level driver uninstallation. |
| **Network Isolation** | Preemptively disables physical network adapters during the purge phase to prevent Windows Update from hijacking the driver installation process. |
| **Silent Execution** | Wraps Display Driver Uninstaller (DDU) and Winget deployments in silent flags for a zero-touch remediation experience. |

---

## ⚙️ Pipeline Architecture

```text
📁 scripts/
├── 📄 01-Isolate-And-BootSafe.ps1  # Uninstalls DisplayLink; optionally isolates network + forces Safe Mode
├── 📄 02-Purge-Drivers.ps1         # Tier 2 only: DDU dual-GPU wipe inside Safe Mode
└── 📄 03-Deploy-DisplayLink.ps1    # Restores adapters & installs clean DisplayLink driver + manager
```

---

## ⚡ Execution

Remediation is **tiered**, chosen by a `y/N` prompt in Stage 1:

| Tier | Path | Touches boot config |
|---|---|---|
| 1 | Uninstall DisplayLink → reboot → reinstall | No |
| 2 | Tier 1 + DDU GPU driver purge from Safe Mode | Yes |

**Prerequisites**
1. Disconnect the DisplayLink adapter.
2. Elevated **64-bit** PowerShell. The x86 host is refused.
3. *Tier 2 only:* a non-DisplayLink display. The external monitor goes dark in Safe Mode; the laptop panel covers it.

Each stage: `Set-ExecutionPolicy Bypass -Scope Process -Force`, then run the script.

| Stage | When | Does |
|---|---|---|
| `01-Isolate-And-BootSafe.ps1` | Normal Windows | Uninstalls DisplayLink, prompts for tier, reboots |
| `02-Purge-Drivers.ps1` | Safe Mode, Tier 2 only | DDU wipes NVIDIA + Intel, clears boot flag, reboots |
| `03-Deploy-DisplayLink.ps1` | Normal Windows | Restores adapters, waits for DNS, installs DisplayLink |

Reconnect the adapter after Stage 3. Intel and NVIDIA drivers are **not** reinstalled by this pipeline — Windows Update restores them once networking returns.

> [!IMPORTANT]
> If any stage fails — especially if you are left in Safe Mode or without network — see **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** for recovery procedures.

---

## 📊 Status

Written retroactively after a manual fix on 2026-07-03. First executed 2026-08-03.

That first run surfaced **nine defects**, all through green CI — root causes in [TROUBLESHOOTING.md](TROUBLESHOOTING.md). Three were identifiers that were never valid: a command name, a cmdlet parameter, and a third-party binary's arguments. A linter cannot catch any of those.

| Path | State |
|---|---|
| Stage 1 — uninstall, boot flag, adapter isolation, Safe Mode reboot | Verified 2026-08-03 |
| Stage 3 — adapter restore, DNS gate, DisplayLink install | Verified 2026-08-04 (Graphics `12.2.2412.0`, Manager `3.2.14.0`) |
| Tier 1 — decline the purge, reinstall only | Verified 2026-08-04, end to end |
| Transcript logging | Verified 2026-08-04 |
| MS Store install under elevation | Verified 2026-08-04 |
| **Stage 2 — DDU purge** | **Never completed.** Two hardware attempts, two unrelated causes, both fixed. See [STAGE-2.md](STAGE-2.md) |

Package IDs verified against live winget on 2026-07-30.

---

## ⚠️ Known Limitations

| Limitation | Detail |
|---|---|
| 64-bit PowerShell required | Under WOW64, `System32` redirects to `SysWOW64`, which has no `bcdedit.exe`. All phases refuse to start in the x86 host |
| Native exit codes | `$ErrorActionPreference = 'Stop'` does not trap native exe failures; `Assert-NativeSuccess` does. GUI apps like DDU set no exit code at all and need `Start-Process -Wait -PassThru` |
| `Write-Host` is deliberate | `Start-Transcript` does not capture the information stream, so `Write-Information` yields silent logs. `PSAvoidUsingWriteHost` is excluded in `PSScriptAnalyzerSettings.psd1` |
| DDU SFX layout unverified | The versioned extraction subfolder comes from on-disk forensics, not an observed extraction. A recursive search mitigates it |
| DDU exit codes unverified | Phase 2 assumes zero means success. Never observed — see [STAGE-2.md](STAGE-2.md) |

---

> [!NOTE]
> ### 🔮 Future Roadmap
> - **Complete Stage 2** — the only unfinished path. Plan and open questions in [STAGE-2.md](STAGE-2.md)
> - **Centralized Config** — extract hardcoded paths, URLs and package IDs into one config file
> - **Signature Validation** — the DDU download is checked for an `MZ` header only; add hash or signature verification

---

## ⚙️ CI/CD Pipeline

This project implements a **GitHub Actions** pipeline for automated static analysis. Every push triggers `PSScriptAnalyzer` to lint the PowerShell execution scripts. 
**Note:** This CI pipeline covers *static analysis only* and does not guarantee execution correctness or run the pipeline on live hardware.
