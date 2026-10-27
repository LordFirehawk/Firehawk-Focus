#!/usr/bin/env python3
"""Rebuild the requested batch offline from hash-pinned inputs. Run with python3 -I.

No network access or downloaded code execution. Original inputs and audition
selections stay in ~/FirehawkAudioWork; only prepared FLAC loops enter the app.
"""
import array
import hashlib
import json
import math
import os
import sys
from pathlib import Path
import subprocess
import wave

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts/audio'))
from encode_flac import encode_pcm_to_flac  # noqa: E402
WORK = Path.home() / 'FirehawkAudioWork'
DEST = ROOT / 'platforms/macos/Sources/FirehawkFocus/Resources/Ambience'
MASTERS = WORK / 'masters/requested'
PCM_MASTERS = WORK / 'masters/requested-pcm'
MASTERS.mkdir(parents=True, exist_ok=True)
RATE = 44100
ENV = dict(os.environ, DEVELOPER_DIR='/Applications/Xcode.app/Contents/Developer')
ITEMS = json.loads((ROOT / 'scripts/audio/library-requested.json').read_text())


def read(path):
    converted = MASTERS / 'conversion.wav'
    subprocess.run(['afconvert', '-f', 'WAVE', '-d', 'LEI16@44100', '-c', '2',
                    str(path), str(converted)], check=True)
    with wave.open(str(converted)) as f:
        assert (f.getframerate(), f.getnchannels(), f.getsampwidth()) == (RATE, 2, 2)
        data = array.array('h', f.readframes(f.getnframes()))
    converted.unlink()
    return data


def write(name, data):
    with wave.open(str(MASTERS / (name + '.wav')), 'wb') as f:
        f.setparams((2, 2, RATE, 0, 'NONE', 'not compressed'))
        f.writeframes(data.tobytes())


for item in ITEMS:
    for source in item['sources']:
        path = WORK / 'raw' / source['raw']
        assert hashlib.sha256(path.read_bytes()).hexdigest() == source['sha256'], path

# Align the actual recorded attacks, rather than just the clip boundaries.
clock = read(WORK / 'raw/soundbible/clock/download.wav')
bin_size = 441
energy = [sum(float(x)**2 for x in clock[i:i + bin_size * 2])
          for i in range(0, len(clock), bin_size * 2)]
peaks = []
for i in sorted(range(len(energy)), key=lambda i: energy[i], reverse=True):
    if energy[i] < max(energy) * .04:
        break
    if all(abs(i - j) > 23 for j in peaks):
        peaks.append(i)
peaks = sorted(peaks)[:70]
assert len(peaks) == 70
clips = []
for index in peaks:
    lo, hi = max(0, (index - 2) * bin_size), min(len(clock) // 2, (index + 3) * bin_size)
    peak = max(range(lo, hi), key=lambda j: max(abs(clock[j*2]), abs(clock[j*2+1])))
    start = peak - 1764
    assert start >= 0
    clips.append(clock[start*2:(start + round(.18 * RATE))*2])
output = array.array('h', [0]) * (50 * RATE * 2)
for tick in range(50):
    clip = clips[0]
    for i, value in enumerate(clip):
        fade = min(1, i / 352, (len(clip) - i - 1) / 352)
        output[tick * RATE * 2 + i] = round(value * fade)
write('clock', output)

# Keep the real storm's rain and thunder; add the credited wind bed.
storm = read(WORK / 'raw/soundbible/storm-full/download.wav')[20*RATE*2:80*RATE*2]
wind = read(WORK / 'raw/blankie/wind/download.m4a')[140*RATE*2:200*RATE*2]
assert len(storm) == len(wind) == 60 * RATE * 2
rms = lambda a: math.sqrt(sum(float(v)**2 for v in a) / len(a))
wind_gain = rms(storm) / rms(wind) * 10**(-8/20)
mixed = array.array('f', (a + b * wind_gain for a, b in zip(storm, wind)))
headroom = min(1, 20000 / max(abs(v) for v in mixed))
write('thunderstorm', array.array('h', (round(v * headroom) for v in mixed)))

catalog = json.loads((DEST / 'catalog.json').read_text())
ids = {item['id'] for item in ITEMS}
catalog = [entry for entry in catalog if entry['id'] not in ids]
for entry in catalog:
    if entry['id'] == 'clock-ticking':
        entry['name'] = 'Fast clock'

credits = ['## Requested listening-feedback batch, 2026-10-27', '',
           'Six additions bring the catalog to 26 recordings. Fast clock retains '
           '`clock-ticking`, preserving saved mixes. All files use stereo 44.1 kHz '
           'FLAC delivery from PCM16 masters, -23 dBFS RMS, and at least 6 dB sample-peak headroom. '
           'Campfire has an additional -4.5 dB catalog gain by design. '
           'Thunderstorm is a composite; Clock is an edited event sequence. '
           'The Commons inputs are MP3 transcodes, not original Ogg masters. '
           'No human listening approval is claimed. Source descriptions and '
           'signal measurements support the selections; the audition files allow '
           'review of timbre, background distractions and repeated seams.', '']
for item in ITEMS:
    path = MASTERS / (item['id'] + '.wav') if item['montage'] else WORK / 'raw' / item['sources'][0]['raw']
    PCM_MASTERS.mkdir(parents=True, exist_ok=True)
    pcm = PCM_MASTERS / (item['id'] + '-pcm.caf')
    output = DEST / (item['id'] + '.flac')
    audition = WORK / 'audition' / (item['id'] + '.m4a')
    command = ['swift', str(ROOT / 'scripts/audio/prepare.swift'), str(path), str(pcm),
               str(item['start']), str(item['duration']), str(item['overlap']), str(audition), str(item['peakKneeRMS'])]
    result = subprocess.run(command, env=ENV, capture_output=True, text=True, check=True)
    encode_pcm_to_flac(pcm, output)
    print(item['id'], result.stdout.strip(), flush=True)
    sources = [{key: s[key] for key in ['title', 'creator', 'url', 'license']} for s in item['sources']]
    first = sources[0]
    attribution = '; '.join(s['title'] + ' by ' + s['creator'] + '; ' + s['url'] + '; ' + s['license'] +
                            (' https://creativecommons.org/licenses/by/' + s['license'].split('-')[-1] + '/'
                             if s['license'].startswith('CC-BY-') else '') for s in sources)
    attribution += '; ' + item['edits'] + ' by Firehawk Focus'
    catalog.append(dict(id=item['id'], name=item['name'], symbolName=item['symbol'], category=item['category'],
                        file=output.name, gainDb=item['gainDb'], loopStartSeconds=0,
                        loopEndSeconds=item['duration']-item['overlap'], credit=attribution,
                        sourceURL=first['url'], license=first['license'], sources=sources, editors=item['editors']))
    credits += ['### ' + item['name'], '', '- Edits: ' + item['edits'] + '.',
                '- Peak reduction knee: ' + str(item['peakKneeRMS']) + ' times input RMS, applied only when the crest factor exceeds 17 dB.',
                '- Measurement: `' + result.stdout.strip() + '`.',
                '- Delivered FLAC SHA256: `' + hashlib.sha256(output.read_bytes()).hexdigest() + '`.',
                '- Un-looped selection: `~/FirehawkAudioWork/audition/' + item['id'] + '.m4a`.', '']
    for source in item['sources']:
        credits += ['- Source: [' + source['title'] + '](' + source['url'] + ') by ' + source['creator'] + '.',
                    '- Licence: ' + source['license'] + '. Per-file evidence: ' + source['licenseEvidence'],
                    '- Acquired ' + source['downloadDate'] + ' from ' + source['download'],
                    '- Downloaded input SHA256: `' + source['sha256'] + '`.', '']
    credits += ['Attribution and change notice: ' + attribution + '.', '']
(DEST / 'catalog.json').write_text(json.dumps(catalog, indent=2, ensure_ascii=False) + '\n')
p = ROOT / 'docs/sounds/CREDITS.md'
text = p.read_text().split('## Requested listening-feedback batch, 2026-10-27')[0].rstrip()
text = text.replace('Catalog status: 20 audition assets', 'Catalog status: 26 audition assets')
p.write_text(text + '\n\n' + '\n'.join(credits))
