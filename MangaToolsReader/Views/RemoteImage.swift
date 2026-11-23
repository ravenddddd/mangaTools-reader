import SwiftUI

/// An image from Stash, loaded through `ImageStore` so the API key travels with
/// the request.
struct RemoteImage: View {
    let path: String?
    var contentMode: ContentMode = .fill

    @EnvironmentObject private var session: Session
    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        ZStack {
            Rectangle().fill(Color(.secondarySystemBackground))
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
