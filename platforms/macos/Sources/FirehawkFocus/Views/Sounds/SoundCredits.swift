import Foundation

extension SoundLicense {
    /// Sentence case for the licence tag: "CC BY 4.0", "Public domain".
    var tagTitle: String { self == .publicDomain ? "Public domain" : title }

    /// Attribution licences oblige us to credit the creator and say what we changed.
    var requiresAttribution: Bool { self == .ccBy3 || self == .ccBy4 }
}

/// Display-ready credit for one recording, read from `SoundDescriptor.sources` and `editors`.
struct SoundCredit: Identifiable, Equatable {
    /// One original recording that went into the sound.
    struct Source: Equatable, Hashable {
        /// "By felix.blume", "“Page Turn” by Mark DiAngelo".
        let byline: String
        /// Nil only for legacy credits that carry no licence.
        let licence: SoundLicense?
        let url: URL?
    }

    let id: String
    let name: String
    let symbolName: String
    let category: SoundCategory
    let sources: [Source]
    /// Prior editors and redistributors, e.g. "Edited by Porrumentzio and Blankie". Firehawk Focus is
    /// left out because `editNote` already says what we changed.
    let contributors: String?

    static let editNote = "Trimmed, looped and level-matched for Firehawk Focus."

    /// The licence shown beside the name when every source shares one; otherwise each source shows its own.
    var sharedLicence: SoundLicense? {
        let licences = Set(sources.compactMap(\.licence))
        return sources.count == 1 || licences.count == 1 ? sources.first?.licence : nil
    }

    var showsLicencePerSource: Bool { sources.count > 1 && sharedLicence == nil }

    init(_ sound: SoundDescriptor) {
        id = sound.id
        name = sound.name
        symbolName = sound.symbolName
        category = sound.category

        if sound.sources.isEmpty {
            sources = Self.legacySource(sound).map { [$0] } ?? []
        } else {
            sources = sound.sources.map { source in
                // A title that only repeats the sound's name adds nothing.
                let title = source.title.map { $0.trimmingCharacters(in: .whitespaces) }
                    .flatMap { $0.isEmpty || $0.caseInsensitiveCompare(sound.name) == .orderedSame ? nil : $0 }
                let byline = title.map { "“\($0)” by \(source.creator)" } ?? "By \(source.creator)"
                return Source(byline: byline, licence: source.license, url: source.url)
            }
        }

        let editors = sound.editors.filter { $0.caseInsensitiveCompare("Firehawk Focus") != .orderedSame }
        contributors = editors.isEmpty ? nil : "Edited by " + ListFormatter.localizedString(byJoining: editors)
    }

    /// Catalog entries written before structured sources: show the credit text as-is.
    private static func legacySource(_ sound: SoundDescriptor) -> Source? {
        var text = sound.credit ?? ""
        var licence: SoundLicense?
        if let separator = text.range(of: " · ", options: .backwards) {
            licence = SoundLicense(rawValue: String(text[separator.upperBound...]))
            text = String(text[..<separator.lowerBound])
        }
        text = text.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty || sound.sourceURL != nil else { return nil }
        return Source(byline: text.isEmpty ? "Creator on source page" : text, licence: licence, url: sound.sourceURL)
    }

    /// "freesound.org", "commons.wikimedia.org".
    static func label(for url: URL) -> String {
        guard var host = url.host else { return url.absoluteString }
        if host.hasPrefix("www.") { host.removeFirst(4) }
        return host
    }
}
