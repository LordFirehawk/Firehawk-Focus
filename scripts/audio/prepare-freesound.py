#!/usr/bin/env python3
"""Offline, hash-pinned Freesound preparation. Run with python3 -I.

Originals and intermediate masters remain in ~/FirehawkAudioWork. This appends
only the selected entries and replaces this batch's own credits on reruns.
"""
import hashlib
import json
import os
import sys
from pathlib import Path
import re
import subprocess
import wave

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts/audio'))
from encode_flac import encode_pcm_to_flac  # noqa: E402
WORK = Path.home() / 'FirehawkAudioWork'
DEST = ROOT / 'platforms/macos/Sources/FirehawkFocus/Resources/Ambience'
MASTERS = WORK / 'masters/freesound'
ENV = dict(os.environ, DEVELOPER_DIR='/Applications/Xcode.app/Contents/Developer')
HEADING = '## Freesound originals, 2026-10-27'


def main():
    items = json.loads((ROOT / 'scripts/audio/library-freesound.json').read_text())
    MASTERS.mkdir(parents=True, exist_ok=True)
    (WORK / 'audition').mkdir(exist_ok=True)
    catalog_path = DEST / 'catalog.json'
    catalog = json.loads(catalog_path.read_text())
    ids = {item['id'] for item in items}
    catalog = [entry for entry in catalog if entry['id'] not in ids]
    # Check the entire batch and delivery budget before changing any asset.
    for item in items:
        source = item['source']
        raw = WORK / 'raw/freesound' / str(item['freesoundID']) / 'original.audio'
        assert hashlib.sha256(raw.read_bytes()).hexdigest() == source['sha256'], raw
    projected = sum(p.stat().st_size for p in DEST.iterdir() if p.is_file() and p.stem not in ids)
    projected += sum(round((i['duration'] - i['overlap']) * 44100) * 4 * i.get('repetitions', 1) + 4096 for i in items)
    if projected > 250 * 1024**2:
        raise SystemExit('Would exceed 250 MiB; propose a delivery-format change before preparing')
    credits = [HEADING, '',
               'Original licences were reverified through the sound-instance API on the download date. '
               'All five additions use stereo 44.1 kHz FLAC delivery from PCM16 masters, the library '
               'RMS target of -23 dBFS, at least 6 dB sample-peak headroom, and equal-power overlaps. '
               'Selections use source descriptions, waveform envelopes and offline sound classification. '
               'These checks do not establish human listening approval. Café is excluded because a '
               'qualifying 45-second segment has not been established.', '']
    for item in items:
        source = item['source']
        raw = WORK / 'raw/freesound' / str(item['freesoundID']) / 'original.audio'
        audition = WORK / 'audition' / (str(item['freesoundID']) + '.m4a')
        output = DEST / (item['id'] + '.flac')
        repetitions = item.get('repetitions', 1)
        prepared = MASTERS / (item['id'] + '-pcm.caf')
        result = subprocess.run(['swift', str(ROOT / 'scripts/audio/prepare.swift'), str(raw), str(prepared),
                                 str(item['start']), str(item['duration']), str(item['overlap']),
                                 str(audition), str(item['peakKneeRMS'])], env=ENV, capture_output=True, text=True, check=True)
        frames = int(re.search(r'frames=(\d+)', result.stdout)[1])
        pcm_for_flac = prepared
        if repetitions != 1:
            one_pass = MASTERS / (item['id'] + '-one-pass.wav')
            repeated = MASTERS / (item['id'] + '-repeated.wav')
            subprocess.run(['afconvert', '-f', 'WAVE', '-d', 'LEI16', str(prepared), str(one_pass)], check=True)
            with wave.open(str(one_pass)) as reader:
                params, pcm = reader.getparams(), reader.readframes(reader.getnframes())
                assert params.nframes == frames
            with wave.open(str(repeated), 'wb') as writer:
                writer.setparams(params)
                writer.writeframes(pcm * repetitions)
            pcm_for_flac = repeated
        encode_pcm_to_flac(pcm_for_flac, output)
        attribution = f"{source['title']} by {source['creator']}; {source['url']}; {source['license']}; {item['edits']} by Firehawk Focus"
        if source['license'].startswith('CC-BY-'):
            attribution += '; https://creativecommons.org/licenses/by/' + source['license'].split('-')[-1] + '/'
        catalog.append(dict(id=item['id'], name=item['name'], symbolName=item['symbol'], category=item['category'],
                            file=output.name, gainDb=0, loopStartSeconds=0, loopEndSeconds=frames * repetitions / 44100,
                            credit=attribution, sourceURL=source['url'], license=source['license'],
                            sources=[{k: source[k] for k in ('title', 'creator', 'url', 'license')}], editors=['Firehawk Focus']))
        credits += ['### ' + item['name'], '',
                    f"- Freesound ID: {item['freesoundID']}. Source: [{source['title']}]({source['url']}) by {source['creator']}.",
                    f"- Licence: {source['license']}; API verification and original download: {source['downloadDate']}.",
                    f"- Original SHA256: `{source['sha256']}`.",
                    '- Edits: ' + item['edits'] + '.',
                    '- Selection evidence: ' + item['selectionEvidence'] + '.',
                    '- Peak reduction knee: ' + str(item['peakKneeRMS']) + ' times input RMS, used only above a 17 dB crest factor.',
                    '- Measurement before any exact loop repetition: `' + result.stdout.strip() + '`.',
                    f'- Delivered duration: {frames * repetitions / 44100:.6f} s.',
                    '- Delivered FLAC SHA256: `' + hashlib.sha256(output.read_bytes()).hexdigest() + '`.',
                    '- Un-looped source audition: `~/FirehawkAudioWork/audition/' + audition.name + '`.', '']
        print(item['id'], result.stdout.strip(), flush=True)
    catalog_path.write_text(json.dumps(catalog, indent=2, ensure_ascii=False) + '\n')
    path = ROOT / 'docs/sounds/CREDITS.md'
    text = path.read_text().split(HEADING)[0].rstrip()
    text = re.sub(r'Catalog status: \d+ audition assets', f'Catalog status: {len(catalog)} audition assets', text)
    path.write_text(text + '\n\n' + '\n'.join(credits))
    for item in items:
        preview = item.get('preview')
        if preview:
            (WORK / 'audition' / preview).unlink(missing_ok=True)
    print(f'Ambience: {sum(p.stat().st_size for p in DEST.rglob("*") if p.is_file()) / 1024**2:.3f} MiB')


if __name__ == '__main__':
    main()
