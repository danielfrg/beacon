import UIKit
import Observation

/// Allows at most `limit` operations at once; extra callers wait their turn.
actor RequestLimiter {
    static let shared = RequestLimiter(limit: 4)

    private let limit: Int
    private var active = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(limit: Int) { self.limit = limit }

    func run<T: Sendable>(_ operation: @Sendable () async throws -> T) async throws -> T {
        if active >= limit {
            await withCheckedContinuation { waiters.append($0) }
        } else {
            active += 1
        }
        defer { release() }
        return try await operation()
    }

    private func release() {
        if waiters.isEmpty {
            active -= 1
        } else {
            waiters.removeFirst().resume() // hand the slot straight to the next waiter
        }
    }
}

/// Keeps one camera's latest snapshot fresh by polling while started.
@MainActor
@Observable
final class SnapshotModel {
    typealias Fetch = @Sendable (Camera, Int) async throws -> UIImage

    static let freshWindow: TimeInterval = 10
    nonisolated static func interval(lowPower: Bool) -> TimeInterval { lowPower ? 10 : 2 }

    private(set) var image: UIImage?
    private(set) var lastUpdated: Date?
    private(set) var isFresh = false
    /// True while fetches are failing and there is no image to show yet.
    private(set) var hasFailed = false

    private let camera: Camera
    private let height: Int
    private let fetch: Fetch
    private let now: () -> Date
    private let interval: () -> TimeInterval
    private let sleep: (TimeInterval) async -> Void
    private var task: Task<Void, Never>?

    init(camera: Camera,
         height: Int = 360,
         fetch: @escaping Fetch,
         now: @escaping () -> Date = { Date() },
         interval: @escaping () -> TimeInterval = { SnapshotModel.interval(lowPower: ProcessInfo.processInfo.isLowPowerModeEnabled) },
         sleep: @escaping (TimeInterval) async -> Void = { try? await Task.sleep(for: .seconds($0)) }) {
        self.camera = camera
        self.height = height
        self.fetch = fetch
        self.now = now
        self.interval = interval
        self.sleep = sleep
    }

    /// Production fetcher: goes through the shared request limiter.
    static func fetcher(api: FrigateAPI) -> Fetch {
        { camera, height in
            let data = try await RequestLimiter.shared.run { try await api.snapshotData(for: camera, height: height) }
            guard let image = UIImage(data: data) else { throw FrigateError.invalidResponse }
            return image
        }
    }

    func start() {
        guard task == nil, camera.enabled else { return }
        task = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.tick()
                await self.sleep(self.interval())
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    private func tick() async {
        if let fetched = try? await fetch(camera, height), !Task.isCancelled {
            image = fetched
            lastUpdated = now()
            hasFailed = false
        } else if !Task.isCancelled {
            hasFailed = true
        }
        isFresh = lastUpdated.map { now().timeIntervalSince($0) < Self.freshWindow } ?? false
    }
}
