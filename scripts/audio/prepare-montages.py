#!/usr/bin/env python3
"""Offline montage inputs. Run with python3 -I; never executes downloaded code."""
import array
import pathlib
import subprocess
import wave
import zipfile

WORK = pathlib.Path.home() / 'FirehawkAudioWork'
RAW = WORK / 'raw'
OUT = WORK / 'masters' / 'expansion'
OUT.mkdir(parents=True, exist_ok=True)
RATE = 44100


def read(path):
    converted = OUT / 'conversion.wav'
    subprocess.run(['afconvert', '-f', 'WAVE', '-d', 'LEI16@44100', '-c', '2', str(path), str(converted)], check=True)
    with wave.open(str(converted)) as f:
        assert f.getframerate() == RATE and f.getnchannels() == 2 and f.getsampwidth() == 2
        data = array.array('h', f.readframes(f.getnframes()))
    converted.unlink()
    return data


def write(name, data):
    with wave.open(str(OUT / (name + '.wav')), 'wb') as f:
        f.setparams((2, 2, RATE, 0, 'NONE', 'not compressed'))
        f.writeframes(data.tobytes())


def place(dest, samples, seconds, gain=1):
    start = round(seconds * RATE) * 2
    # Fade only each isolated event's outer 4 ms, keeping its attack intact.
    edge = 176 * 2
    for i, value in enumerate(samples):
        if start + i >= len(dest):
            break
        fade = min(1, i / edge, (len(samples) - i - 1) / edge)
        dest[start + i] = max(-32768, min(32767, dest[start + i] + round(value * gain * fade)))


# Clock: retain 70 distinct source ticks in alternating tick/tock order,
# then place 160 ticks at exact 14,112-frame (0.32 s) intervals.
clock = read(RAW / 'soundbible/clock/download.wav')
bin_size = 441
energy = [sum(float(x)**2 for x in clock[i:i + bin_size * 2]) for i in range(0, len(clock), bin_size * 2)]
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
    lo = max(0, (index - 2) * bin_size)
    hi = min(len(clock) // 2, (index + 3) * bin_size)
    peak = max(range(lo, hi), key=lambda j: max(abs(clock[j*2]), abs(clock[j*2+1])))
    start = max(0, peak - round(.04 * RATE))
    clips.append(clock[start*2:(start + round(.26 * RATE))*2])
output = array.array('h', [0]) * (160 * 14112 * 2)
for i in range(160):
    place(output, clips[i % len(clips)], i * .32)
write('clock-ticking', output)

# A quiet work session: five different unhurried human takes, with pauses
# and three page turns between takes. No generated keyboard takes are used.
with zipfile.ZipFile(RAW / 'opengameart/typing/download.zip') as z:
    takes = []
    for i in [1, 2, 3, 4, 5]:
        path = OUT / f'human-{i}.wav'
        path.write_bytes(z.read(f'Human Typing/human_vel-{i:03}.wav'))
        takes.append(read(path))
page = read(RAW / 'soundbible/page-turn/download.wav')
output = array.array('h', [0]) * (52 * RATE * 2)
for take, at in zip(takes, [1, 12, 23, 32, 42]):
    place(output, take, at, .65)
for at in [10.2, 30.1, 50.0]:
    place(output, page, at, .25)
write('typing-pages', output)

# Snow-covered gravel footsteps. All 18 extracted lossless source variations
# take turns in a deterministic permutation at a steady 0.8-second cadence.
step_directory = RAW / 'opengameart/winter/snow-steps'
step_directory.mkdir(exist_ok=True)
for i in range(1, 19):
    path = step_directory / f'{i:02}.flac'
    if not path.exists():
        member = f'Corsica_S-Walking_in_Snow/Corsica_S-Walking_on_snow_covered_gravel_{i:02}.flac'
        path.write_bytes(subprocess.check_output(['tar', '-xOf', str(RAW / 'opengameart/winter/download.7z'), member]))
steps = [read(RAW / f'opengameart/winter/snow-steps/{i:02}.flac') for i in range(1, 19)]
output = array.array('h', [0]) * (64 * 35280 * 2)
for i in range(64):
    step = steps[(i * 7) % 18]
    # Remove leading/trailing digital near-silence from each isolated step.
    active = [j for j in range(len(step)//2) if max(abs(step[j*2]), abs(step[j*2+1])) > 120]
    assert active
    lo = max(0, active[0] - 220)
    hi = min(len(step)//2, active[-1] + 442)
    assert hi - lo < 35280, 'Step overlaps the following footfall'
    place(output, step[lo*2:hi*2], .02 + i * .8, .8)
write('winter-walk', output)
print('Prepared clock-ticking, typing-pages and winter-walk montage inputs offline')
