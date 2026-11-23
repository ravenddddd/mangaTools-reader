import Foundation

struct NamedEntity: Codable, Hashable {
    let id: String
    let name: String
}

/// The subset of Stash's Gallery a shelf card and a reader need.
struct Gallery: Codable, Identifiable, Hashable {
    let id: String
    let title: String?
    let details: String?
    let date: String?
    let updatedAt: String?
    let imageCount: Int?
    let studio: NamedEntity?
    let tags: [NamedEntity]?
    let customFields: [String: JSONValue]?
    let paths: Paths?
    let files: [FileEntry]?
    let folder: Folder?

    struct Paths: Codable, Hashable {
        let cover: String?
    }

    struct FileEntry: Codable, Hashable {
        let path: String
    }

    struct Folder: Codable, Hashable {
        let path: String
    }

    var displayTitle: String { TitleFallback.displayTitle(for: self) }

    var circle: String? {
        guard let name = studio?.name, !name.isEmpty else { return nil }
        return name
    }

    var language: String? { customFields?[Fields.language]?.string }

    /// The plugin's chapters, or nil when this gallery has none this reader can
    /// read (and so is one book over the whole gallery).
    var chapters: [MangaChapter]? { Chapters.parse(customFields?[Fields.chapters]?.string) }

    private enum CodingKeys: String, CodingKey {
        case id, title, details, date, updatedAt, imageCount, studio, tags,
             customFields, paths, files, folder
    }
}

/// One page as Stash's image API knows it.
struct StashImage: Codable, Identifiable, Hashable {
    let id: String
    let title: String?
    let paths: Paths

    struct Paths: Codable, Hashable {
        let image: String
        let thumbnail: String?
    }
}
