import SwiftUI

@main
struct PicInnApp: App {
    var body: some Scene {
        WindowGroup {
#if os(macOS)
            ContentView()
                .frame(minWidth: 480, minHeight: 640)
#else
            ContentView()
#endif
        }
    }
}
