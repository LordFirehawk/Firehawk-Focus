import Foundation

// Shared contract between the Sounds UI and the Sounds audio engine.
// Keep these types stable: the views depend on them. Add fields with defaults rather than renaming.

enum SoundCategory: String, Codable, CaseIterable, Identifiable {
    case rain, water, nature, fire, indoor, noise, travel

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rain: return "Rain"
        case .water: return "Water"
        case .nature: return "Nature"
        case .fire: return "Fire"
        case .indoor: return "Indoors"
        case .noise: return "Noise"
        case .travel: return "Travel"
        }
    }
}

enum SoundLicense: String, Codable {
    case cc0 = "CC0-1.0"
    case ccBy3 = "CC-BY-3.0"
    case ccBy4 = "CC-BY-4.0"
    case publicDomain = "Public Domain"

    var title: String {
        switch self {
        case .cc0: return "CC0 1.0"
        case .ccBy3: return "CC BY 3.0"
        case .ccBy4: return "CC BY 4.0"
        case .publicDomain: return "Public Domain"
        }
    }

    var deedURL: URL? {
        switch self {
        case .cc0: return URL(string: "https://creativecommons.org/publicdomain/zero/1.0/")
        case .ccBy3: return URL(string: "https://creativecommons.org/licenses/by/3.0/")
        case .ccBy4: return URL(string: "https://creativecommons.org/licenses/by/4.0/")
        case .publicDomain: return nil
        }
    }
}

struct SoundSource: Hashable, Codable {
    let title: String?
    let creator: String
    let url: URL
    let license: SoundLicense

    init(title: String? = nil, creator: String, url: URL, license: SoundLicense) {
        self.title = title
        self.creator = creator
        self.url = url
        self.license = license
    }
}

/// One playable layer in the library: a bundled recording or a generated noise colour.
struct SoundDescriptor: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    /// SF Symbol shown in the mixer row.
    let symbolName: String
    let category: SoundCategory
    let isGenerated: Bool
    /// Creator and licence line for the credits screen; nil for generated sounds.
    let credit: String?
    let sourceURL: URL?
    let sources: [SoundSource]
    /// Prior editors/redistributors and the app that prepared the bundled recording.
    let editors: [String]

    init(id: String, name: String, symbolName: String, category: SoundCategory,
         isGenerated: Bool, credit: String?, sourceURL: URL?,
         sources: [SoundSource] = [], editors: [String] = []) {
        self.id = id
        self.name = name
        self.symbolName = symbolName
        self.category = category
        self.isGenerated = isGenerated
        self.credit = credit
        self.sourceURL = sourceURL
        self.sources = sources
        self.editors = editors
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, symbolName, category, isGenerated, credit, sourceURL, sources, editors
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        name = try values.decode(String.self, forKey: .name)
        symbolName = try values.decode(String.self, forKey: .symbolName)
        category = try values.decode(SoundCategory.self, forKey: .category)
        isGenerated = try values.decode(Bool.self, forKey: .isGenerated)
        credit = try values.decodeIfPresent(String.self, forKey: .credit)
        sourceURL = try values.decodeIfPresent(URL.self, forKey: .sourceURL)
        sources = try values.decodeIfPresent([SoundSource].self, forKey: .sources) ?? []
        editors = try values.decodeIfPresent([String].self, forKey: .editors) ?? []
    }
}

/// Slow, gentle volume movement applied on top of the layer's slider value.
struct OscillationSettings: Codable, Hashable {
    var isEnabled: Bool = false
    /// 0...1 — fraction of the layer volume that the swell may take away.
    var depth: Double = 0.4
    /// Seconds for one full swell, 10...600.
    var period: TimeInterval = 60

    static let depthRange: ClosedRange<Double> = 0...1
    static let periodRange: ClosedRange<TimeInterval> = 10...600
}

struct LayerState: Codable, Hashable {
    var isActive: Bool = false
    /// 0...1 slider position (the engine applies perceptual scaling).
    var volume: Double = 0.5
    var oscillation = OscillationSettings()
}

enum ToneMode: String, Codable, CaseIterable, Identifiable {
    case binaural, monaural, isochronic

    var id: String { rawValue }

    var title: String {
        switch self {
        case .binaural: return "Binaural"
        case .monaural: return "Monaural"
        case .isochronic: return "Isochronic"
        }
    }

    var requiresHeadphones: Bool { self == .binaural }
}

enum BrainwaveBand: String, Codable, CaseIterable, Identifiable {
    case delta, theta, alpha, beta, gamma

    var id: String { rawValue }

    var title: String { rawValue.capitalized }

    var range: ClosedRange<Double> {
        switch self {
        case .delta: return 0.5...4
        case .theta: return 4...8
        case .alpha: return 8...13
        case .beta: return 13...30
        case .gamma: return 30...40
        }
    }

    var defaultFrequency: Double {
        switch self {
        case .delta: return 2
        case .theta: return 6
        case .alpha: return 10
        case .beta: return 18
        case .gamma: return 40
        }
    }

    static func band(for frequency: Double) -> BrainwaveBand {
        allCases.first { $0.range.contains(frequency) && frequency < $0.range.upperBound } ?? .gamma
    }
}

struct ToneSettings: Codable, Hashable {
    var isEnabled: Bool = false
    var mode: ToneMode = .binaural
    /// Beat or pulse rate in Hz.
    var beatFrequency: Double = 10
    /// Carrier pitch in Hz.
    var carrierFrequency: Double = 220
    var volume: Double = 0.3
    /// Isochronic only: 0...1 depth of the amplitude pulse.
    var pulseDepth: Double = 0.8

    static let beatRange: ClosedRange<Double> = 0.5...40
    static let carrierRange: ClosedRange<Double> = 100...1000
}

struct SoundMix: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    /// Only layers that are part of the mix; absent ids are off.
    var layers: [String: LayerState]
    var tone: ToneSettings?
    var isFavorite: Bool = false
    /// Shipped presets cannot be renamed or deleted.
    var isBuiltIn: Bool = false
}

/// A sequence of mixes that the engine moves through with crossfades.
struct MixPlaylist: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var mixIDs: [UUID]
    /// Seconds each mix plays before moving on.
    var interval: TimeInterval = 15 * 60
    var isShuffled: Bool = false
    var isBuiltIn: Bool = false

    static let intervalChoices: [TimeInterval] = [5, 10, 15, 20, 30, 45, 60].map { $0 * 60 }
}

/// Short user-facing notice raised by the engine, e.g. the layer limit or a device change.
struct SoundsNotice: Identifiable, Equatable {
    enum Kind: Equatable {
        case layerLimit, devicePaused, loadFailed, importFailed, imported, headphonesRecommended
    }

    let id = UUID()
    let kind: Kind
    let message: String
}
