import SwiftUI

@main
struct GalleryApp: App {
    var body: some Scene {
        WindowGroup("SwiftShaders Gallery") {
            ContentView()
                .frame(minWidth: 1080, minHeight: 720)
        }
        .windowResizability(.contentMinSize)
    }
}
