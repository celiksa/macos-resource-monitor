import AppKit
import UniformTypeIdentifiers

@MainActor
extension MetricsEngine {
    func exportSnapshot() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        do { save(try encoder.encode(snapshot), type: .json, name: "Vitals-snapshot.json") }
        catch { exportError = error.localizedDescription }
    }

    func exportHistory() {
        let h = recordedHistory
        let formatter = ISO8601DateFormatter()
        var rows = ["timestamp,cpu_percent,gpu_percent,memory_percent,temperature_celsius,power_watts,download_bytes_per_second,upload_bytes_per_second,disk_read_bytes_per_second,disk_write_bytes_per_second,battery_percent"]
        for i in h.timestamps.indices {
            let metrics: [(Series, Double)] = [(h.cpu, 100), (h.gpu, 100), (h.memory, 100), (h.temperature, 1), (h.power, 1), (h.networkDown, 1), (h.networkUp, 1), (h.diskRead, 1), (h.diskWrite, 1), (h.battery, 100)]
            rows.append(([formatter.string(from: h.timestamps[i])] + metrics.map { series, scale in
                guard series.values.indices.contains(i), series.values[i].isFinite else { return "" }
                return String(format: "%.4f", locale: Locale(identifier: "en_US_POSIX"), series.values[i] * scale)
            }).joined(separator: ","))
        }
        save(Data((rows.joined(separator: "\n") + "\n").utf8), type: .commaSeparatedText, name: "Vitals-history.csv")
    }

    private func save(_ data: Data, type: UTType, name: String) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [type]
        panel.nameFieldStringValue = name
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try data.write(to: url, options: .atomic) }
        catch { exportError = error.localizedDescription }
    }
}
