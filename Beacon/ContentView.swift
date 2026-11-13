import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            CameraListView()
        }
    }
}

#Preview {
    ContentView()
        .environment(ServerSettings())
        .environment(CamerasModel())
}
