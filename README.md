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
├── 📄 01-Isolate-And-BootSafe.ps1  # Prepares environment, isolates network, forces Safe Mode
├── 📄 02-Purge-Drivers.ps1         # Silently executes DDU dual-GPU wipe
└── 📄 03-Deploy-DisplayLink.ps1    # Restores network & installs clean DisplayLink UI/Drivers
```

---

## ⚡ Execution

**Prerequisites:** 
1. **Have a non-DisplayLink display available.** Stage 2 runs in Safe Mode, where the DisplayLink USB display driver is not expected to load, so the external monitor will likely go dark for that stage. The laptop's built-in panel covers this. (HDMI 1.4 is *not* a substitute for the 4K monitor here — it caps at 4K/30, which is the reason DisplayLink is used in the first place.)
2. Disconnect the DisplayLink adapter.
3. Open an elevated PowerShell terminal.

### Stage 1: Isolate & Reboot
Prompts to uninstall DisplayLink for a clean rebuild, then disables network adapters and reboots into Safe Mode.
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\01-Isolate-And-BootSafe.ps1
```

### Stage 2: The Purge
*(Run after logging into Safe Mode)*. Silently wipes corrupted drivers and reboots normally.
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\02-Purge-Drivers.ps1
```

### Stage 3: Deploy & Reconnect
*(Run in normal Windows)*. Rebuilds the underlying Intel/NVIDIA GPU stack that DisplayLink composites through, and ensures the DisplayLink drivers are present. Restores networking. Reconnect adapter after completion.
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\03-Deploy-DisplayLink.ps1
```

> [!IMPORTANT]
> If any stage fails — especially if you are left in Safe Mode or without network — see **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** for recovery procedures.

---

## 📊 Status

This pipeline is currently written and statically analyzed via CI, but **it has not yet been executed end-to-end on hardware.** The original display fix performed on 2026-07-03 was done manually; this automated code was created retroactively and awaits a live execution run for validation. 

**Clean Rebuild:** Stage 1 prompts (`y/N`, defaulting to No) to uninstall the DisplayLink packages before the purge, and Stage 3 reinstalls them. This exists because Stage 3's `Install-IfMissing` check tests only for *presence* — a corrupted-but-installed DisplayLink, the exact fault this pipeline targets, would otherwise be skipped over and left in place. Answer `y` for a genuine remediation; answer `N` to leave the current version untouched.

*(Note: The winget package ID `DisplayLink.GraphicsDriver` was verified against live winget on 2026-07-30).*

---

## ⚠️ Known Limitations

- **PowerShell 5.1 Native Exit Codes:** By design, `$ErrorActionPreference = 'Stop'` does not trap native exe failures (e.g., `bcdedit`, `winget`, `curl`). We rely on a manual `Assert-NativeSuccess` helper function to catch non-zero `$LASTEXITCODE` values.
- **Unverified DDU SFX Layout:** The assumption that the DDU 7-Zip self-extractor extracts to a specific versioned subfolder is based on on-disk forensics, not an observed execution run. A recursive search mitigates this.
- **Unverified MS Store Elevation:** MS Store package installations (`9N09F8V8FS02`) via winget executed under an elevated `Administrator` context can be unreliable. This needs a live run to confirm.

---

> [!NOTE]
> ### 🔮 Future Roadmap
> - **Centralized Config** — extract hardcoded URLs and version paths into a shared configuration file
> - **Security Validation** — enforce hash/signature validation on downloaded binaries before execution
> - **Idempotent Resilience** — validate exit codes and handle silent DDU failures to prevent pipeline lockups

---

## ⚙️ CI/CD Pipeline

This project implements a **GitHub Actions** pipeline for automated static analysis. Every push triggers `PSScriptAnalyzer` to lint the PowerShell execution scripts. 
**Note:** This CI pipeline covers *static analysis only* and does not guarantee execution correctness or run the pipeline on live hardware.
