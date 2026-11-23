import Foundation

/// A read-only client for Stash's GraphQL API, scoped to what a manga shelf
/// needs: the galleries the mangaTools plugin marked, and their images in path
/// order.
struct StashClient {
    let config: StashConfig
    private let urlSession = URLSession.shared

    init(config: StashConfig) {
        self.config = config
    }

    // MARK: - Queries

    func version() async throws -> String {
        let data: VersionData = try await query("query { version { version } }", as: VersionData.self)
        return data.version.version
    }

    /// Every gallery the plugin marks as manga. The mark is the filter, so a
    /// gallery without it never reaches the shelf.
    func galleries() async throws -> [Gallery] {
        let text = """
        query Works {
          findGalleries(
            gallery_filter: { custom_fields: [{ field: "\(Fields.mark)", modifier: NOT_NULL }] }
            filter: { per_page: -1, sort: "title", direction: ASC }
          ) {
            galleries {
              id
              title
              details
              date
              updated_at
              image_count
              studio { id name }
              tags { id name }
              custom_fields
              paths { cover }
              files { path }
              folder { path }
            }
          }
        }
        """
        let data: WorksData = try await query(text, as: WorksData.self)
        return data.findGalleries.galleries
    }

    /// One gallery's images in Stash's path order — the order its own lightbox
    /// and the plugin's chapters both count in.
    func images(galleryID: String) async throws -> [StashImage] {
        let text = """
        query Images($id: ID!) {
          findImages(
            image_filter: { galleries: { value: [$id], modifier: INCLUDES } }
            filter: { per_page: -1, sort: "path", direction: ASC }
          ) {
            images { id title paths { image thumbnail } }
          }
        }
        """
        let data: ImagesData = try await query(
            text,
            variables: ["id": galleryID],
            as: ImagesData.self
        )
        return data.findImages.images
    }

    // MARK: - Transport

    private struct Envelope<T: Decodable>: Decodable {
        let data: T?
        let errors: [GraphQLError]?
    }

    private struct GraphQLError: Decodable {
        let message: String
    }

    private struct VersionData: Decodable {
        let version: Version
        struct Version: Decodable { let version: String }
    }

    private struct WorksData: Decodable {
        let findGalleries: Galleries
        struct Galleries: Decodable { let galleries: [Gallery] }
    }

    private struct ImagesData: Decodable {
        let findImages: Images
        struct Images: Decodable { let images: [StashImage] }
    }

    private func query<T: Decodable>(
        _ text: String,
        variables: [String: Any] = [:],
        as type: T.Type
    ) async throws -> T {
        guard let url = URL(string: normalizedBase + "/graphql") else {
            throw StashError.badURL(config.baseURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !config.apiKey.isEmpty {
            request.setValue(config.apiKey, forHTTPHeaderField: "ApiKey")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "query": text,
            "variables": variables,
        ])

        let (payload, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw StashError.http(-1)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw StashError.http(http.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let envelope: Envelope<T>
        do {
            envelope = try decoder.decode(Envelope<T>.self, from: payload)
        } catch {
            throw StashError.shape(String(describing: error))
        }
        if let message = envelope.errors?.first?.message {
            throw StashError.graphQL(message)
        }
        guard let data = envelope.data else {
            throw StashError.graphQL("Stash answered with no data.")
        }
        return data
    }

    private var normalizedBase: String {
        var base = config.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        while base.hasSuffix("/") { base.removeLast() }
        let lower = base.lowercased()
        if !lower.hasPrefix("http://") && !lower.hasPrefix("https://") {
            base = "http://" + base
        }
        return base
    }
}

enum StashError: LocalizedError {
    case badURL(String)
    case http(Int)
    case graphQL(String)
    case shape(String)
    case notAnImage

    var errorDescription: String? {
        switch self {
        case .badURL(let value):
            return "The server address “\(value)” is not a URL."
        case .http(let code):
            return code > 0
                ? "Stash answered with status \(code)."
                : "Stash did not answer."
        case .graphQL(let message):
            return message
        case .shape(let detail):
            return "The answer did not fit the expected shape: \(detail)"
        case .notAnImage:
            return "Stash answered with something that is not an image."
        }
    }
}
