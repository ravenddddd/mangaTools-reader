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

    var languageName: String? { LanguageName.display(customFields?[Fields.language]?.string) }

    var translationGroup: String? {
        guard let raw = customFields?[Fields.group]?.string else { return nil }
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    var censorshipLabel: String? { Censorship.label(customFields?[Fields.censorship]?.string) }

    var isUncensored: Bool { Censorship.isUncensored(customFields?[Fields.censorship]?.string) }

    /// The plugin's two ways of saying "nothing was translated": its own field,
    /// and the language code that means the work has no text of its own.
    var isOriginal: Bool {
        if let value = customFields?[Fields.original]?.string, !value.isEmpty {
            return true
        }
        return customFields?[Fields.language]?.string == "zxx"
    }

    /// The release year, when Stash has a date for the work.
    var year: String? {
        guard let date, date.count >= 4 else { return nil }
        let prefix = String(date.prefix(4))
        return Int(prefix) != nil ? prefix : nil
    }

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
