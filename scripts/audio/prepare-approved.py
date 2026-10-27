#!/usr/bin/env python3
"""Prepare user-approved café / croaky frogs / night frogs. Run with python3 -I.

Replaces bullfrogs (rejects prior 750818 asset), adds cafe and night-frogs.
Originals stay under ~/FirehawkAudioWork. PCM masters are written outside the
repo, then encoded to FLAC level 8 for Ambience delivery.
"""
import hashlib
import json
import os
import sys
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts/audio'))
from encode_flac import encode_pcm_to_flac  # noqa: E402
WORK = Path.home() / 'FirehawkAudioWork'
DEST = ROOT / 'platforms/macos/Sources/FirehawkFocus/Resources/Ambience'
ENV = dict(os.environ, DEVELOPER_DIR='/Applications/Xcode.app/Contents/Developer')
HEADING = '## User-approved café and frogs, 2026-10-27'


def main():
    items = json.loads((ROOT / 'scripts/audio/library-approved.json').read_text())
    (WORK / 'audition').mkdir(exist_ok=True)
    catalog_path = DEST / 'catalog.json'
    catalog = json.loads(catalog_path.read_text())
    ids = {item['id'] for item in items}
    catalog = [entry for entry in catalog if entry['id'] not in ids]
    for item in items:
        raw = WORK / 'raw/freesound' / str(item['freesoundID']) / 'original.audio'
        digest = hashlib.sha256(raw.read_bytes()).hexdigest()
        assert digest == item['source']['sha256'], (item['id'], digest)

    credits = [HEADING, '',
               'These three recordings were approved by the user after listening to previews. '
               'Original licences were reverified through the sound-instance API on the download date. '
               'Preparation uses stereo 44.1 kHz PCM16 masters encoded to FLAC level 8, '
               'equal-power overlap loops, the library RMS target of -23 dBFS, and at least 6 dB '
               'sample-peak headroom. Croaky frogs keep catalog id `bullfrogs` and replace rejected '
               'Freesound 750818 (madamdata).', '']

    for item in items:
        source = item['source']
        raw = WORK / 'raw/freesound' / str(item['freesoundID']) / 'original.audio'
        audition = WORK / 'audition' / (item['name'] + '-prepared.m4a')
        pcm = WORK / 'masters' / (item['id'] + '-pcm.caf')
        pcm.parent.mkdir(parents=True, exist_ok=True)
        output = DEST / (item['id'] + '.flac')
        result = subprocess.run(
            ['swift', str(ROOT / 'scripts/audio/prepare.swift'), str(raw), str(pcm),
             str(item['start']), str(item['duration']), str(item['overlap']),
             str(audition), str(item['peakKneeRMS'])],
            env=ENV, capture_output=True, text=True, check=False)
        if result.returncode != 0:
            raise SystemExit(result.stderr or result.stdout or 'prepare.swift failed')
        encode_pcm_to_flac(pcm, output)
        frames = int(re.search(r'frames=(\d+)', result.stdout)[1])
        gain_db = item.get('gainDb', 0)
        attribution = (f"{source['title']} by {source['creator']}; {source['url']}; "
                       f"{source['license']}; {item['edits']} by Firehawk Focus")
        if source['license'].startswith('CC-BY-'):
            version = source['license'].split('-')[-1]
            attribution += f'; https://creativecommons.org/licenses/by/{version}/'
        catalog.append(dict(
            id=item['id'], name=item['name'], symbolName=item['symbol'], category=item['category'],
            file=output.name, gainDb=gain_db, loopStartSeconds=0,
            loopEndSeconds=frames / 44100, credit=attribution, sourceURL=source['url'],
            license=source['license'],
            sources=[{k: source[k] for k in ('title', 'creator', 'url', 'license')}],
            editors=['Firehawk Focus']))
        credits += [
            '### ' + item['name'], '',
            f"- Freesound ID: {item['freesoundID']}. Source: [{source['title']}]({source['url']}) by {source['creator']}.",
            f"- Licence: {source['license']}; API verification and original download: {source['downloadDate']}.",
            f"- Original SHA256: `{source['sha256']}`.",
            '- Edits: ' + item['edits'] + '.',
            '- Selection evidence: ' + item['selectionEvidence'] + '.',
            '- Peak reduction knee: ' + str(item['peakKneeRMS']) + ' times input RMS, used only above a 17 dB crest factor.',
            '- Measurement: `' + result.stdout.strip() + '`.',
            f'- Delivered duration: {frames / 44100:.6f} s.',
            f'- Catalog gainDb: {gain_db}.',
            '- Delivered FLAC SHA256: `' + hashlib.sha256(output.read_bytes()).hexdigest() + '`.',
            '- Un-looped audition: `~/FirehawkAudioWork/audition/' + item['name'] + '.m4a`.',
            '',
        ]
        print(item['id'], result.stdout.strip(), 'gainDb=', gain_db, flush=True)

    # already overwritten by new bullfrogs preparation above

    catalog_path.write_text(json.dumps(catalog, indent=2, ensure_ascii=False) + '\n')
    path = ROOT / 'docs/sounds/CREDITS.md'
    text = path.read_text()
    # Drop prior Croaky frogs / Soft Café unresolved sections' shipping claims by appending
    # this heading and updating status line.
    if HEADING in text:
        text = text.split(HEADING)[0].rstrip()
    text = re.sub(r'Catalog status: \d+ recordings[^\n]*',
                  f'Catalog status: {len(catalog)} recordings are bundled.', text, count=1)
    # Explicit removal notice for 750818
    removal = (
        '\n\n## Removed: Croaky frogs (Freesound 750818)\n\n'
        '- Previous asset `bullfrogs` from madamdata / Freesound 750818 was **rejected by the user** '
        'after listening and removed on 2026-10-27.\n'
        '- Replaced by reinsamba / Freesound 58236 while retaining catalog id `bullfrogs` '
        '(see User-approved café and frogs below).\n'
    )
    if '## Removed: Croaky frogs (Freesound 750818)' not in text:
        # Insert before Soft Café unresolved block or at end of Freesound originals section
        marker = '## Cafeteria user override and soft Café search, 2026-10-27'
        if marker in text:
            text = text.replace(marker, removal.lstrip() + '\n' + marker)
        else:
            text += removal
    # Soft Café 263584 is now shipped; annotate the old shortlist table decision.
    path.write_text(text + '\n\n' + '\n'.join(credits))
    print(f'Ambience: {sum(p.stat().st_size for p in DEST.rglob("*") if p.is_file()) / 1024**2:.3f} MiB')
    print(f'Catalog entries: {len(catalog)}')


if __name__ == '__main__':
    main()
