import SwiftUI

/// One mixer row: on/off icon, the level bar (which is the volume slider) and an expand control
/// for rise-and-fall settings. Equatable so a change to one layer doesn't redraw the others.
struct SoundLayerRow: View, Equatable {
    let sound: SoundDescriptor
    /// Read only for the live level; not observed, so rows don't redraw on every change.
    let sounds: SoundsController
    let state: LayerState
    let isPlaying: Bool
    let isExpanded: Bool
    let onToggle: () -> Void
    let onVolume: (Double) -> Void
    let onExpand: () -> Void
    let onOscillation: (OscillationSettings) -> Void

    static func == (lhs: SoundLayerRow, rhs: SoundLayerRow) -> Bool {
        lhs.sound == rhs.sound && lhs.state == rhs.state && lhs.isPlaying == rhs.isPlaying && lhs.isExpanded == rhs.isExpanded
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                toggleButton
                EmberLevelBar(
                    sounds: sounds,
                    soundID: sound.id,
                    title: sound.name,
                    value: state.volume,
                    isActive: state.isActive,
                    isBreathing: state.isActive && isPlaying && state.oscillation.isEnabled,
                    onChange: onVolume
                )
                expandButton
            }

            if isExpanded {
                OscillationPanel(name: sound.name, settings: state.oscillation, onChange: onOscillation)
                    .padding(.leading, SoundsStyle.iconColumn + 8)
                    .padding(.trailing, 32)
                    .padding(.bottom, 4)
                    .transition(.opacity)
            }
        }
    }

    private var toggleButton: some View {
        Button(action: onToggle) {
            Image(systemName: SoundsStyle.symbol(sound.symbolName))
                .font(.system(size: 13, weight: .semibold))
                .symbolVariant(state.isActive ? .fill : .none)
                .foregroundStyle(state.isActive ? Color.white : Color.secondary)
                .frame(width: SoundsStyle.iconColumn, height: SoundsStyle.iconColumn)
                .background(state.isActive ? SoundsStyle.ember : SoundsStyle.surface)
                .clipShape(Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(state.isActive ? "Turn off \(sound.name)" : "Turn on \(sound.name)")
        .accessibilityLabel(sound.name)
        .accessibilityValue(state.isActive ? "On" : "Off")
        .accessibilityAddTraits(state.isActive ? .isSelected : [])
    }

    private var expandButton: some View {
        Button(action: onExpand) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    .foregroundStyle(isExpanded ? Color.primary : Color.secondary)
                    .frame(width: 24, height: SoundsStyle.barHeight)
                if state.oscillation.isEnabled {
                    Circle()
                        .fill(SoundsStyle.ember)
                        .frame(width: 5, height: 5)
                        .offset(x: -3, y: 6)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(isExpanded ? "Hide rise and fall" : "Rise and fall")
        .accessibilityLabel("Rise and fall for \(sound.name)")
        .accessibilityValue(state.oscillation.isEnabled ? "On" : "Off")
        .accessibilityHint(isExpanded ? "Collapses settings" : "Expands settings")
    }
}

/// The signature control: the row fills with ember up to the layer's volume, with the name on top.
/// Click or drag anywhere to set the level; arrow keys nudge it by 5%.
struct EmberLevelBar: View {
    let sounds: SoundsController
    let soundID: String
    let title: String
    let value: Double
    let isActive: Bool
    /// Rise and fall is running: the inner fill follows the live level.
    let isBreathing: Bool
    let onChange: (Double) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var isFocused: Bool

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            ZStack(alignment: .leading) {
                Rectangle().fill(SoundsStyle.surface)

                if isActive {
                    // Set level, faint, with a thin edge marking the ceiling the swell rises to.
                    Rectangle()
                        .fill(SoundsStyle.emberSetLevel)
                        .frame(width: width * value)
                        .overlay(alignment: .trailing) {
                            Rectangle()
                                .fill(SoundsStyle.ember.opacity(0.55))
                                .frame(width: width * value > 2 ? 1 : 0)
                        }
                    // Heard level, strong. Breathes only when rise and fall runs and motion is allowed.
                    if isBreathing && !reduceMotion {
                        LiveLevelFill(sounds: sounds, soundID: soundID, width: width, ceiling: value)
                    } else {
                        EmberFill(width: width * value)
                    }
                } else {
                    // Preset level for a sound that's off: barely there, so active rows lead.
                    Rectangle()
                        .fill(Color.primary.opacity(0.04))
                        .frame(width: width * value)
                }

                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 12.5, weight: isActive ? .semibold : .regular))
                        .foregroundStyle(isActive ? Color.primary : Color.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(SoundsStyle.percent(value))
                        .font(SoundsStyle.number(11))
                        .foregroundStyle(isActive ? Color.primary.opacity(0.75) : Color.secondary.opacity(0.5))
                }
                .padding(.horizontal, 10)
            }
            .clipShape(RoundedRectangle(cornerRadius: SoundsStyle.cornerRadius, style: .continuous))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        guard width > 0 else { return }
                        onChange((drag.location.x / width).clamped(to: 0...1))
                    }
            )
        }
        .frame(height: SoundsStyle.barHeight)
        .overlay(
            RoundedRectangle(cornerRadius: SoundsStyle.cornerRadius, style: .continuous)
                .strokeBorder(SoundsStyle.ember, lineWidth: isFocused ? 2 : 0)
        )
        .focusable()
        .focused($isFocused)
        .focusEffectDisabled()
        .onMoveCommand { direction in
            switch direction {
            case .left, .down: nudge(-0.05)
            case .right, .up: nudge(0.05)
            @unknown default: break
            }
        }
        .help("Drag to set the \(title.lowercased()) volume")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title) volume")
        .accessibilityValue(SoundsStyle.percent(value))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: nudge(0.05)
            case .decrement: nudge(-0.05)
            @unknown default: break
            }
        }
    }

    private func nudge(_ delta: Double) {
        onChange(((value + delta) * 20).rounded() / 20)
    }
}

private struct EmberFill: View {
    let width: CGFloat

    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [SoundsStyle.emberFillStart, SoundsStyle.emberFillEnd],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: max(0, width))
            .overlay(alignment: .trailing) {
                // Bright edge marks the exact level.
                Rectangle()
                    .fill(SoundsStyle.ember)
                    .frame(width: width > 2 ? 2 : 0)
            }
    }
}

/// Polls the engine's live level at 12 fps. Only rows with rise and fall running mount this.
private struct LiveLevelFill: View {
    let sounds: SoundsController
    let soundID: String
    let width: CGFloat
    let ceiling: Double

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 12.0)) { _ in
            let level = min(ceiling, sounds.liveLevel(for: soundID))
            EmberFill(width: width * level)
        }
    }
}

/// Rise-and-fall settings beneath an expanded row.
private struct OscillationPanel: View {
    let name: String
    let settings: OscillationSettings
    let onChange: (OscillationSettings) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: binding(\.isEnabled)) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Rise and fall")
                        .font(.system(size: 12, weight: .medium))
                    Text("Slowly swells the level so it never sits still.")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)
            .controlSize(.mini)
            .tint(SoundsStyle.ember)
            .accessibilityLabel("Rise and fall for \(name)")

            Group {
                SoundsValueSlider(
                    title: "Depth",
                    valueText: SoundsStyle.percent(settings.depth),
                    value: binding(\.depth),
                    range: OscillationSettings.depthRange
                )
                SoundsValueSlider(
                    title: "One swell",
                    valueText: SoundsStyle.duration(settings.period),
                    value: periodBinding
                )
            }
            .disabled(!settings.isEnabled)
            .opacity(settings.isEnabled ? 1 : 0.45)
        }
    }

    private func binding<T>(_ keyPath: WritableKeyPath<OscillationSettings, T>) -> Binding<T> {
        Binding(
            get: { settings[keyPath: keyPath] },
            set: { newValue in
                var next = settings
                next[keyPath: keyPath] = newValue
                onChange(next)
            }
        )
    }

    /// Log scale so 10 s–2 min gets most of the track; snaps to 5 s.
    private var periodBinding: Binding<Double> {
        let range = OscillationSettings.periodRange
        let ratio = range.upperBound / range.lowerBound
        return Binding(
            get: { log(settings.period / range.lowerBound) / log(ratio) },
            set: { position in
                var next = settings
                let seconds = range.lowerBound * pow(ratio, position)
                next.period = ((seconds / 5).rounded() * 5).clamped(to: range)
                onChange(next)
            }
        )
    }
}
