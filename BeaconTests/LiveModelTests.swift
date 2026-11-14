import XCTest
@testable import Beacon

private final class FakeConnector: LiveConnector, @unchecked Sendable {
    enum Behavior { case succeed, fail, hang, stubborn }

    private let lock = NSLock()
    private var _behavior: Behavior
    private var _disconnects = 0
    private var _cancelled = false
    private var _connects = 0
    private var _failureHandler: (@Sendable (String) -> Void)?
    private var stuck: CheckedContinuation<Void, Error>?

    var behavior: Behavior {
        get { lock.withLock { _behavior } }
        set { lock.withLock { _behavior = newValue } }
    }
    var disconnects: Int { lock.withLock { _disconnects } }
    var cancelled: Bool { lock.withLock { _cancelled } }
    var connects: Int { lock.withLock { _connects } }
    var failureHandler: (@Sendable (String) -> Void)? { lock.withLock { _failureHandler } }

    init(_ behavior: Behavior) { _behavior = behavior }

    func setFailureHandler(_ handler: @escaping @Sendable (String) -> Void) {
        lock.withLock { _failureHandler = handler }
    }

    func connect() async throws {
        let current = lock.withLock { () -> Behavior in _connects += 1; return _behavior }
        switch current {
        case .succeed: return
        case .fail: throw FrigateError.unreachable
        case .stubborn:
            // Like the bridged WebRTC callbacks: ignores Task cancellation, only disconnect() frees it.
            try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in
                lock.withLock { stuck = c }
            }
        case .hang:
            do { try await Task.sleep(nanoseconds: 60_000_000_000) } catch {
                lock.withLock { _cancelled = true }
                throw error
            }
        }
    }

    func disconnect() {
        let waiting = lock.withLock { () -> CheckedContinuation<Void, Error>? in
            _disconnects += 1
            defer { stuck = nil }
            return stuck
        }
        waiting?.resume(throwing: CancellationError())
    }
}

@MainActor
final class LiveModelTests: XCTestCase {
    private func waitUntil(_ timeout: TimeInterval = 2, _ condition: () -> Bool) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() && Date() < deadline { try? await Task.sleep(nanoseconds: 2_000_000) }
    }

    /// A clock that never fires, so only the connector decides the outcome.
    private let neverSleep: (TimeInterval) async -> Void = { _ in try? await Task.sleep(nanoseconds: 60_000_000_000) }
    /// A clock that fires at once, i.e. the timeout elapses immediately.
    private let instantSleep: (TimeInterval) async -> Void = { _ in }

    func testConnectSuccessGoesLive() async {
        let model = LiveModel(connector: FakeConnector(.succeed), timeout: 8, sleep: neverSleep)
        model.start()
        await waitUntil { model.mode == .live }
        XCTAssertEqual(model.mode, .live)
        model.stop()
    }

    func testSuccessfulConnectionIsNotTornDown() async {
        // Regression: the cancelled timeout timer used to call disconnect() on the connection that had just succeeded.
        let connector = FakeConnector(.succeed)
        let model = LiveModel(connector: connector, timeout: 8, sleep: neverSleep)
        model.start()
        await waitUntil { model.mode == .live }
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(model.mode, .live)
        XCTAssertEqual(connector.disconnects, 0)
        model.stop()
    }

    func testConnectFailureFallsBackWithReason() async {
        let model = LiveModel(connector: FakeConnector(.fail), timeout: 8, sleep: neverSleep)
        model.start()
        await waitUntil { if case .fallback = model.mode { true } else { false } }
        guard case .fallback(let reason) = model.mode else { return XCTFail("expected fallback, got \(model.mode)") }
        XCTAssertFalse(reason.isEmpty)
        model.stop()
    }

    func testConnectTimeoutFallsBack() async {
        let connector = FakeConnector(.hang)
        let model = LiveModel(connector: connector, timeout: 8, sleep: instantSleep)
        model.start()
        await waitUntil { if case .fallback = model.mode { true } else { false } }
        guard case .fallback(let reason) = model.mode else { return XCTFail("expected fallback, got \(model.mode)") }
        XCTAssertTrue(reason.lowercased().contains("timed out"))
        XCTAssertGreaterThanOrEqual(connector.disconnects, 1)
    }

    func testRetryReconnects() async {
        let connector = FakeConnector(.fail)
        let model = LiveModel(connector: connector, timeout: 8, sleep: neverSleep)
        model.start()
        await waitUntil { if case .fallback = model.mode { true } else { false } }
        connector.behavior = .succeed
        model.retry()
        await waitUntil { model.mode == .live }
        XCTAssertEqual(model.mode, .live)
        XCTAssertEqual(connector.connects, 2)
        model.stop()
    }

    func testStopCancelsConnection() async {
        let connector = FakeConnector(.hang)
        let model = LiveModel(connector: connector, timeout: 8, sleep: neverSleep)
        model.start()
        await waitUntil { connector.connects == 1 }
        model.stop()
        await waitUntil { connector.cancelled }
        XCTAssertTrue(connector.cancelled)
        XCTAssertGreaterThanOrEqual(connector.disconnects, 1)
    }

    func testLiveDropFallsBack() async {
        let connector = FakeConnector(.succeed)
        let model = LiveModel(connector: connector, timeout: 8, sleep: neverSleep)
        model.start()
        await waitUntil { model.mode == .live }
        connector.failureHandler?("connection lost")
        await waitUntil { if case .fallback = model.mode { true } else { false } }
        XCTAssertEqual(model.mode, .fallback(reason: "connection lost"))
        XCTAssertGreaterThanOrEqual(connector.disconnects, 1, "a dropped connection must be closed, not left open")
        model.stop()
    }

    func testTimeoutDisconnectsSoAConnectThatIgnoresCancellationCannotHangTheDeadline() async {
        let connector = FakeConnector(.stubborn)
        let model = LiveModel(connector: connector, timeout: 8, sleep: instantSleep)
        model.start()
        await waitUntil { if case .fallback = model.mode { true } else { false } }
        guard case .fallback = model.mode else { return XCTFail("still \(model.mode): the timeout never fired") }
    }
}
