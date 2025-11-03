import SwiftUI

@main
struct HurricaneReplayApp: App {
    @StateObject private var storm = StormData.loadFromBundle()

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .environmentObject(storm)
        }
        ImmersiveSpace(id: "immersive") {
            ImmersiveView()
                .environmentObject(storm)
        }
    }
}
