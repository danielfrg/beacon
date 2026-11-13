import SwiftUI

/// A rounded 16:9 card showing a camera's latest snapshot, its name and a freshness dot.
struct CameraCard: View {
    let camera: Camera
    @State private var snapshot: SnapshotModel
    @Environment(\.scenePhase) private var scenePhase

    init(camera: Camera, api: FrigateAPI) {
        self.camera = camera
        _snapshot = State(initialValue: SnapshotModel(camera: camera, fetch: SnapshotModel.fetcher(api: api)))
    }

    var body: some View {
        Color(.secondarySystemBackground)
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
            .overlay { picture }
            .overlay(alignment: .bottom) { caption }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(camera.name), \(statusText)")
            .onAppear { if scenePhase == .active { snapshot.start() } }
            .onDisappear { snapshot.stop() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { snapshot.start() } else { snapshot.stop() }
            }
    }

    private var statusText: String {
        !camera.enabled ? "disabled" : snapshot.isFresh ? "live" : "no signal"
    }

    @ViewBuilder private var picture: some View {
        if let image = snapshot.image {
            Image(uiImage: image).resizable().scaledToFill()
        } else if camera.enabled {
            ProgressView()
        } else {
            Image(systemName: "video.slash").font(.title).foregroundStyle(.secondary)
        }
    }

    private var caption: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(snapshot.isFresh ? Color.green : Color.gray)
                .frame(width: 8, height: 8)
            Text(camera.name).font(.headline)
            if !camera.enabled { Text("Disabled").font(.caption).foregroundStyle(.white.opacity(0.7)) }
            Spacer()
        }
        .foregroundStyle(.white)
        .padding(12)
        .background(LinearGradient(colors: [.clear, .black.opacity(0.65)], startPoint: .top, endPoint: .bottom))
    }
}
