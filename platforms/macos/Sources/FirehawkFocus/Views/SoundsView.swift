import SwiftUI

enum SoundsSection: String, CaseIterable, Identifiable {
    case mixer, mixes, tones

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mixer: return "Mixer"
        case .mixes: return "Mixes"
        case .tones: return "Tones"
        }
    }
}

struct SoundsView: View {
    @ObservedObject private var sounds: SoundsController
    /// Remembered so reopening the tray returns to the same pane.
    @AppStorage("soundsSection") private var section: SoundsSection = .mixer
    private let initialExpandedSoundID: String?
    @State private var showsCredits: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// `sounds` defaults to the app-wide controller; previews and snapshots pass an offline one.
    @MainActor
    init(sounds: SoundsController? = nil, initialExpandedSoundID: String? = nil, showsCredits: Bool = false) {
        _sounds = ObservedObject(wrappedValue: sounds ?? .shared)
        self.initialExpandedSoundID = initialExpandedSoundID
        _showsCredits = State(initialValue: showsCredits)
    }

    var body: some View {
        if showsCredits {
            SoundCreditsView(catalog: sounds.catalog) { setShowsCredits(false) }
                .transition(reduceMotion ? .opacity : .move(edge: .trailing))
        } else {
            mainPane
                .transition(reduceMotion ? .opacity : .move(edge: .leading))
        }
    }

    private func setShowsCredits(_ value: Bool) {
        withAnimation(reduceMotion ? .easeInOut(duration: 0.15) : .snappy(duration: 0.25)) { showsCredits = value }
    }

    private var mainPane: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                SoundsTransportView(sounds: sounds)

                if let notice = sounds.notice {
                    SoundsNoticeBanner(notice: notice) { sounds.dismissNotice() }
                        .transition(.opacity)
                }

                Picker("Sounds view", selection: $section) {
                    ForEach(SoundsSection.allCases) { section in
                        Text(section.title).tag(section)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(.regular)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 10)
            .animation(.snappy(duration: 0.2), value: sounds.notice)

            Divider()

            Group {
                switch section {
                case .mixer:
                    SoundsMixerView(sounds: sounds, expandedID: initialExpandedSoundID) { setShowsCredits(true) }
                case .mixes:
                    SoundsMixesView(sounds: sounds)
                case .tones:
                    SoundsTonesView(sounds: sounds)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
}
