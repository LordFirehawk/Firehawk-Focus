# Sounds backend handoff

Current state: 26 recordings with lazy loading. See the final section for the current design, measurements and verification. Earlier sections retain the acquisition history.

Engine and state implementation are ready for review. The recording library contains eleven audition recordings, including five additions documented in SOURCES-SHORTLIST.md and CREDITS.md. The exact preferred Light Rain 167034 and fire_crackling 263864 recordings remain unavailable. No Freesound requests were made during this acquisition pass. No Homebrew tools were installed.

## Changes

- Added `Sources/FirehawkDSP/{FirehawkDSP.c,include/FirehawkDSP.h}`: allocation-free render path, atomic control parameters, stereo PCM looping, white/pink/brown noise, binaural/monaural/isochronic tones, gain ramps, oscillation, and output saturation with headroom.
- Added `Audio/SoundsAudioEngine.swift`; replaced `Audio/SoundsController.swift` internals. `SoundsModels.swift` and all existing controller names/signatures remain compatible.
- Added six CAF recordings and `Resources/Ambience/catalog.json`, provenance in `CREDITS.md`, and reproducible acquisition/preparation/inspection/benchmark scripts under `scripts/audio/`.
- Added `Tests/FirehawkFocusTests/SoundsTests.swift`. Other agent test files are not ours.
- Updated `Package.swift` for DSP dependencies/resources. Added only startup creation and termination shutdown in the already-modified `App.swift`. Removed the redundant legacy alarm-sound copy block from the already-modified `install.sh`; the SwiftPM resource bundle carries Sounds and Ambience once.
- No Views edits, no commits, and no timer alarm changes.

Controller additions: optional `storageURL`, `enableAudio`, and `catalogOverride` initializer parameters; `decodedAudioBytes`; `persistNow()`; `shutdown()`; `advanceTime(by:)`. Existing `init()` still works. The new engine/catalog/DSP types are internal implementation details. No new notice kinds.

## UI behavior

Launch restores settings paused. Activating a layer, enabling a tone, applying a mix, random mix, and starting a playlist are explicit playback actions. Manual pause prevents playlist skip from resuming audio. Mute silences output while progression continues; pause freezes playlist/stop-timer countdown. Oscillation never changes the saved slider value. `liveLevel` returns effective perceptually scaled gain including oscillation, master, mute, and timer fade, without publishing frame-level state.

Slider ramps are 40 ms; master play/pause fades 300 ms; mix gain transitions are three seconds. The engine pauses after the pause fade and starts again only on an explicit playback action. Sleep and output configuration/default-device changes stop Sounds and raise `.devicePaused`; there is no automatic recovery playback. Route identification uses headphone data-source code plus Bluetooth transport as a best-effort heuristic, so a Bluetooth speaker may be classified as headphones.

State is debounced to `Application Support/FirehawkFocus/sounds.json`, separate from timer configuration/history. Five built-in mixes and a built-in playlist reference generated or bundled sounds. Imports are bounded, validated, receive fresh IDs, and cannot inject built-in status. Missing/failed mix assets leave the current mix intact. The app loads at most sixteen recordings of at most 60 seconds each before starting the render graph.

## Assets

See [CREDITS.md](CREDITS.md) for individual source links, licenses, exact derivative hashes, trims, and measurements. Five recordings are CC0: wind, pine branches, birds, fan, and stream. Lisa Redfern crickets are Public Domain. Inputs are pinned full-length AAC derivatives from Blankie's public repository, not Freesound previews and not original masters. They have not been approved by listening. Prepared delivery is stereo 44.1 kHz PCM16 CAF with equal-power overlap loops. The original six are 38 seconds each. New loops are 38 seconds for rain, thunder and dawn chorus, 22 seconds for fireplace, and 8 seconds for tree frogs. All measure -23 dBFS RMS; sample peaks range from -9.54 to -6.08 dBFS. Peak reduction is documented per asset. RMS matching is not LUFS normalization.

Alternative rain and fireplace, NPS thunder, Yellowstone dawn chorus and Everglades tree frogs are bundled. Cafe remains unfilled because the checked candidate contains conversation. Rejected ocean, forest, and café recordings were not used. The bundled forest and insects are alternative sources, not the unacquired Fester993/OwlStorm leads.

## Verification and measurements

Run from repository root, or omit `--package-path` from `platforms/macos`:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build --package-path platforms/macos --scratch-path /tmp/firehawk-backend-build
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path platforms/macos --scratch-path /tmp/firehawk-backend-build
FIREHAWK_AUDIO_SMOKE=1 DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path platforms/macos --scratch-path /tmp/firehawk-backend-build --filter SoundsHardwareSmokeTests
node --test
```

Results on 2026-10-26: build passed; full Swift suite 13 tests, 11 passed and 2 opt-in UI/hardware tests skipped, zero failures. The hardware test passed separately with two simultaneous generated layers. Node suite passed. DSP tests check tone frequencies, noise normalization/limiting, loop continuity, ramps, oscillation, and actual bundled-file seams/peaks/frame counts. Controller tests check the layer limit, mix export/import/persistence, restoring paused, playlist pause/mute semantics, and stop-timer completion. A packaged debug app launched for two seconds without crashing. Its only log was a macOS sandbox-extension diagnostic; the process remained alive. Existing running app was left alone.

Measured with optimized offline rendering, excluding hardware/UI overhead:

| Scenario | DSP storage | Process peak RSS | CPU seconds per 60 seconds audio | One core |
| --- | ---: | ---: | ---: | ---: |
| Current six recordings + pink + brown + binaural tone | 76.72 MiB | 101.66 MiB | 0.496 | 0.83% |
| Synthetic eight 60-second recordings + tone | 161.50 MiB | 173.52 MiB | 0.556 | 0.93% |

Reproducible benchmark commands are in the headers of `scripts/audio/benchmark.c` and `benchmark-library.swift`. Real playback device changes, sleep/wake behavior, subjective loop quality, and extended listening still need manual confirmation.

Ambience logical size is 40,245,971 bytes, about 38.38 MiB. The assembled debug smoke app is 48,526,024 bytes, about 46.28 MiB, with exactly one Ambience directory. No installed user app was replaced. The installer change and the equivalent smoke bundle layout were inspected; the installer itself was not run.

## Expanded library verification, 2026-10-26

Five additions bring the catalog to eleven recordings. The loader cap is sixteen, bounded to 60 seconds per recording and 19 DSP slots including generated noises. Worst-case sample storage is 338,688,000 bytes, about 323.00 MiB. Actual decoded samples occupy 131,241,600 bytes; including DSP state the asset test measures 131,247,712 bytes, about 125.17 MiB. This is allocation size, not process RSS.

The required Swift test command passed with 14 tests, 12 passed and 2 opt-in hardware/snapshot tests skipped, zero failures. The asset test checks every recording, including the eleventh entry, engine decoding, finite samples, RMS, peak headroom, duration, format, unique files and loop seams. `node --test test/model.test.js` passed, one test. No Views files were edited by the acquisition pass.

Current Ambience size is 65,670,084 bytes, about 62.63 MiB, with eleven CAF files and one catalog. Each recording has one source resource copy. The five un-looped AAC selections are outside the app under `~/FirehawkAudioWork/audition/`. Earlier six-recording sizes and benchmarks above describe the initial implementation and are retained as historical measurements. No new CPU/RSS benchmark or hardware listening approval is claimed.

## Train, beach and gull additions, 2026-10-26

Added three separate recording layers, bringing the catalog to fourteen, within the sixteen-recording cap:

- `train`, Train on tracks: Ural-66's CC0 in-carriage wheel recording from Wikimedia Commons, using its pinned MP3 transcode. Seconds 45 to 105 produce a 58-second loop.
- `beach-waves`, Calm beach waves: Luftrum's CC BY 4.0 stony-shore recording via the pinned Blankie AAC derivative, with complete attribution and edit notice. Seconds 20 to 80 produce a 58-second loop. Rejected Rmutt 156598 is not used.
- `seagulls`, Seagulls: H. Lentfer / NPS, Shoreline Rhapsody, Public Domain. Seconds 48 to 108 produce a 59-second loop. This includes gentle water underneath and other coastal wildlife in the source; it is independently mixed from beach waves.

Farm remains unfilled. The checked Public Domain farm/chicken recordings are only 5 to 17 seconds, and a longer hungry-goat recording does not establish calm farmyard ambience. Candidate details, rights evidence and rejection reasons are in SOURCES-SHORTLIST.md.

Added `SoundCategory.travel`, title Travel, without changing existing raw values. Views enumerate categories dynamically and required no edits. Symbols `tram.fill`, `water.waves` and `bird` were checked against Apple's installed public CoreGlyphs availability metadata, all available on macOS 14. Asset tests resolve every symbol through AppKit.

Extended `scripts/audio/library-additions.json` and reused `prepare-library.py` / `prepare.swift`. All fourteen inputs were cached during the preparation run, so it made no network requests. The source hashes, delivery hashes, edits, licensing and levels are in CREDITS.md. New loops measure -23 dBFS RMS with peaks of -8.82, -6.79 and -6.21 dBFS respectively. Train uses no peak reduction; waves and gulls use the existing tanh knee. New un-looped AAC selections are in `~/FirehawkAudioWork/audition/`.

This agent session did not perform a listening audition. Source transcripts, spectral inspection, level measurements and sample-continuity tests support selection but do not establish subjective gentleness, absence of distracting sounds, intact animal calls or unobtrusive repetition. These remain audition assets.

Required verification passed:

- From `platforms/macos`, `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --scratch-path /tmp/firehawk-backend-build`: 14 tests, 12 passed, 2 opt-in hardware/snapshot skips, zero failures. All fourteen recordings decode, meet levels/headroom/format/duration/seam checks, and reach the controller.
- `node --test test/model.test.js`: one test passed.

Current Ambience logical size is 96,553,717 bytes, about 92.08 MiB. Decoded samples occupy 192,981,600 bytes. The asset test measures 192,987,712 bytes including DSP state, about 184.05 MiB, an increase of 61,740,000 bytes or 58.88 MiB. This is allocated decoded storage, not process RSS. No new CPU or hardware benchmark is claimed.

No Views edits and no commits. Zero Freesound requests; no blocked or rate-limited sites. Acquisition accounting and limitations are in SOURCES-SHORTLIST.md.

## Lazy loading and six additions, 2026-10-26

This section supersedes the historical eager-loading and sixteen-recording limits
above. The catalog now contains **20 recordings** plus the three generated noises.
No Views files were edited and no commit was made by this implementation pass.

### Buffer ownership and loading

`SoundsAudioEngine` constructs the graph without decoding any recording. The
controller supplies desired active IDs; a serial background queue decodes only
requested recordings and creates immutable C-owned buffers. Restored settings
stay paused and unloaded until an explicit playback action. Applying a mix or
playlist requests its recordings immediately. A pending request is shared by
rapid off/on toggles. An off state at completion discards the buffer; on state
publishes it and starts the normal fade, retaining the three-second mix fade
when applicable. Completion never starts the audio graph, so manual pause wins.
A failed load marks only that recording unavailable, deactivates it and raises
`.loadFailed`; remaining sounds continue. If nothing remains enabled, playback
pauses.

The C DSP supports 256 slots, replacing the old 32-slot DSP limit and removing
the controller's 16-entry truncation. Each render callback increments a lock-free
reader counter, snapshots atomic buffer pointers on its stack, renders, then
decrements the counter. The single main-thread writer exchanges pointers and
links old buffers into a retirement list. It reclaims them only after observing
zero readers. Sequentially consistent ordering prevents any later reader from
acquiring an old pointer. No allocation, free, mutex, or Swift buffer ownership
operation occurs in render. Compile-time assertions require lock-free pointer,
integer and double atomics on the build target.

Inactive recordings retain a 33-second grace period, covering the longest fade
plus about 30 seconds. If more than eight are cached, inactive clips older than
3.1 seconds are evicted first. The controller's existing 100 ms timer collects
retired buffers even while paused. The active set is never evicted. Rapid mix
changes can temporarily retain outgoing buffers during their fades; this is a
steady-state bound, not a promise that transient process RSS never exceeds eight
clips. Serial decoding limits temporary AVFoundation/C-copy storage to one
recording at a time. Allocator retention also means freed PCM does not guarantee
an immediate equal drop in RSS.

### Measurements

Measured on this Mac in debug builds, with the prepared assets already in the
filesystem cache. Reproduction command is in `scripts/audio/README.md`.

| Scenario | Measurement |
| --- | ---: |
| Packaged full app, 20-recording catalog, paused launch after 2 s | 87,920 KiB RSS = 85.86 MiB |
| Fresh engine test process before loading | 31,784,960 bytes RSS = 30.31 MiB |
| Same fresh process, eight recordings plus tone, offline render | 134,414,336 bytes RSS = 128.19 MiB |
| Eight selected recordings, decoded PCM plus DSP state | 101,649,648 bytes = 96.94 MiB |
| Initial recording PCM at launch | 0 bytes; DSP state alone is 43,248 bytes |
| First nonzero 512-frame offline block after activation | 21.3 ms |

The eight-layer measurement includes the first eight catalog recordings and an
enabled binaural tone. It is the engine test process, **not full-app UI RSS**.
The latency includes asynchronous decode and the benchmark's polling granularity;
it is not a measurement of device startup, speaker latency, or human perception.
Other passes measured roughly 10–37 ms to that block. The eight longest current
recordings require 152,903,520 PCM bytes, about 145.82 MiB, plus DSP state.
Decoding all twenty would require 301,785,120 PCM bytes, about 287.80 MiB, and no
longer occurs at launch.

### Assets and verification

Added Rain on a tent, Cabin hum, Wind chimes, Clock ticking, Typing and turning
pages, and Walking through snow. All new loops last 50–52 seconds. The clock,
keyboard/paper and snow layers are documented montages. Clock events use an
exact 14,112-frame grid, including the loop seam. Every output measures -23 dBFS
RMS with at least 6 dB sample-peak headroom. Typing and snow use a 3× RMS tanh knee so their event dynamics do not force lower RMS.
There are no new categories; the original seven raw values remain intact. All
symbols support macOS 14 according to installed CoreGlyphs availability metadata.
No CC BY-SA recording was added. CREDITS.md has every creator, source, licence,
download date, input hash, delivery hash, and edit notice.

The mandatory Swift command from `platforms/macos` passed **22 tests: 20 passed,
2 opt-in hardware/snapshot skips, zero failures**. Tests cover all twenty assets,
clock spacing across the seam, out-of-order completions, off/on/off request
sharing, manual pause during pending work, `.loadFailed` reporting, preserving
another recording after failure, concurrent pointer publication/retirement,
loading/retiring every catalog entry, and reducing a rapid catalog sweep to eight
active cached recordings after the fade. A separate AddressSanitizer C stress
run published/retired 20,000 buffers concurrently with 4,000 render callbacks and
returned storage to baseline without sanitizer errors. The required
`node --test test/model.test.js` passed, one test. Listening approval and actual
speaker-latency measurement remain outstanding; no subjective audition is claimed.

Ambience logical size is **150,984,012 bytes = 143.99 MiB**, including its catalog.
It remains below 250 MiB, so no delivery-format change is proposed or applied.
Un-looped AAC auditions are in `~/FirehawkAudioWork/audition/`.

Seven requested slots remain unfilled: tin-roof rain, library/reading room,
distant city at night, cat purring, rowing boat, campfire at night, and farm.
SOURCES-SHORTLIST.md records per-candidate reasons. The farm retry checked
combining stephan's two compatible public-domain recordings, but their combined
24.446 seconds still falls short before crossfades. Wikimedia media returned
HTTP 429 on the cat-purr request; all Wikimedia network access stopped with no
retry or mirror switch. No Freesound page, API, or CDN request was made.

## Requested listening-feedback batch, 2026-10-27

Six recordings bring the catalog to 26: Campfire, Big fire, Waterfall, Close
thunder, Thunderstorm and Clock. The original `clock-ticking` entry now displays
Fast clock, retaining its id, CAF and 0.32 s grid. Existing saved mixes continue
to resolve it. Rolling thunder and the original Fireplace remain unchanged.

Campfire uses Glaneur de sons' CC BY 3.0 small summer-camp fire. Its asset is
RMS-matched like the rest of the library; `gainDb: -4.5` makes playback softer by
design. Big fire is Kimmo Kestinen / Work With Sounds / Werstas' real Midsummer
bonfire, CC BY 4.0. Waterfall uses Daniel Simion's CC BY 3.0 Large Waterfall.
Close thunder retains several different clap groups from Mike Koenig's CC BY
3.0 Elaborate Thunder in a 52 s loop. Thunderstorm is explicitly a composite of
Mike Koenig's CC BY 3.0 2 Minute Storm and felix.blume's existing CC0 wind
recording, with wind RMS 8 dB below storm RMS before final processing. Every
source and prior editor appears in structured catalog fields and CREDITS.md.
No new licence enum or category was needed.

Clock uses one clean 180 ms tick from KevanGC's Public Domain original, repeated
50 times on an exact 44,100-frame grid. The initial varied-tick edit failed the
new measured peak-spacing test after peak reduction. Repeating a single intact
tick fixes the waveform timing and avoids retaining a partial neighbouring tick.
It is a single tick timbre, without artificial alternating pitch. The test
measures every channel's peaks at 1.000 s ±3 ms, including the last-to-first gap.

New loops last 40.5–58 s. All measure -23.00 dBFS RMS; sample peaks range from
-10.08 to -6.11 dBFS. Campfire and Clock use a 3× RMS soft knee; Thunderstorm
uses 5×; the remaining defaults are 6×, applied only above a 17 dB crest factor.
Waterfall needs no peak reduction. No delivery format was changed.

The four remaining slots are deliberately absent. The checked fountain source
is 21.9 s; the full café WAV is 16.667 s, and Blankie/Blanket use a shorter edit
of that same source; the wash-cycle lead is 27 s and tagged “spin”; the frog
leads are either faint under chirping, too short, or BY-SA. Low indistinct café
conversation is now acceptable and is not itself a rejection reason. The longer
Commons restaurant recording is BY-SA and includes toddler cries. See the
requested-batch shortlist for up to three candidates per slot and rights checks.

`python3 -I scripts/audio/prepare-requested.py` rebuilds this batch offline from
`library-requested.json`, preserves existing structured attributions, reapplies
the rename and writes provenance idempotently. Source audio/page evidence stays
in `~/FirehawkAudioWork/raw/<source>/<id>/`. Un-looped AAC selections are in
`~/FirehawkAudioWork/audition/{campfire,bonfire,waterfall,thunder-close,thunderstorm,clock}.m4a`.
For Clock and Thunderstorm, these are single passes of their edited sequence or
composite. Auditions use the prepared asset level, before catalog gain.

Required verification passed:

- From `platforms/macos`, `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --scratch-path /tmp/firehawk-backend-build`: 33 tests, 30 passed, three opt-in hardware/snapshot skips, zero failures.
- From repo root, `node --test test/model.test.js`: one passed, zero failures.
- Asset tests inspect all 26 CAF files for format, duration, finite samples,
  RMS, headroom, seam continuity, unique resources and resolvable SF Symbols.
  Attribution tests cover all new sources and the two-source storm composite.

Ambience logical size is **204,557,752 bytes = 195.08 MiB**, including catalog.
It is below 250 MiB; no delivery-format change is proposed. No Views files were
edited and no commit was created. Human listening review of crackle balance,
background distractions, croak character and repeated seams remains outstanding;
automated checks do not certify subjective quality.

## User-approved café/frogs and ALAC library, 2026-10-27

Added Café (`cafe`, Berwitz 263584, CC0), replaced Croaky frogs (`bullfrogs`) with
reinsamba 58236 (CC BY 4.0, `gainDb: -4.0`), and added Night frogs (`night-frogs`,
mycompasstv 462889, CC0). Catalog is **34** recordings. Rejected madamdata 750818
was removed. All Ambience assets were Apple Lossless CAF at the end of that pass;
AAC cafeteria was re-encoded from its lossless master. `verify-alac-lossless.py`
reported 0 differing samples vs PCM. Ambience size then: **158,649,370 bytes
(151.300 MiB)** after ALAC (was 260,976,642 / 248.887 MiB at session start).
Nine Freesound requests. No Views edits; no commit.

Network log `~/FirehawkAudioWork/requests-requested.jsonl` records 36 successful
requests: SoundBible 20, Commons 12, Wikimedia media 2, NPS 2. GitHub/raw and
OpenGameArt direct requests were zero; cached mirror metadata was used.
Twenty-one index search queries supplied leads. Freesound pages/API/CDN requests
were zero. No 403, 429 or captcha occurred and no retry loop was used. One
upload-to-Commons transition had a logged 1.3 s gap, violating the cross-host
Wikimedia pacing requirement; the helper was corrected to share Wikimedia timing
and no further Wikimedia requests were made. All other Wikimedia gaps exceeded
6 s. No downloaded code was executed; all Python readers used `python3 -I`.

## FLAC delivery for cross-platform sharing, 2026-10-27

Converted all 34 Ambience loops from Apple Lossless CAF to FLAC (compression
level 8, same 16-bit / 44.1 kHz / stereo). Encoding used `afconvert` to PCM16 WAV
then Homebrew `flac -8`. Staged under `~/FirehawkAudioWork/flac-staging/`, verified
with `scripts/audio/verify-lossless.py` against the ALAC CAF set (**0 differing
samples, identical frame counts for all 34**), then swapped into
`Resources/Ambience/` with an updated `catalog.json`. Ambience size after FLAC:
**154,026,683 bytes (146.891 MiB)** (was 158,649,370 / 151.300 MiB ALAC). The
macOS engine continues to load via `AVAudioFile` (CoreAudio FLAC since macOS
10.13; app targets 14). Future prepare scripts write FLAC delivery through
`encode_flac.py`. The Linux port is expected to play these with Qt Multimedia's
FFmpeg backend (expected, not tested). No Views edits; no commit.
