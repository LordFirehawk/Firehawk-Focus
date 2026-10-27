#!/usr/bin/env python3
"""Encode a PCM audio file to stereo FLAC (compression level 8).

Usage (python3 -I):
  scripts/audio/encode_flac.py INPUT.{caf,wav,...} OUTPUT.flac

Decodes with afconvert to little-endian PCM16 WAV, then encodes with
`flac -8`. Requires Homebrew `flac` (or another flac on PATH).
"""
from __future__ import annotations

import subprocess
import sys
import tempfile
from pathlib import Path


def encode_pcm_to_flac(pcm: Path, flac: Path) -> None:
    pcm = pcm.expanduser().resolve()
    flac = flac.expanduser().resolve()
    flac.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp_name:
        wav = Path(tmp_name) / 'pcm16.wav'
        subprocess.run(
            ['afconvert', '-f', 'WAVE', '-d', 'LEI16', str(pcm), str(wav)],
            check=True, capture_output=True)
        partial = flac.with_suffix('.partial.flac')
        subprocess.run(
            ['flac', '-8', '--force', '--silent', '-o', str(partial), str(wav)],
            check=True, capture_output=True)
        partial.replace(flac)


def main() -> int:
    if len(sys.argv) != 3:
        print('usage: encode_flac.py INPUT OUTPUT.flac', file=sys.stderr)
        return 2
    encode_pcm_to_flac(Path(sys.argv[1]), Path(sys.argv[2]))
    return 0


if __name__ == '__main__':
    sys.exit(main())
