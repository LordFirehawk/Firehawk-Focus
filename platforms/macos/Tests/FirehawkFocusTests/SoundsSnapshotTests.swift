import AppKit
import SwiftUI
import XCTest
@testable import FirehawkFocus

/// Renders the Sounds tab to PNGs for visual review. Skipped unless SOUNDS_SNAPSHOT_DIR is set:
/// SOUNDS_SNAPSHOT_DIR=/tmp/firehawk-sounds-shots swift test --filter SoundsSnapshotTests
@MainActor
final class SoundsSnapshotTests: XCTestCase {
    private var outputDirectory: URL?
    private var sounds: SoundsController!

    private static let catalog: [SoundDescriptor] = [
        ("rain-light", "Light rain", "cloud.rain", SoundCategory.rain), ("thunder", "Distant thunder", "cloud.bolt", .rain),
        ("stream", "Stream", "drop", .water), ("waves", "Ocean waves", "water.waves", .water),
        ("forest", "Forest", "tree", .nature), ("birds", "Birds", "bird", .nature), ("wind", "Wind", "wind", .nature),
        ("fireplace", "Fireplace", "flame", .fire),
        ("cafe", "Café", "cup.and.saucer", .indoor), ("fan", "Fan", "fan", .indoor), ("train", "Train", "tram", .indoor),
        ("noise-white", "White noise", "waveform", .noise), ("noise-pink", "Pink noise", "waveform", .noise), ("noise-brown", "Brown noise", "waveform", .noise),
    ].map { SoundDescriptor(id: $0.0, name: $0.1, symbolName: $0.2, category: $0.3, isGenerated: $0.3 == .noise, credit: nil, sourceURL: nil) }

    override func setUp() async throws {
        guard let path = ProcessInfo.processInfo.environment["SOUNDS_SNAPSHOT_DIR"] else {
            throw XCTSkip("Set SOUNDS_SNAPSHOT_DIR to render Sounds snapshots")
        }
        outputDirectory = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: outputDirectory!, withIntermediateDirectories: true)
    }

    func testRenderSoundsScreens() throws {
        let storage = FileManager.default.temporaryDirectory.appendingPathComponent("sounds-snapshot-\(UUID().uuidString).json")
        let catalog = Self.catalog
        let sounds = SoundsController(storageURL: storage, enableAudio: false, catalogOverride: catalog)
        self.sounds = sounds

        // Empty state.
        sounds.clearAll()
        sounds.dismissNotice()
        render("empty", section: .mixer)

        // A small mix with rise and fall on one layer.
        sounds.setLayerActive(catalog[0].id, true)
        sounds.setLayerVolume(catalog[0].id, 0.62)
        sounds.setLayerActive(catalog[7].id, true)
        sounds.setLayerVolume(catalog[7].id, 0.38)
        sounds.setLayerActive(catalog[13].id, true)
        sounds.setLayerVolume(catalog[13].id, 0.24)
        var swell = OscillationSettings()
        swell.isEnabled = true
        sounds.setOscillation(catalog[0].id, swell)
        render("mixer", section: .mixer)
        render("mixer-expanded", section: .mixer, expanded: catalog[0].id)

        // Mixes and a playlist.
        let rainy = sounds.saveCurrentMix(named: "Rainy cabin")
        sounds.toggleFavorite(rainy.id)
        sounds.setLayerActive(catalog[8].id, true)
        let cafe = sounds.saveCurrentMix(named: "Busy café")
        let playlist = sounds.createPlaylist(named: "Afternoon", mixIDs: [rainy.id, cafe.id])
        sounds.applyMix(rainy.id)
        render("mixes", section: .mixes)
        sounds.startPlaylist(playlist.id)
        sounds.startStopTimer(duration: 30 * 60, fadeOut: 30)
        render("mixes-playlist", section: .mixes)
        sounds.stopPlaylist()
        sounds.cancelStopTimer()

        // Tones, each mode.
        for mode in ToneMode.allCases {
            var tone = sounds.tone
            tone.isEnabled = true
            tone.mode = mode
            tone.beatFrequency = mode == .isochronic ? 6 : 10
            sounds.updateTone(tone)
            sounds.dismissNotice()
            render("tones-\(mode.rawValue)", section: .tones)
        }

        // Notice at the layer limit.
        for sound in catalog.prefix(sounds.maxActiveLayers + 1) {
            sounds.setLayerActive(sound.id, true)
        }
        render("notice", section: .mixer)
        sounds.dismissNotice()
    }

    /// The shipped catalog: folding categories, "On now", credits, the Settings entry and the tab header.
    func testRenderLibraryScreens() throws {
        let storage = FileManager.default.temporaryDirectory.appendingPathComponent("sounds-library-\(UUID().uuidString).json")
        let sounds = SoundsController(storageURL: storage, enableAudio: false)
        self.sounds = sounds
        XCTAssertGreaterThanOrEqual(sounds.catalog.count, 23)
        sounds.clearAll()
        sounds.dismissNotice()

        for (id, volume) in [("rain", 0.62), ("birds", 0.4), ("noise-brown", 0.24)] {
            sounds.setLayerActive(id, true)
            sounds.setLayerVolume(id, volume)
        }
        var swell = OscillationSettings()
        swell.isEnabled = true
        sounds.setOscillation("rain", swell)

        let defaults = UserDefaults.standard
        let savedOpen = defaults.string(forKey: "soundsOpenCategories")
        defer { defaults.set(savedOpen, forKey: "soundsOpenCategories") }

        defaults.set("", forKey: "soundsOpenCategories")
        render("v2/mixer-collapsed", section: .mixer)
        defaults.set("rain", forKey: "soundsOpenCategories")
        render("v2/mixer-default", section: .mixer)
        defaults.set(SoundCategory.allCases.map(\.rawValue).joined(separator: ","), forKey: "soundsOpenCategories")
        render("v2/mixer-expanded", section: .mixer)
        defaults.set("nature", forKey: "soundsOpenCategories")
        render("v2/mixer-nature", section: .mixer)

        render("v3/credits", section: .mixer, credits: true)
        renderView("v3/credits-full", height: 2600) {
            SoundCreditsView(catalog: sounds.catalog) {}
        }
        renderView("v2/settings-entry", height: 150) {
            VStack(spacing: 8) {
                SoundCreditsSettingsRow {}
            }
            .padding(16)
        }
        for tab in [0, 3, 1, 2] {
            renderView("v2/header-tab\(tab)", height: 49) {
                PopoverHeader(activeTab: .constant(tab))
            }
        }
    }

    private func render(_ name: String, section: SoundsSection, expanded: String? = nil, credits: Bool = false) {
        UserDefaults.standard.set(section.rawValue, forKey: "soundsSection")
        let sounds = self.sounds!
        renderView(name, height: 490) {
            VStack(spacing: 0) {
                // Stand-in for the popover header so proportions match the real tray.
                HStack {
                    Image(systemName: "flame.fill").foregroundStyle(.orange)
                    Text("Firehawk Focus").font(.system(size: 14, weight: .semibold))
                    Spacer()
                }
                .padding(.horizontal, 14)
                .frame(height: 49)
                Divider()
                SoundsView(sounds: sounds, initialExpandedSoundID: expanded, showsCredits: credits)
            }
        }
    }

    private func renderView<Content: View>(_ name: String, height: CGFloat, @ViewBuilder content: () -> Content) {
        let content = content()
        for (suffix, appearanceName, background) in [
            ("dark", NSAppearance.Name.darkAqua, NSColor(srgbRed: 0.17, green: 0.17, blue: 0.18, alpha: 1)),
            ("light", NSAppearance.Name.aqua, NSColor(srgbRed: 0.93, green: 0.93, blue: 0.93, alpha: 1)),
        ] {
            let root = content
                .frame(width: 360, height: height, alignment: .top)
                .background(Color(nsColor: background))

            let host = NSHostingView(rootView: root)
            host.frame = NSRect(x: 0, y: 0, width: 360, height: height)
            let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
            window.appearance = NSAppearance(named: appearanceName)
            window.contentView = host
            window.orderFrontRegardless()
            host.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.4))

            guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { continue }
            host.cacheDisplay(in: host.bounds, to: rep)
            let url = outputDirectory!.appendingPathComponent("\(name)-\(suffix).png")
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? rep.representation(using: .png, properties: [:])?.write(to: url)
            window.orderOut(nil)
        }
    }
}
