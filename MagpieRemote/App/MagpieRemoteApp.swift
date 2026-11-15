import SwiftUI
import SwiftData

@main
struct MagpieRemoteApp: App {
    @State private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appModel)
        }
        .modelContainer(for: Connection.self)
    }
}