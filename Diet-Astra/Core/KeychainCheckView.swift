#if DEBUG
import SwiftUI
import Supabase

// Exercises storage inside the app process, where Simulator entitlements matter.
struct KeychainCheckView: View {
    @State private var result = "Checking Keychain…"
    var body: some View {
        Text(result).task {
            let storage = KeychainLocalStorage(service: "DietAstra.StorageCheck")
            let key = UUID().uuidString
            let sentinel = Data("storage-check-only".utf8)
            do {
                try storage.store(key: key, value: sentinel)
                defer { try? storage.remove(key: key) }
                guard try storage.retrieve(key: key) == sentinel else {
                    result = "Keychain read failed"; return
                }
                result = "Keychain storage verified"
            } catch {
                result = "Keychain storage unavailable"
            }
        }
    }
}
#endif
