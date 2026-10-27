#!/usr/bin/env python3
"""Prepare verified, cached additions offline. Run with python3 -I."""
import hashlib
import json
import os
import sys
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts/audio'))
from encode_flac import encode_pcm_to_flac  # noqa: E402
WORK = Path.home() / 'FirehawkAudioWork'
DEST = ROOT / 'platforms/macos/Sources/FirehawkFocus/Resources/Ambience'
MASTERS = WORK / 'masters/expansion-pcm'
items = json.loads((ROOT / 'scripts/audio/library-expansion.json').read_text())
env = dict(os.environ, DEVELOPER_DIR='/Applications/Xcode.app/Contents/Developer')
for item in items:
    for source in item['sources']:
        path = WORK / 'raw' / source['raw']
        if hashlib.sha256(path.read_bytes()).hexdigest() != source['sha256']:
            raise SystemExit('Input hash mismatch: ' + str(path))
subprocess.run(['python3', '-I', str(ROOT / 'scripts/audio/prepare-montages.py')], check=True)
catalog = json.loads((DEST / 'catalog.json').read_text())
ids = {item['id'] for item in items}
catalog = [item for item in catalog if item['id'] not in ids]
credits = ['## Lazy-library additions, 2026-10-26', '',
    'Six additions use the same -23 dBFS RMS / -6 dBFS peak preparation as the existing library. '
    'The two Commons downloads are MP3 transcodes, not original Ogg masters. '
    'No CC BY-SA asset was added. The clock, keyboard/paper and snow layers are edited montages; '
    'their silence at the boundary is intentional. They need listening approval for timbre and repetition.', '']
for item in items:
    source = item['sources'][0]
    path = WORK / 'masters/expansion' / (item['id'] + '.wav') if item['montage'] else WORK / 'raw' / source['raw']
    MASTERS.mkdir(parents=True, exist_ok=True)
    pcm = MASTERS / (item['id'] + '-pcm.caf')
    output = DEST / (item['id'] + '.flac')
    audition = WORK / 'audition' / (item['id'] + '.m4a')
    command = ['swift', str(ROOT / 'scripts/audio/prepare.swift'), str(path), str(pcm),
               str(item['start']), str(item['duration']), str(item['overlap']), str(audition), str(item.get('peakKneeRMS', 6))]
    result = subprocess.run(command, env=env, capture_output=True, text=True, check=True)
    encode_pcm_to_flac(pcm, output)
    measurement = result.stdout.strip()
    print(item['id'], measurement, flush=True)
    if item['id'] == 'clock-ticking':
        # Audition the original recorded run without the delivery grid or repeats.
        subprocess.run(['afconvert', '-f', 'm4af', '-d', 'aac@44100', '-c', '2', '-b', '192000',
                        str(WORK / 'raw' / source['raw']), str(audition)], check=True)
    catalog.append(dict(id=item['id'], name=item['name'], symbolName=item['symbol'], category=item['category'],
        file=output.name, gainDb=0, loopStartSeconds=0,
        loopEndSeconds=item['duration'] - item['overlap'], credit=item['credit'],
        sourceURL=source['source'], license='CC-BY-3.0' if any(s['license']=='CC-BY-3.0' for s in item['sources']) else source['license']))
    credits += ['### ' + item['name'], '', '- Edits: ' + item['edits'] + '.',
                '- Measurement: `' + measurement + '`.',
                '- Delivered FLAC SHA256: `' + hashlib.sha256(output.read_bytes()).hexdigest() + '`.',
                '- Audition: `~/FirehawkAudioWork/audition/' + item['id'] + '.m4a`.', '']
    for s in item['sources']:
        credits += ['- Creator: ' + s['creator'] + '.', '- Source: ' + s['source'],
                    '- Per-file licence evidence: ' + s['licenseEvidence'], '- Licence: ' + s['license'] + '.',
                    '- Downloaded ' + s['downloadDate'] + ' from ' + s['download'],
                    '- Input SHA256: `' + s['sha256'] + '`.', '']
    credits += ['Attribution: ' + item['credit'] + '.', '']
(DEST / 'catalog.json').write_text(json.dumps(catalog, indent=2) + '\n')
p = ROOT / 'docs/sounds/CREDITS.md'
text = p.read_text().split('## Lazy-library additions, 2026-10-26')[0].rstrip()
text = text.replace('Catalog status: 14 audition assets', 'Catalog status: 20 audition assets')
p.write_text(text + '\n\n' + '\n'.join(credits))
