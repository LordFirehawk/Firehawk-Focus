# Ambient asset preparation

Raw files are untrusted data. Store them under `~/FirehawkAudioWork/raw/<source>/<id>/` and never execute their contents. Run Python readers with `python3 -I`.

The preparation entry point is `python3 -I scripts/audio/prepare-library.py`. It verifies pinned SHA256 values, prepares the original six Blankie derivatives plus the entries in `library-additions.json`, and writes the catalog and credits. Cached inputs avoid network requests. New acquisitions use a browser-style User-Agent, pause about two seconds before requests, and stop on errors without retries. It never requests the Freesound source URLs in the metadata. The original research task prohibited Freesound requests. The separately authorized 2026-10-27 original acquisition and preparation are documented below.

For new recordings:

1. Verify each file's own license and provenance. Record the license evidence URL and input hash. Prefer CC0 or explicit public domain; CC BY needs a complete attribution with creator, title, source URL, license URL and edit notice in both catalog and credits. Reject NC and ND material.
2. Inspect the file with `afinfo` and optionally `inspect.swift`. The latter ranks 40-second windows by peak/RMS ratio; it does not detect speech, music or approve sound quality.
3. Run `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift scripts/audio/prepare.swift INPUT OUTPUT.caf START DURATION OVERLAP [AUDITION.m4a]`. Duration must be more than three and at most 60 seconds; overlap must be positive and less than half the duration. That writes a stereo PCM16 CAF master (kept under `~/FirehawkAudioWork/masters/` by the prepare scripts).
4. Encode delivery with `python3 -I scripts/audio/encode_flac.py MASTER.caf DEST/<id>.flac` (FLAC compression level 8 via Homebrew `flac`). Masters stay outside the repo; Ambience ships only `.flac`. The prepare script joins tail/head with equal-power overlap, so delivered duration is input selection minus overlap. RMS target is -23 dBFS subject to a -6 dBFS sample-peak ceiling. Crest factors above 17 dB receive smooth tanh peak reduction at six times RMS. These are RMS measurements, not LUFS.
5. The optional AAC audition contains the un-looped selected window, resampled and given the same peak processing and gain. Additions write these to `~/FirehawkAudioWork/audition/<id>.m4a` for Finder playback. They are not bundled.
6. Record exact trims, overlap, input and delivery hashes, acquisition date and measurements in `docs/sounds/CREDITS.md`. Keep one FLAC delivery asset per catalog entry in the SwiftPM resource bundle. Verify with `python3 -I scripts/audio/verify-lossless.py DIR_A DIR_B` (bit-identical decoded PCM).
7. Listen to several repeats before approving subjective quality. Automated seam, RMS, peak and format checks cannot establish absence of voices or distracting events.

The catalog loader accepts at most sixteen recordings, each capped at 60 seconds. Together with three generated noises this fits the 32 DSP slots. Worst-case sample storage is 338,688,000 bytes, about 323.00 MiB. Eight simultaneous active layers remains the playback limit. The current fourteen recordings use 192,981,600 bytes of decoded samples; including DSP state the test measured 192,987,712 bytes, about 184.05 MiB. Three additions are train, beach waves and seagulls. Farm remains unfilled because the checked recordings did not meet the calm, varied ambience requirement. All recordings decode before playback.

Run the suite with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path platforms/macos --scratch-path /tmp/firehawk-backend-build`. Asset tests verify the complete catalog reaches the controller, files are unique, every file decodes into the engine, formats and durations match, RMS is matched, peaks have headroom and seams have no exceptional sample step. `benchmark.c` and `benchmark-library.swift` remain available for offline CPU and RSS measurement.

The train uses Wikimedia's MP3 transcode of Ural-66's CC0 carriage recording. Beach waves uses Luftrum's CC BY 4.0 Blankie derivative; seagulls uses the Public Domain NPS Shoreline Rhapsody recording. All three are pinned in `library-additions.json`. Acquisition and selection evidence is in `docs/sounds/SOURCES-SHORTLIST.md`. They have not received a listening audition in this session.

## Lazy library and six more layers

`library-expansion.json` pins the six new layers and every source hash. With the
listed downloads cached under `~/FirehawkAudioWork/raw/`, run:

```sh
python3 -I scripts/audio/prepare-expansion.py
```

This command is offline. It checks hashes, creates the clock, typing/paper and
snow montages, prepares FLAC delivery and AAC auditions, and updates the catalog
and appended credits idempotently. `prepare-library.py` also reapplies this
expansion after rebuilding the original fourteen layers. Do not execute code
from the downloaded archives. Only named audio members are read.

`prepare.swift` accepts optional `peakKneeRMS` after the audition path. The default
is 6; typing/paper and snow use 3 to reach -23 dBFS RMS without exceeding -6 dBFS.
Overlap zero is reserved for event montages with silent, verified seams. The
clock uses 160 recorded ticks at exactly 14,112 frames per tick, including across
the boundary. Its audition is the original uninterrupted recorded run rather
than the retimed delivery. Typing/paper and winter auditions play one montage
once, without a playback loop.

Reproduce cold engine RSS, eight decoded recordings plus a tone, and first
nonzero offline render-block timing in a fresh process:

```sh
cd platforms/macos
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --scratch-path /tmp/firehawk-backend-build --filter SoundsLoadingTests.testEightLayersAndToneBenchmark
```

The benchmark measures the test process and does not measure speaker/device
latency. Full-app launch RSS is measured separately from a temporary packaged
.app, since running the bare executable cannot initialize UserNotifications.

## Requested batch, 2026-10-27

The requested-feedback batch brought the catalog to 26 recordings, loaded lazily. The later Freesound batch is described below. Earlier fourteen-recording
limits above are historical; the eight-active-layer limit remains unchanged.

Run `python3 -I scripts/audio/prepare-requested.py` to rebuild the six requested
additions offline. `library-requested.json` pins every input hash, source,
licence, selection and edit. It preserves existing catalog entries and their
structured attributions, renames `clock-ticking` to Fast clock, and replaces the
six additions and their credits idempotently. Run this after any older rebuild
scripts, which predate the structured attribution catalog. Its Clock sequence
uses exactly 44,100 frames between recorded attacks. Thunderstorm is a credited
storm/wind composite; all other new sources are single recordings. Campfire's
-4.5 dB catalog gain is additional to the prepared -23 dBFS RMS asset level.

New loops last 40.5–58 s. Peak knees are pinned per item: Campfire/Clock use 3×
input RMS, Thunderstorm 5×, others 6×. The knee is applied only above a 17 dB crest
factor. Auditions are un-looped selections, including one pass of each edited
sequence/composite, at the prepared asset level before catalog gain. Audition
files stay outside the repo in `~/FirehawkAudioWork/audition/`.

## Freesound originals acquisition, 2026-10-27

`python3 -I scripts/audio/download.py SOUND_ID` reads `access_token` from
`~/.config/firehawk/freesound-oauth.json`, without logging credentials. An optional
second argument selects another private OAuth JSON file. Originals and API
metadata go to `~/FirehawkAudioWork/raw/freesound/<id>/`, never into the repo.
The licence allowlist accepts only CC0 and CC BY 3.0/4.0, verified from fresh API
metadata before acquiring an original. Transfers stream to a partial file and
are renamed only after completion; original SHA256 and acquisition date are
saved with the private work metadata.

A shared file lock serializes this batch. Its persistent ledger counts all HTTP
requests, including redirects, with at least 3.2 seconds between request starts
and a maximum of 30 requests. There are no automatic retries. Authorization is
sent only to freesound.org. Only original-download HTTP 301/302 redirects to
exactly HTTPS cdn.freesound.org on the default HTTPS port are accepted, without
credentials in the URL. The CDN receives no Authorization header. A redirect may
have an HTML content type; its body is discarded. HTTP 403/429, HTML 200 bodies,
captcha, unrecognized audio signatures and all other redirects stop acquisition.
RIFF/WAVE, FLAC, FORM/AIFF or AIFC, Ogg and ID3/valid MP3 frame signatures are
accepted. Incomplete bodies are discarded. No signed CDN URLs are logged.

The initial attempt stopped after two requests because it rejected the expected
HTML-typed 302 before checking its destination. The corrected task explicitly
authorized resuming that same ledger. The original two requests remain counted.

Run `python3 -I scripts/audio/test-download.py` for offline redirect, header,
block-response and audio-signature regression checks. It makes no HTTP requests.

`python3 -I scripts/audio/prepare-freesound.py` verifies the original SHA256 values
in `library-freesound.json`, checks the projected 250 MiB budget, then prepares
five additions and appends their structured attribution. It retains the existing
rain and fire choices. Light rain is a 26.3198-second user favourite; its prepared
24.319796-second loop is repeated exactly twice for a 48.639592-second delivered
file, with its actual shorter recurrence disclosed in credits. Auditions contain
one un-looped original selection, named by Freesound ID. Only shipped sounds'
preview auditions are removed. Café remains excluded unless a qualifying
45-second music-free and distraction-free segment can be established. Signal
measurements and machine classification do not establish intelligibility or
human listening approval. See the shortlist and credits for selection evidence.


## Cafeteria user-approved long loop

Run `python3 -I scripts/audio/prepare-cafeteria.py` after older batch rebuilds.
`library-cafeteria.json` pins the original, CC0 source, selection and overlap.
The pipeline prepares a PCM master then encodes FLAC level 8 delivery.
The named Cafeteria audition is the un-looped, matched AAC selection for Finder
listening only. Exact decoded length and edge continuity are covered in
SoundsTests; lazy decoding is covered in SoundsLoadingTests.

## User-approved café / frogs and FLAC delivery

```sh
python3 -I scripts/audio/download.py SOUND_ID   # OAuth original; fresh batch ledger
python3 -I scripts/audio/prepare-approved.py    # cafe, bullfrogs replacement, night-frogs
# Whole-library lossless check (pair any two decoded directories by stem):
python3 -I scripts/audio/verify-lossless.py \
  ~/FirehawkAudioWork/masters/pcm-before-alac \
  platforms/macos/Sources/FirehawkFocus/Resources/Ambience
```

`library-approved.json` pins the three listening-approved originals. Delivery for
the whole Ambience library is stereo 44.1 kHz FLAC (compression level 8); requires
Homebrew `flac`. `verify-lossless.py` compares decoded samples bit-for-bit (must
be zero differing samples and identical frame counts). No AAC or CAF remains under
`Resources/Ambience/`. The historical `verify-alac-lossless.py` targeted the prior
ALAC CAF delivery against PCM snapshots.
