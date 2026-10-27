import AppKit
import AVFoundation
import CoreAudio
import FirehawkDSP
import Combine
import Foundation

/// App-owned Sounds state. Lives for the whole app session, so audio keeps playing when the
/// tray closes or the user switches tabs.
///
/// CONTRACT: the public surface below (published properties and methods) is what the Sounds UI
/// binds to. Audio rendering and timing are independent of the timer engine.
@MainActor
final class SoundsController: ObservableObject {
    static let shared = SoundsController()

    /// Maximum number of simultaneously active layers (tone counts separately).
    let maxActiveLayers = 8

    @Published private(set) var catalog: [SoundDescriptor] = []
    @Published private(set) var layers: [String: LayerState] = [:]
    @Published private(set) var isPlaying = false
    @Published private(set) var isMuted = false
    @Published private(set) var masterVolume: Double = 0.8
    @Published private(set) var tone = ToneSettings()

    @Published private(set) var mixes: [SoundMix] = []
    @Published private(set) var playlists: [MixPlaylist] = []
    /// The saved mix the current layers came from; nil once the user edits away from it.
    @Published private(set) var activeMixID: UUID?
    @Published private(set) var activePlaylistID: UUID?
    /// Time until the playlist moves to its next mix, while a playlist runs.
    @Published private(set) var playlistNextChangeIn: TimeInterval?

    /// Remaining time on the Sounds stop timer, nil when no stop timer is set.
    @Published private(set) var stopTimerRemaining: TimeInterval?
    @Published private(set) var stopTimerFadeDuration: TimeInterval = 30

    @Published private(set) var headphonesConnected = false
    @Published private(set) var notice: SoundsNotice?

    var activeLayerCount: Int { layers.values.filter(\.isActive).count }
    var hasAnythingEnabled: Bool { activeLayerCount > 0 || tone.isEnabled }

    private struct SavedState: Codable {
        var layers: [String: LayerState]
        var master: Double
        var muted: Bool
        var tone: ToneSettings
        var mixes: [SoundMix]
        var playlists: [MixPlaylist]
    }
    private let storageURL: URL
    private(set) var audio: SoundsAudioEngine?
    private var entries: [AmbienceEntry] = []
    private var saveWork: DispatchWorkItem?
    private var pauseWork: DispatchWorkItem?
    private var clock: Timer?
    private var observers: [NSObjectProtocol] = []
    private var previousTick = ProcessInfo.processInfo.systemUptime
    private var playlistOrder: [UUID] = []
    private var playlistIndex = 0
    private var lastRouteCheck: TimeInterval = 0
    private var routeID: AudioDeviceID = 0
    private var suppressChanges = false
    private var subscriptions = Set<AnyCancellable>()
    var decodedAudioBytes: UInt64 { audio?.decodedBytes ?? 0 }

    /// Separate storage and disabled hardware are useful for offline tests.
    init(storageURL: URL? = nil, enableAudio: Bool = true, catalogOverride: [SoundDescriptor]? = nil) {
        self.storageURL = storageURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("FirehawkFocus/sounds.json")
        if let url = Bundle.module.url(forResource: "catalog", withExtension: "json", subdirectory: "Ambience"),
           let data = try? Data(contentsOf: url), let decoded = try? JSONDecoder().decode([AmbienceEntry].self, from: data) {
            entries = decoded
        }
        catalog = entries.map(\.descriptor) + [("white", "waveform"), ("pink", "waveform.path"), ("brown", "water.waves")].map {
            SoundDescriptor(id: "noise-" + $0.0, name: $0.0.capitalized + " noise", symbolName: $0.1, category: .noise, isGenerated: true, credit: nil, sourceURL: nil)
        }
        if let catalogOverride { catalog = catalogOverride }
        layers = Dictionary(uniqueKeysWithValues: catalog.map { ($0.id, LayerState()) })
        if let data = try? Data(contentsOf: self.storageURL), let saved = try? JSONDecoder().decode(SavedState.self, from: data) {
            layers = sanitized(saved.layers)
            masterVolume = finite(saved.master, range: 0...1, fallback: 0.8)
            isMuted = saved.muted
            tone = sanitized(saved.tone)
            mixes = saved.mixes.map { var m = $0; m.layers = sanitized(m.layers); m.tone = m.tone.map(sanitized); return m }
            playlists = saved.playlists.map { var p = $0; p.interval = finite(p.interval, range: 1...86400, fallback: 900); return p }
        }
        addBuiltIns()
        if enableAudio {
            audio = SoundsAudioEngine(catalog: catalog, entries: entries)
            audio?.onLoad = { [weak self] id, success in
                guard let self else { return }
                if !success {
                    self.layers[id]?.isActive = false
                    self.notice = SoundsNotice(kind: .loadFailed, message: "This sound could not be loaded. Other sounds will keep playing.")
                }
                self.syncAudio(ramp: self.audio?.fadeInDuration(for: id) ?? 0.04)
                if !success && !self.hasAnythingEnabled { self.pause() }
            }
            observers.append(NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: audio?.engine, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.devicePause() }
            })
            observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.devicePause() }
            })
            refreshRoute()
            clock = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    let now = ProcessInfo.processInfo.systemUptime
                    self.advanceTime(by: now - self.previousTick)
                    self.previousTick = now
                    self.refreshRoute()
                    self.audio?.collectInactive()
                }
            }
        }
        objectWillChange.sink { [weak self] in
            guard let self, !self.suppressChanges else { return }
            self.scheduleSave()
        }.store(in: &subscriptions)
        syncAudio()
    }

    private func finite(_ value: Double, range: ClosedRange<Double>, fallback: Double) -> Double {
        value.isFinite ? value.clamped(to: range) : fallback
    }
    private func sanitized(_ settings: ToneSettings) -> ToneSettings {
        var t = settings
        t.beatFrequency = finite(t.beatFrequency, range: ToneSettings.beatRange, fallback: 10)
        t.carrierFrequency = finite(t.carrierFrequency, range: ToneSettings.carrierRange, fallback: 220)
        t.volume = finite(t.volume, range: 0...1, fallback: 0.3)
        t.pulseDepth = finite(t.pulseDepth, range: 0...1, fallback: 0.8)
        return t
    }
    private func sanitized(_ states: [String: LayerState]) -> [String: LayerState] {
        var result: [String: LayerState] = [:]
        var count = 0
        for sound in catalog {
            var s = states[sound.id] ?? LayerState()
            s.volume = finite(s.volume, range: 0...1, fallback: 0.5)
            s.oscillation.depth = finite(s.oscillation.depth, range: 0...1, fallback: 0.4)
            s.oscillation.period = finite(s.oscillation.period, range: OscillationSettings.periodRange, fallback: 60)
            if s.isActive { count += 1; if count > maxActiveLayers { s.isActive = false } }
            result[sound.id] = s
        }
        return result
    }
    private func addBuiltIns() {
        guard !mixes.contains(where: \.isBuiltIn) else { return }
        let choices: [(String, String)] = [("Quiet focus", "noise-pink"), ("Deep hush", "noise-brown"), ("Even texture", "noise-white")]
        for (name, id) in choices {
            mixes.append(SoundMix(name: name, layers: [id: LayerState(isActive: true, volume: 0.45)], isBuiltIn: true))
        }
        if layers["forest"] != nil, layers["birds"] != nil {
            mixes.append(SoundMix(name: "Woodland breeze", layers: ["forest": LayerState(isActive: true, volume: 0.5), "birds": LayerState(isActive: true, volume: 0.45)], isBuiltIn: true))
        }
        if layers["fan"] != nil, layers["night-insects"] != nil {
            mixes.append(SoundMix(name: "Evening hush", layers: ["fan": LayerState(isActive: true, volume: 0.4), "night-insects": LayerState(isActive: true, volume: 0.5)], isBuiltIn: true))
        }
        playlists.append(MixPlaylist(name: "Focus textures", mixIDs: mixes.filter(\.isBuiltIn).map(\.id), isBuiltIn: true))
    }
    private func scheduleSave() {
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.persistNow() }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }
    func persistNow() {
        do {
            let saved = SavedState(layers: layers, master: masterVolume, muted: isMuted, tone: tone, mixes: mixes, playlists: playlists)
            let data = try JSONEncoder().encode(saved)
            try FileManager.default.createDirectory(at: storageURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            suppressChanges = true
            notice = SoundsNotice(kind: .loadFailed, message: "Sounds settings could not be saved: \(error.localizedDescription)")
            suppressChanges = false
        }
    }
    func shutdown() {
        saveWork?.cancel(); pauseWork?.cancel(); clock?.invalidate(); clock = nil
        persistNow(); audio?.stop()
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        observers.removeAll()
    }
    private func syncAudio(ramp: Double = 0.04) {
        guard let audio else { return }
        for (i, id) in audio.ids.enumerated() {
            let s = layerState(for: id)
            let noise = ["noise-white": 1, "noise-pink": 2, "noise-brown": 3][id] ?? 0
            audio.setRecordingActive(id, active: s.isActive, ramp: ramp)
            let ready = noise != 0 || audio.loaded.contains(id)
            let db = entries.first(where: { $0.id == id })?.gainDb ?? 0
            fh_layer(audio.dsp, Int32(i), Int32(noise), s.isActive && ready ? pow(s.volume, 2) * pow(10, db / 20) : 0,
                     s.oscillation.isEnabled ? s.oscillation.depth : 0, s.oscillation.period, ramp)
        }
        fh_tone(audio.dsp, Int32(ToneMode.allCases.firstIndex(of: tone.mode) ?? 0), tone.carrierFrequency,
                tone.beatFrequency, tone.pulseDepth, tone.isEnabled ? pow(tone.volume, 2) : 0, ramp)
        syncMaster()
    }
    private var timerGain: Double {
        guard let remaining = stopTimerRemaining, stopTimerFadeDuration > 0 else { return 1 }
        return min(1, remaining / stopTimerFadeDuration)
    }
    private func syncMaster(seconds: Double = 0.3) {
        if let audio { fh_master(audio.dsp, isPlaying && !isMuted ? pow(masterVolume, 2) * timerGain : 0, seconds) }
    }
    func layerState(for id: String) -> LayerState { layers[id] ?? LayerState() }
    func play() {
        guard hasAnythingEnabled else { return }
        pauseWork?.cancel()
        do { try audio?.start(); isPlaying = true; previousTick = ProcessInfo.processInfo.systemUptime; syncMaster() }
        catch { notice = SoundsNotice(kind: .loadFailed, message: "Could not start Sounds: \(error.localizedDescription)") }
    }
    func pause() {
        isPlaying = false; syncMaster()
        pauseWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, !self.isPlaying else { return }
            self.audio?.engine.pause()
        }
        pauseWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }
    func togglePlayback() { isPlaying ? pause() : play() }
    func setMuted(_ muted: Bool) { isMuted = muted; syncMaster(seconds: 0.04) }
    func setMasterVolume(_ value: Double) { masterVolume = finite(value, range: 0...1, fallback: 0.8); syncMaster(seconds: 0.04) }
    func clearAll() {
        for id in layers.keys { layers[id]?.isActive = false }
        tone.isEnabled = false; activeMixID = nil; stopPlaylist(); pause(); syncAudio()
    }
    func setLayerActive(_ id: String, _ active: Bool) {
        guard layers[id] != nil else { return }
        if active, !layerState(for: id).isActive, activeLayerCount >= maxActiveLayers {
            notice = SoundsNotice(kind: .layerLimit, message: "Up to \(maxActiveLayers) sounds can play at once. Turn one off to add another."); return
        }
        if active, audio?.unavailable.contains(id) == true {
            notice = SoundsNotice(kind: .loadFailed, message: "This sound could not be loaded."); return
        }
        layers[id]?.isActive = active; activeMixID = nil; syncAudio()
        if active { play() }; if !hasAnythingEnabled { pause() }
    }
    func setLayerVolume(_ id: String, _ volume: Double) {
        guard layers[id] != nil else { return }
        layers[id]?.volume = finite(volume, range: 0...1, fallback: 0.5); activeMixID = nil; syncAudio()
    }
    func setOscillation(_ id: String, _ settings: OscillationSettings) {
        guard var state = layers[id] else { return }
        state.oscillation = settings
        layers[id] = sanitized([id: state])[id]; activeMixID = nil; syncAudio()
    }
    func liveLevel(for id: String) -> Double {
        guard isPlaying, !isMuted, let audio, let i = audio.ids.firstIndex(of: id) else { return 0 }
        return min(1, fh_level(audio.dsp, Int32(i)) * pow(masterVolume, 2) * timerGain)
    }
    func updateTone(_ settings: ToneSettings) {
        let next = sanitized(settings)
        if next.isEnabled, next.mode.requiresHeadphones, !headphonesConnected, !tone.isEnabled || tone.mode != next.mode {
            notice = SoundsNotice(kind: .headphonesRecommended, message: "Binaural beats need stereo headphones. Monaural and isochronic work on speakers.")
        }
        tone = next; activeMixID = nil; syncAudio()
        if next.isEnabled { play() }; if !hasAnythingEnabled { pause() }
    }
    @discardableResult func saveCurrentMix(named name: String) -> SoundMix {
        let mix = SoundMix(name: name, layers: layers.filter(\.value.isActive), tone: tone.isEnabled ? tone : nil)
        mixes.append(mix); activeMixID = mix.id; return mix
    }
    func applyMix(_ id: UUID) { applyMix(id, start: true) }
    private func applyMix(_ id: UUID, start: Bool) {
        guard let mix = mixes.first(where: { $0.id == id }) else { return }
        let requested = mix.layers.filter(\.value.isActive)
        guard requested.keys.allSatisfy({ layers[$0] != nil && audio?.unavailable.contains($0) != true }), requested.count <= maxActiveLayers else {
            notice = SoundsNotice(kind: .loadFailed, message: "The mix contains unavailable sounds or too many layers. Your current mix is still selected."); return
        }
        layers = sanitized(mix.layers); tone = sanitized(mix.tone ?? ToneSettings()); activeMixID = id
        syncAudio(ramp: 3); if start { play() }
    }
    func renameMix(_ id: UUID, to name: String) {
        guard let i = mixes.firstIndex(where: { $0.id == id }), !mixes[i].isBuiltIn else { return }; mixes[i].name = name
    }
    func deleteMix(_ id: UUID) {
        guard mixes.contains(where: { $0.id == id && !$0.isBuiltIn }) else { return }
        mixes.removeAll { $0.id == id }; for i in playlists.indices { playlists[i].mixIDs.removeAll { $0 == id } }
        if activeMixID == id { activeMixID = nil }
    }
    func toggleFavorite(_ id: UUID) { if let i = mixes.firstIndex(where: { $0.id == id }) { mixes[i].isFavorite.toggle() } }
    func randomMix() {
        let available = catalog.filter { !$0.isGenerated && audio?.unavailable.contains($0.id) != true }
        let picks = (available.isEmpty ? catalog : available).shuffled().prefix(Int.random(in: 2...4))
        var next: [String: LayerState] = [:]
        for sound in picks { next[sound.id] = LayerState(isActive: true, volume: Double.random(in: 0.3...0.7)) }
        layers = sanitized(next); tone.isEnabled = false; activeMixID = nil; syncAudio(ramp: 3); play()
    }
    @discardableResult func createPlaylist(named name: String, mixIDs: [UUID]) -> MixPlaylist {
        let p = MixPlaylist(name: name, mixIDs: mixIDs.filter { id in mixes.contains { $0.id == id } }); playlists.append(p); return p
    }
    func updatePlaylist(_ playlist: MixPlaylist) {
        guard let i = playlists.firstIndex(where: { $0.id == playlist.id }), !playlists[i].isBuiltIn else { return }
        var p = playlist; p.interval = finite(p.interval, range: 1...86400, fallback: 900); playlists[i] = p
        if activePlaylistID == p.id { playlistOrder = p.isShuffled ? p.mixIDs.shuffled() : p.mixIDs; playlistIndex = -1; playlistNextChangeIn = p.interval }
    }
    func deletePlaylist(_ id: UUID) {
        guard playlists.contains(where: { $0.id == id && !$0.isBuiltIn }) else { return }
        playlists.removeAll { $0.id == id }; if activePlaylistID == id { stopPlaylist() }
    }
    func startPlaylist(_ id: UUID) {
        guard let p = playlists.first(where: { $0.id == id }), !p.mixIDs.isEmpty else { return }
        playlistOrder = p.isShuffled ? p.mixIDs.shuffled() : p.mixIDs; playlistIndex = -1
        activePlaylistID = id; skipToNextInPlaylist(); play()
    }
    func stopPlaylist() { activePlaylistID = nil; playlistNextChangeIn = nil; playlistOrder = [] }
    func skipToNextInPlaylist() {
        guard let p = playlists.first(where: { $0.id == activePlaylistID }), !playlistOrder.isEmpty else { return }
        playlistIndex += 1
        if playlistIndex >= playlistOrder.count { playlistIndex = 0; if p.isShuffled { playlistOrder.shuffle() } }
        applyMix(playlistOrder[playlistIndex], start: false); playlistNextChangeIn = p.interval
    }
    func startStopTimer(duration: TimeInterval, fadeOut: TimeInterval) {
        stopTimerRemaining = finite(duration, range: 0...604800, fallback: 0)
        stopTimerFadeDuration = finite(fadeOut, range: 0...(stopTimerRemaining ?? 0), fallback: 0); syncMaster()
    }
    func cancelStopTimer() { stopTimerRemaining = nil; syncMaster() }
    /// Monotonic elapsed time, separate from the Pomodoro timer. Also drives deterministic offline tests.
    func advanceTime(by elapsed: TimeInterval) {
        guard isPlaying, elapsed.isFinite, elapsed > 0 else { return }
        suppressChanges = true
        defer { suppressChanges = false }
        if let remaining = stopTimerRemaining {
            stopTimerRemaining = max(0, remaining - elapsed)
            if stopTimerRemaining == 0 { pause(); stopTimerRemaining = nil }
            syncMaster(seconds: 0.1)
        }
        if isPlaying, let remaining = playlistNextChangeIn {
            playlistNextChangeIn = max(0, remaining - elapsed)
            if playlistNextChangeIn == 0 { skipToNextInPlaylist() }
        }
    }
    func exportMixes(to url: URL) throws { try JSONEncoder().encode(mixes.filter { !$0.isBuiltIn }).write(to: url, options: .atomic) }
    @discardableResult func importMixes(from url: URL) throws -> Int {
        do {
            let data = try Data(contentsOf: url)
            guard data.count <= 2_000_000 else { throw CocoaError(.fileReadTooLarge) }
            let imported = try JSONDecoder().decode([SoundMix].self, from: data)
            guard imported.count <= 1000 else { throw CocoaError(.fileReadTooLarge) }
            guard imported.allSatisfy({ mix in
                let active = mix.layers.filter(\.value.isActive)
                return active.count <= maxActiveLayers && active.keys.allSatisfy { layers[$0] != nil }
            }) else { throw CocoaError(.fileReadCorruptFile) }
            let fresh = imported.map { mix -> SoundMix in
                var copy = mix; copy.id = UUID(); copy.isBuiltIn = false
                copy.layers = sanitized(mix.layers).filter(\.value.isActive); copy.tone = mix.tone.map(sanitized); return copy
            }
            mixes.append(contentsOf: fresh); notice = SoundsNotice(kind: .imported, message: "Added \(fresh.count) mixes."); return fresh.count
        } catch { notice = SoundsNotice(kind: .importFailed, message: "Could not import mixes: \(error.localizedDescription)"); throw error }
    }
    func dismissNotice() { notice = nil }
    private func devicePause() {
        pause(); audio?.stop()
        notice = SoundsNotice(kind: .devicePaused, message: "Sounds paused because the audio device changed or the Mac went to sleep. Press Play to resume.")
    }
    private func refreshRoute() {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastRouteCheck >= 1 else { return }
        lastRouteCheck = now
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var device: AudioDeviceID = 0; var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device) == noErr else { return }
        if routeID != 0, routeID != device { devicePause() }; routeID = device
        address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyDataSource, mScope: kAudioDevicePropertyScopeOutput, mElement: kAudioObjectPropertyElementMain)
        var source: UInt32 = 0; size = 4
        let hasSource = AudioObjectGetPropertyData(device, &address, 0, nil, &size, &source) == noErr
        address.mSelector = kAudioDevicePropertyTransportType; address.mScope = kAudioObjectPropertyScopeGlobal
        var transport: UInt32 = 0; size = 4
        _ = AudioObjectGetPropertyData(device, &address, 0, nil, &size, &transport)
        let connected = (hasSource && source == 0x6864706e) || transport == kAudioDeviceTransportTypeBluetooth || transport == kAudioDeviceTransportTypeBluetoothLE
        if headphonesConnected != connected { headphonesConnected = connected }
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self { min(max(self, range.lowerBound), range.upperBound) }
}
