import Foundation
import Supabase
import OSLog

@MainActor
final class Backend {
    let client: SupabaseClient
    static func configured() -> Backend? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              let url = URL(string: raw), url.scheme == "https", url.host != nil,
              !raw.contains("YOUR_PROJECT"),
              let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY") as? String,
              key.count > 20, !key.contains("$("), !key.hasPrefix("sb_secret_") else { return nil }
        // Reject legacy privileged keys as well as modern secret keys.
        if key.split(separator: ".").count == 3 {
            var payload = String(key.split(separator: ".")[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
            payload += String(repeating: "=", count: (4 - payload.count % 4) % 4)
            guard let data = Data(base64Encoded: payload), let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any], json["role"] as? String == "anon" else { return nil }
        } else if !key.hasPrefix("sb_publishable_") { return nil }
        return Backend(url: url, key: key)
    }
    init(url: URL, key: String) {
        client = SupabaseClient(supabaseURL: url, supabaseKey: key,
                                options: .init(auth: .init(emitLocalSessionAsInitialSession: true)))
    }
    func rows<T: Decodable>(_ table: String, user: UUID, order: String = "id") async throws -> [T] {
        var result: [T] = [], offset = 0
        while true {
            let page: [T]
            do {
                page = try await client.from(table).select().eq("user_id", value: user.uuidString)
                    .order(order).range(from: offset, to: offset + 499).execute().value
            } catch {
                // Only schema/error codes are logged, never records, credentials or response bodies.
                let code = (error as? PostgrestError)?.code ?? String((error as NSError).code)
                Logger(subsystem: "DietAstra", category: "Database").error("Read failed: \(table, privacy: .public), code \(code, privacy: .public), type \(String(describing: type(of: error)), privacy: .public)")
                throw error
            }
            result += page
            if page.count < 500 { return result }
            offset += 500
        }
    }
    func save<T: Encodable>(_ row: T, table: String) async throws {
        try await client.from(table).upsert(row).execute()
    }
    func delete(_ id: UUID, table: String, user: UUID) async throws {
        try await client.from(table).delete().eq("id", value: id.uuidString).eq("user_id", value: user.uuidString).execute()
    }
    nonisolated struct MealRequest: Encodable { var text: String; var image: String? }
    nonisolated struct Interpretation: Decodable { var title: String; var foods: [FoodItem]; var note: String }
    func interpret(text: String, photo: Data?) async throws -> Interpretation {
        let result: Interpretation = try await client.functions.invoke("interpret-meal", options: .init(body: MealRequest(text: text, image: photo?.base64EncodedString())))
        guard !result.foods.isEmpty, result.foods.count <= 50, result.foods.allSatisfy(\.valid) else { throw AppFailure.invalid }
        return result
    }
}
