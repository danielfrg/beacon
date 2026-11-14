import Foundation
import Observation
import OSLog

/// Something that can establish a live video connection (WebRTC in production, a fake in tests).
protocol LiveConnector: AnyObject, Sendable {
    /// Called if an established connection later fails.
    func setFailureHandler(_ handler: @escaping @Sendable (String) -> Void)
    /// Returns once video is flowing; throws if it can't be established.
    func connect() async throws
    func disconnect()
}

/// Drives the live view: connecting → live, or a snapshot fallback with a reason.
@MainActor
@Observable
final class LiveModel {
    enum Mode: Equatable {
        case connecting
        case live
        case fallback(reason: String)
    }

    private(set) var mode: Mode = .connecting {
        didSet { Self.log.info("live mode: \(String(describing: self.mode), privacy: .public)") }
    }
    private static let log = Logger(subsystem: "com.example.Beacon", category: "live")

    private let connector: LiveConnector
    private let timeout: TimeInterval
    private let sleep: (TimeInterval) async -> Void
    private var task: Task<Void, Never>?
    private var generation = 0

    init(connector: LiveConnector,
         timeout: TimeInterval = 8,
         sleep: @escaping (TimeInterval) async -> Void = { try? await Task.sleep(for: .seconds($0)) }) {
        self.connector = connector
        self.timeout = timeout
        self.sleep = sleep
        connector.setFailureHandler { [weak self] reason in
            Task { @MainActor in self?.handleDrop(reason) }
        }
    }

    func start() {
        guard task == nil else { return }
        run()
    }

    func retry() {
        cancel()
        run()
    }

    func stop() {
        cancel()
    }

    private func cancel() {
        generation += 1
        task?.cancel()
        task = nil
        connector.disconnect()
    }

    private func run() {
        mode = .connecting
        generation += 1
        let current = generation
        task = Task { [weak self] in
            guard let self else { return }
            let result = await self.attempt()
            guard !Task.isCancelled, current == self.generation else { return }
            switch result {
            case .success:
                self.mode = .live
            case .failure(let failure):
                self.connector.disconnect()
                self.mode = .fallback(reason: failure.reason)
            }
        }
    }

    private struct Failure: Error { let reason: String }

    /// Races the connection against the timeout; the first to finish wins.
    private func attempt() async -> Result<Void, Failure> {
        let connector = self.connector
        let timeout = self.timeout
        let sleep = self.sleep
        return await withTaskGroup(of: Result<Void, Failure>.self) { group in
            group.addTask {
                do {
                    try await connector.connect()
                    return .success(())
                } catch {
                    return .failure(Failure(reason: Self.describe(error)))
                }
            }
            group.addTask {
                await sleep(timeout)
                // A cancelled timer wakes early; that means connect() already won, so leave it alone.
                if Task.isCancelled { return .failure(Failure(reason: "Cancelled")) }
                // connect() may be stuck in calls that ignore cancellation; tearing the connection
                // down is what frees it, so the deadline really is a deadline.
                connector.disconnect()
                return .failure(Failure(reason: "Timed out connecting to live video."))
            }
            let first = await group.next() ?? .failure(Failure(reason: "Live video unavailable."))
            group.cancelAll()
            return first
        }
    }

    private func handleDrop(_ reason: String) {
        guard mode == .live else { return }
        connector.disconnect() // don't leave the dead session's socket and peer open
        mode = .fallback(reason: reason)
    }

    private nonisolated static func describe(_ error: Error) -> String {
        error is FrigateError ? FrigateError.userMessage(for: error)
            : "Couldn't connect to live video (\(error.localizedDescription))"
    }
}
