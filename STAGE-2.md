# Stage 2 — Completion Plan

The DDU driver purge is the only path in this pipeline that has never run to completion.
Stages 1 and 3 and the Tier 1 path are verified on hardware; this is what is left.

## Why it is unfinished

Two hardware attempts, two unrelated causes. Both are fixed in code, neither fix is proven.

| Date | Symptom | Root cause | Fixed in |
|---|---|---|---|
| 2026-08-03 23:46 | `DDU NVIDIA purge failed with exit code .` — empty, not a number | DDU is a GUI process (PE subsystem 2). The call operator does not wait for GUI apps and never sets `$LASTEXITCODE` | `838220e` |
| 2026-08-04 10:44 | Transcript stops at `Evicting NVIDIA driver allocations...`, DDU's window opens, script blocks until manual reboot | `-nvidiaspecific`, `-intelspecific`, `-cleannorestart` are not DDU arguments. Unrecognised arguments drop DDU into interactive mode | `e46fb3c` |

Real DDU verbs, extracted from the binary's own strings:

```
-silent  -cleannvidia  -cleanintel  -cleanamd  -cleanallgpus  -cleancomplete
-restart -shutdown  -removephysx  -removenvcp  -removegfe  -removemonitors
```

There is no `-norestart`. Restart is opt-in via `-restart`, so omitting it leaves reboot
control with the script.

## Open questions

| # | Question | Why it matters | How to answer |
|---|---|---|---|
| 1 | What exit code does DDU return on a successful silent purge? | Phase 2 throws on non-zero. If DDU returns non-zero on success, every run fails | Read `[-] DDU NVIDIA exit code:` from the transcript |
| 2 | Does `-silent` actually run headless? | If the GUI still appears, `Start-Process -Wait` blocks again | Observe whether a window opens |
| 3 | Does `-silent` require `-restart` or `-shutdown`? | Some silent modes refuse to run without a terminal action | Fails fast if so |
| 4 | Does the Intel purge step behave like the NVIDIA one? | Never reached on any run | Run to completion |
| 5 | Does the success path clear the boot flag and reboot? | `bcdedit /deletevalue` + `Restart-Computer` never executed | Machine should return to normal boot unattended |
| 6 | Does the DisplayLink monitor render in Safe Mode? | Asserted in the README, never measured | Look at the screen during Stage 2 |

## Tasks

| # | Task | Blocked by | Effort |
|---|---|---|---|
| 1 | Run Stage 1 answering `y` to both prompts | — | 1 reboot |
| 2 | Run Stage 2 in Safe Mode, capture both exit-code lines | 1 | ~5 min |
| 3 | Decide exit-code policy from the observed values | 2 | code change |
| 4 | Run Stage 3, confirm display restored | 2 | ~2 min |
| 5 | Update README status table with the result | 4 | docs |
| 6 | Tag `v1.3.0` | 5 | — |

If question 1 shows DDU returns non-zero on success, task 3 becomes an allow-list of known
codes rather than a plain `-ne 0` check. Do not guess the value — take it from a transcript.

## Cost and risk

| Item | Detail |
|---|---|
| Time | ~15 minutes, two reboots, Safe Mode once |
| Blast radius | NVIDIA and Intel display drivers removed |
| Recovery | Windows Update reinstalls both once networking returns. Laptop panel runs on the basic display adapter meanwhile — low resolution, usable |
| Monitor | Dark from Stage 1 until Stage 3 completes |
| Failure mode | Stage 2's catch clears the boot flag and re-enables the recorded adapters, then stops. Manual recovery in [TROUBLESHOOTING.md](TROUBLESHOOTING.md) |

## Abort criteria

Stop and reassess if any of these occur:

- DDU's window opens despite `-silent` — question 2 failed, do not click through it
- Stage 2 blocks for more than five minutes with no exit-code line
- The machine returns to Safe Mode after Stage 2 rather than normal boot

## Whether to do it at all

The fault this pipeline exists to fix was resolved by Tier 1 alone, twice — on 2026-07-03
manually, and on 2026-08-04 by this code. `C:\DDU\wipe_state.txt` from the original session
is still frozen at `PHASE_1`, so the purge was never load-bearing then either.

Stage 2 is the escalation path for when a reinstall is not enough. That case has not occurred
on this hardware. Finishing it closes the last unverified code path; leaving it documented as
incomplete is also defensible. What is not defensible is claiming it works.
