import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SoundsMixesView: View {
    @ObservedObject var sounds: SoundsController

    @State private var newMixName = ""
    @State private var renamingID: UUID?
    @State private var renameText = ""
    @State private var pendingDelete: SoundMix?
    @State private var editingPlaylist: MixPlaylist?
    @State private var pendingPlaylistDelete: MixPlaylist?
    @State private var fileError: String?

    private var favourites: [SoundMix] { sounds.mixes.filter(\.isFavorite) }
    private var presets: [SoundMix] { sounds.mixes.filter { $0.isBuiltIn && !$0.isFavorite } }
    private var ownMixes: [SoundMix] { sounds.mixes.filter { !$0.isBuiltIn && !$0.isFavorite } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                saveCurrent
                    .padding(.bottom, 4)

                mixSection("Favourites", favourites)
                mixSection("Your mixes", ownMixes)
                mixSection("Presets", presets)

                playlistsSection
                    .padding(.top, 8)

                if let fileError {
                    SoundsNoticeBanner(notice: SoundsNotice(kind: .importFailed, message: fileError)) {
                        self.fileError = nil
                    }
                    .padding(.top, 6)
                }

                HStack(spacing: 6) {
                    SoundsQuietButton(title: "Export mixes…", icon: "square.and.arrow.up") { exportMixes() }
                        .disabled(ownMixes.isEmpty && !favourites.contains { !$0.isBuiltIn })
                        .help("Save your mixes to a file")
                    SoundsQuietButton(title: "Import mixes…", icon: "square.and.arrow.down") { importMixes() }
                        .help("Add mixes from a file")
                    Spacer()
                }
                .padding(.top, 10)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 14)
        }
        .confirmationDialog(
            "Delete \u{201C}\(pendingDelete?.name ?? "")\u{201D}?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete mix", role: .destructive) {
                if let id = pendingDelete?.id { sounds.deleteMix(id) }
                pendingDelete = nil
            }
        } message: {
            Text("Playlists that use it will skip it.")
        }
        .confirmationDialog(
            "Delete \u{201C}\(pendingPlaylistDelete?.name ?? "")\u{201D}?",
            isPresented: Binding(get: { pendingPlaylistDelete != nil }, set: { if !$0 { pendingPlaylistDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete playlist", role: .destructive) {
                if let id = pendingPlaylistDelete?.id { sounds.deletePlaylist(id) }
                pendingPlaylistDelete = nil
            }
        } message: {
            Text("The mixes in it stay saved.")
        }
    }

    // MARK: Save

    @ViewBuilder
    private var saveCurrent: some View {
        if sounds.hasAnythingEnabled && sounds.activeMixID == nil {
            HStack(spacing: 6) {
                TextField("Name this mix", text: $newMixName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(SoundsStyle.surface)
                    .clipShape(RoundedRectangle(cornerRadius: SoundsStyle.cornerRadius, style: .continuous))
                    .onSubmit(save)
                    .accessibilityLabel("Name for the current mix")
                Button(action: save) {
                    Text("Save mix")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(trimmedName.isEmpty ? Color.secondary : Color.white)
                        .padding(.horizontal, 12)
                        .frame(height: 28)
                        .background(trimmedName.isEmpty ? SoundsStyle.surfaceStrong : SoundsStyle.ember)
                        .clipShape(RoundedRectangle(cornerRadius: SoundsStyle.cornerRadius, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(trimmedName.isEmpty)
                .help("Save the sounds and tone playing now")
            }
        } else if !sounds.hasAnythingEnabled {
            Text("Turn on a few sounds in the mixer, then save them here as a mix.")
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var trimmedName: String { newMixName.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func save() {
        guard !trimmedName.isEmpty else { return }
        sounds.saveCurrentMix(named: trimmedName)
        newMixName = ""
    }

    // MARK: Mixes

    @ViewBuilder
    private func mixSection(_ title: String, _ mixes: [SoundMix]) -> some View {
        if !mixes.isEmpty {
            SoundsSectionLabel(title: title)
                .padding(.top, 8)
            ForEach(mixes) { mix in
                mixRow(mix)
            }
        }
    }

    private func mixRow(_ mix: SoundMix) -> some View {
        let isActive = sounds.activeMixID == mix.id
        return HStack(spacing: 8) {
            Button {
                sounds.toggleFavorite(mix.id)
            } label: {
                Image(systemName: mix.isFavorite ? "star.fill" : "star")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(mix.isFavorite ? SoundsStyle.emberText : Color.secondary.opacity(0.7))
                    .frame(width: 24, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(mix.isFavorite ? "Remove from favourites" : "Add to favourites")
            .accessibilityLabel(mix.isFavorite ? "Remove \(mix.name) from favourites" : "Add \(mix.name) to favourites")

            if renamingID == mix.id {
                TextField("Mix name", text: $renameText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
                    .padding(.horizontal, 8)
                    .frame(height: 26)
                    .background(SoundsStyle.surfaceStrong)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .onSubmit { commitRename(mix.id) }
                    .onExitCommand { renamingID = nil }
                Button("Done") { commitRename(mix.id) }
                    .controlSize(.small)
            } else {
                Button {
                    sounds.applyMix(mix.id)
                } label: {
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(mix.name)
                                .font(.system(size: 12.5, weight: isActive ? .semibold : .regular))
                                .foregroundStyle(Color.primary)
                                .lineLimit(1)
                            MixIngredients(mix: mix, catalog: sounds.catalog)
                        }
                        Spacer(minLength: 4)
                        if isActive {
                            Image(systemName: sounds.isPlaying ? "waveform" : "pause.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(SoundsStyle.emberText)
                                .accessibilityLabel(sounds.isPlaying ? "Playing" : "Paused")
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Play \(mix.name)")

                if !mix.isBuiltIn {
                    Menu {
                        Button("Rename") {
                            renameText = mix.name
                            renamingID = mix.id
                        }
                        Button("Delete…", role: .destructive) { pendingDelete = mix }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .frame(width: 24, height: 24)
                    .accessibilityLabel("More for \(mix.name)")
                }
            }
        }
        .padding(.vertical, 3)
        .padding(.trailing, 6)
        .background(isActive ? SoundsStyle.ember.opacity(0.12) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: SoundsStyle.cornerRadius, style: .continuous))
    }

    private func commitRename(_ id: UUID) {
        let name = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { sounds.renameMix(id, to: name) }
        renamingID = nil
    }

    // MARK: Playlists

    @ViewBuilder
    private var playlistsSection: some View {
        HStack {
            SoundsSectionLabel(title: "Playlists")
            if editingPlaylist == nil {
                SoundsQuietButton(title: "New playlist", icon: "plus") {
                    editingPlaylist = MixPlaylist(name: "", mixIDs: [])
                }
                .disabled(sounds.mixes.count < 2)
                .opacity(sounds.mixes.count < 2 ? 0.4 : 1)
                .help("Move through several mixes on a schedule")
            }
        }

        if let draft = editingPlaylist {
            PlaylistEditor(
                draft: draft,
                mixes: sounds.mixes,
                isNew: !sounds.playlists.contains { $0.id == draft.id },
                onCancel: { editingPlaylist = nil },
                onSave: { playlist in
                    if sounds.playlists.contains(where: { $0.id == playlist.id }) {
                        sounds.updatePlaylist(playlist)
                    } else {
                        var created = sounds.createPlaylist(named: playlist.name, mixIDs: playlist.mixIDs)
                        created.interval = playlist.interval
                        created.isShuffled = playlist.isShuffled
                        sounds.updatePlaylist(created)
                    }
                    editingPlaylist = nil
                }
            )
        }

        if sounds.playlists.isEmpty && editingPlaylist == nil {
            Text(sounds.mixes.count < 2
                 ? "Save two or more mixes to build a playlist."
                 : "A playlist changes mix every few minutes, crossfading as it goes.")
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }

        ForEach(sounds.playlists) { playlist in
            playlistRow(playlist)
        }
    }

    private func playlistRow(_ playlist: MixPlaylist) -> some View {
        let isActive = sounds.activePlaylistID == playlist.id
        return HStack(spacing: 8) {
            SoundsIconButton(
                icon: isActive ? "stop.fill" : "play.fill",
                label: isActive ? "Stop \(playlist.name)" : "Start \(playlist.name)",
                isOn: isActive,
                size: 24
            ) {
                isActive ? sounds.stopPlaylist() : sounds.startPlaylist(playlist.id)
            }
            .disabled(playlist.mixIDs.isEmpty)

            VStack(alignment: .leading, spacing: 2) {
                Text(playlist.name)
                    .font(.system(size: 12.5, weight: isActive ? .semibold : .regular))
                    .lineLimit(1)
                Text(playlistDetail(playlist, isActive: isActive))
                    .font(.system(size: 10.5))
                    .foregroundStyle(isActive ? SoundsStyle.emberText : Color.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            if isActive {
                SoundsIconButton(icon: "forward.fill", label: "Next mix", size: 24) {
                    sounds.skipToNextInPlaylist()
                }
            }
            if !playlist.isBuiltIn {
                Menu {
                    Button("Edit") { editingPlaylist = playlist }
                    Button("Delete…", role: .destructive) { pendingPlaylistDelete = playlist }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .frame(width: 24, height: 24)
                .accessibilityLabel("More for \(playlist.name)")
            }
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 4)
        .background(isActive ? SoundsStyle.ember.opacity(0.12) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: SoundsStyle.cornerRadius, style: .continuous))
    }

    private func playlistDetail(_ playlist: MixPlaylist, isActive: Bool) -> String {
        if isActive, let next = sounds.playlistNextChangeIn {
            return "Next mix in \(SoundsStyle.remaining(next))"
        }
        let count = playlist.mixIDs.count
        var text = "\(count) mix\(count == 1 ? "" : "es"), every \(Int(playlist.interval / 60)) min"
        if playlist.isShuffled { text += ", shuffled" }
        return text
    }

    // MARK: Files

    private func exportMixes() {
        let panel = NSSavePanel()
        panel.title = "Export mixes"
        panel.nameFieldStringValue = "Firehawk mixes.json"
        panel.allowedContentTypes = [.json]
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try sounds.exportMixes(to: url)
            fileError = nil
        } catch {
            fileError = "Couldn't save the file. Choose a folder you can write to and try again."
        }
    }

    private func importMixes() {
        let panel = NSOpenPanel()
        panel.title = "Import mixes"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try sounds.importMixes(from: url)
            fileError = nil
        } catch {
            fileError = "That file isn't a Firehawk mixes export. Pick a .json file saved with Export mixes."
        }
    }
}

/// Tiny symbol strip showing what's in a mix.
private struct MixIngredients: View {
    let mix: SoundMix
    let catalog: [SoundDescriptor]

    var body: some View {
        let symbols = catalog.filter { mix.layers[$0.id]?.isActive == true }.map(\.symbolName)
        HStack(spacing: 5) {
            ForEach(Array(symbols.prefix(6).enumerated()), id: \.offset) { _, symbol in
                Image(systemName: SoundsStyle.symbol(symbol))
                    .font(.system(size: 9.5))
            }
            if symbols.count > 6 {
                Text("+\(symbols.count - 6)").font(.system(size: 9.5))
            }
            if let tone = mix.tone, tone.isEnabled {
                Text("\(tone.mode.title) \(SoundsStyle.hertz(tone.beatFrequency))")
                    .font(SoundsStyle.number(9.5, weight: .regular))
            }
        }
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        let names = catalog.filter { mix.layers[$0.id]?.isActive == true }.map(\.name)
        var text = names.joined(separator: ", ")
        if let tone = mix.tone, tone.isEnabled { text += (text.isEmpty ? "" : ", ") + "\(tone.mode.title) tone" }
        return text
    }
}

/// Inline create/edit form for a playlist.
private struct PlaylistEditor: View {
    @State var draft: MixPlaylist
    let mixes: [SoundMix]
    let isNew: Bool
    let onCancel: () -> Void
    let onSave: (MixPlaylist) -> Void

    private var canSave: Bool {
        !draft.name.trimmingCharacters(in: .whitespaces).isEmpty && !draft.mixIDs.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Playlist name", text: $draft.name)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
                .padding(.horizontal, 8)
                .frame(height: 26)
                .background(SoundsStyle.surfaceStrong)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            Text("Mixes, in play order")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                ForEach(mixes) { mix in
                    let position = draft.mixIDs.firstIndex(of: mix.id)
                    Button {
                        if let position { draft.mixIDs.remove(at: position) } else { draft.mixIDs.append(mix.id) }
                    } label: {
                        HStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(position == nil ? SoundsStyle.surfaceStrong : SoundsStyle.ember)
                                if let position {
                                    Text("\(position + 1)")
                                        .font(SoundsStyle.number(10, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }
                            .frame(width: 18, height: 18)
                            Text(mix.name)
                                .font(.system(size: 12))
                            Spacer()
                        }
                        .frame(minHeight: 24)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(mix.name)
                    .accessibilityValue(position.map { "Number \($0 + 1) in playlist" } ?? "Not in playlist")
                }
            }

            HStack(spacing: 12) {
                Picker("Change every", selection: $draft.interval) {
                    ForEach(MixPlaylist.intervalChoices, id: \.self) { interval in
                        Text("\(Int(interval / 60)) min").tag(interval)
                    }
                }
                .pickerStyle(.menu)
                .controlSize(.small)
                .fixedSize()
                Toggle("Shuffle", isOn: $draft.isShuffled)
                    .toggleStyle(.checkbox)
                    .controlSize(.small)
            }
            .font(.system(size: 11.5))

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .controlSize(.small)
                Button(isNew ? "Create playlist" : "Save playlist") {
                    var final = draft
                    final.name = final.name.trimmingCharacters(in: .whitespaces)
                    onSave(final)
                }
                .controlSize(.small)
                .buttonStyle(.borderedProminent)
                .tint(SoundsStyle.ember)
                .disabled(!canSave)
            }
        }
        .padding(10)
        .background(SoundsStyle.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
