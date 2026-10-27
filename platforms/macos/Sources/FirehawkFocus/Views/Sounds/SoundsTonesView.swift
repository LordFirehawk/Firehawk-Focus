import SwiftUI

struct SoundsTonesView: View {
    @ObservedObject var sounds: SoundsController

    private var tone: ToneSettings { sounds.tone }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Toggle(isOn: binding(\.isEnabled)) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Play a tone")
                            .font(.system(size: 13, weight: .semibold))
                        Text("A steady pitch that pulses at the rate you choose, under your sounds.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(SoundsStyle.ember)

                VStack(alignment: .leading, spacing: 8) {
                    Picker("Kind", selection: binding(\.mode)) {
                        ForEach(ToneMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .accessibilityLabel("Tone kind")

                    Text(explanation(for: tone.mode))
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    outputStatus
                }

                ToneEnvelopeView(tone: tone)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 8) {
                    SoundsSectionLabel(title: "Beat rate")
                    bandPresets
                    HertzControl(
                        title: "Beat",
                        value: binding(\.beatFrequency),
                        range: ToneSettings.beatRange,
                        step: 0.5,
                        logarithmic: true
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    SoundsSectionLabel(title: "Sound")
                    HertzControl(
                        title: "Pitch",
                        value: binding(\.carrierFrequency),
                        range: ToneSettings.carrierRange,
                        step: 10,
                        logarithmic: true
                    )
                    SoundsValueSlider(title: "Volume", valueText: SoundsStyle.percent(tone.volume), value: binding(\.volume))
                    if tone.mode == .isochronic {
                        SoundsValueSlider(title: "Pulse", valueText: SoundsStyle.percent(tone.pulseDepth), value: binding(\.pulseDepth))
                    }
                }

                Text("Tones are a listening preference, not a treatment. Keep them quiet, just above where you can hear them.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 14)
        }
    }

    // MARK: Pieces

    private var bandPresets: some View {
        let current = BrainwaveBand.band(for: tone.beatFrequency)
        return HStack(spacing: 4) {
            ForEach(BrainwaveBand.allCases) { band in
                let isCurrent = band == current
                Button {
                    var next = tone
                    next.beatFrequency = band.defaultFrequency
                    sounds.updateTone(next)
                } label: {
                    VStack(spacing: 1) {
                        Text(band.title)
                            .font(.system(size: 11.5, weight: isCurrent ? .semibold : .regular))
                        Text(rangeText(band.range))
                            .font(SoundsStyle.number(9.5, weight: .regular))
                            .foregroundStyle(isCurrent ? SoundsStyle.emberText : Color.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .background(isCurrent ? SoundsStyle.ember.opacity(0.18) : SoundsStyle.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: SoundsStyle.cornerRadius, style: .continuous)
                            .strokeBorder(isCurrent ? SoundsStyle.ember.opacity(0.6) : .clear, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: SoundsStyle.cornerRadius, style: .continuous))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Set the beat to \(SoundsStyle.hertz(band.defaultFrequency))")
                .accessibilityLabel("\(band.title), \(rangeText(band.range)) hertz")
                .accessibilityAddTraits(isCurrent ? .isSelected : [])
            }
        }
    }

    @ViewBuilder
    private var outputStatus: some View {
        let needsHeadphones = tone.mode.requiresHeadphones
        let connected = sounds.headphonesConnected
        HStack(spacing: 6) {
            Image(systemName: connected ? "headphones" : (needsHeadphones ? "exclamationmark.triangle.fill" : "hifispeaker"))
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(needsHeadphones && !connected ? Color.yellow : Color.secondary)
            Text(statusText(needsHeadphones: needsHeadphones, connected: connected))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(needsHeadphones && !connected ? Color.primary : Color.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private func statusText(needsHeadphones: Bool, connected: Bool) -> String {
        if connected { return "Headphones connected" }
        return needsHeadphones ? "No headphones found. Connect stereo headphones to hear the beat." : "Plays fine on speakers"
    }

    private func explanation(for mode: ToneMode) -> String {
        switch mode {
        case .binaural:
            return "Each ear gets a slightly different pitch, and the beat forms between them."
        case .monaural:
            return "Two close pitches are mixed before they reach you, so the beat is in the sound itself."
        case .isochronic:
            return "One pitch switches on and off at the beat rate. The most distinct pulse."
        }
    }

    private func rangeText(_ range: ClosedRange<Double>) -> String {
        func short(_ value: Double) -> String {
            value == value.rounded() ? "\(Int(value))" : String(format: "%.1f", value)
        }
        return "\(short(range.lowerBound))–\(short(range.upperBound))"
    }

    private func binding<T>(_ keyPath: WritableKeyPath<ToneSettings, T>) -> Binding<T> {
        Binding(
            get: { sounds.tone[keyPath: keyPath] },
            set: { newValue in
                var next = sounds.tone
                next[keyPath: keyPath] = newValue
                sounds.updateTone(next)
            }
        )
    }
}

/// Slider plus exact numeric entry and fine steps for a frequency.
private struct HertzControl: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let logarithmic: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .leading)
            Slider(value: sliderBinding, in: 0...1)
                .controlSize(.small)
                .tint(SoundsStyle.ember)
                .accessibilityLabel("\(title) frequency")
                .accessibilityValue(SoundsStyle.hertz(value))
            HStack(spacing: 2) {
                TextField(title, value: $value, format: .number.precision(.fractionLength(step < 1 ? 1 : 0)))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
                    .font(SoundsStyle.number(12))
                    .frame(width: 40)
                    .accessibilityLabel("\(title) in hertz")
                Text("Hz")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 6)
            .frame(height: 24)
            .background(SoundsStyle.surface)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            Stepper(title, value: $value, in: range, step: step)
                .labelsHidden()
                .controlSize(.small)
                .accessibilityLabel("Adjust \(title.lowercased()) by \(step == step.rounded() ? "\(Int(step))" : "\(step)") hertz")
        }
    }

    private var sliderBinding: Binding<Double> {
        let lower = range.lowerBound
        let ratio = range.upperBound / lower
        return Binding(
            get: { logarithmic ? log(value / lower) / log(ratio) : (value - lower) / (range.upperBound - lower) },
            set: { position in
                let raw = logarithmic ? lower * pow(ratio, position) : lower + position * (range.upperBound - lower)
                value = ((raw / step).rounded() * step).clamped(to: range)
            }
        )
    }
}

/// Static picture of the tone: carrier inside its beat envelope. Isochronic shows gated pulses.
/// Shows up to eight beats so fast rates stay legible.
struct ToneEnvelopeView: View {
    let tone: ToneSettings

    var body: some View {
        let beats = min(8, max(1, tone.beatFrequency))
        VStack(alignment: .trailing, spacing: 3) {
        Canvas { context, size in
            let mid = size.height / 2
            let amplitude = size.height / 2 - 2
            let carrierCycles = max(beats * 7, 28 + tone.carrierFrequency / 12)
            let steps = Int(size.width * 2)
            var envelopeTop = Path()
            var envelopeBottom = Path()
            var carrier = Path()

            for index in 0...steps {
                let t = Double(index) / Double(steps)
                let x = CGFloat(t) * size.width
                let env = envelope(at: t * beats)
                let y = mid - CGFloat(sin(t * carrierCycles * 2 * .pi) * env) * amplitude
                let top = mid - CGFloat(env) * amplitude
                let bottom = mid + CGFloat(env) * amplitude
                if index == 0 {
                    carrier.move(to: CGPoint(x: x, y: y))
                    envelopeTop.move(to: CGPoint(x: x, y: top))
                    envelopeBottom.move(to: CGPoint(x: x, y: bottom))
                } else {
                    carrier.addLine(to: CGPoint(x: x, y: y))
                    envelopeTop.addLine(to: CGPoint(x: x, y: top))
                    envelopeBottom.addLine(to: CGPoint(x: x, y: bottom))
                }
            }

            var area = envelopeTop
            for index in stride(from: steps, through: 0, by: -1) {
                let t = Double(index) / Double(steps)
                area.addLine(to: CGPoint(x: CGFloat(t) * size.width, y: mid + CGFloat(envelope(at: t * beats)) * amplitude))
            }
            area.closeSubpath()

            let strength = tone.isEnabled ? 1.0 : 0.45
            context.fill(area, with: .color(SoundsStyle.ember.opacity(0.14 * strength)))
            context.stroke(carrier, with: .color(SoundsStyle.ember.opacity(0.75 * strength)), lineWidth: 0.8)
            context.stroke(envelopeTop, with: .color(SoundsStyle.ember.opacity(strength)), lineWidth: 1.2)
            context.stroke(envelopeBottom, with: .color(SoundsStyle.ember.opacity(strength)), lineWidth: 1.2)
        }
        .frame(height: 40)
            Text(caption(beats: beats))
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
    }

    private func caption(beats: Double) -> String {
        let rate = SoundsStyle.hertz(tone.beatFrequency)
        return tone.beatFrequency <= 8 ? "One second at \(rate)" : "Eight beats at \(rate), shown slower"
    }

    /// 0...1 loudness over beat phase `p` (one unit per beat).
    private func envelope(at p: Double) -> Double {
        let phase = p - p.rounded(.down)
        switch tone.mode {
        case .binaural, .monaural:
            return 0.12 + 0.88 * abs(cos(phase * .pi))
        case .isochronic:
            let floor = 1 - tone.pulseDepth
            // Soft-edged gate, on for the first half of each beat.
            let edge = 0.08
            let gate: Double
            if phase < edge { gate = phase / edge }
            else if phase < 0.5 { gate = 1 }
            else if phase < 0.5 + edge { gate = 1 - (phase - 0.5) / edge }
            else { gate = 0 }
            return max(0.04, floor + (1 - floor) * gate)
        }
    }
}
