import SwiftUI

/// The server the shelf is read from, and the way out of it.
struct SettingsView: View {
    @EnvironmentObject private var session: Session
    @Environment(\.dismiss) private var dismiss

    @State private var address = ""
    @State private var apiKey = ""
    @State private var testing = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Address", text: $address)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    SecureField("API key", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Stash server")
                }

                Section {
                    Button {
                        Task { await testAndSave() }
                    } label: {
                        HStack {
                            Text(testing ? "Testing…" : "Save")
                            Spacer()
                            if testing { ProgressView() }
                        }
                    }
                    .disabled(testing)

                    Button("Sign out", role: .destructive) {
                        dismiss()
                        session.signOut()
                    }
                } footer: {
                    if let message {
                        Text(message)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                address = session.config?.baseURL ?? ""
                apiKey = session.config?.apiKey ?? ""
            }
        }
    }

    private func testAndSave() async {
        testing = true
        message = nil
        let config = StashConfig(baseURL: address, apiKey: apiKey)
        do {
            let version = try await StashClient(config: config).version()
            session.use(config)
            message = "Connected to Stash \(version)."
        } catch {
            message = error.localizedDescription
        }
        testing = false
    }
}
