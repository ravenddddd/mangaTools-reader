import Foundation

/// The custom fields the mangaTools plugin owns. The plugin never writes
/// Stash's own chapter rows; these are the fields its reader lives on.
enum Fields {
    static let mark = "plugin.mangaTools.manga"
    static let chapters = "plugin.mangaTools.chapters"
    static let language = "plugin.mangaTools.language"
    static let group = "plugin.mangaTools.translationGroup"
    static let censorship = "plugin.mangaTools.censorship"
    static let original = "plugin.mangaTools.original"
}

/// One chapter as the plugin stores it: a name and the **set** of images in it.
struct MangaChapter: Identifiable, Hashable {
    /// Position in the stored list — the list order is the reading order.
    let id: Int
    /// May be empty: the plugin allows an unnamed chapter.
    let title: String
    /// Image ids. Not a sequence — the images are drawn in Stash's path order
    /// and this only says which ones belong here.
    let imageIDs: [String]

    var displayTitle: String {
        title.isEmpty ? "Chapter \(id + 1)" : title
    }
}

enum Chapters {
    /// The plugin writes two versions of the field; both carry `images`.
    ///
    /// Returns nil for anything this reader cannot read — an absent field, a
    /// value somebody edited by hand, a version from a newer plugin — so the
    /// caller can fall back to reading the whole gallery as one book. An empty
    /// array is a gallery whose chapters were deliberately cleared.
    static func parse(_ raw: String?) -> [MangaChapter]? {
        guard let raw, let data = raw.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let version = object["v"] as? Int, version == 1 || version == 2,
              let rows = object["chapters"] as? [[String: Any]] else {
            return nil
        }

        return rows.enumerated().map { index, row in
            let ids = (row["images"] as? [Any] ?? []).compactMap { value -> String? in
                if let text = value as? String { return text }
                if let number = value as? NSNumber { return number.stringValue }
                return nil
            }
            return MangaChapter(id: index, title: row["title"] as? String ?? "", imageIDs: ids)
        }
    }
}
