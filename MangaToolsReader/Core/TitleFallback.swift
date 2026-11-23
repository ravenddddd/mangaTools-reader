import Foundation

/// Stash's own rule for naming a gallery: its title, else the name of its first
/// file, else its folder (`ui/v2.5/src/core/galleries.ts`, `galleryTitle`).
///
/// The library carries galleries that were imported but never titled, and in
/// Stash's interface those are named by their archive. The catalog should read
/// the same, or a reader shows names nobody recognises.
enum TitleFallback {
    static func displayTitle(for gallery: Gallery) -> String {
        if let title = gallery.title?.trimmingCharacters(in: .whitespacesAndNewlines),
           !title.isEmpty {
            return title
        }
        if let path = gallery.files?.first?.path, let name = name(from: path) {
            return name
        }
        if let path = gallery.folder?.path, let name = name(from: path) {
            return name
        }
        return "Gallery \(gallery.id)"
    }

    /// The last segment of a path, without an archive extension. Both separators
    /// are handled: Stash's paths are POSIX, a Windows instance's are not.
    static func name(from path: String) -> String? {
        var name = path.trimmingCharacters(in: .whitespacesAndNewlines)
        while name.hasSuffix("/") || name.hasSuffix("\\") {
            name.removeLast()
        }
        if let index = name.lastIndex(where: { $0 == "/" || $0 == "\\" }) {
            name = String(name[name.index(after: index)...])
        }
        for suffix in [".zip", ".cbz", ".cbr", ".rar", ".7z"]
        where name.lowercased().hasSuffix(suffix) {
            name = String(name.dropLast(suffix.count))
            break
        }
        return name.isEmpty ? nil : name
    }
}
