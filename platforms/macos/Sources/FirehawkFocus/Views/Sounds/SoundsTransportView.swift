import SwiftUI

/// Fixed top of the Sounds tab: what's playing, play/pause, master level, mute and the stop timer.
struct SoundsTransportView: View {
    @ObservedObject var sounds: SoundsController
    @State private var showsStopTimer = false

    private static let stopChoices: [Int] = [15, 30, 45, 60, 90]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                playButton

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13.5, weight: .semibold))
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .monospacedDigit()
                }
                .accessibilityElement(children: .combine)

                Spacer(minLength: 4)

                if sounds.activePlaylistID != nil {
                    SoundsIconButton(icon: "forward.fill", label: "Next mix in playlist") {
                        sounds.skipToNextInPlaylist()
                    }
                }
                stopTimerButton
                SoundsIconButton(
                    icon: sounds.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                    label: sounds.isMuted ? "Unmute sounds" : "Mute sounds",
                    isOn: sounds.isMuted
                ) {
                    sounds.setMuted(!sounds.isMuted)
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "speaker.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                Slider(value: Binding(get: { sounds.masterVolume }, set: { sounds.setMasterVolume($0) }), in: 0...1)
                    .controlSize(.small)
                    .tint(SoundsStyle.ember)
                    .accessibilityLabel("Master volume")
                    .accessibilityValue(SoundsStyle.percent(sounds.masterVolume))
                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
            .opacity(sounds.isMuted ? 0.45 : 1)

            if showsStopTimer || sounds.stopTimerRemaining != nil {
                stopTimerStrip
                    .transition(.opacity)
            }
        }
    }

    // MARK: Pieces

    private var playButton: some View {
        let enabled = sounds.hasAnythingEnabled
        return Button {
            sounds.togglePlayback()
        } label: {
            Image(systemName: sounds.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 15, weight: .bold))
                .offset(x: sounds.isPlaying ? 0 : 1.5)
                .foregroundStyle(enabled ? Color.white : Color.secondary)
                .frame(width: 40, height: 40)
                .background(enabled ? SoundsStyle.ember : SoundsStyle.surfaceStrong)
                .clipShape(Circle())
                .shadow(color: enabled ? SoundsStyle.ember.opacity(0.35) : .clear, radius: 5, y: 2)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .help(sounds.isPlaying ? "Pause sounds" : "Play sounds")
        .accessibilityLabel(sounds.isPlaying ? "Pause sounds" : "Play sounds")
    }

    private var stopTimerButton: some View {
        SoundsIconButton(
            icon: "moon.zzz.fill",
            label: sounds.stopTimerRemaining == nil ? "Stop after a while" : "Stop timer",
            isOn: sounds.stopTimerRemaining != nil || showsStopTimer
        ) {
            withAnimation(.snappy(duration: 0.2)) { showsStopTimer.toggle() }
        }
    }

    @ViewBuilder
    private var stopTimerStrip: some View {
        HStack(spacing: 6) {
            if let remaining = sounds.stopTimerRemaining {
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(SoundsStyle.emberText)
                Text("Fades out in \(SoundsStyle.remaining(remaining))")
                    .font(.system(size: 11.5, weight: .medium))
                    .monospacedDigit()
                Spacer()
                SoundsQuietButton(title: "Cancel", icon: "xmark") {
                    sounds.cancelStopTimer()
                    withAnimation(.snappy(duration: 0.2)) { showsStopTimer = false }
                }
                .help("Keep playing")
            } else {
                Text("Stop after")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .fixedSize()
                Spacer(minLength: 2)
                ForEach(Self.stopChoices, id: \.self) { minutes in
                    Button {
                        sounds.startStopTimer(duration: TimeInterval(minutes * 60), fadeOut: 30)
                    } label: {
                        Text("\(minutes)m")
                            .font(SoundsStyle.number(11.5))
                            .frame(minWidth: 34, minHeight: 24)
                            .background(SoundsStyle.surface)
                            .clipShape(Capsule())
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("Fade out and stop in \(minutes) minutes")
                    .accessibilityLabel("Stop after \(minutes) minutes")
                }
            }
        }
        .padding(.leading, 10)
        .padding(.trailing, 4)
        .padding(.vertical, 3)
        .background(SoundsStyle.surface)
        .clipShape(RoundedRectangle(cornerRadius: SoundsStyle.cornerRadius, style: .continuous))
    }

    // MARK: Copy

    private var title: String {
        if let id = sounds.activePlaylistID, let playlist = sounds.playlists.first(where: { $0.id == id }) {
            return playlist.name
        }
        if let id = sounds.activeMixID, let mix = sounds.mixes.first(where: { $0.id == id }) {
            return mix.name
        }
        return sounds.hasAnythingEnabled ? "Your mix" : "Nothing playing"
    }

    private var subtitle: String {
        guard sounds.hasAnythingEnabled else { return "Pick a sound below to start" }
        if sounds.isMuted { return "Muted" }
        if let next = sounds.playlistNextChangeIn {
            return sounds.isPlaying ? "Next mix in \(SoundsStyle.remaining(next))" : "Paused"
        }
        var parts: [String] = []
        let count = sounds.activeLayerCount
        if count > 0 { parts.append(count == 1 ? "1 sound" : "\(count) sounds") }
        if sounds.tone.isEnabled { parts.append("\(sounds.tone.mode.title.lowercased()) tone") }
        var text = parts.joined(separator: " and ")
        text = text.prefix(1).uppercased() + text.dropFirst()
        if !sounds.isPlaying {
            text += ", paused"
        }
        return text
    }
}

/// Inline, dismissible message from the engine.
struct SoundsNoticeBanner: View {
    let notice: SoundsNotice
    let onDismiss: () -> Void

    private var icon: String {
        switch notice.kind {
        case .layerLimit: return "square.stack.3d.up.fill"
        case .devicePaused: return "pause.circle.fill"
        case .loadFailed, .importFailed: return "exclamationmark.triangle.fill"
        case .imported: return "checkmark.circle.fill"
        case .headphonesRecommended: return "headphones"
        }
    }

    private var tint: Color {
        switch notice.kind {
        case .imported: return .green
        case .loadFailed, .importFailed: return .red
        default: return SoundsStyle.emberText
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 16)
                .padding(.top, 1)
            Text(notice.message)
                .font(.system(size: 11.5))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Dismiss")
            .accessibilityLabel("Dismiss message")
            .padding(.top, -4)
            .padding(.trailing, -4)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(tint.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: SoundsStyle.cornerRadius, style: .continuous))
        .accessibilityElement(children: .contain)
    }
}
