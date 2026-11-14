import SwiftUI

struct ContentView: View {
    @AppStorage(Appearance.storageKey) private var appearance = Appearance.default.rawValue

    var body: some View {
        NavigationStack {
            CameraListView()
        }
        .preferredColorScheme(Appearance(storedValue: appearance).colorScheme)
    }
}

#Preview {
    ContentView()
        .environment(ServerSettings())
        .environment(CamerasModel())
}
