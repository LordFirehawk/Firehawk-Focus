import AVFoundation
import AudioToolbox
import AppKit
import XCTest
import FirehawkDSP
@testable import FirehawkFocus

final class SoundsDSPTests: XCTestCase {
    private let rate = 44_100.0
    private func render(_ dsp: OpaquePointer, frames: Int) -> ([Float], [Float]) {
        var l = [Float](repeating: 0, count: frames), r = l
        fh_render(dsp, &l, &r, UInt32(frames))
        return (l, r)
    }
    private func frequency(_ values: ArraySlice<Float>) -> Double {
        let crossings = zip(values, values.dropFirst()).filter { $0 <= 0 && $1 > 0 }.count
        return Double(crossings) * rate / Double(values.count)
    }
    func testBundledCatalogLoopsAndLevels() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "catalog", withExtension: "json", subdirectory: "Ambience"))
        let entries = try JSONDecoder().decode([AmbienceEntry].self, from: Data(contentsOf: url))
        XCTAssertEqual(entries.count, 34)
        XCTAssertEqual(Set(entries.map(\.id)).count, entries.count)
        XCTAssertEqual(Set(entries.map(\.file)).count, entries.count)
        XCTAssertTrue(Set(["rain", "fireplace", "thunder", "dawn-chorus", "tree-frogs", "train", "beach-waves", "seagulls", "rain-tent", "cabin-hum", "wind-chimes", "clock-ticking", "typing-pages", "winter-walk"]).isSubset(of: Set(entries.map(\.id))))
        XCTAssertTrue(Set(["campfire", "bonfire", "waterfall", "thunder-close", "thunderstorm", "clock", "cafe", "night-frogs"]).isSubset(of: Set(entries.map(\.id))))
        XCTAssertEqual(entries.first { $0.id == "clock-ticking" }?.name, "Fast clock")
        XCTAssertEqual(entries.first { $0.id == "campfire" }?.gainDb, -4.5)
        XCTAssertEqual(entries.first { $0.id == "bullfrogs" }?.gainDb, -4.0)
        XCTAssertEqual(entries.first { $0.id == "cafe" }?.name, "Café")
        let directory = url.deletingLastPathComponent()
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        XCTAssertEqual(Set(files.filter { $0.pathExtension == "flac" }.map(\.lastPathComponent)), Set(entries.map(\.file)))
        XCTAssertTrue(files.filter { $0.pathExtension == "caf" }.isEmpty)
        XCTAssertTrue(files.filter { $0.pathExtension == "m4a" }.isEmpty)
        var totalFrames: Int64 = 0
        for entry in entries {
            let sound = try XCTUnwrap(Bundle.module.url(forResource: entry.file, withExtension: nil, subdirectory: "Ambience"))
            let file = try AVAudioFile(forReading: sound)
            let duration = try XCTUnwrap(entry.loopEndSeconds)
            XCTAssertEqual(file.length, Int64(duration * 44_100), entry.id)
            XCTAssertLessThanOrEqual(Int64(duration * 44_100), SoundsAudioEngine.maximumClipFrames)
            XCTAssertEqual(file.processingFormat.sampleRate, 44_100)
            XCTAssertEqual(file.processingFormat.channelCount, 2)
            XCTAssertFalse(entry.credit.isEmpty)
            XCTAssertNotNil(NSImage(systemSymbolName: entry.symbolName, accessibilityDescription: nil), entry.id)
            XCTAssertTrue(["CC0-1.0", "CC-BY-4.0", "Public Domain", "CC-BY-3.0"].contains(entry.license))
            if entry.license.hasPrefix("CC-BY-") {
                let version = entry.license == "CC-BY-3.0" ? "3.0" : "4.0"
                XCTAssertTrue(entry.credit.contains("https://creativecommons.org/licenses/by/\(version)/"))
                XCTAssertTrue(entry.credit.contains(entry.sourceURL.absoluteString))
            }
            totalFrames += file.length
            let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)))
            try file.read(into: buffer)
            XCTAssertEqual(Int64(buffer.frameLength), file.length, entry.id)
            let pcm = try XCTUnwrap(buffer.floatChannelData)
            var energy = 0.0
            for c in 0..<2 {
                let count = Int(buffer.frameLength)
                for i in 0..<count { energy += Double(pcm[c][i]) * Double(pcm[c][i]) }
                let seam = abs(pcm[c][0] - pcm[c][count-1])
                let nearby = (1..<1000).map { abs(pcm[c][$0] - pcm[c][$0-1]) }.max()!
                XCTAssertLessThanOrEqual(seam, nearby * 1.5 + 0.002, entry.id)
                XCTAssertTrue((0..<count).allSatisfy { pcm[c][$0].isFinite && abs(pcm[c][$0]) <= 0.502 })
            }
            let rms = sqrt(energy / Double(buffer.frameLength * 2))
            XCTAssertEqual(20 * log10(rms), -23, accuracy: 0.1, entry.id)
        }
        let engine = SoundsAudioEngine(catalog: entries.map(\.descriptor), entries: entries)
        XCTAssertTrue(engine.unavailable.isEmpty)
        XCTAssertEqual(engine.ids.count, 34)
        XCTAssertLessThan(engine.decodedBytes, 100_000)
        XCTAssertTrue(engine.loaded.isEmpty)
        print("Bundled decoded audio bytes including DSP: \(engine.decodedBytes)")
    }
    func testEveryCatalogFLACLoopMatchesExpectedLengthAndSeam() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "catalog", withExtension: "json", subdirectory: "Ambience"))
        let entries = try JSONDecoder().decode([AmbienceEntry].self, from: Data(contentsOf: url))
        for entry in entries {
            let sound = try XCTUnwrap(Bundle.module.url(forResource: entry.file, withExtension: nil, subdirectory: "Ambience"))
            XCTAssertEqual(sound.pathExtension, "flac", entry.id)
            let file = try AVAudioFile(forReading: sound)
            XCTAssertEqual(file.fileFormat.streamDescription.pointee.mFormatID, kAudioFormatFLAC, entry.id)
            let expected = Int64(try XCTUnwrap(entry.loopEndSeconds) * 44_100)
            XCTAssertEqual(file.length, expected, entry.id)
            let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)))
            try file.read(into: buffer)
            XCTAssertEqual(Int64(buffer.frameLength), expected, entry.id)
            let pcm = try XCTUnwrap(buffer.floatChannelData)
            for channel in 0..<2 {
                let count = Int(buffer.frameLength)
                let seam = abs(pcm[channel][0] - pcm[channel][count - 1])
                let nearby = (1..<1000).map { abs(pcm[channel][$0] - pcm[channel][$0 - 1]) }.max()!
                XCTAssertLessThanOrEqual(seam, nearby * 1.5 + 0.002, entry.id)
            }
        }
    }
    func testCafeteriaFLACDecodesExactLoopLengthAndSeam() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "cafeteria", withExtension: "flac", subdirectory: "Ambience"))
        let file = try AVAudioFile(forReading: url)
        XCTAssertEqual(file.fileFormat.streamDescription.pointee.mFormatID, kAudioFormatFLAC)
        let frames = 234 * 44_100
        XCTAssertEqual(file.length, Int64(frames))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(frames)))
        try file.read(into: buffer)
        XCTAssertEqual(Int(buffer.frameLength), frames)
        XCTAssertEqual(frames * 2 * MemoryLayout<Float>.size, 82_555_200)
        let pcm = try XCTUnwrap(buffer.floatChannelData)
        for channel in 0..<2 {
            let p = pcm[channel]
            let seam = abs(p[0] - p[frames - 1])
            let nearby = (1..<1000).map { abs(p[$0] - p[$0 - 1]) }.max()!
            XCTAssertLessThan(seam, nearby * 1.5 + 0.002)
            let head = (0..<4410).reduce(0.0) { $0 + Double(p[$1]) * Double(p[$1]) }
            let tail = ((frames - 4410)..<frames).reduce(0.0) { $0 + Double(p[$1]) * Double(p[$1]) }
            XCTAssertGreaterThan(head, 0.1)
            XCTAssertEqual(10 * log10(head / tail), 0, accuracy: 1)
            XCTAssertTrue((0..<256).contains { abs(p[$0]) > 0.001 })
            XCTAssertTrue(((frames - 256)..<frames).contains { abs(p[$0]) > 0.001 })
        }
    }

    func testClockTickGridIsEvenAcrossTheLoopSeam() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "clock-ticking", withExtension: "flac", subdirectory: "Ambience"))
        let file = try AVAudioFile(forReading: url)
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)))
        try file.read(into: buffer)
        let pcm = try XCTUnwrap(buffer.floatChannelData)[0]
        let period = 14_112
        XCTAssertEqual(Int(buffer.frameLength), period * 160)
        var peaks = [Int]()
        for tick in 0..<160 {
            let start = tick * period
            let peak = (start..<(start + period)).max { abs(pcm[$0]) < abs(pcm[$1]) }!
            peaks.append(peak)
            XCTAssertTrue(((start + period - 800)..<(start + period)).allSatisfy { pcm[$0] == 0 })
        }
        for (a, b) in zip(peaks, Array(peaks.dropFirst()) + [peaks[0] + Int(buffer.frameLength)]) {
            XCTAssertLessThanOrEqual(abs((b - a) - period), 8)
        }
    }
    func testNormalClockTicksOncePerSecondIncludingTheLoopSeam() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "clock", withExtension: "flac", subdirectory: "Ambience"))
        let file = try AVAudioFile(forReading: url)
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)))
        try file.read(into: buffer)
        let pcm = try XCTUnwrap(buffer.floatChannelData)
        let period = 44_100
        XCTAssertEqual(Int(buffer.frameLength), period * 50)
        for channel in 0..<2 {
            var peaks = [Int]()
            for tick in 0..<50 {
                let start = tick * period
                let peak = (start..<(start + period)).max { abs(pcm[channel][$0]) < abs(pcm[channel][$1]) }!
                XCTAssertGreaterThan(abs(pcm[channel][peak]), 0.01)
                peaks.append(peak)
                XCTAssertTrue(((start + period - 800)..<(start + period)).allSatisfy { pcm[channel][$0] == 0 })
            }
            for (a, b) in zip(peaks, Array(peaks.dropFirst()) + [peaks[0] + Int(buffer.frameLength)]) {
                XCTAssertEqual(Double(b - a) / rate, 1.000, accuracy: 0.003)
            }
        }
    }
    func testBinauralAndMonauralFrequencies() {
        for mode in 0...1 {
            let dsp = fh_create(rate, 0)!
            defer { fh_destroy(dsp) }
            fh_master(dsp, 1, 0.03)
            fh_tone(dsp, Int32(mode), 220, 10, 0.8, 0.3, 0.03)
            _ = render(dsp, frames: 44_100)
            let (l, r) = render(dsp, frames: 88_200)
            if mode == 0 {
                XCTAssertEqual(frequency(l[...]), 215, accuracy: 0.6)
                XCTAssertEqual(frequency(r[...]), 225, accuracy: 0.6)
            } else {
                XCTAssertEqual(l, r)
                // Correlate against both constituent tones, not zero crossings of their sum.
                for hz in [215.0, 225.0] {
                    let projection = l.enumerated().reduce(0.0) { $0 + Double($1.element) * sin(2 * .pi * hz * Double($1.offset) / rate) } / Double(l.count)
                    XCTAssertGreaterThan(abs(projection), 0.025)
                }
            }
        }
    }
    func testIsochronicIsStereoAndPulsesSmoothly() {
        let dsp = fh_create(rate, 0)!; defer { fh_destroy(dsp) }
        fh_master(dsp, 1, 0); fh_tone(dsp, 2, 220, 10, 1, 0.5, 0.03)
        _ = render(dsp, frames: 44_100)
        let (l, r) = render(dsp, frames: 44_100)
        XCTAssertEqual(l, r)
        XCTAssertLessThan(zip(l, l.dropFirst()).map { abs($1 - $0) }.max()!, 0.015)
        XCTAssertEqual(frequency(l[...]), 220, accuracy: 1)
    }
    func testNoiseIsFiniteNormalizedAndProtectedAtEightLayers() {
        for type in 1...3 {
            let dsp = fh_create(rate, 8)!; defer { fh_destroy(dsp) }
            fh_master(dsp, 1, 0)
            for i in 0..<8 { fh_layer(dsp, Int32(i), Int32(type), 1, 0, 60, 0.03) }
            let (l, _) = render(dsp, frames: 88_200)
            XCTAssertTrue(l.allSatisfy { $0.isFinite && abs($0) <= 1 })
            let rms = sqrt(l.reduce(0.0) { $0 + Double($1 * $1) } / Double(l.count))
            XCTAssertGreaterThan(rms, 0.03); XCTAssertLessThan(rms, 0.8)
            XCTAssertLessThan(abs(l.reduce(0, +) / Float(l.count)), 0.05)
        }
    }
    func testLoopAndGainRampsHaveNoBoundaryStep() {
        let dsp = fh_create(rate, 1)!; defer { fh_destroy(dsp) }
        let samples = (0..<441).map { Float(sin(2 * .pi * Double($0) / 441)) * 0.2 }
        samples.withUnsafeBufferPointer { XCTAssertEqual(fh_set_buffer(dsp, 0, $0.baseAddress, $0.baseAddress, 441), 1) }
        fh_master(dsp, 1, 0.03); fh_layer(dsp, 0, 0, 1, 0, 60, 0.04)
        var (l, _) = render(dsp, frames: 4410)
        fh_layer(dsp, 0, 0, 0.1, 0, 60, 0.04)
        l += render(dsp, frames: 4410).0
        fh_master(dsp, 0, 0.3); l += render(dsp, frames: 15000).0
        XCTAssertLessThan(zip(l, l.dropFirst()).map { abs($1 - $0) }.max()!, 0.002)
        XCTAssertEqual(l.last!, 0, accuracy: 0.00001)
    }
    func testOscillationModulatesWithoutWritingGain() {
        let dsp = fh_create(rate, 1)!; defer { fh_destroy(dsp) }
        fh_layer(dsp, 0, 1, 0.25, 1, 10, 0.04)
        _ = render(dsp, frames: 44_100)
        let high = fh_level(dsp, 0)
        _ = render(dsp, frames: 4 * 44_100)
        XCTAssertGreaterThan(high, 0.2); XCTAssertLessThan(fh_level(dsp, 0), 0.001)
        _ = render(dsp, frames: 5 * 44_100)
        XCTAssertEqual(fh_level(dsp, 0), 0.25, accuracy: 0.001)
    }
}

@MainActor
final class SoundsControllerTests: XCTestCase {
    private func url() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("sounds.json") }
    func testMixRoundTripAndPersistenceRestoresPaused() throws {
        let storage = url(), export = url()
        try FileManager.default.createDirectory(at: export.deletingLastPathComponent(), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: storage.deletingLastPathComponent()); try? FileManager.default.removeItem(at: export.deletingLastPathComponent()) }
        let c = SoundsController(storageURL: storage, enableAudio: false)
        c.setLayerActive("noise-pink", true); c.setLayerVolume("noise-pink", 0.37)
        c.setOscillation("noise-pink", OscillationSettings(isEnabled: true, depth: 0.8, period: 10))
        let mix = c.saveCurrentMix(named: "Test")
        c.toggleFavorite(mix.id); c.setMasterVolume(0.63); c.setMuted(true)
        c.advanceTime(by: 100)
        XCTAssertEqual(c.layerState(for: "noise-pink").volume, 0.37)
        try c.exportMixes(to: export)
        XCTAssertEqual(try c.importMixes(from: export), 1)
        XCTAssertNotEqual(c.mixes.last?.id, mix.id)
        c.clearAll(); c.applyMix(mix.id)
        XCTAssertEqual(c.layerState(for: "noise-pink").volume, 0.37)
        XCTAssertTrue(c.isPlaying)
        c.shutdown()
        let restored = SoundsController(storageURL: storage, enableAudio: false)
        defer { restored.shutdown() }
        XCTAssertFalse(restored.isPlaying); XCTAssertTrue(restored.isMuted)
        XCTAssertEqual(restored.masterVolume, 0.63)
        XCTAssertTrue(restored.mixes.first(where: { $0.id == mix.id })!.isFavorite)
        XCTAssertTrue(restored.layerState(for: "noise-pink").isActive)
    }
    func testCompleteBundledCatalogIsVisible() {
        let storage = url()
        let c = SoundsController(storageURL: storage, enableAudio: false)
        defer { c.shutdown(); try? FileManager.default.removeItem(at: storage.deletingLastPathComponent()) }
        XCTAssertEqual(c.catalog.filter { !$0.isGenerated }.count, 34)
        XCTAssertNotNil(c.catalog.first { $0.id == "tree-frogs" })
        XCTAssertEqual(c.catalog.first { $0.id == "train" }?.category, .travel)
        XCTAssertNotNil(c.catalog.first { $0.id == "beach-waves" })
        XCTAssertNotNil(c.catalog.first { $0.id == "seagulls" })
    }
    func testLayerLimitAndStopTimerAndPausedPlaylist() {
        let storage = url()
        let catalog = (0..<10).map { SoundDescriptor(id: "test-\($0)", name: "Test", symbolName: "waveform", category: .noise, isGenerated: true, credit: nil, sourceURL: nil) }
        let c = SoundsController(storageURL: storage, enableAudio: false, catalogOverride: catalog)
        defer { c.shutdown(); try? FileManager.default.removeItem(at: storage.deletingLastPathComponent()) }
        for sound in catalog { c.setLayerActive(sound.id, true) }
        XCTAssertEqual(c.activeLayerCount, 8); XCTAssertEqual(c.notice?.kind, .layerLimit)
        let first = c.saveCurrentMix(named: "First")
        c.clearAll(); c.setLayerActive("test-9", true)
        let second = c.saveCurrentMix(named: "Second")
        var p = c.createPlaylist(named: "Sequence", mixIDs: [first.id, second.id]); p.interval = 5; c.updatePlaylist(p)
        c.startPlaylist(p.id); c.setMuted(true); c.advanceTime(by: 5)
        XCTAssertEqual(c.activeMixID, second.id)
        c.pause(); c.skipToNextInPlaylist(); XCTAssertFalse(c.isPlaying)
        c.play(); c.startStopTimer(duration: 10, fadeOut: 4); c.advanceTime(by: 8)
        XCTAssertEqual(c.stopTimerRemaining, 2); XCTAssertTrue(c.isPlaying)
        c.advanceTime(by: 2); XCTAssertFalse(c.isPlaying); XCTAssertNil(c.stopTimerRemaining)
    }
    func testInvalidImportAndFailedMixPreservePlayingLayers() throws {
        let storage = url(), data = url()
        let c = SoundsController(storageURL: storage, enableAudio: false)
        defer { c.shutdown(); try? FileManager.default.removeItem(at: storage.deletingLastPathComponent()); try? FileManager.default.removeItem(at: data.deletingLastPathComponent()) }
        c.setLayerActive("noise-brown", true)
        try FileManager.default.createDirectory(at: data.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("invalid".utf8).write(to: data)
        XCTAssertThrowsError(try c.importMixes(from: data)); XCTAssertEqual(c.notice?.kind, .importFailed)
        c.applyMix(UUID()); XCTAssertTrue(c.layerState(for: "noise-brown").isActive)
    }
}

@MainActor
final class SoundsHardwareSmokeTests: XCTestCase {
    func testOptionalHardwarePlayback() throws {
        guard ProcessInfo.processInfo.environment["FIREHAWK_AUDIO_SMOKE"] == "1" else {
            throw XCTSkip("Opt-in hardware check; normal suite remains offline")
        }
        let storage = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("sounds.json")
        let c = SoundsController(storageURL: storage)
        defer { c.shutdown(); try? FileManager.default.removeItem(at: storage.deletingLastPathComponent()) }
        c.setMasterVolume(0.05)
        c.setLayerActive("noise-pink", true)
        c.setLayerActive("noise-brown", true)
        XCTAssertTrue(c.isPlaying)
        XCTAssertGreaterThan(c.decodedAudioBytes, 80_000_000)
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssertGreaterThan(c.liveLevel(for: "noise-pink"), 0)
        c.pause()
        Thread.sleep(forTimeInterval: 0.4)
        XCTAssertFalse(c.isPlaying)
        print("Hardware smoke decoded audio bytes: \(c.decodedAudioBytes)")
    }
}
