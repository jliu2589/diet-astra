import SwiftUI

struct AppRoot: View {
    @State private var account = AccountStore()
    @Environment(\.scenePhase) private var scenePhase
    private var demo: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--demo")
        #else
        false
        #endif
    }
    var body: some View {
        Group {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--keychain-check") { KeychainCheckView() }
            else if ProcessInfo.processInfo.arguments.contains("--v1-ui-check") { V1ReviewHarness() }
            else { appContent }
            #else
            appContent
            #endif
        }
        .tint(AstraStyle.accent)
        .task { if !demo { await account.observeSession() } }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await account.reload(); await account.refreshHealth() } }
        }
    }
    @ViewBuilder private var appContent: some View {
        if demo { ContentView() }
        else if account.backend == nil {
            ContentUnavailableView("Connect Diet Astra", systemImage: "server.rack", description: Text("Add your Supabase project configuration to build this private app. See docs/V1.md for setup. No sample health data is shown in your account."))
        } else if account.userID == nil { SignInView(account: account) }
        else { ContentView(diary: account.diary).environment(\.accountStore, account).id(account.userID) }
    }
}

struct SignInView: View {
    let account: AccountStore
    @State private var email = ""
    @State private var password = ""
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Your space.\nYour progress.").font(.system(.largeTitle, design: .serif))
                    Text("Sign in to your private Diet Astra account.").foregroundStyle(.secondary)
                }.listRowBackground(Color.clear)
                Section {
                    TextField("Email", text: $email).textContentType(.username).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                    SecureField("Password", text: $password).textContentType(.password)
                    Button("Sign in") { Task { await account.signIn(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password); password = "" } }
                        .disabled(account.authBusy || email.isEmpty || password.isEmpty)
                }
                if account.authBusy { ProgressView("Signing in…") }
                if let error = account.error { Text(error).foregroundStyle(.red) }
                Text("Accounts are created privately by the project owner. Contact them if you need access or a password reset.").font(.footnote).foregroundStyle(.secondary)
            }.scrollContentBackground(.hidden).background(AstraStyle.background).navigationTitle("ASTRA")
        }
    }
}
