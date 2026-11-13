import SwiftUI

@main
struct BeaconApp: App {
    @State private var settings = ServerSettings()
    @State private var cameras = CamerasModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(settings)
                .environment(cameras)
        }
    }
}
