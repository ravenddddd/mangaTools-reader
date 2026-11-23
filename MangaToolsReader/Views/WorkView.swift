import SwiftUI
import UIKit

/// One work: the artwork as a header, the three facts the plugin keeps about it,
/// then the details and the chapters.
struct WorkView: View {
    let gallery: Gallery

    @EnvironmentObject private var session: Session
    @Environment(\.openURL) private var openURL

    @State private var images: [StashImage] = []
    @State private var loading = false
    @State private var errorMessage: String?
    @State private var open: OpenChapter?
    @State private var showsGroup = false
    @State private var synopsisExpanded = false
    @State private var tagsExpanded = false
    @State private var scrolled = false

    private static let tagLimit = 6

    private struct OpenChapter: Identifiable {
        let index: Int
        var id: Int { index }
    }

    private struct OffsetKey: PreferenceKey {
        static var defaultValue: CGFloat = 0
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = nextValue()
        }
    }

    // MARK: - Derived

    private var storedChapters: [MangaChapter] { gallery.chapters ?? [] }

    private var isSingleBook: Bool { storedChapters.isEmpty }

    private var sections: [MangaChapter] {
        isSingleBook ? [MangaChapter(id: 0, title: "", imageIDs: [])] : storedChapters
    }

    private var pageTotal: Int { gallery.imageCount ?? images.count }

    private var chapterTotal: Int { isSingleBook ? 1 : storedChapters.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                hero
                metaPills
                statsCard
                tagsSection
                synopsisSection
                chaptersSection
                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                }
                Color.clear.frame(height: 28)
            }
        }
        .coordinateSpace(name: "work")
        .background(Color(.systemGroupedBackground))
        .ignoresSafeArea(edges: .top)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(scrolled ? .visible : .hidden, for: .navigationBar)
        .toolbarColorScheme(scrolled ? nil : .dark, for: .navigationBar)
        .tint(scrolled ? nil : .white)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(gallery.displayTitle)
                    .font(.headline)
                    .lineLimit(1)
                    .opacity(scrolled ? 1 : 0)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Open in Stash") { openInStash() }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
        .onPreferenceChange(OffsetKey.self) { value in
            let next = value < -60
            if next != scrolled {
                scrolled = next
            }
        }
        .task { await load() }
        .sheet(isPresented: $showsGroup) {
            GroupWorksView(group: gallery.translationGroup ?? "", excluding: gallery.id)
        }
        .fullScreenCover(item: $open) { chapter in
            ReaderView(
                gallery: gallery,
                images: images,
                chapters: storedChapters,
                chapterIndex: chapter.index
            )
        }
    }

    // MARK: - Header

    private var hero: some View {
        HeroBackdrop(path: gallery.paths?.cover)
            .frame(height: 300)
            .overlay(alignment: .bottom) {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.55),
                        .init(color: Color(.systemGroupedBackground).opacity(0.85), location: 0.86),
                        .init(color: Color(.systemGroupedBackground), location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .overlay(alignment: .bottomLeading) {
                HStack(alignment: .bottom, spacing: 13) {
                    RemoteImage(path: gallery.paths?.cover)
                        .frame(width: 96, height: 128)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .shadow(color: .black.opacity(0.35), radius: 12, x: 0, y: 8)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(gallery.displayTitle)
                            .font(.title3.weight(.bold))
                            .lineLimit(2)
                        if let circle = gallery.circle {
                            Text(circle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
            .clipped()
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: OffsetKey.self,
                        value: proxy.frame(in: .named("work")).minY
                    )
                }
            }
    }

    // MARK: - Facts

    private var metaPills: some View {
        FlowLayout(spacing: 8) {
            if let language = gallery.languageName {
                pill(icon: "globe", text: language)
            }
            if let group = gallery.translationGroup {
                Button {
                    showsGroup = true
                } label: {
                    pill(icon: "person.2", text: group, chevron: true)
                }
                .buttonStyle(.plain)
            }
            if gallery.isOriginal && gallery.translationGroup == nil {
                pill(icon: "sparkle", text: "Original")
            }
            if let censorship = gallery.censorshipLabel {
                pill(
                    icon: gallery.isUncensored ? "checkmark.shield" : "eye.slash",
                    text: censorship,
                    tint: gallery.isUncensored ? .green : .secondary
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private func pill(
        icon: String,
        text: String,
        chevron: Bool = false,
        tint: Color = .secondary
    ) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(tint)
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
            if chevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(Color(.secondarySystemGroupedBackground), in: Capsule())
        .overlay(Capsule().strokeBorder(Color(.separator), lineWidth: 0.5))
    }

    private var statsCard: some View {
        card {
            HStack(spacing: 8) {
                stat("\(pageTotal)", "Pages")
                stat("\(chapterTotal)", "Chapters")
                stat(gallery.year ?? "—", "Released")
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
        }
        .padding(.top, 8)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .semibold))
                .monospacedDigit()
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Tags

    @ViewBuilder
    private var tagsSection: some View {
        let tags = gallery.tags ?? []
        if !tags.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                sectionTitle("Tags")
                card {
                    FlowLayout(spacing: 6) {
                        ForEach(visibleTags(tags)) { tag in
                            Text(tag.name)
                                .font(.system(size: 13))
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .background(
                                    Color(.secondarySystemFill),
                                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                                )
                        }
                        if tags.count > Self.tagLimit {
                            Button {
                                withAnimation(.easeOut(duration: 0.15)) { tagsExpanded.toggle() }
                            } label: {
                                Text(tagsExpanded ? "Less" : "+\(tags.count - Self.tagLimit)")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(12)
                }
            }
        }
    }

    private func visibleTags(_ tags: [NamedEntity]) -> [NamedEntity] {
        tagsExpanded ? tags : Array(tags.prefix(Self.tagLimit))
    }

    // MARK: - Synopsis

    @ViewBuilder
    private var synopsisSection: some View {
        if let details = gallery.details?.trimmingCharacters(in: .whitespacesAndNewlines),
           !details.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                sectionTitle("Synopsis")
                card {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(details)
                            .font(.system(size: 15))
                            .lineSpacing(2)
                            .lineLimit(synopsisExpanded ? nil : 2)
                        if details.count > 80 {
                            Button {
                                withAnimation(.easeOut(duration: 0.15)) { synopsisExpanded.toggle() }
                            } label: {
                                Text(synopsisExpanded ? "Less" : "More")
                                    .font(.system(size: 15))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Color.accentColor)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                }
            }
        }
    }

    // MARK: - Chapters

    private var chaptersSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionTitle("Chapters")
            card {
                VStack(spacing: 0) {
                    if loading && images.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                    } else {
                        ForEach(Array(sections.enumerated()), id: \.element.id) { position, chapter in
                            chapterRow(chapter)
                            if position < sections.count - 1 {
                                Divider().padding(.leading, 16)
                            }
                        }
                    }
                }
            }
        }
    }

    private func chapterRow(_ chapter: MangaChapter) -> some View {
        let count = pageCount(of: chapter)
        return Button {
            open = OpenChapter(index: chapter.id)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(isSingleBook ? "Read" : chapter.displayTitle)
                        .font(.system(size: 17))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    Text(count == 1 ? "1 page" : "\(count) pages")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                if let badge = progressBadge(for: chapter, pageCount: count) {
                    Text(badge)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Color.accentColor.opacity(0.11),
                            in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                        )
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(count == 0)
    }

    private func progressBadge(for chapter: MangaChapter, pageCount: Int) -> String? {
        guard pageCount > 0,
              let position = ProgressStore.position(for: gallery.id),
              position.chapter == chapter.id else {
            return nil
        }
        return "page \(min(position.page + 1, pageCount))"
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

    // MARK: - Pieces

    private func sectionTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 7)
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .padding(.horizontal, 16)
    }

    // MARK: - Actions

    private func openInStash() {
        guard let base = session.config?.baseURL else { return }
        var root = base.trimmingCharacters(in: .whitespacesAndNewlines)
        while root.hasSuffix("/") { root.removeLast() }
        guard let url = URL(string: root + "/galleries/" + gallery.id) else { return }
        openURL(url)
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

/// The cover, blown up and blurred, as the header's background. Falls back to a
/// soft gradient until the image arrives (and for a gallery without a cover).
///
/// The image is framed by a `GeometryReader`, not left to `scaledToFill`'s own
/// idea of its size: a `scaledToFill` image reports the height its aspect ratio
/// needs (390 × ~430 for a 3:4 cover), and an enclosing `ZStack` would lay the
/// title out against *that* height — below the 300 pt the header clips at.
private struct HeroBackdrop: View {
    let path: String?

    @EnvironmentObject private var session: Session
    @State private var image: UIImage?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.11, green: 0.14, blue: 0.25),
                        Color(red: 0.48, green: 0.25, blue: 0.37),
                        Color(red: 0.85, green: 0.55, blue: 0.37),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                        .blur(radius: 36)
                        .overlay(Color.black.opacity(0.12))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .task(id: path) {
            image = nil
            guard let path, let config = session.config else { return }
            image = try? await ImageStore.shared.image(for: path, config: config)
        }
    }
}
