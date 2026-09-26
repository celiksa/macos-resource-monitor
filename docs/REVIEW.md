# Review and redesign

## Findings addressed

| Finding | Change |
| --- | --- |
| No whole-system view; navigation had little hierarchy | New overview, hardware summary, live metric cards, grouped sidebar, consistent page headers, restrained accent colors, clearer typography and contrast |
| CPU types inferred from reversed perflevel ordering | Verified logical CPU IDs from the device tree, matched against perflevel names/counts; generic fallback for unknown topologies |
| Only current core loads visible | Individual core histories plus separate Super / Performance / Efficiency group charts |
| Missing GPU counters looked like idle 0% | Optional GPU utilization, explicit unavailable readings, chart gaps, hardware core count, renderer/tiler panels, explanation of per-core limitations |
| No process attribution | Searchable / sortable libproc process readings with PID-reuse protection, physical footprint, Mach timebase conversion, and inaccessible-process count |
| No notebook battery information | Battery charge, cycles, health estimate, condition, power source, battery watts, and remaining-time estimate |
| Memory pressure was a synthetic weighted utilization score | Kernel Normal / Warning / Critical state |
| Network aggregated 32-bit counters across physical and virtual layers | 64-bit routing counters with deltas per interface; virtual traffic separated from physical totals; reset protection |
| No pause, time-window selection, or export | Pausing with history gaps, timestamp-based windows/graphs, persisted refresh interval, JSON and CSV export |
| Interval changes could overlap mutable sampler access | Serialized sampler access and cancellation generation checks; interval changes take effect without restarting samplers |
| Unidentified SMC power keys could be guessed as system watts | Only recognized rails are used; no arbitrary largest/summed rail fallback |
| Hottest unrelated sensor could appear as CPU temperature | Removed fallback; CPU/SoC classification is explicit and missing values remain unavailable |
| Composition bars could overflow, capacity subtraction could underflow | Normalize segment widths, clamp volume availability to capacity |
| Headless screenshots duplicated UI and drifted from the app | Shared dashboard shell with bounded snapshot viewport and renderable controls |

## Verification

- Debug and release builds succeeded; 12 regression tests passed on the local Apple Silicon Mac.
- Live UI checks verified navigation, pause/resume, process filtering, and JSON and CSV exports through the native Save dialog (91 retained rows, including a verified pause gap).
- Tests cover M5 Super/Performance topology, earlier Efficiency/Performance topology, noncontiguous CPU IDs, unknown/incomplete layouts, tick rollover, interface reset / attachment, route messages with short address records, timestamp windows, unavailable samples, bounded history, pause gaps, JSON round trips, and history controls.
- A controlled `yes` subprocess verified CPU utilization near one core; the test terminates and reaps its own child.
- Live probes verified 18 CPU cores, Super IDs 12–17, Performance IDs 0–11, a 32-core GPU, GPU engine activity, notebook battery metrics, kernel pressure, storage, network, and accessible process readings.
- All nine panels were rendered from real samples for visual inspection. Eight panel screenshots are published; process-list captures are excluded from published documentation. The live process list remains complete and scrollable.

## Deliberate boundaries

- No invented individual GPU-core utilization, frequency, power estimates, or fan-control features.
- Process monitoring is read-only. No termination controls or automatic changes to other apps.
- UI warnings indicate current thermal/memory pressure; the app does not request notification permission.
- Sensor and core-mapping support on other physical Macs is not yet verified. Unknown hardware falls back conservatively.

## Source references

- [Apple XNU resource accounting](https://github.com/apple-oss-distributions/xnu/blob/main/osfmk/kern/bsd_kern.c): process CPU counters and physical footprint.
- [Apple Metal counter statistics](https://developer.apple.com/documentation/xcode/analyzing-apple-gpu-performance-using-counter-statistics): GPU profiling context; application profiling counters do not supply a system-wide per-core monitor.
- Local macOS SDK headers (`libproc.h`, `sys/resource.h`, `net/if.h`) and read-only IORegistry/sysctl inspection supplied the implementation details validated on this machine.
