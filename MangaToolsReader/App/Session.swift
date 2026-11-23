import Foundation

/// Where the app talks to and with what key. The address is ordinary
/// preferences; the key lives in the keychain.
struct StashConfig: Equatable {
    var baseURL: String
    var apiKey: String

    static func load() -> StashConfig? {
        let defaults = UserDefaults.standard
        guard let address = defaults.string(forKey: Keys.baseURL), !address.isEmpty,
              let key = Keychain.read(account: Keys.apiKey) else {
            return nil
        }
        return StashConfig(baseURL: address, apiKey: key)
    }

    func save() {
        UserDefaults.standard.set(baseURL, forKey: Keys.baseURL)
        Keychain.write(account: Keys.apiKey, value: apiKey)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: Keys.baseURL)
        Keychain.delete(account: Keys.apiKey)
    }

    private enum Keys {
        static let baseURL = "stash.baseURL"
        static let apiKey = "stash.apiKey"
    }
}

@MainActor
final class Session: ObservableObject {
    @Published private(set) var config: StashConfig?

    init() {
        config = StashConfig.load()
    }

    var isConfigured: Bool { config != nil }

    /// A client for the current server, or nil before the first setup.
    var client: StashClient? {
        config.map(StashClient.init)
    }

    func use(_ config: StashConfig) {
        self.config = config
        config.save()
    }

    func signOut() {
        StashConfig.clear()
        config = nil
    }
}
