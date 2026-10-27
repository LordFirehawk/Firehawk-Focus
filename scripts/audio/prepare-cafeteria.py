#!/usr/bin/env python3
"""Rebuild the user-approved Cafeteria selection offline with python3 -I.

Run after earlier batch scripts. Originals, temporary files and named auditions
stay outside the repository. Never fetch a replacement for the pinned input.
"""
import hashlib
import json
import os
import sys
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
WORK = Path.home() / 'FirehawkAudioWork'
DEST = ROOT / 'platforms/macos/Sources/FirehawkFocus/Resources/Ambience'


def main():
    item = json.loads((ROOT / 'scripts/audio/library-cafeteria.json').read_text())
    raw = WORK / 'raw/freesound' / str(item['freesoundID']) / 'original.audio'
    metadata = json.loads(raw.with_name('metadata.json').read_text())
    assert metadata['license'].rstrip('/') in (
        'http://creativecommons.org/publicdomain/zero/1.0',
        'https://creativecommons.org/publicdomain/zero/1.0')
    assert hashlib.sha256(raw.read_bytes()).hexdigest() == item['sha256']
    pcm = WORK / 'masters' / 'cafeteria-pcm.caf'
    pcm.parent.mkdir(parents=True, exist_ok=True)
    audition = WORK / 'audition' / (item['name'] + '.m4a')
    temporary = audition.with_name(item['name'] + '-prepared.m4a')
    subprocess.run(['swift', str(ROOT / 'scripts/audio/prepare.swift'), str(raw), str(pcm),
                    str(item['start']), str(item['duration']), str(item['overlap']),
                    str(temporary), str(item['peakKneeRMS'])], check=True,
                   env=dict(os.environ, DEVELOPER_DIR='/Applications/Xcode.app/Contents/Developer'))
    output = DEST / (item['id'] + '.flac')
    # Lossless delivery: PCM master → FLAC level 8 (decoded samples stay bit-identical).
    sys.path.insert(0, str(ROOT / 'scripts/audio'))
    from encode_flac import encode_pcm_to_flac  # noqa: E402
    encode_pcm_to_flac(pcm, output)
    if not audition.exists() or hashlib.sha256(audition.read_bytes()).digest() != hashlib.sha256(temporary.read_bytes()).digest():
        temporary.replace(audition)
    else:
        temporary.unlink()
    assert sum(p.stat().st_size for p in DEST.rglob('*') if p.is_file()) <= 250 * 1024**2
    source = item['source']
    path = DEST / 'catalog.json'
    catalog = json.loads(path.read_text())
    catalog = [entry for entry in catalog if entry['id'] != item['id']]
    credit = (f"{source['title']} by {source['creator']}; {source['url']}; {source['license']}; "
              '936–1176 s selection, 6 s equal-power overlap, RMS matching with standard peak reduction, '
              'FLAC delivery by Firehawk Focus')
    catalog.append(dict(id=item['id'], name=item['name'], symbolName=item['symbol'], category='indoor',
                        file=output.name, gainDb=0, loopStartSeconds=0,
                        loopEndSeconds=item['duration'] - item['overlap'], credit=credit,
                        sourceURL=source['url'], license=source['license'], sources=[source], editors=['Firehawk Focus']))
    path.write_text(json.dumps(catalog, indent=2, ensure_ascii=False) + '\n')
    print(f'{output.name}: {output.stat().st_size} bytes; SHA256 {hashlib.sha256(output.read_bytes()).hexdigest()}')


if __name__ == '__main__':
    main()
