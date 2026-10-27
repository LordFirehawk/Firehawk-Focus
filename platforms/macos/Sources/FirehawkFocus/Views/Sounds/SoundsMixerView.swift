import AppKit
import SwiftUI

/// The library as folding categories, with the sounds that are playing pinned in "On now" at the top.
///
/// "On now" holds still while the pointer is over the list: turning a sound on or off doesn't shift the
/// rows under the cursor. It catches up when the pointer leaves, or straight away for keyboard and
/// VoiceOver users, who never hover.
struct SoundsMixerView: View {
    @ObservedObject var sounds: SoundsController
    var onShowCredits: (() -> Void)? = nil

    /// Row whose rise-and-fall panel is open, keyed by section so a pinned row and its category twin open separately.
    @State private var expandedKey: String?
    @State private var pinnedIDs: [String] = []
    @State private var isHovering = false
    /// Comma-separated categories that are open. New installs start with Rain open as an example.
    @AppStorage("soundsOpenCategories") private var openCategoriesRaw = SoundCategory.rain.rawValue
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(sounds: SoundsController, expandedID: String? = nil, onShowCredits: (() -> Void)? = nil) {
        self.sounds = sounds
        self.onShowCredits = onShowCredits
        _expandedKey = State(initialValue: expandedID.map { Self.key(.library, $0) })
    }

    private enum Place: String { case pinned, library }

    private static func key(_ place: Place, _ id: String) -> String { "\(place.rawValue):\(id)" }

    private var groups: [(category: SoundCategory, sounds: [SoundDescriptor])] {
        let byCategory = Dictionary(grouping: sounds.catalog, by: \.category)
        return SoundCategory.allCases.compactMap { category in
            guard let items = byCategory[category], !items.isEmpty else { return nil }
            return (category, items)
        }
    }

    /// Catalog order, so pinned rows don't reshuffle as levels change.
    private var activeIDs: [String] {
        sounds.catalog.map(\.id).filter { sounds.layerState(for: $0).isActive }
    }

    private var openCategories: Set<String> {
        Set(openCategoriesRaw.split(separator: ",").map(String.init))
    }

    private var motion: Animation? { reduceMotion ? nil : .snappy(duration: 0.2) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                toolbar
                    .padding(.bottom, 2)

                if !pinnedIDs.isEmpty {
                    SoundsSectionLabel(title: "On now")
                        .padding(.top, 8)
                        .padding(.bottom, 1)
                    ForEach(pinnedSounds) { sound in
                        row(for: sound, in: .pinned)
                    }
                    .transition(.opacity)
                }

                SoundsSectionLabel(title: "All sounds", trailing: "\(sounds.catalog.count)")
                    .padding(.top, pinnedIDs.isEmpty ? 8 : 14)
                    .padding(.bottom, 1)

                ForEach(groups, id: \.category) { group in
                    categorySection(group.category, items: group.sounds)
                }

                if let onShowCredits {
                    Button(action: onShowCredits) {
                        Text("Sound credits")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Who made these recordings, and their licences")
                    .frame(maxWidth: .infinity)
                    .padding(.top, 14)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 14)
        }
        .onHover { hovering in
            isHovering = hovering
            if !hovering { syncPinned() }
        }
        .onAppear { pinnedIDs = activeIDs }
        .onChange(of: activeIDs) { _, _ in
            if !isHovering { syncPinned() }
        }
    }

    private var pinnedSounds: [SoundDescriptor] {
        let byID = Dictionary(uniqueKeysWithValues: sounds.catalog.map { ($0.id, $0) })
        return pinnedIDs.compactMap { byID[$0] }
    }

    private func syncPinned() {
        let next = activeIDs
        guard next != pinnedIDs else { return }
        withAnimation(motion) { pinnedIDs = next }
        if let expandedKey, expandedKey.hasPrefix(Place.pinned.rawValue), !next.contains(where: { Self.key(.pinned, $0) == expandedKey }) {
            self.expandedKey = nil
        }
    }

    private var toolbar: some View {
        HStack(spacing: 6) {
            Text(countText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            Spacer()
            SoundsQuietButton(title: "Random mix", icon: "dice") {
                sounds.randomMix()
                withAnimation(motion) { pinnedIDs = activeIDs }
            }
            .help("Turn on a random combination of sounds")
            SoundsQuietButton(title: "Clear all", icon: "xmark") {
                withAnimation(motion) {
                    expandedKey = nil
                    sounds.clearAll()
                    pinnedIDs = []
                }
            }
            .disabled(!sounds.hasAnythingEnabled)
            .opacity(sounds.hasAnythingEnabled ? 1 : 0.4)
            .help("Turn every sound and the tone off")
        }
    }

    private var countText: String {
        let count = sounds.activeLayerCount
        if count == 0 { return "Layer up to \(sounds.maxActiveLayers) sounds" }
        return "\(count) of \(sounds.maxActiveLayers) sounds on"
    }

    @ViewBuilder
    private func categorySection(_ category: SoundCategory, items: [SoundDescriptor]) -> some View {
        let isOpen = openCategories.contains(category.rawValue)
        SoundsCategoryHeader(
            category: category,
            items: items,
            activeIDs: Set(items.map(\.id).filter { sounds.layerState(for: $0).isActive }),
            isOpen: isOpen,
            onToggle: { allCategories in
                withAnimation(motion) { setOpen(!isOpen, category: category, all: allCategories) }
            },
            onSetAll: { open in
                withAnimation(motion) { setOpen(open, category: category, all: true) }
            }
        )

        if isOpen {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(items) { sound in
                    row(for: sound, in: .library)
                }
            }
            .padding(.bottom, 6)
            .transition(.opacity)
        }
    }

    private func setOpen(_ open: Bool, category: SoundCategory, all: Bool) {
        var next = openCategories
        let targets = all ? groups.map(\.category.rawValue) : [category.rawValue]
        for target in targets {
            if open { next.insert(target) } else { next.remove(target) }
        }
        openCategoriesRaw = SoundCategory.allCases.map(\.rawValue).filter(next.contains).joined(separator: ",")
        if !open, let expandedKey, expandedKey.hasPrefix(Place.library.rawValue) {
            let closedIDs = sounds.catalog.filter { targets.contains($0.category.rawValue) }.map { Self.key(.library, $0.id) }
            if closedIDs.contains(expandedKey) { self.expandedKey = nil }
        }
    }

    private func row(for sound: SoundDescriptor, in place: Place) -> some View {
        let state = sounds.layerState(for: sound.id)
        let key = Self.key(place, sound.id)
        return SoundLayerRow(
            sound: sound,
            sounds: sounds,
            state: state,
            isPlaying: sounds.isPlaying,
            isExpanded: expandedKey == key,
            onToggle: { [sounds] in
                sounds.setLayerActive(sound.id, !sounds.layerState(for: sound.id).isActive)
            },
            onVolume: { [sounds] volume in
                sounds.setLayerVolume(sound.id, volume)
                // Setting a level on a quiet row means you want to hear it.
                // At the layer limit, raise the notice once per drag rather than on every tick.
                if !sounds.layerState(for: sound.id).isActive, sounds.notice?.kind != .layerLimit {
                    sounds.setLayerActive(sound.id, true)
                }
            },
            onExpand: {
                withAnimation(motion) {
                    expandedKey = expandedKey == key ? nil : key
                }
            },
            onOscillation: { [sounds] settings in
                sounds.setOscillation(sound.id, settings)
            }
        )
        .equatable()
        .id(key)
    }
}

/// Folding header for one category: chevron, name, how many it holds and how many are on.
/// Option-click (or the context menu) opens or closes every category, as in Finder.
private struct SoundsCategoryHeader: View {
    let category: SoundCategory
    let items: [SoundDescriptor]
    let activeIDs: Set<String>
    let isOpen: Bool
    let onToggle: (_ allCategories: Bool) -> Void
    let onSetAll: (_ open: Bool) -> Void

    @State private var isHovering = false

    var body: some View {
        Button {
            onToggle(NSEvent.modifierFlags.contains(.option))
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isOpen ? 90 : 0))
                    .frame(width: SoundsStyle.iconColumn)

                Text(category.title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.primary)

                Text("\(items.count)")
                    .font(SoundsStyle.number(11))
                    .foregroundStyle(.tertiary)

                Spacer(minLength: 6)

                if !isOpen {
                    // A glance at what's inside without opening it.
                    HStack(spacing: 5) {
                        ForEach(items.prefix(5)) { sound in
                            Image(systemName: SoundsStyle.symbol(sound.symbolName))
                                .font(.system(size: 10, weight: .medium))
                                .symbolVariant(isActive(sound) ? .fill : .none)
                                .foregroundStyle(isActive(sound) ? AnyShapeStyle(SoundsStyle.emberText) : AnyShapeStyle(.tertiary))
                        }
                        if items.count > 5 {
                            Text("+\(items.count - 5)")
                                .font(SoundsStyle.number(10))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .accessibilityHidden(true)
                }

                if onCount > 0 {
                    Text("\(onCount) on")
                        .font(SoundsStyle.number(10.5, weight: .semibold))
                        .foregroundStyle(SoundsStyle.emberText)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1.5)
                        .background(SoundsStyle.ember.opacity(0.14))
                        .clipShape(Capsule())
                }
            }
            .padding(.trailing, 8)
            .frame(height: 28)
            .background(isHovering ? SoundsStyle.surface : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: SoundsStyle.cornerRadius, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .contextMenu {
            Button("Open all categories") { onSetAll(true) }
            Button("Close all categories") { onSetAll(false) }
        }
        .help(isOpen ? "Hide \(category.title.lowercased()) sounds. Option-click to close all." : "Show \(category.title.lowercased()) sounds. Option-click to open all.")
        .accessibilityLabel(category.title)
        .accessibilityValue("\(items.count) sounds" + (onCount > 0 ? ", \(onCount) on" : ""))
        .accessibilityHint(isOpen ? "Collapses the category" : "Expands the category")
        .accessibilityAddTraits(.isHeader)
    }

    private var onCount: Int { activeIDs.count }

    private func isActive(_ sound: SoundDescriptor) -> Bool { activeIDs.contains(sound.id) }
}
