import SwiftUI

/// An image from Stash, loaded through `ImageStore` so the API key travels with
/// the request.
///
/// The picture is an **overlay on a fill**, never a child that can size the
/// view: `scaledToFill` reports the size its aspect ratio needs, which is larger
/// than the frame it was given, and a `ZStack` around it grows to that size —
/// in a grid that means cards of different heights and covers drawn over their
/// neighbours. A `Color` takes exactly the proposed size, and the image lays out
/// inside it, clipped.
struct RemoteImage: View {
    let path: String?
    var contentMode: ContentMode = .fill

    @EnvironmentObject private var session: Session
    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        Color(.secondarySystemBackground)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                } else if failed {
                    Image(systemName: "photo")
                        .font(.title3)
                        .foregroundStyle(.tertiary)
                } else {
                    ProgressView()
                }
            }
            .clipped()
            .task(id: path) {
                await load()
            }
    }

    private func load() async {
        image = nil
        failed = false
        guard let path, let config = session.config else {
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
