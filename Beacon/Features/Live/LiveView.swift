import SwiftUI
import WebRTC

/// Full-screen live view: WebRTC video, or refreshing snapshots when live video isn't available.
struct LiveView: View {
    let camera: Camera
    let api: FrigateAPI

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(CamerasModel.self) private var cameras

    @State private var connector: WebRTCConnector
    @State private var live: LiveModel
    @State private var snapshot: SnapshotModel
    @State private var track: RTCVideoTrack?
    @State private var controlsVisible = true
    @State private var showDetails = false

    init(camera: Camera, api: FrigateAPI) {
        self.camera = camera
        self.api = api
        let connector = WebRTCConnector(signalingURL: api.signalingURL(for: camera))
        _connector = State(initialValue: connector)
        _live = State(initialValue: LiveModel(connector: connector))
        _snapshot = State(initialValue: SnapshotModel(camera: camera, height: 720, fetch: SnapshotModel.fetcher(api: api)))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            content
            if controlsVisible { controls.transition(.opacity) }
        }
        .contentShape(Rectangle())
        .onTapGesture { withAnimation { controlsVisible.toggle() } }
        .task(id: controlsVisible) {
            guard controlsVisible else { return }
            try? await Task.sleep(for: .seconds(3))
            if !Task.isCancelled { withAnimation { controlsVisible = false } }
        }
        .toolbar(.hidden, for: .navigationBar)
        .background(SwipeBackEnabler())
        .statusBarHidden()
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showDetails) {
            CameraDetailView(camera: camera, api: api) { cameras.update($0) }
        }
        .onAppear {
            connector.onVideoTrack = { track = $0 }
            UIApplication.shared.isIdleTimerDisabled = true
            live.start()
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            live.stop()
            snapshot.stop()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { live.retry() } else { live.stop(); snapshot.stop() }
        }
        .onChange(of: live.mode) { _, mode in
            if case .fallback = mode { snapshot.start() } else { snapshot.stop() }
        }
    }

    @ViewBuilder private var content: some View {
        switch live.mode {
        case .connecting:
            VStack(spacing: 12) {
                ProgressView().tint(.white)
                Text("Connecting…").font(.subheadline).foregroundStyle(.white.opacity(0.7))
            }
        case .live:
            VideoSurface(track: track).ignoresSafeArea()
                .accessibilityLabel("Live video of \(camera.name)")
        case .fallback(let reason):
            ZStack {
                if let image = snapshot.image {
                    Image(uiImage: image).resizable().scaledToFit()
                        .accessibilityLabel("Latest snapshot of \(camera.name)")
                }
                VStack {
                    Spacer()
                    fallbackBanner(reason)
                }
            }
        }
    }

    private func fallbackBanner(_ reason: String) -> some View {
        VStack(spacing: 8) {
            Label("Live video unavailable", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold))
            Text(reason).font(.caption).foregroundStyle(.white.opacity(0.7)).multilineTextAlignment(.center)
            Button("Try Again") { live.retry() }
                .buttonStyle(.borderedProminent)
        }
        .foregroundStyle(.white)
        .padding()
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding()
    }

    private var controls: some View {
        VStack {
            HStack {
                circleButton("xmark", label: "Close") { dismiss() }
                Spacer()
                Text(camera.name).font(.headline).foregroundStyle(.white)
                Spacer()
                circleButton("info.circle", label: "Details") { showDetails = true }
            }
            .padding(.horizontal)
            Spacer()
        }
    }

    private func circleButton(_ systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial, in: Circle())
        }
        .accessibilityLabel(label)
    }
}
