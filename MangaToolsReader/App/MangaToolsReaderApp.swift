import SwiftUI

@main
struct MangaToolsReaderApp: App {
    @StateObject private var session = Session()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
        }
    }
}

/// The server setup until there is one, the library after.
struct RootView: View {
    @EnvironmentObject private var session: Session

    var body: some View {
        if session.isConfigured {
            LibraryView()
        } else {
            SetupView()
        }
    }
}
