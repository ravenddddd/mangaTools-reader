import SwiftUI

/// The other works of one translation group, pushed from the group pill.
struct GroupWorksView: View {
    let group: String
    let excluding: String

    @EnvironmentObject private var session: Session
    @Environment(\.dismiss) private var dismiss

    @State private var galleries: [Gallery] = []
    @State private var loading = false
    @State private var errorMessage: String?

    private var shown: [Gallery] {
        galleries.filter { $0.id != excluding }
    }

    var body: some View {
        NavigationStack {
            Group {
                if loading && galleries.isEmpty {
                    ProgressView()
                } else if let errorMessage, galleries.isEmpty {
                    ContentUnavailableView(
                        "Cannot load this group",
                        systemImage: "wifi.slash",
                        description: Text(errorMessage)
                    )
                } else if shown.isEmpty {
                    ContentUnavailableView(
                        "Nothing else",
                        systemImage: "person.2",
                        description: Text("No other work carries this group.")
                    )
                } else {
                    List(shown) { gallery in
                        NavigationLink(value: gallery) {
                            row(for: gallery)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(group)
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Gallery.self) { gallery in
                WorkView(gallery: gallery)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await load() }
        }
    }

    private func row(for gallery: Gallery) -> some View {
        HStack(spacing: 12) {
            RemoteImage(path: gallery.paths?.cover)
                .frame(width: 44, height: 58)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(gallery.displayTitle)
                    .font(.subheadline)
                    .lineLimit(2)
                if let year = gallery.year {
                    Text(year)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func load() async {
        guard galleries.isEmpty, let client = session.client else { return }
        loading = true
        errorMessage = nil
        do {
            galleries = try await client.galleries(inGroup: group)
        } catch {
            errorMessage = error.localizedDescription
        }
        loading = false
    }
}
