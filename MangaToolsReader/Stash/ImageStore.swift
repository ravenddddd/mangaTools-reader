import UIKit

/// Loads Stash's images with the API key attached, and keeps the ones it has
/// seen.
///
/// SwiftUI's `AsyncImage` cannot set a header, which is what an authenticated
/// Stash needs, so image requests go through here instead.
@MainActor
final class ImageStore {
    static let shared = ImageStore()

    private let cache = NSCache<NSString, UIImage>()
    /// One request per URL: a cover is asked for by the grid and by the details
    /// page at almost the same moment.
    private var running: [String: Task<UIImage, Error>] = [:]

    private init() {
        cache.countLimit = 240
    }

    func image(for path: String, config: StashConfig) async throws -> UIImage {
        let urlString = absolute(path: path, base: config.baseURL)
        if let hit = cache.object(forKey: urlString as NSString) {
            return hit
        }
        if let task = running[urlString] {
            return try await task.value
        }

        let task = Task<UIImage, Error> {
            guard let url = URL(string: urlString) else {
                throw StashError.badURL(urlString)
            }
            var request = URLRequest(url: url)
            if !config.apiKey.isEmpty {
                request.setValue(config.apiKey, forHTTPHeaderField: "ApiKey")
            }
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw StashError.http(-1)
            }
            guard (200..<300).contains(http.statusCode) else {
                throw StashError.http(http.statusCode)
            }
            guard let image = UIImage(data: data) else {
                throw StashError.notAnImage
            }
            return image
        }
        running[urlString] = task
        defer { running[urlString] = nil }

        let image = try await task.value
        cache.setObject(image, forKey: urlString as NSString)
        return image
    }

    /// Stash answers with absolute URLs, but a relative one is handled too.
    func absolute(path: String, base: String) -> String {
        let lower = path.lowercased()
        if lower.hasPrefix("http://") || lower.hasPrefix("https://") {
            return path
        }
        var root = base.trimmingCharacters(in: .whitespacesAndNewlines)
        while root.hasSuffix("/") { root.removeLast() }
        let cleaned = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return root + "/" + cleaned
    }

    func clear() {
        cache.removeAllObjects()
    }
}
