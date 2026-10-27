#!/usr/bin/env python3
"""Compare two directories of lossless audio bit-for-bit after decode.

Usage (python3 -I):
  scripts/audio/verify-lossless.py DIR_A DIR_B

Pairs files by stem (extension ignored). Each file is decoded with afconvert to
stereo little-endian PCM16 WAV at its native sample rate, then compared
sample-by-sample. Reports frame counts and differing stereo frames. Exit 0 only
when every paired stem matches with zero differing samples and identical frame
counts. Extra/missing stems are failures.
"""
from __future__ import annotations

import argparse
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

AUDIO_SUFFIXES = {'.caf', '.flac', '.wav', '.m4a', '.aiff', '.aif', '.aifc'}


def audio_files(directory: Path) -> dict[str, Path]:
    found: dict[str, Path] = {}
    for path in sorted(directory.iterdir()):
        if not path.is_file() or path.suffix.lower() not in AUDIO_SUFFIXES:
            continue
        stem = path.stem
        if stem in found:
            raise SystemExit(f'duplicate stem in {directory}: {found[stem].name} and {path.name}')
        found[stem] = path
    return found


def read_pcm16_stereo(path: Path) -> tuple[bytes, int, int]:
    with wave.open(str(path), 'rb') as reader:
        channels = reader.getnchannels()
        width = reader.getsampwidth()
        rate = reader.getframerate()
        frames = reader.getnframes()
        assert channels == 2, f'{path}: expected stereo, got {channels}'
        assert width == 2, f'{path}: expected 16-bit, got {width * 8}-bit'
        return reader.readframes(frames), frames, rate


def decode_to_wav(src: Path, dst: Path) -> None:
    subprocess.run(
        ['afconvert', '-f', 'WAVE', '-d', 'LEI16', str(src), str(dst)],
        check=True, capture_output=True)


def compare_pair(stem: str, left: Path, right: Path, tmp: Path) -> tuple[bool, str]:
    a_wav = tmp / f'{stem}-a.wav'
    b_wav = tmp / f'{stem}-b.wav'
    decode_to_wav(left, a_wav)
    decode_to_wav(right, b_wav)
    a, a_frames, a_rate = read_pcm16_stereo(a_wav)
    b, b_frames, b_rate = read_pcm16_stereo(b_wav)
    if a_rate != b_rate:
        return False, f'{stem}: sample-rate mismatch {a_rate} vs {b_rate}'
    if a_frames != b_frames or len(a) != len(b):
        return False, (
            f'{stem}: frame-count mismatch {left.name}={a_frames} '
            f'{right.name}={b_frames}')
    if a == b:
        return True, f'OK {stem}: 0 differing samples ({a_frames} frames @ {a_rate} Hz)'
    diffs = sum(1 for i in range(0, len(a), 4) if a[i:i + 4] != b[i:i + 4])
    return False, f'{stem}: {diffs} differing stereo frames ({a_frames} frames)'


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('dir_a', type=Path)
    parser.add_argument('dir_b', type=Path)
    args = parser.parse_args()
    dir_a = args.dir_a.expanduser().resolve()
    dir_b = args.dir_b.expanduser().resolve()
    if not dir_a.is_dir() or not dir_b.is_dir():
        print(f'both arguments must be directories: {dir_a} {dir_b}', file=sys.stderr)
        return 2
    files_a = audio_files(dir_a)
    files_b = audio_files(dir_b)
    stems = sorted(set(files_a) | set(files_b))
    failures: list[str] = []
    ok_count = 0
    total_diff = 0
    with tempfile.TemporaryDirectory() as tmp_name:
        tmp = Path(tmp_name)
        for stem in stems:
            if stem not in files_a:
                failures.append(f'{stem}: missing in {dir_a}')
                continue
            if stem not in files_b:
                failures.append(f'{stem}: missing in {dir_b}')
                continue
            ok, message = compare_pair(stem, files_a[stem], files_b[stem], tmp)
            print(message)
            if ok:
                ok_count += 1
            else:
                failures.append(message)
                if 'differing stereo frames' in message:
                    total_diff += int(message.split(': ', 1)[1].split(' ', 1)[0])
    print(f'compared_stems={len(stems)} ok={ok_count} failures={len(failures)}')
    if failures:
        print('FAILURES:')
        for line in failures:
            print(' ', line)
        if total_diff:
            print(f'total_differing_frames={total_diff}')
        return 1
    print('ALL_FILES_BIT_IDENTICAL differing_samples=0')
    return 0


if __name__ == '__main__':
    sys.exit(main())
