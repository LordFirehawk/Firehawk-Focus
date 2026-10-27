#!/usr/bin/env python3
"""Rebuild the audition catalog from pinned source files and publicly redistributed derivatives.
These are not Freesound previews or original masters. Original acquisition remains separate.
"""
import hashlib
import json
import os
import sys
from pathlib import Path
import subprocess
import time
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts/audio'))
from encode_flac import encode_pcm_to_flac  # noqa: E402
WORK = Path.home() / 'FirehawkAudioWork'
DEST = ROOT / 'platforms/macos/Sources/FirehawkFocus/Resources/Ambience'
MASTERS = WORK / 'masters/library'
REVISION = 'a106b8de559344fe3e6dff0a626e5a21a74a344e'
EXPECTED_SHA256 = {'birds': '3443510bccbad7186bb465a5d5455fcb36769dbc695e471b54bbfa47c24bbb71', 'wind': '079211ac8198bef84fadb81a71bda445fdd522677e6eb3150a7eecadbd0cf68a', 'forest': 'b2a71c2f86a642ee2ad649f358fcf5862f0e5b493897e596ab9abe89eb1fef59', 'fan': '6ddeba35366d967900e4f8b1bfd5e0372ffb9259d23bf537b18a65c35c54c209', 'summer-night': '9b930ff82758bc80a6b452444c93d3499a33215f3d99ea480f189f7c2f857bd5', 'stream': '55925d96c53d1b8e53ffa27403e439055851936fce6ea319b8bad30e18b6abf8'}
# id, mirror name, display name, symbol, category, creator, source, license, start
SOUNDS = [
    ('wind', 'wind', 'Wind', 'wind', 'nature', 'felix.blume; edited by Porrumentzio / Blankie', 'https://freesound.org/people/felix.blume/sounds/217506/', 'CC0-1.0', 171),
    ('forest', 'forest', 'Pine branches', 'tree', 'nature', 'sinewave1kHz; redistributed by Blankie', 'https://freesound.org/people/sinewave1kHz/sounds/202989/', 'CC0-1.0', 4),
    ('birds', 'birds', 'Woodland birds', 'bird', 'nature', 'kvgarlic; edited by Porrumentzio / Blankie', 'https://freesound.org/people/kvgarlic/sounds/156826/', 'CC0-1.0', 22),
    ('fan', 'fan', 'Fan', 'fan', 'indoor', 'LilMati; redistributed by Blankie', 'https://freesound.org/people/LilMati/sounds/515859/', 'CC0-1.0', 10),
    ('night-insects', 'summer-night', 'Night crickets', 'moon.stars', 'nature', 'Lisa Redfern; redistributed by Blanket / Blankie', 'https://soundbible.com/2083-Crickets-Chirping-At-Night.html', 'Public Domain', 2),
    ('stream', 'stream', 'Woodland stream', 'drop', 'water', 'gluckose; redistributed by Blanket / Blankie', 'https://freesound.org/people/gluckose/sounds/333987/', 'CC0-1.0', 76),
]
DEST.mkdir(parents=True, exist_ok=True)
catalog = []
credits = ['# Sounds credits', '',
    'Catalog status: six audition assets are bundled. Listening approval is still required. No sound-quality approval is inferred from metadata or automated tests.', '',
    'These inputs are full-length AAC derivatives publicly redistributed by [Blankie](https://blankie.rest/credits/), pinned to revision `' + REVISION + '`. They are not the Freesound online previews. The upstream original masters were not acquired, so original SHA256 values are unavailable. Hashes below identify the exact downloaded derivatives.', '',
    'Source license labels were checked on 2026-10-26. [CC0 terms](https://creativecommons.org/publicdomain/zero/1.0/). Third-party recordings retain their stated licenses and are not relicensed under the repository MIT license.', '',
    'Preparation: stereo 44.1 kHz PCM16 masters encoded to FLAC level 8; 40-second segment; 2-second equal-power tail/head overlap; 38-second delivered loop; RMS target -23 dBFS subject to -6 dBFS peak ceiling. For crest factors above 17 dB, a smooth tanh knee at six times RMS reduces isolated peaks before normalization. RMS measurements are not LUFS. No fade-to-silence is used.', '']
MASTERS.mkdir(parents=True, exist_ok=True)
for sound_id, mirror, name, symbol, category, creator, source, license_name, start in SOUNDS:
    raw = WORK / 'raw' / 'blankie' / mirror
    legacy = WORK / 'raw' / ('blankie-' + mirror) / 'download.m4a'
    if legacy.exists() and not raw.exists():
        raw.mkdir(parents=True)
        legacy.rename(raw / 'download.m4a')
    raw.mkdir(parents=True, exist_ok=True)
    url = f'https://raw.githubusercontent.com/codybrom/blankie/{REVISION}/Blankie/Resources/Sounds/{mirror}.m4a'
    path = raw / 'download.m4a'
    if not path.exists():
        time.sleep(2.1)
        request = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0 FirehawkFocus/1.0 audio research'})
        path.write_bytes(urllib.request.urlopen(request, timeout=90).read())
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    if digest != EXPECTED_SHA256[mirror]:
        raise SystemExit("Downloaded derivative hash mismatch: " + mirror)
    env = dict(os.environ, DEVELOPER_DIR='/Applications/Xcode.app/Contents/Developer')
    pcm = MASTERS / (sound_id + '-pcm.caf')
    result = subprocess.run(['swift', str(ROOT / 'scripts/audio/prepare.swift'), str(path), str(pcm), str(start), '40', '2'], env=env, capture_output=True, text=True, check=True)
    output = DEST / (sound_id + '.flac')
    encode_pcm_to_flac(pcm, output)
    print(sound_id, result.stdout.strip())
    catalog.append(dict(id=sound_id, name=name, symbolName=symbol, category=category, file=output.name, gainDb=0,
                        loopStartSeconds=0, loopEndSeconds=38, credit=creator, sourceURL=source, license=license_name))
    credits += ['## ' + name, '', f'- Creator / prior editors: {creator}', f'- Source: [{name}]({source}); license: {license_name}.',
                f'- Acquisition: 2026-10-26; [downloaded derivative]({url}). Original SHA256: unavailable.',
                f'- Downloaded derivative SHA256: `{digest}`.', f'- Edits: selected {start}–{start+40} seconds of derivative, resampled if needed, overlap-looped and level-matched.',
                '- Measurement: `' + result.stdout.strip() + '`.',
                '- Delivered FLAC SHA256: `' + hashlib.sha256(output.read_bytes()).hexdigest() + '`.', '']
# Additions carry their own pinned provenance and preparation window.
additions = json.loads((ROOT / 'scripts/audio/library-additions.json').read_text())
audition = WORK / 'audition'
audition.mkdir(parents=True, exist_ok=True)
for item in additions:
    path = WORK / 'raw' / item['raw']
    if not path.exists():
        host = urllib.parse.urlparse(item['download']).hostname
        if host not in {'raw.githubusercontent.com', 'www.nps.gov', 'soundbible.com', 'upload.wikimedia.org'}:
            raise SystemExit('Unapproved download host: ' + str(host))
        path.parent.mkdir(parents=True, exist_ok=True)
        time.sleep(2.1)
        request = urllib.request.Request(item['download'], headers={'User-Agent': 'Mozilla/5.0 FirehawkFocus/1.0 audio research'})
        # No retries. A 403/429 stops this entire preparation run.
        with urllib.request.urlopen(request, timeout=120) as response:
            path.write_bytes(response.read())
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    if digest != item['sha256']:
        raise SystemExit('Downloaded input hash mismatch: ' + item['id'])
    env = dict(os.environ, DEVELOPER_DIR='/Applications/Xcode.app/Contents/Developer')
    pcm = MASTERS / (item['id'] + '-pcm.caf')
    result = subprocess.run(['swift', str(ROOT / 'scripts/audio/prepare.swift'), str(path),
        str(pcm), str(item['start']), str(item['duration']),
        str(item['overlap']), str(audition / (item['id'] + '.m4a'))],
        env=env, capture_output=True, text=True, check=True)
    output = DEST / (item['id'] + '.flac')
    encode_pcm_to_flac(pcm, output)
    print(item['id'], result.stdout.strip())
    catalog.append(dict(id=item['id'], name=item['name'], symbolName=item['symbol'], category=item['category'],
        file=output.name, gainDb=0, loopStartSeconds=0,
        loopEndSeconds=item['duration']-item['overlap'], credit=item.get('credit', item['creator']),
        sourceURL=item['source'], license=item['license']))
    output_hash = hashlib.sha256(output.read_bytes()).hexdigest()
    input_type = 'Downloaded derivative' if item['derivative'] else 'Downloaded source file'
    credits += ['## ' + item['name'], '', '- Creator / prior editors: ' + item['creator'],
        '- Source: [' + item['name'] + '](' + item['source'] + '); license: ' + item['license'] + '.',
        '- Per-file license evidence: ' + item['licenseEvidence'],
        '- Acquisition: ' + item.get('downloadDate', '2026-10-26') + '; [download](' + item['download'] + ').',
        '- ' + input_type + ' SHA256: `' + digest + '`.',
        '- Delivered FLAC SHA256: `' + output_hash + '`.',
        '- Edits: selected seconds ' + str(item['start']) + ' to ' + str(item['start']+item['duration']) +
        '; resampled to stereo 44.1 kHz PCM16; ' + str(item['overlap']) +
        '-second equal-power overlap; RMS matched with headroom and peak reduction as measured below.',
        '- Measurement: `' + result.stdout.strip() + '`.',
        '- Un-looped, level-matched AAC selection: `~/FirehawkAudioWork/audition/' + item['id'] + '.m4a`.', '']
    if item['license'] == 'CC-BY-4.0':
        credits += ['Attribution: ' + item['credit'] + '.', '']
credits += ['## Generated audio', '',
    'White, pink and brown noise and the tones are synthesized locally by FirehawkDSP. No third-party recording is used.', '',
    '## Acquisition limits and listening status', '',
    'The ' + str(len(catalog)) + ' catalog entries are audition assets. Automated measurements do not establish absence of speech, music, traffic or distracting events. User listening approval remains outstanding.', '',
    'Light Rain by soundrecorder7, Freesound 167034, and fire_crackling by ceich93, Freesound 263864, are absent from the checked Blankie and Blanket catalogs. No requests were made to Freesound, its API or its CDN in this task. The alternative rain uses pinned per-file redistribution metadata; its original page was not accessed. Its original master hash remains unavailable.', '',
    'The NPS woodstove candidate is jointly credited to MSU Acoustic Atlas. The per-file notice does not establish third-party rights, so it was excluded despite Blankie labeling it public domain. The bundled fireplace instead has an explicit per-file Public Domain listing on SoundBible.', '',
    'Cafe remains unfilled. The checked Public Domain restaurant candidate explicitly includes conversation and is too short for a quiet unobtrusive bed. Rejected files 156598, 687054 and 370973 were not downloaded or used.', '']
(DEST / 'catalog.json').write_text(json.dumps(catalog, indent=2) + '\n')
credits[2] = 'Catalog status: ' + str(len(catalog)) + ' audition assets are bundled. Listening approval is still required.'
credits[4] = 'The first six inputs, alternative rain and beach waves are AAC derivatives redistributed by Blankie, pinned to revision `' + REVISION + '`. These are not Freesound online previews. Train uses Wikimedia\'s MP3 transcode of the credited CC0 Ogg recording. Other additions use direct source downloads. Individual licenses and hashes follow.'
credits[8] = 'Preparation uses stereo 44.1 kHz PCM16 masters with equal-power tail/head overlap, RMS target -23 dBFS and a -6 dBFS peak ceiling, then FLAC level 8 delivery. Window lengths vary by source and are listed below. Crest factors above 17 dB receive a smooth tanh knee at six times RMS. RMS measurements are not LUFS. No fade-to-silence is used.'
credits_path = ROOT / 'docs/sounds/CREDITS.md'
credits += ['## Train, beach and gull selection notes', '',
    'Train selects 45 to 105 seconds of Ural-66\'s carriage wheel recording. The downloaded Wikimedia MP3 transcode is 240.664671 seconds, stereo 44.1 kHz. Its hash identifies the transcode, not the original Ogg. Blankie\'s different train recording was rejected because its two short pass-bys do not provide 40 seconds of stable train sound.', '',
    'Beach waves selects 20 to 80 seconds of Luftrum\'s stony fjord shore derivative, away from the strongest wave group at 84 to 93 seconds. This is not the rejected Rmutt 156598 recording. The original Freesound file was not requested. The pinned per-file metadata labels this source ccBy4; Blankie\'s License.swift maps that to CC BY 4.0.', '',
    'Seagulls selects 48 to 108 seconds of Shoreline Rhapsody. NPS identifies Bonaparte\'s gulls over gentle lapping water, with other seabirds and occasional marine mammal breaths in the full recording. The selection precedes the later dense high-pitched calls. A 60-second source selection and one-second overlap retain more variation. Spectral and level inspection found quiet selection edges; this is not a listening confirmation of intact calls or unobtrusive repeats.', '',
    'Farm is absent. SoundBible Farm and On The Farm are only 16.662 and 7.784 seconds; NPS Chickens is 5.329 seconds. A longer Commons goat recording describes about 30 hungry goats crowding a fence, so it was screened out as a poor calm-farmyard match. No short farm effect was stretched or tiled to fill the slot.', '',
    'No listening audition could be performed in this agent session. The three new layers require listening approval for individual-wave character, absence of distracting sounds, and event continuity across several repeats. See SOURCES-SHORTLIST.md for candidate decisions and network accounting.', '']
credits_path.write_text('\n'.join(credits))

# Reapply the offline expansion after regenerating the original fourteen entries.
subprocess.run(['python3', '-I', str(ROOT / 'scripts/audio/prepare-expansion.py')], check=True)
