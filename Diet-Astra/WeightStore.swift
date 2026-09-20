import Foundation
import Observation

@MainActor
@Observable
final class WeightStore {
    private(set) var entries: [WeightEntry] = []
    private(set) var loadError: String?
    private let fileURL: URL?

    nonisolated static var defaultFileURL: URL {
        URL.applicationSupportDirectory
            .appending(path: "DietAstra", directoryHint: .isDirectory)
            .appending(path: "weights.json")
    }

    var latest: WeightEntry? { entries.last }

    init(fileURL: URL? = WeightStore.defaultFileURL, initialEntries: [WeightEntry] = []) {
        self.fileURL = fileURL
        if fileURL == nil {
            entries = initialEntries.sorted { $0.date < $1.date }
        } else {
            reload()
        }
    }

    func reload() {
        guard let fileURL else { return }
        do {
            let data: Data
            do {
                data = try Data(contentsOf: fileURL)
            } catch CocoaError.fileReadNoSuchFile {
                entries = []
                loadError = nil
                return
            }
            let loaded = try JSONDecoder().decode([WeightEntry].self, from: data)
            guard loaded.allSatisfy({ $0.pounds.isFinite && $0.pounds > 0 }),
                  Set(loaded.map(\.id)).count == loaded.count else {
                throw StorageError.invalidData
            }
            entries = loaded.sorted { $0.date < $1.date }
            loadError = nil
        } catch {
            // Block writes after a failed read so existing data cannot be overwritten.
            loadError = "Saved weights could not be loaded. Your existing file has not been changed. Try again."
        }
    }

    func add(pounds: Double, date: Date = .now) throws {
        guard pounds.isFinite && pounds > 0 else { throw StorageError.invalidWeight }
        let updated = (entries + [WeightEntry(date: date, pounds: pounds)])
            .sorted { $0.date < $1.date }
        try persist(updated)
    }

    func delete(ids: Set<UUID>) throws {
        try persist(entries.filter { !ids.contains($0.id) })
    }

    static func parsePounds(_ text: String, locale: Locale = .current) -> Double? {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: locale.decimalSeparator ?? ".", with: ".")
        guard normalized.range(of: #"^(?:[0-9]+(?:\.[0-9]{0,2})?|\.[0-9]{1,2})$"#,
                               options: .regularExpression) != nil,
              let value = Double(normalized), value.isFinite, value > 0 else { return nil }
        return value
    }

    private func persist(_ updated: [WeightEntry]) throws {
        guard loadError == nil else { throw StorageError.unavailable }
        if let fileURL {
            let data = try JSONEncoder().encode(updated)
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            var options: Data.WritingOptions = [.atomic]
            #if os(iOS)
            options.insert(.completeFileProtection)
            #endif
            try data.write(to: fileURL, options: options)
        }
        entries = updated
    }

    enum StorageError: LocalizedError {
        case invalidWeight, invalidData, unavailable

        var errorDescription: String? {
            switch self {
            case .invalidWeight: "Enter a weight greater than zero."
            case .invalidData: "The saved weight file contains invalid entries."
            case .unavailable: "Load your saved weights successfully before making changes."
            }
        }
    }
}
