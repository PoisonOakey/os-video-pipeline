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

**Prerequisites:** Disconnect the DisplayLink adapter. Open an elevated PowerShell terminal.

### Stage 1: Isolate & Reboot
Disables network adapters and reboots into Safe Mode.
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
*(Run in normal Windows)*. Restores networking and installs clean drivers. Reconnect adapter after completion.
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\03-Deploy-DisplayLink.ps1
```

---

## 📈 The Outcome

| Issue | Before (The Problem) | After (The Outcome) |
|---|---|---|
| **Hardware Gap** | Reliant on a USB adapter that is prone to driver corruption | Perfectly managed software layer enabling flawless adapter use |
| **Video Quality** | Blocky, pixelated, or completely unusable video | Crystal clear 4K display output with zero artifacts |
| **Reliability** | Old, glitchy software corrupting the USB pipeline | Automated script ensures fresh, 100% stable drivers every time |

---

> [!NOTE]
> ### 🔮 Future Roadmap
> - **Centralized Config** — extract hardcoded URLs and version paths into a shared configuration file
> - **Security Validation** — enforce hash/signature validation on downloaded binaries before execution
> - **Idempotent Resilience** — validate exit codes and handle silent DDU failures to prevent pipeline lockups

---

## ⚙️ CI/CD Pipeline

This project implements a **GitHub Actions** pipeline for automated static analysis. Every push triggers `PSScriptAnalyzer` to lint the PowerShell execution scripts, ensuring robust code quality and error-free remediation deployments.

---

