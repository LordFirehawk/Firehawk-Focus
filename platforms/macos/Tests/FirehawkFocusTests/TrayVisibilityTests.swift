import Combine
import XCTest
@testable import FirehawkFocus

final class TrayVisibilityTests: XCTestCase {
    @MainActor
    private func makeEngine(remainingMs: Double) throws -> (FocusEngine, URL) {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        let now = Date().timeIntervalSince1970 * 1000
        let state: [String: Any] = [
            "phase": "focus", "status": "running",
            "endsAtMs": now + remainingMs, "remainingMs": remainingMs,
            "sessionDurationMs": 60_000, "startedAtMs": now - 10_000,
            "config": ["trackApps": false, "notifications": false, "soundEnabled": false],
            "sessions": []
        ]
        try JSONSerialization.data(withJSONObject: state).write(to: url)
        return (FocusEngine(stateFileURL: url, requestsNotifications: false), url)
    }

    @MainActor
    func testHiddenTimerUpdatesClockWithoutPublishingRingOrStatistics() async throws {
        let (engine, url) = try makeEngine(remainingMs: 30_000)
        defer { try? FileManager.default.removeItem(at: url) }
        let initialProgress = engine.progress
        let clockChanged = expectation(description: "Background countdown advances")
        var progressUpdates = 0
        var statisticsUpdates = 0
        let clock = engine.$clockText.dropFirst().prefix(1).sink { _ in clockChanged.fulfill() }
        let progress = engine.$progress.dropFirst().sink { _ in progressUpdates += 1 }
        let statistics = engine.$week.dropFirst().sink { _ in statisticsUpdates += 1 }

        await fulfillment(of: [clockChanged], timeout: 3)
        XCTAssertEqual(progressUpdates, 0)
        XCTAssertEqual(statisticsUpdates, 0)
        XCTAssertEqual(engine.progress, initialProgress)

        engine.setTrayVisible(true)
        XCTAssertGreaterThan(engine.progress, initialProgress)
        XCTAssertGreaterThan(statisticsUpdates, 0)

        engine.setTrayVisible(false)
        let updatesAtClose = progressUpdates
        let nextClock = expectation(description: "Countdown continues after closing")
        let next = engine.$clockText.dropFirst().prefix(1).sink { _ in nextClock.fulfill() }
        await fulfillment(of: [nextClock], timeout: 3)
        XCTAssertEqual(progressUpdates, updatesAtClose)
        withExtendedLifetime([clock, progress, statistics, next]) {}
    }

    @MainActor
    func testHiddenTimerStillCompletesAndPersistsSession() async throws {
        let (engine, url) = try makeEngine(remainingMs: 300)
        defer { try? FileManager.default.removeItem(at: url) }
        let completed = expectation(description: "Hidden timer completes")
        let subscription = engine.$status.filter { $0 == .complete }.prefix(1).sink { _ in completed.fulfill() }

        await fulfillment(of: [completed], timeout: 3)
        XCTAssertEqual(engine.clockText, "0:00")
        let saved = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        XCTAssertEqual(saved["status"] as? String, "complete")
        engine.primaryAction()
        let accepted = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        XCTAssertEqual((accepted["sessions"] as? [[String: Any]])?.count, 1)
        withExtendedLifetime(subscription) {}
    }
}
