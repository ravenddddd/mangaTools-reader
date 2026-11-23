import SwiftUI

/// One work: its cover, and its chapters as a list of entry points.
struct WorkView: View {
    let gallery: Gallery

    @EnvironmentObject private var session: Session

    @State private var images: [StashImage] = []
    @State private var loading = false
    @State private var errorMessage: String?
    @State private var open: OpenChapter?

    private struct OpenChapter: Identifiable {
        let index: Int
        var id: Int { index }
    }

    private var storedChapters: [MangaChapter] { gallery.chapters ?? [] }

    private var isSingleBook: Bool { storedChapters.isEmpty }

    private var sections: [MangaChapter] {
        isSingleBook ? [MangaChapter(id: 0, title: "", imageIDs: [])] : storedChapters
    }

    var body: some View {
        List {
            Section {
                header
            }

            Section("Chapters") {
                if loading && images.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else {
                    ForEach(sections) { chapter in
                        Button {
                            open = OpenChapter(index: chapter.id)
                        } label: {
                            row(for: chapter)
                        }
                        .disabled(pageCount(of: chapter) == 0)
                    }
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(gallery.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .fullScreenCover(item: $open) { chapter in
            ReaderView(
                gallery: gallery,
                images: images,
                chapters: storedChapters,
                chapterIndex: chapter.index
            )
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            RemoteImage(path: gallery.paths?.cover)
                .frame(width: 96, height: 128)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(gallery.displayTitle)
                    .font(.headline)
                if let circle = gallery.circle {
                    Text(circle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if let language = gallery.language {
                    Text(language)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let details = gallery.details, !details.isEmpty {
                    Text(details)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                }
            }
        }
    }

    private func row(for chapter: MangaChapter) -> some View {
        let count = pageCount(of: chapter)
        let position = ProgressStore.position(for: gallery.id)
        let resume = position?.chapter == chapter.id ? position?.page : nil
        return HStack {
            Text(chapter.displayTitle)
                .foregroundStyle(.primary)
                .lineLimit(2)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(count == 1 ? "1 page" : "\(count) pages")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let resume, count > 0 {
                    Text("page \(min(resume + 1, count))")
                        .font(.caption2)
                        .foregroundStyle(.tint)
                }
            }
        }
    }

    /// A chapter is a set of image ids; its pages are those images in the
    /// gallery's path order.
    private func pageCount(of chapter: MangaChapter) -> Int {
        if isSingleBook { return images.count }
        let ids = Set(chapter.imageIDs)
        return images.reduce(into: 0) { count, image in
            if ids.contains(image.id) { count += 1 }
        }
    }

    private func load() async {
        guard images.isEmpty, let client = session.client else { return }
        loading = true
        errorMessage = nil
        do {
            images = try await client.images(galleryID: gallery.id)
        } catch {
            errorMessage = error.localizedDescription
        }
        loading = false
    }
}
