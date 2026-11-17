import SwiftUI

struct CameraListView: View {
    @Environment(ServerSettings.self) private var settings
    @Environment(CamerasModel.self) private var model
    @State private var showSettings = false
    @State private var detailCamera: Camera?
    @State private var width: CGFloat = 0
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var grid: GridLayout { GridLayout(isRegular: sizeClass == .regular, width: width) }

    var body: some View {
        content
            .toolbarTitleDisplayMode(.inline) // no title: the cameras speak for themselves
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSettings = true } label: { Label("Settings", systemImage: "gearshape") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Task { await reload() } } label: { Label("Refresh", systemImage: "arrow.clockwise") }
                        .disabled(settings.baseURL == nil)
                }
            }
            .navigationDestination(for: Camera.self) { camera in
                if let api = model.api { LiveView(camera: camera, api: api) }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(item: $detailCamera) { camera in
                if let api = model.api {
                    CameraDetailView(camera: camera, api: api) { model.update($0) }
                }
            }
            .task(id: settings.baseURL) { await reload() }
            .refreshable { await reload() }
    }

    private func reload() async { await model.load(baseURL: settings.baseURL) }

    @ViewBuilder private var content: some View {
        switch model.state {
        case .noServer:
            ContentUnavailableView {
                Text("Add your Frigate server").font(.title2.bold())
            } description: {
                Text("Enter the address of your Frigate server to see your cameras.")
            } actions: {
                Button("Open Settings") { showSettings = true }.buttonStyle(.borderedProminent)
            }
        case .failed(let message) where model.visible.isEmpty:
            ContentUnavailableView {
                Label("Can't load cameras", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Retry") { Task { await reload() } }.buttonStyle(.borderedProminent)
            }
        case .idle, .loading:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        default:
            if model.visible.isEmpty {
                ContentUnavailableView("No cameras", systemImage: "video.slash",
                                       description: Text("No cameras are shown. Check Manage Cameras in Settings."))
            } else if let api = model.api {
                ScrollView {
                    if let error = model.refreshError {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .padding(.horizontal, 16)
                            .accessibilityLabel("Couldn't refresh. \(error)")
                    }
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: grid.spacing), count: grid.columns),
                              spacing: grid.spacing) {
                        ForEach(model.visible) { camera in
                            NavigationLink(value: camera) { CameraCard(camera: camera, api: api) }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button { detailCamera = camera } label: {
                                        Label("Details", systemImage: "info.circle")
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, grid.spacing)
                    .padding(.bottom, grid.spacing)
                }
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
            }
        }
    }
}
