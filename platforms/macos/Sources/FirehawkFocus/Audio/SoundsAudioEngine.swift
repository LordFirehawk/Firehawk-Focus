import AVFoundation
import FirehawkDSP
import Foundation

struct AmbienceEntry: Decodable {
    let id: String
    let name: String
    let symbolName: String
    let category: SoundCategory
    let file: String
    let gainDb: Double
    let loopStartSeconds: Double?
    let loopEndSeconds: Double?
    let credit: String
    let sourceURL: URL
    let license: String
    let sources: [SoundSource]
    let editors: [String]

    private enum CodingKeys: String, CodingKey {
        case id, name, symbolName, category, file, gainDb, loopStartSeconds, loopEndSeconds
        case credit, sourceURL, license, sources, editors
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        name = try values.decode(String.self, forKey: .name)
        symbolName = try values.decode(String.self, forKey: .symbolName)
        category = try values.decode(SoundCategory.self, forKey: .category)
        file = try values.decode(String.self, forKey: .file)
        gainDb = try values.decode(Double.self, forKey: .gainDb)
        loopStartSeconds = try values.decodeIfPresent(Double.self, forKey: .loopStartSeconds)
        loopEndSeconds = try values.decodeIfPresent(Double.self, forKey: .loopEndSeconds)
        credit = try values.decode(String.self, forKey: .credit)
        sourceURL = try values.decode(URL.self, forKey: .sourceURL)
        license = try values.decode(String.self, forKey: .license)
        editors = try values.decodeIfPresent([String].self, forKey: .editors) ?? []
        if let structured = try values.decodeIfPresent([SoundSource].self, forKey: .sources) {
            sources = structured
        } else {
            guard let sourceLicense = SoundLicense(rawValue: license) else {
                throw DecodingError.dataCorruptedError(forKey: .license, in: values,
                                                       debugDescription: "Unknown sound license: \(license)")
            }
            // Legacy entries have one creator line before any editor or preparation notes.
            let byline = String(credit.split(separator: ";", maxSplits: 1).first ?? "")
            let creator = byline.components(separatedBy: " by ").last?
                .components(separatedBy: ", CC BY ").first ?? byline
            sources = [SoundSource(title: name, creator: creator.trimmingCharacters(in: .whitespacesAndNewlines),
                                   url: sourceURL, license: sourceLicense)]
        }
    }

    var descriptor: SoundDescriptor {
        SoundDescriptor(id: id, name: name, symbolName: symbolName, category: category,
                        isGenerated: false, credit: credit + " · " + license, sourceURL: sourceURL,
                        sources: sources, editors: editors)
    }
}

/// Control state is owned by the main thread; decoding runs on a serial worker.
/// The C renderer acquires immutable buffers and never allocates or frees them.
final class SoundsAudioEngine {
    let engine = AVAudioEngine()
    let dsp: OpaquePointer
    let ids: [String]
    private var source: AVAudioSourceNode!
    private let entries: [String: AmbienceEntry]
    private let decodeQueue: DispatchQueue
    private var desired = Set<String>()
    private var loading = Set<String>()
    private var activationRamps: [String: Double] = [:]
    private(set) var loaded = Set<String>()
    private var inactiveSince: [String: TimeInterval] = [:]
    private var loadingEnabled = false
    private(set) var unavailable = Set<String>()
    var onLoad: ((String, Bool) -> Void)?
    var decodedBytes: UInt64 { fh_memory(dsp) }
    // Injectable decoder lets tests complete requests in any order without hardware.
    var decoder: (AmbienceEntry) throws -> OpaquePointer = SoundsAudioEngine.decode

    init(catalog: [SoundDescriptor], entries: [AmbienceEntry],
         decodeQueue: DispatchQueue = DispatchQueue(label: "FirehawkFocus.audio.decode", qos: .userInitiated)) {
        self.decodeQueue = decodeQueue
        ids = catalog.map(\.id)
        self.entries = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
        dsp = fh_create(44_100, Int32(ids.count))!
        let pointer = dsp
        source = AVAudioSourceNode { _, _, frames, list in
            let buffers = UnsafeMutableAudioBufferListPointer(list)
            guard buffers.count >= 2, let l = buffers[0].mData, let r = buffers[1].mData else { return noErr }
            fh_render(pointer, l.assumingMemoryBound(to: Float.self), r.assumingMemoryBound(to: Float.self), frames)
            return noErr
        }
        engine.attach(source)
        engine.connect(source, to: engine.mainMixerNode, format: AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!)
    }

    // Four minutes of stereo Float32 is at most 80.75 MiB per active layer.
    // Validate before allocating; the serial decoder bounds temporary PCM memory.
    static let maximumClipFrames: Int64 = 44_100 * 240

    // Bundled loops are FLAC; AVAudioFile/CoreAudio decode them on macOS 10.13+.
    private static func decode(_ entry: AmbienceEntry) throws -> OpaquePointer {
        guard let url = Bundle.module.url(forResource: entry.file, withExtension: nil, subdirectory: "Ambience") else {
            throw CocoaError(.fileNoSuchFile)
        }
        let file = try AVAudioFile(forReading: url)
        guard file.processingFormat.sampleRate == 44_100,
              file.processingFormat.channelCount == 2, file.length > 0, file.length <= maximumClipFrames,
              let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        try file.read(into: buffer)
        guard Int64(buffer.frameLength) == file.length, let pcm = buffer.floatChannelData else { throw CocoaError(.fileReadCorruptFile) }
        let start = Int(max(0, entry.loopStartSeconds ?? 0) * 44_100)
        let end = min(Int(buffer.frameLength), Int((entry.loopEndSeconds ?? Double(buffer.frameLength) / 44_100) * 44_100))
        guard end > start,
              let result = fh_buffer_create(pcm[0] + start, pcm[1] + start, UInt32(end - start)) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return result
    }

    func fadeInDuration(for id: String) -> Double { activationRamps[id] ?? 0.04 }

    func setRecordingActive(_ id: String, active: Bool, ramp: Double = 0.04) {
        guard entries[id] != nil else { return }
        if active {
            if desired.insert(id).inserted { activationRamps[id] = ramp }
            inactiveSince[id] = nil
        } else if desired.remove(id) != nil {
            inactiveSince[id] = ProcessInfo.processInfo.systemUptime
        }
        if active && loadingEnabled { request(id) }
    }

    /// Does not start the audio graph. In particular, load completion cannot undo pause.
    func prepareActive() {
        loadingEnabled = true
        for id in desired { request(id) }
    }

    private func request(_ id: String) {
        guard !loaded.contains(id), !loading.contains(id), !unavailable.contains(id), let entry = entries[id] else { return }
        loading.insert(id)
        let decode = decoder
        decodeQueue.async { [weak self] in
            let result = Result { try decode(entry) }
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    if case .success(let buffer) = result { fh_buffer_destroy(buffer) }
                    return
                }
                self.loading.remove(id)
                switch result {
                case .success(let buffer):
                    // Off/on during a request reuses that request. Off at completion
                    // discards it rather than publishing an unwanted recording.
                    if self.desired.contains(id), let index = self.ids.firstIndex(of: id) {
                        fh_install_buffer(self.dsp, Int32(index), buffer)
                        self.loaded.insert(id)
                    } else { fh_buffer_destroy(buffer) }
                    self.onLoad?(id, true)
                case .failure:
                    self.unavailable.insert(id)
                    self.onLoad?(id, false)
                }
                self.collectInactive()
            }
        }
    }

    /// Keep a 30-second grace cache, but shed excess inactive clips after the
    /// longest mix fade. Active recordings are never evicted.
    func collectInactive(now: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        for id in loaded.subtracting(desired) {
            let age = now - (inactiveSince[id] ?? now)
            if age >= 33 || (loaded.count > 8 && age >= 3.1), let index = ids.firstIndex(of: id) {
                fh_install_buffer(dsp, Int32(index), nil)
                loaded.remove(id); inactiveSince[id] = nil
            }
        }
        fh_collect(dsp)
    }

    func start() throws {
        prepareActive()
        if !engine.isRunning { try engine.start() }
    }
    func stop() { engine.stop() }
    deinit { engine.stop(); fh_destroy(dsp) }
}
