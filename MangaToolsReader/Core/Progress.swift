import Foundation

/// Where the reader stopped: a chapter and a page inside it.
struct ReadingPosition: Codable, Equatable {
    var chapter: Int
    var page: Int
}

/// Reading positions, one per gallery, kept on the device.
///
/// The plugin's own reader keeps nothing, so this is the app's own memory and
/// nothing is written back to Stash.
enum ProgressStore {
    private static let key = "reading.positions"

    static func position(for galleryID: String) -> ReadingPosition? {
        positions()[galleryID]
    }

    static func save(_ position: ReadingPosition, for galleryID: String) {
        var all = positions()
        all[galleryID] = position
        guard let data = try? JSONEncoder().encode(all) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func forget(galleryID: String) {
        var all = positions()
        all.removeValue(forKey: galleryID)
        guard let data = try? JSONEncoder().encode(all) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private static func positions() -> [String: ReadingPosition] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let all = try? JSONDecoder().decode([String: ReadingPosition].self, from: data) else {
            return [:]
        }
        return all
    }
}
