import SwiftUI
import UIKit

/// The reader: one chapter, page by page, swiped horizontally.
struct ReaderView: View {
    let gallery: Gallery
    let images: [StashImage]
    let chapters: [MangaChapter]
    let chapterIndex: Int

    @Environment(\.dismiss) private var dismiss

    @State private var current: Int? = 0
    @State private var showsChrome = true
    @State private var zoomed = false

    private var chapter: MangaChapter? {
        chapters.indices.contains(chapterIndex) ? chapters[chapterIndex] : nil
    }

    /// The chapter is a set of ids; the pages are those images in the
    /// gallery's path order — the same order Stash's lightbox draws.
    private var pages: [StashImage] {
        guard let chapter else { return images }
        let ids = Set(chapter.imageIDs)
        return images.filter { ids.contains($0.id) }
    }

    private var title: String {
        chapter?.displayTitle ?? gallery.displayTitle
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if pages.isEmpty {
                Text("This chapter has no pages.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            } else {
                pager
            }

            if showsChrome {
                chrome
                    .transition(.opacity)
            }
        }
        .onAppear {
            current = startPage
        }
    }

    private var pager: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(pages.indices, id: \.self) { index in
                    ReaderPage(
                        path: pages[index].paths.image,
                        onTap: toggleChrome,
                        onZoomChanged: { zoomed = $0 }
                    )
                    .containerRelativeFrame([.horizontal, .vertical])
                    .id(index)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.never)
        .scrollDisabled(zoomed)
        .scrollPosition(id: $current)
        .ignoresSafeArea()
        .onChange(of: current) { _, value in
            zoomed = false
            if let value { save(position: value) }
        }
    }

    private var chrome: some View {
        VStack {
            HStack(spacing: 12) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .frame(width: 44, height: 44)
                        .background(.black.opacity(0.45), in: Circle())
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(gallery.displayTitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                }

                Spacer()

                Text("\((current ?? 0) + 1) / \(pages.count)")
                    .font(.footnote.monospacedDigit())
            }
            .foregroundStyle(.white)
            .padding(.horizontal)
            .padding(.top, 8)

            Spacer()

            ProgressView(
                value: Double(min((current ?? 0) + 1, pages.count)),
                total: Double(max(pages.count, 1))
            )
            .tint(.white)
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Position

    private var startPage: Int {
        guard pages.count > 0,
              let saved = ProgressStore.position(for: gallery.id),
              saved.chapter == chapterIndex else {
            return 0
        }
        return min(max(saved.page, 0), pages.count - 1)
    }

    private func save(position page: Int) {
        guard !pages.isEmpty else { return }
        ProgressStore.save(ReadingPosition(chapter: chapterIndex, page: page), for: gallery.id)
    }

    private func toggleChrome() {
        withAnimation(.easeOut(duration: 0.15)) {
            showsChrome.toggle()
        }
    }
}

/// One page: its image, once it has arrived, inside the zoom view.
private struct ReaderPage: View {
    let path: String
    let onTap: () -> Void
    let onZoomChanged: (Bool) -> Void

    @EnvironmentObject private var session: Session
    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        ZStack {
            Color.black
            if let image {
                ZoomableImage(image: image, onSingleTap: onTap, onZoomChanged: onZoomChanged)
            } else if failed {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.5))
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .task(id: path) {
            await load()
        }
    }

    private func load() async {
        image = nil
        failed = false
        guard let config = session.config else {
            failed = true
            return
        }
        do {
            image = try await ImageStore.shared.image(for: path, config: config)
        } catch {
            failed = true
        }
    }
}
