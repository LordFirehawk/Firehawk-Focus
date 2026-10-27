#!/usr/bin/env python3
"""One-off: compare decoded ALAC samples with reference PCM WAV bit-for-bit.

Usage (python3 -I):
  scripts/audio/verify-alac-lossless.py [--convert]

With --convert, each Ambience CAF/M4A is re-encoded to Apple Lossless CAF from the
PCM WAV snapshot under ~/FirehawkAudioWork/masters/pcm-before-alac/, then verified.
Without --convert, only verifies existing Ambience ALAC files against that snapshot.
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / 'platforms/macos/Sources/FirehawkFocus/Resources/Ambience'
SNAP = Path.home() / 'FirehawkAudioWork/masters/pcm-before-alac'


def read_pcm16_stereo(path: Path) -> bytes:
    with wave.open(str(path), 'rb') as reader:
        assert reader.getnchannels() == 2, path
        assert reader.getsampwidth() == 2, path
        assert reader.getframerate() == 44100, path
        return reader.readframes(reader.getnframes())


def decode_to_wav(src: Path, dst: Path) -> None:
    subprocess.run(
        ['afconvert', '-f', 'WAVE', '-d', 'LEI16', str(src), str(dst)],
        check=True, capture_output=True)


def convert_wav_to_alac_caf(wav: Path, caf: Path) -> None:
    temporary = caf.with_suffix('.alac.partial.caf')
    subprocess.run(
        ['afconvert', '-f', 'caff', '-d', 'alac', str(wav), str(temporary)],
        check=True, capture_output=True)
    temporary.replace(caf)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('--convert', action='store_true')
    args = parser.parse_args()
    catalog = json.loads((DEST / 'catalog.json').read_text())
    failures = []
    total_diff = 0
    for entry in catalog:
        stem = Path(entry['file']).stem
        ref = SNAP / (stem + '.wav')
        if not ref.exists():
            failures.append(f'{stem}: missing PCM reference {ref}')
            continue
        out = DEST / (stem + '.caf')
        if args.convert:
            convert_wav_to_alac_caf(ref, out)
            entry['file'] = out.name
        if not out.exists():
            failures.append(f'{stem}: missing ALAC delivery {out.name}')
            continue
        with tempfile.TemporaryDirectory() as tmp:
            decoded = Path(tmp) / 'decoded.wav'
            decode_to_wav(out, decoded)
            a = read_pcm16_stereo(ref)
            b = read_pcm16_stereo(decoded)
        if len(a) != len(b):
            failures.append(f'{stem}: length mismatch ref={len(a)} decoded={len(b)}')
            total_diff += abs(len(a) - len(b))
            continue
        # Byte-wise PCM16 comparison (bit-identical samples).
        if a != b:
            # Count differing sample frames (4 bytes stereo frame).
            diffs = sum(1 for i in range(0, len(a), 4) if a[i:i + 4] != b[i:i + 4])
            total_diff += diffs
            failures.append(f'{stem}: {diffs} differing stereo frames')
        else:
            print(f'OK {stem}: 0 differing samples ({len(a) // 4} frames)')
    if args.convert:
        # Drop any leftover AAC cafeteria etc.
        for path in DEST.iterdir():
            if path.suffix.lower() == '.m4a':
                path.unlink()
                print('removed', path.name)
        (DEST / 'catalog.json').write_text(json.dumps(catalog, indent=2, ensure_ascii=False) + '\n')
    size = sum(p.stat().st_size for p in DEST.rglob('*') if p.is_file())
    print(f'Ambience: {size} bytes ({size / 1024**2:.3f} MiB)')
    if failures:
        print('FAILURES:', len(failures))
        for line in failures:
            print(' ', line)
        print(f'total_differing_frames={total_diff}')
        return 1
    print('ALL_FILES_BIT_IDENTICAL differing_samples=0')
    return 0


if __name__ == '__main__':
    sys.exit(main())
