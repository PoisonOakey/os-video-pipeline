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

Remediation is **tiered**. Tier 1 reinstalls DisplayLink and resolves the common case. Tier 2 escalates to a full GPU driver-stack purge from Safe Mode, and is opt-in via a `y/N` prompt in Stage 1. Only Tier 2 modifies boot configuration.

**Prerequisites:**
1. Disconnect the DisplayLink adapter.
2. Open an elevated **64-bit** PowerShell terminal. The scripts refuse to run under `Windows PowerShell (x86)` — see [Known Limitations](#-known-limitations).
3. *Tier 2 only:* have a non-DisplayLink display available. Stage 2 runs in Safe Mode, where the DisplayLink USB display driver is not expected to load, so the external monitor will likely go dark for that stage. The laptop's built-in panel covers this. (HDMI 1.4 is *not* a substitute for a 4K monitor — it caps at 4K/30, which is why DisplayLink is used in the first place.)

### Stage 1: Uninstall & Reboot
Prompts twice: whether to uninstall DisplayLink for a clean rebuild, and whether to escalate to the Tier 2 purge. Answering `N` to the second prompt leaves boot configuration and networking untouched and reboots straight to Stage 3.
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\01-Isolate-And-BootSafe.ps1
```

### Stage 2: The Purge — *Tier 2 only*
*(Run after logging into Safe Mode)*. Wipes the NVIDIA and Intel driver stacks with DDU, clears the Safe Mode flag, and reboots normally. Skip this entirely if you declined the purge prompt.
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\02-Purge-Drivers.ps1
```

### Stage 3: Deploy & Reconnect
*(Run in normal Windows)*. Restores any adapters Stage 1 disabled, waits for real DNS resolution, and installs the DisplayLink driver and manager. Reconnect the adapter after completion.

Note that this stage does **not** reinstall Intel or NVIDIA drivers — Windows Update does that on its own once networking returns.
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\03-Deploy-DisplayLink.ps1
```

> [!IMPORTANT]
> If any stage fails — especially if you are left in Safe Mode or without network — see **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** for recovery procedures.

---

## 📊 Status

The original display fix on 2026-07-03 was performed manually; this code was written retroactively and, until 2026-08-03, had **never been executed**. Running it surfaced six defects that static analysis could not reach — see [TROUBLESHOOTING.md](TROUBLESHOOTING.md).

| Path | State |
|---|---|
| Stage 1 — uninstall, boot-flag set, adapter isolation, reboot to Safe Mode | **Verified on hardware** 2026-08-03 |
| Stage 3 — adapter restore, DNS gate, DisplayLink install | **Verified on hardware** 2026-08-04. Installed Graphics `12.2.2412.0` and Manager `3.2.14.0`; monitor confirmed working |
| Stage 2 — DDU purge | **Partially exercised.** The NVIDIA purge completed and removed the driver; the script then aborted on a false failure before reaching the Intel step. Fixed, not yet re-run |
| Tier 1 branch — skipping the purge entirely | **Not yet executed.** Added after the hardware run |

**Clean Rebuild:** Stage 1 prompts (`y/N`, defaulting to No) to uninstall the DisplayLink packages, and Stage 3 reinstalls them. This exists because Stage 3's `Install-IfMissing` check tests only for *presence* — a corrupted-but-installed DisplayLink, the exact fault this pipeline targets, would otherwise be skipped over. On the verified run this also delivered a version bump from `12.2.2204.0` to `12.2.2412.0`, which a presence check alone would have skipped.

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
