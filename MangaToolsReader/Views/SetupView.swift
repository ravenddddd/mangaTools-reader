import SwiftUI

/// First run: where the server is, and the key to read it.
struct SetupView: View {
    @EnvironmentObject private var session: Session

    @State private var address = ""
    @State private var apiKey = ""
    @State private var testing = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("http://stash.local:9999", text: $address)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    SecureField("API key", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Stash server")
                } footer: {
                    Text("The key is in Stash under Settings › Security. It is kept in this device's keychain.")
                }

                Section {
                    Button {
                        Task { await testAndSave() }
                    } label: {
                        HStack {
                            Text(testing ? "Testing…" : "Connect")
                            Spacer()
                            if testing { ProgressView() }
                        }
                    }
                    .disabled(testing || address.trimmingCharacters(in: .whitespaces).isEmpty)
                } footer: {
                    if let message {
                        Text(message)
                    }
                }
            }
            .navigationTitle("mangaTools Reader")
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
