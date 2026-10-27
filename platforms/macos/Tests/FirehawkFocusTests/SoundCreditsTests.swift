import XCTest
@testable import FirehawkFocus

@MainActor
final class SoundCreditsTests: XCTestCase {
    private func shippedRecordings() -> [SoundDescriptor] {
        let storage = FileManager.default.temporaryDirectory.appendingPathComponent("credits-\(UUID().uuidString).json")
        let sounds = SoundsController(storageURL: storage, enableAudio: false)
        return sounds.catalog.filter { !$0.isGenerated }
    }

    private func credit(_ id: String) throws -> SoundCredit {
        let sound = try XCTUnwrap(shippedRecordings().first { $0.id == id }, "\(id) missing from catalog")
        return SoundCredit(sound)
    }

    func testEveryRecordingHasStructuredSources() {
        let recordings = shippedRecordings()
        XCTAssertEqual(recordings.count, 34)
        for sound in recordings {
            XCTAssertFalse(sound.sources.isEmpty, "\(sound.id) has no structured source")
            let credit = SoundCredit(sound)
            XCTAssertEqual(credit.sources.count, sound.sources.count)
            for source in credit.sources {
                XCTAssertNotNil(source.licence, "\(sound.id) source has no licence")
                XCTAssertNotNil(source.url, "\(sound.id) source has no link")
                XCTAssertFalse(source.byline.contains("http"), "\(sound.id) byline shows a URL")
            }
            XCTAssertNotNil(credit.sharedLicence ?? credit.sources.first?.licence)
        }
    }

    func testAttributionLicencesLinkToTheirDeeds() {
        let expected: [SoundLicense: String] = [
            .ccBy3: "https://creativecommons.org/licenses/by/3.0/",
            .ccBy4: "https://creativecommons.org/licenses/by/4.0/",
        ]
        var seen = Set<SoundLicense>()
        for sound in shippedRecordings() {
            for source in sound.sources where source.license.requiresAttribution {
                seen.insert(source.license)
                XCTAssertEqual(source.license.deedURL?.absoluteString, expected[source.license], "\(sound.id)")
            }
        }
        XCTAssertEqual(seen, [.ccBy3, .ccBy4])
        XCTAssertNil(SoundLicense.publicDomain.deedURL)
        XCTAssertEqual(SoundLicense.publicDomain.tagTitle, "Public domain")
    }

    func testTypingPagesShowsBothSourcesWithTheirOwnLicences() throws {
        let credit = try credit("typing-pages")
        XCTAssertEqual(credit.sources.map(\.licence), [.cc0, .ccBy3])
        XCTAssertTrue(credit.showsLicencePerSource)
        XCTAssertNil(credit.sharedLicence)
        XCTAssertEqual(credit.sources.map(\.byline), [
            "“Keyboard Soundpack 1 - Typing and Single Keystrokes” by unicaegames",
            "“Page Turn” by Mark DiAngelo",
        ])
        XCTAssertEqual(credit.sources.compactMap(\.url?.host), ["opengameart.org", "soundbible.com"])
        XCTAssertNil(credit.contributors)
    }

    func testSnowNamesCreatorAndEditor() throws {
        let credit = try credit("winter-walk")
        XCTAssertEqual(credit.sources.map(\.byline), ["By Corsica_S"])
        XCTAssertEqual(credit.sharedLicence, .cc0)
        XCTAssertFalse(credit.showsLicencePerSource)
        XCTAssertEqual(credit.contributors, "Edited by Iwan Gabovitch")
    }

    func testDistinctTitleIsKeptAndFirehawkIsNotListedAsEditor() throws {
        let credit = try credit("rain")
        XCTAssertEqual(credit.sources.map(\.byline), ["“rain ambience” by alex36917"])
        XCTAssertEqual(credit.contributors, "Edited by Porrumentzio and Blankie")
    }

    func testFallsBackToCreditTextWithoutSources() {
        let sound = SoundDescriptor(id: "x", name: "X", symbolName: "wind", category: .nature, isGenerated: false,
                                    credit: "By Someone · CC-BY-4.0", sourceURL: URL(string: "https://example.org/x"))
        let credit = SoundCredit(sound)
        XCTAssertEqual(credit.sources, [.init(byline: "By Someone", licence: .ccBy4, url: URL(string: "https://example.org/x"))])

        let bare = SoundCredit(SoundDescriptor(id: "y", name: "Y", symbolName: "wind", category: .nature,
                                               isGenerated: false, credit: nil, sourceURL: nil))
        XCTAssertTrue(bare.sources.isEmpty)
        XCTAssertNil(bare.sharedLicence)
    }
}
