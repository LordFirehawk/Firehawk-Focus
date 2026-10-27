import AVFoundation
import XCTest
import FirehawkDSP
@testable import FirehawkFocus

@MainActor
final class SoundsLoadingTests: XCTestCase {
    private func entries() throws -> [AmbienceEntry] {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "catalog", withExtension: "json", subdirectory: "Ambience"))
        return try JSONDecoder().decode([AmbienceEntry].self, from: Data(contentsOf: url))
    }
    private func waitUntil(_ predicate: () -> Bool) async throws {
        for _ in 0..<500 {
            if predicate() { return }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("Timed out waiting for decode completion")
    }
    func testOutOfOrderRapidTogglesAndPausedCompletion() async throws {
        let entries = Array(try entries().prefix(2))
        let engine = SoundsAudioEngine(catalog: entries.map(\.descriptor), entries: entries,
                                      decodeQueue: DispatchQueue(label: "test.decode", attributes: .concurrent))
        let firstGate = DispatchSemaphore(value: 0), secondGate = DispatchSemaphore(value: 0)
        let lock = NSLock()
        var calls: [String: Int] = [:]
        engine.decoder = { entry in
            lock.lock(); calls[entry.id, default: 0] += 1; lock.unlock()
            (entry.id == entries[0].id ? firstGate : secondGate).wait()
            let samples = [Float](repeating: 0.1, count: 441)
            return samples.withUnsafeBufferPointer { fh_buffer_create($0.baseAddress, $0.baseAddress, 441)! }
        }
        defer { firstGate.signal(); secondGate.signal() }
        for entry in entries { engine.setRecordingActive(entry.id, active: true, ramp: 3) }
        engine.prepareActive()
        engine.setRecordingActive(entries[0].id, active: false)
        engine.setRecordingActive(entries[0].id, active: true)
        secondGate.signal()
        try await waitUntil { engine.loaded.contains(entries[1].id) }
        XCTAssertFalse(engine.loaded.contains(entries[0].id))
        XCTAssertEqual(engine.fadeInDuration(for: entries[1].id), 3)
        engine.setRecordingActive(entries[0].id, active: false)
        firstGate.signal()
        // The late completion is discarded and never starts the paused graph.
        var completions = 0
        engine.onLoad = { _, _ in completions += 1 }
        try await waitUntil { completions == 1 }
        XCTAssertEqual(engine.loaded, [entries[1].id])
        XCTAssertFalse(engine.engine.isRunning)
        let counts = lock.withLock { calls }
        XCTAssertEqual(counts[entries[0].id], 1)
        XCTAssertEqual(counts[entries[1].id], 1)
    }
    func testFailureLeavesOtherBufferPlaying() async throws {
        let entries = Array(try entries().prefix(2))
        let engine = SoundsAudioEngine(catalog: entries.map(\.descriptor), entries: entries)
        let original = engine.decoder
        engine.decoder = { entry in
            if entry.id == entries[1].id { throw CocoaError(.fileReadCorruptFile) }
            return try original(entry)
        }
        var failures = [String]()
        engine.onLoad = { id, success in if !success { failures.append(id) } }
        engine.setRecordingActive(entries[0].id, active: true)
        engine.prepareActive()
        try await waitUntil { engine.loaded.contains(entries[0].id) }
        engine.setRecordingActive(entries[1].id, active: true)
        try await waitUntil { !failures.isEmpty }
        XCTAssertEqual(failures, [entries[1].id])
        XCTAssertEqual(engine.loaded, [entries[0].id])
        XCTAssertEqual(engine.unavailable, [entries[1].id])
        fh_layer(engine.dsp, 0, 0, 1, 0, 60, 0.04); fh_master(engine.dsp, 1, 0.04)
        var left = [Float](repeating: 0, count: 4096), right = left
        fh_render(engine.dsp, &left, &right, 4096)
        XCTAssertTrue(left.contains { abs($0) > 0.0001 })
    }
    func testEveryRecordingCanLoadAndRetireWithinMemoryBound() async throws {
        let entries = try entries()
        let engine = SoundsAudioEngine(catalog: entries.map(\.descriptor), entries: entries)
        let baseline = engine.decodedBytes
        XCTAssertLessThan(baseline, 100_000)
        engine.prepareActive()
        for entry in entries {
            engine.setRecordingActive(entry.id, active: true)
            try await waitUntil { engine.loaded.contains(entry.id) }
            XCTAssertLessThanOrEqual(engine.decodedBytes, baseline + UInt64(SoundsAudioEngine.maximumClipFrames) * 8)
            engine.setRecordingActive(entry.id, active: false)
            engine.collectInactive(now: ProcessInfo.processInfo.systemUptime + 34)
            XCTAssertEqual(engine.decodedBytes, baseline)
        }
        XCTAssertTrue(engine.loaded.isEmpty)
    }
    func testControllerReportsLoadFailureWithoutResumingPause() async throws {
        let storage = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("sounds.json")
        let controller = SoundsController(storageURL: storage)
        defer { controller.shutdown(); try? FileManager.default.removeItem(at: storage.deletingLastPathComponent()) }
        let engine = try XCTUnwrap(controller.audio)
        let id = try XCTUnwrap(controller.catalog.first { !$0.isGenerated }?.id)
        engine.decoder = { _ in throw CocoaError(.fileReadCorruptFile) }
        engine.setRecordingActive(id, active: true); engine.prepareActive()
        controller.pause()
        try await waitUntil { controller.notice?.kind == .loadFailed }
        XCTAssertFalse(controller.isPlaying)
        XCTAssertFalse(engine.engine.isRunning)
    }
    func testRapidCatalogSweepShedsAllButEightAfterFade() async throws {
        let entries = try entries()
        let engine = SoundsAudioEngine(catalog: entries.map(\.descriptor), entries: entries)
        engine.prepareActive()
        for entry in entries {
            engine.setRecordingActive(entry.id, active: true)
            try await waitUntil { engine.loaded.contains(entry.id) }
            engine.setRecordingActive(entry.id, active: false)
        }
        for entry in entries.suffix(8) { engine.setRecordingActive(entry.id, active: true) }
        engine.collectInactive(now: ProcessInfo.processInfo.systemUptime + 4)
        XCTAssertEqual(engine.loaded.count, 8)
        XCTAssertLessThanOrEqual(engine.decodedBytes, 100_000 + 8 * UInt64(SoundsAudioEngine.maximumClipFrames) * 8)
        engine.collectInactive(now: ProcessInfo.processInfo.systemUptime + 34)
        XCTAssertEqual(engine.loaded.count, 8)
    }
    func testEightLayersAndToneBenchmark() async throws {
        let entries = Array(try entries().prefix(8))
        let engine = SoundsAudioEngine(catalog: entries.map(\.descriptor), entries: entries)
        func rss() -> UInt64 {
            var info = mach_task_basic_info()
            var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)
            let status = withUnsafeMutablePointer(to: &info) {
                $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                    task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
                }
            }
            return status == KERN_SUCCESS ? info.resident_size : 0
        }
        let launch = rss(), start = ProcessInfo.processInfo.systemUptime
        engine.setRecordingActive(entries[0].id, active: true); engine.prepareActive()
        try await waitUntil { !engine.loaded.isEmpty }
        fh_layer(engine.dsp, 0, 0, 0.5, 0, 60, 0.04); fh_master(engine.dsp, 1, 0.3)
        var l = [Float](repeating: 0, count: 512), r = l
        fh_render(engine.dsp, &l, &r, 512)
        let first = ProcessInfo.processInfo.systemUptime - start
        XCTAssertTrue(l.contains { $0 != 0 })
        for (i, entry) in entries.enumerated() {
            engine.setRecordingActive(entry.id, active: true)
            fh_layer(engine.dsp, Int32(i), 0, 0.5, 0, 60, 0.04)
        }
        try await waitUntil { engine.loaded.count == 8 }
        fh_tone(engine.dsp, 0, 220, 10, 0.8, 0.3, 0.04)
        fh_render(engine.dsp, &l, &r, 512)
        print("LAZY BENCH test-process launch RSS=\(launch) eight+tone RSS=\(rss()) decoded=\(engine.decodedBytes) first audible block=\(first)s")
    }
}

final class SoundsBufferRetirementTests: XCTestCase {
    func testConcurrentPublicationRetirementAndRender() {
        let dsp = fh_create(44_100, 1)!
        let baseline = fh_memory(dsp)
        let renderDone = expectation(description: "render")
        DispatchQueue.global().async {
            var l = [Float](repeating: 0, count: 512), r = l
            for _ in 0..<2000 { fh_render(dsp, &l, &r, 512) }
            renderDone.fulfill()
        }
        for count in 1...2000 {
            let samples = [Float](repeating: 0.1, count: count % 1024 + 1)
            samples.withUnsafeBufferPointer {
                fh_install_buffer(dsp, 0, fh_buffer_create($0.baseAddress, $0.baseAddress, UInt32($0.count)))
            }
            if count % 2 == 0 { fh_install_buffer(dsp, 0, nil) }
        }
        wait(for: [renderDone], timeout: 20)
        fh_install_buffer(dsp, 0, nil); fh_collect(dsp)
        XCTAssertEqual(fh_memory(dsp), baseline)
        fh_destroy(dsp)
    }
}
