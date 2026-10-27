import Foundation
import XCTest
@testable import FirehawkFocus

final class SoundAttributionTests: XCTestCase {
    private func catalogData() throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "catalog", withExtension: "json", subdirectory: "Ambience"))
        return try Data(contentsOf: url)
    }

    func testEveryRecordingHasExplicitStructuredAttribution() throws {
        let data = try catalogData()
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        let entries = try JSONDecoder().decode([AmbienceEntry].self, from: data)
        XCTAssertEqual(entries.count, 34)
        for entry in json {
            XCTAssertFalse(try XCTUnwrap(entry["sources"] as? [[String: Any]]).isEmpty)
            XCTAssertNotNil(entry["editors"] as? [String])
        }
        for entry in entries {
            XCTAssertFalse(entry.sources.isEmpty, entry.id)
            XCTAssertEqual(entry.descriptor.sources, entry.sources)
            XCTAssertEqual(entry.descriptor.editors, entry.editors)
            XCTAssertEqual(entry.descriptor.credit, entry.credit + " · " + entry.license)
            XCTAssertEqual(entry.descriptor.sourceURL, entry.sourceURL)
            for source in entry.sources {
                XCTAssertFalse(source.creator.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, entry.id)
                XCTAssertEqual(source.url.scheme, "https", entry.id)
                XCTAssertNotNil(source.url.host, entry.id)
                XCTAssertNotNil(SoundLicense(rawValue: source.license.rawValue), entry.id)
                switch source.license {
                case .ccBy3:
                    XCTAssertEqual(source.license.deedURL?.absoluteString, "https://creativecommons.org/licenses/by/3.0/")
                case .ccBy4:
                    XCTAssertEqual(source.license.deedURL?.absoluteString, "https://creativecommons.org/licenses/by/4.0/")
                case .cc0, .publicDomain: break
                }
            }
        }
        let typing = try XCTUnwrap(entries.first { $0.id == "typing-pages" })
        XCTAssertEqual(typing.sources.count, 2)
        XCTAssertEqual(typing.sources.map(\.creator), ["unicaegames", "Mark DiAngelo"])
        XCTAssertEqual(typing.sources.map(\.license), [.cc0, .ccBy3])
        XCTAssertEqual(typing.sources.last?.url.absoluteString, "https://soundbible.com/2066-Page-Turn.html")
        let snow = try XCTUnwrap(entries.first { $0.id == "winter-walk" })
        XCTAssertEqual(snow.sources.count, 1)
        XCTAssertEqual(snow.sources.first?.creator, "Corsica_S")
        XCTAssertEqual(snow.sources.first?.license, .cc0)
        XCTAssertTrue(snow.editors.contains("Iwan Gabovitch"))
        let storm = try XCTUnwrap(entries.first { $0.id == "thunderstorm" })
        XCTAssertEqual(storm.sources.map(\.creator), ["Mike Koenig", "felix.blume"])
        XCTAssertEqual(storm.sources.map(\.license), [.ccBy3, .cc0])
        for id in ["campfire", "bonfire", "waterfall", "thunder-close", "clock"] {
            let entry = try XCTUnwrap(entries.first { $0.id == id })
            XCTAssertEqual(entry.sources.count, 1, id)
            XCTAssertTrue(entry.editors.contains("Firehawk Focus"), id)
        }
    }

    func testFreesoundOriginalsRetainVerifiedCreatorsAndSeparateEntries() throws {
        let entries = try JSONDecoder().decode([AmbienceEntry].self, from: catalogData())
        let expected = [
            ("rain-light", "soundrecorder7", "167034", SoundLicense.cc0),
            ("fire-crackling", "ceich93", "263864", SoundLicense.cc0),
            ("fountain", "skyko", "169254", SoundLicense.cc0),
            ("washing-machine", "alienistcog", "125307", SoundLicense.cc0),
            ("cafe", "Berwitz", "263584", SoundLicense.cc0),
            ("night-frogs", "mycompasstv", "462889", SoundLicense.cc0),
            ("bullfrogs", "reinsamba", "58236", SoundLicense.ccBy4),
        ]
        for (id, creator, soundID, license) in expected {
            let entry = try XCTUnwrap(entries.first { $0.id == id })
            XCTAssertEqual(entry.sources.count, 1, id)
            XCTAssertEqual(entry.sources.first?.creator, creator, id)
            XCTAssertEqual(entry.sources.first?.url.absoluteString,
                           "https://freesound.org/people/\(creator)/sounds/\(soundID)/", id)
            XCTAssertEqual(entry.sources.first?.license, license, id)
            XCTAssertEqual(entry.editors, ["Firehawk Focus"], id)
            XCTAssertGreaterThanOrEqual(try XCTUnwrap(entry.loopEndSeconds), 40, id)
            XCTAssertLessThanOrEqual(try XCTUnwrap(entry.loopEndSeconds), 60, id)
        }
        for id in ["rain", "fireplace", "campfire", "bonfire"] {
            XCTAssertNotNil(entries.first { $0.id == id }, id)
        }
        let cafeteria = try XCTUnwrap(entries.first { $0.id == "cafeteria" })
        XCTAssertEqual(cafeteria.name, "Cafeteria")
        XCTAssertEqual(cafeteria.file, "cafeteria.flac")
        XCTAssertEqual(cafeteria.sources.first?.creator, "bittermelonheart")
        XCTAssertEqual(cafeteria.sources.first?.license, .cc0)
        XCTAssertEqual(cafeteria.category, .indoor)
        XCTAssertEqual(cafeteria.editors, ["Firehawk Focus"])
        XCTAssertEqual(cafeteria.loopEndSeconds, 234)
        let cafe = try XCTUnwrap(entries.first { $0.id == "cafe" })
        XCTAssertEqual(cafe.name, "Café")
        XCTAssertEqual(cafe.category, .indoor)
        XCTAssertEqual(cafe.symbolName, "cup.and.saucer")
        let frogs = try XCTUnwrap(entries.first { $0.id == "bullfrogs" })
        XCTAssertEqual(frogs.name, "Croaky frogs")
        XCTAssertEqual(frogs.gainDb, -4.0)
        XCTAssertEqual(frogs.license, "CC-BY-4.0")
        XCTAssertTrue(frogs.credit.contains("https://creativecommons.org/licenses/by/4.0/"))
    }

    func testLegacyCatalogEntriesFallBackToOneSource() throws {
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: catalogData()) as? [[String: Any]])
        for index in json.indices {
            json[index].removeValue(forKey: "sources")
            json[index].removeValue(forKey: "editors")
        }
        let entries = try JSONDecoder().decode([AmbienceEntry].self, from: JSONSerialization.data(withJSONObject: json))
        for entry in entries {
            XCTAssertEqual(entry.sources.count, 1, entry.id)
            XCTAssertEqual(entry.sources.first?.url, entry.sourceURL)
            XCTAssertEqual(entry.sources.first?.license.rawValue, entry.license)
            XCTAssertFalse(entry.sources.first?.creator.isEmpty ?? true, entry.id)
            XCTAssertTrue(entry.editors.isEmpty)
        }
        XCTAssertEqual(entries.first { $0.id == "rain" }?.sources.first?.creator, "alex36917")
    }

    func testDescriptorDefaultsAndCodableCompatibility() throws {
        let legacy = Data(#"{"id":"noise","name":"Noise","symbolName":"waveform","category":"noise","isGenerated":true}"#.utf8)
        let decoded = try JSONDecoder().decode(SoundDescriptor.self, from: legacy)
        let initialized = SoundDescriptor(id: "noise", name: "Noise", symbolName: "waveform", category: .noise,
                                          isGenerated: true, credit: nil, sourceURL: nil)
        XCTAssertEqual(decoded, initialized)
        XCTAssertTrue(decoded.sources.isEmpty)
        XCTAssertTrue(decoded.editors.isEmpty)
        for entry in try JSONDecoder().decode([AmbienceEntry].self, from: catalogData()) {
            let encoded = try JSONEncoder().encode(entry.descriptor)
            XCTAssertEqual(try JSONDecoder().decode(SoundDescriptor.self, from: encoded), entry.descriptor)
        }
        XCTAssertEqual(SoundLicense.cc0.deedURL?.absoluteString, "https://creativecommons.org/publicdomain/zero/1.0/")
        XCTAssertNil(SoundLicense.publicDomain.deedURL)
    }
}
