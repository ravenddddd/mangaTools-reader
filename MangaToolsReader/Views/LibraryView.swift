import SwiftUI

/// The shelf: every gallery the plugin marked as manga, as covers.
struct LibraryView: View {
    @EnvironmentObject private var session: Session

    @State private var galleries: [Gallery] = []
    @State private var loading = false
    @State private var errorMessage: String?
    @State private var search = ""
    @State private var showsSettings = false

    private let columns = [GridItem(.adaptive(minimum: 140), spacing: 12)]

    private var filtered: [Gallery] {
        let needle = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return galleries }
        return galleries.filter { gallery in
            if gallery.displayTitle.lowercased().contains(needle) { return true }
            if let circle = gallery.circle, circle.lowercased().contains(needle) { return true }
            return (gallery.tags ?? []).contains { $0.name.lowercased().contains(needle) }
        }
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("mangaTools")
                .searchable(text: $search, prompt: "Title, circle or tag")
                .navigationDestination(for: Gallery.self) { gallery in
                    WorkView(gallery: gallery)
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            galleries.shuffle()
                        } label: {
                            Image(systemName: "shuffle")
                        }
                        .disabled(galleries.isEmpty)
                        .accessibilityLabel("Shuffle the shelf")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showsSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                        }
                    }
                }
                .sheet(isPresented: $showsSettings) {
                    SettingsView()
                }
                .task {
                    if galleries.isEmpty { await load() }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if galleries.isEmpty && loading {
            ProgressView("Reading the library…")
        } else if let errorMessage, galleries.isEmpty {
            ContentUnavailableView {
                Label("Cannot reach Stash", systemImage: "wifi.slash")
            } description: {
                Text(errorMessage)
            } actions: {
                Button("Try again") {
                    Task { await load() }
                }
            }
        } else if galleries.isEmpty {
            ContentUnavailableView(
                "No manga yet",
                systemImage: "books.vertical",
                description: Text("Mark a gallery as manga in Stash, then pull to refresh.")
            )
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(filtered) { gallery in
                        NavigationLink(value: gallery) {
                            card(gallery)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
            .refreshable {
                await load()
            }
        }
    }

    private func card(_ gallery: Gallery) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            RemoteImage(path: gallery.paths?.cover)
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            // Two reserved lines and a reserved line for the circle: every card
            // is then the same height, whether or not its title is long or its
            // studio is set.
            Text(gallery.displayTitle)
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.leading)
                .lineLimit(2, reservesSpace: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(gallery.circle ?? " ")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func load() async {
        guard let client = session.client else { return }
        loading = true
        errorMessage = nil
        do {
            // The order is the shelf's own: random, not Stash's title sort.
            let works = try await client.galleries()
            galleries = works.shuffled()
        } catch {
            errorMessage = error.localizedDescription
        }
        loading = false
    }
}
