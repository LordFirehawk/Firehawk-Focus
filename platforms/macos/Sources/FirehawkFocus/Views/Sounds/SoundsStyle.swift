import AppKit
import SwiftUI

/// Shared look for the Sounds tab: one ember accent, quiet surfaces, rounded digits for numbers.
enum SoundsStyle {
    /// Fill colour for active levels and the play control.
    static let ember = Color.orange
    /// Ember for text and small glyphs; darker in light mode so it stays readable.
    static let emberText = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 1.0, green: 0.70, blue: 0.25, alpha: 1)
            : NSColor(srgbRed: 0.72, green: 0.31, blue: 0.0, alpha: 1)
    })
    /// Level-bar fills. Translucent system orange over a dark surface mixes to brown, so dark mode uses a
    /// redder, more opaque ember and light mode a soft peach. Start and end of the fill gradient, then the
    /// faint "set level" behind a breathing fill.
    static let emberFillStart = dynamic(dark: (0.92, 0.40, 0.10, 0.62), light: (1.0, 0.55, 0.12, 0.30))
    static let emberFillEnd = dynamic(dark: (0.98, 0.45, 0.10, 0.88), light: (1.0, 0.52, 0.08, 0.55))
    static let emberSetLevel = dynamic(dark: (0.95, 0.42, 0.10, 0.24), light: (1.0, 0.55, 0.12, 0.16))

    private static func dynamic(dark: (Double, Double, Double, Double), light: (Double, Double, Double, Double)) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let c = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: c.0, green: c.1, blue: c.2, alpha: c.3)
        })
    }

    static let surface = Color.primary.opacity(0.06)
    static let surfaceStrong = Color.primary.opacity(0.10)

    static let barHeight: CGFloat = 30
    static let iconColumn: CGFloat = 28
    static let cornerRadius: CGFloat = 8

    static func number(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .rounded).monospacedDigit()
    }

    static func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    /// "45 s", "1 min", "2 min 30 s".
    static func duration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        if total < 60 { return "\(total) s" }
        let minutes = total / 60
        let rest = total % 60
        return rest == 0 ? "\(minutes) min" : "\(minutes) min \(rest) s"
    }

    /// Countdown text for timers: whole minutes above a minute, seconds below.
    static func remaining(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.up))
        if total >= 60 { return "\(Int((Double(total) / 60).rounded(.up))) min" }
        return "\(total) s"
    }

    static func hertz(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(value < 10 ? 1 : 0)))) Hz"
    }

    /// Falls back to a generic glyph when the catalog names a symbol this macOS doesn't have.
    static func symbol(_ name: String) -> String {
        NSImage(systemSymbolName: name, accessibilityDescription: nil) == nil ? "speaker.wave.2" : name
    }
}

/// Small borderless text button used for secondary actions (Random mix, Clear all, Export…).
struct SoundsQuietButton: View {
    let title: String
    let icon: String
    var role: ButtonRole? = nil
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 11.5, weight: .medium))
                .labelStyle(.titleAndIcon)
                .padding(.horizontal, 9)
                .frame(minHeight: 24)
                .background(SoundsStyle.surface)
                .clipShape(Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// Round 24–28 pt icon button with a tinted surface.
struct SoundsIconButton: View {
    let icon: String
    let label: String
    var isOn = false
    var size: CGFloat = 26
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.46, weight: .semibold))
                .foregroundStyle(isOn ? SoundsStyle.emberText : Color.secondary)
                .frame(width: size, height: size)
                .background(isOn ? SoundsStyle.ember.opacity(0.18) : SoundsStyle.surface)
                .clipShape(Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
    }
}

/// Section label inside a scrolling Sounds pane, matching Settings' caption headers.
struct SoundsSectionLabel: View {
    let title: String
    var trailing: String? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .accessibilityAddTraits(.isHeader)
    }
}

/// Labelled native slider with a rounded numeric readout on the right.
struct SoundsValueSlider: View {
    let title: String
    let valueText: String
    @Binding var value: Double
    var range: ClosedRange<Double> = 0...1

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 58, alignment: .leading)
            Slider(value: $value, in: range)
                .controlSize(.small)
                .tint(SoundsStyle.ember)
                .accessibilityLabel(title)
                .accessibilityValue(valueText)
            Text(valueText)
                .font(SoundsStyle.number(11.5))
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .trailing)
        }
    }
}
