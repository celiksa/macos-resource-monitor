# Changelog

## 1.1.0

First packaged release of Vitals for Apple Silicon Macs running macOS 14 or later.

- Redesigned overview, sidebar, metric cards, and live charts.
- Verified CPU core groups with individual core histories, including Super, Performance, and Efficiency cores where supported.
- GPU hardware core count, device utilization, renderer / tiler activity, and shared-memory statistics.
- Searchable and sortable process monitoring, battery health, memory pressure, thermal sensors, network interfaces, and disk activity.
- Pause / resume, timestamp-based history windows, configurable refresh interval, and JSON / CSV exports.
- Corrected counter rollover, CPU time conversion, network accounting, and unavailable sensor handling.
- Published documentation excludes local process-list screenshots.

Individual GPU-core utilization and some sensors are unavailable on certain hardware. The downloadable build is arm64, ad-hoc signed, and not notarized.
