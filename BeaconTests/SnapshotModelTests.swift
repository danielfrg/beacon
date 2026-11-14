import XCTest
import UIKit
@testable import Beacon

private actor Counter {
    var current = 0, peak = 0, done = 0
    func enter() { current += 1; peak = max(peak, current) }
    func leave() { current -= 1; done += 1 }
}

@MainActor
final class SnapshotModelTests: XCTestCase {
    private let camera = Camera(name: "front_door", enabled: true, detectEnabled: false, motionEnabled: false,
                                recordEnabled: false, snapshotsEnabled: false, width: nil, height: nil, fps: nil,
                                goStream: "front_door")

    private final class Box: @unchecked Sendable {
        var fetches = 0
        var sleeps: [TimeInterval] = []
        var now = Date(timeIntervalSince1970: 1000)
        var fail = false
        var lowPower = false
    }

    private func makeModel(_ box: Box) -> SnapshotModel {
        SnapshotModel(
            camera: camera,
            fetch: { _, _ in
                box.fetches += 1
                if box.fail { throw FrigateError.unreachable }
                return UIImage()
            },
            now: { box.now },
            interval: { SnapshotModel.interval(lowPower: box.lowPower) },
            sleep: { seconds in
                box.sleeps.append(seconds)
                try? await Task.sleep(nanoseconds: 2_000_000)
            })
    }

    private func waitUntil(_ timeout: TimeInterval = 2, _ condition: () -> Bool) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() && Date() < deadline { try? await Task.sleep(nanoseconds: 2_000_000) }
    }

    func testRefreshesOnInterval() async {
        let box = Box()
        let model = makeModel(box)
        model.start()
        await waitUntil { box.fetches >= 3 }
        model.stop()
        XCTAssertGreaterThanOrEqual(box.fetches, 3)
        XCTAssertEqual(Set(box.sleeps), [2])
        XCTAssertNotNil(model.image)
    }

    func testStopHaltsRefresh() async {
        let box = Box()
        let model = makeModel(box)
        model.start()
        await waitUntil { box.fetches >= 1 }
        model.stop()
        try? await Task.sleep(nanoseconds: 20_000_000)
        let count = box.fetches
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(box.fetches, count)
    }

    func testFreshnessTurnsStaleAfter10s() async {
        let box = Box()
        let model = makeModel(box)
        model.start()
        await waitUntil { model.isFresh }
        XCTAssertTrue(model.isFresh)
        box.fail = true
        let before = box.fetches
        await waitUntil { box.fetches >= before + 2 } // any in-flight success has landed
        box.now = box.now.addingTimeInterval(11)
        await waitUntil { !model.isFresh }
        model.stop()
        XCTAssertFalse(model.isFresh)
        XCTAssertNotNil(model.image, "keeps the last good image while stale")
    }

    func testLowPowerUsesSlowInterval() async {
        XCTAssertEqual(SnapshotModel.interval(lowPower: false), 2)
        XCTAssertEqual(SnapshotModel.interval(lowPower: true), 10)
        let box = Box()
        box.lowPower = true
        let model = makeModel(box)
        model.start()
        await waitUntil { box.sleeps.count >= 1 }
        model.stop()
        XCTAssertEqual(box.sleeps.first, 10)
    }

    func testFailureWithoutAnImageIsReported() async {
        let box = Box()
        box.fail = true
        let model = makeModel(box)
        XCTAssertFalse(model.hasFailed)
        model.start()
        await waitUntil { model.hasFailed }
        XCTAssertTrue(model.hasFailed)
        XCTAssertNil(model.image)
        box.fail = false
        await waitUntil { !model.hasFailed }
        model.stop()
        XCTAssertFalse(model.hasFailed, "recovers when a fetch succeeds")
    }

    func testDisabledCameraNeverFetches() async {
        let box = Box()
        var disabled = camera
        disabled.enabled = false
        let model = SnapshotModel(camera: disabled, fetch: { _, _ in box.fetches += 1; return UIImage() })
        model.start()
        try? await Task.sleep(nanoseconds: 30_000_000)
        model.stop()
        XCTAssertEqual(box.fetches, 0)
    }

    func testLimiterCapsConcurrency() async throws {
        let limiter = RequestLimiter(limit: 2)
        let counter = Counter()
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<6 {
                group.addTask {
                    try? await limiter.run {
                        await counter.enter()
                        try await Task.sleep(nanoseconds: 15_000_000)
                        await counter.leave()
                    }
                }
            }
        }
        let peak = await counter.peak
        let done = await counter.done
        XCTAssertLessThanOrEqual(peak, 2)
        XCTAssertEqual(done, 6)
    }
}
