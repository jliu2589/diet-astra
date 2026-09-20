import Foundation

@main
struct WeightStoreChecks {
    @MainActor
    static func main() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "DietAstra-Checks-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appending(path: "weights.json")
        let store = WeightStore(fileURL: file)
        try check(store.entries.isEmpty && store.loadError == nil, "First launch is empty")

        let english = Locale(identifier: "en_US")
        let french = Locale(identifier: "fr_FR")
        try check(WeightStore.parsePounds(" 181.25 ", locale: english) == 181.25, "Decimal input")
        try check(WeightStore.parsePounds("181,25", locale: french) == 181.25, "Localized decimal input")
        for input in ["", "0", "-1", "nan", "inf", "181lb", "1.2.3", "1,000", "1e3", "0.001"] {
            try check(WeightStore.parsePounds(input, locale: english) == nil, "Reject invalid input: \(input)")
        }
        for invalid in [0.0, -1.0, Double.nan, Double.infinity] {
            try expectFailure("Reject invalid stored weight") { try store.add(pounds: invalid) }
        }

        let firstDate = Date(timeIntervalSince1970: 1_800_000_000)
        try store.add(pounds: 181.2, date: firstDate.addingTimeInterval(60))
        try store.add(pounds: 182.4, date: firstDate)
        try check(store.entries.map(\.pounds) == [182.4, 181.2], "Chronological order")
        try check(store.latest?.pounds == 181.2, "Latest uses measurement date")
        try check(store.entries.count == 2, "Keep multiple same-day measurements")

        let reopened = WeightStore(fileURL: file)
        try check(reopened.entries == store.entries, "Entries, dates, and IDs survive relaunch")
        try reopened.delete(ids: [reopened.latest!.id])
        let afterDeletion = WeightStore(fileURL: file)
        try check(afterDeletion.entries.count == 1 && afterDeletion.latest?.pounds == 182.4,
                  "Deletion persists and updates latest")
        try afterDeletion.delete(ids: Set(afterDeletion.entries.map(\.id)))
        try check(WeightStore(fileURL: file).entries.isEmpty, "Deleting last entry persists")

        let corrupt = Data("not JSON".utf8)
        try corrupt.write(to: file)
        let broken = WeightStore(fileURL: file)
        try check(broken.loadError != nil, "Corrupt data reports a load error")
        try expectFailure("Block writes after load failure") { try broken.add(pounds: 180) }
        try check(try Data(contentsOf: file) == corrupt, "Never overwrite unreadable data")
        try JSONEncoder().encode(store.entries).write(to: file)
        broken.reload()
        try check(broken.loadError == nil && broken.entries == store.entries, "Retry loading recovers")

        let beforeFailure = broken.entries
        try FileManager.default.removeItem(at: file)
        try FileManager.default.createDirectory(at: file, withIntermediateDirectories: false)
        try expectFailure("Report failed save") { try broken.add(pounds: 180) }
        try check(broken.entries == beforeFailure, "Failed save keeps visible data unchanged")
        try expectFailure("Report failed delete") { try broken.delete(ids: [beforeFailure[0].id]) }
        try check(broken.entries == beforeFailure, "Failed delete keeps visible data unchanged")

        let preview = WeightStore(fileURL: nil)
        try preview.add(pounds: 180)
        try check(preview.entries.count == 1, "Preview works without disk storage")
        print("All weight storage checks passed.")
    }

    private static func check(_ condition: Bool, _ message: String) throws {
        if !condition { throw CheckFailure(message: message) }
    }

    private static func expectFailure(_ message: String, operation: () throws -> Void) throws {
        do {
            try operation()
        } catch {
            return
        }
        throw CheckFailure(message: message)
    }

    private struct CheckFailure: Error {
        let message: String
    }
}
