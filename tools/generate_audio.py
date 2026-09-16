#!/usr/bin/env python3
"""Generate tiny original 8-bit arcade WAV effects used by the game."""

import math
import os
import random
import struct
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "Assets", "Audio")
RATE = 22050


def square(phase):
    return 1.0 if math.sin(phase) >= 0 else -1.0


def write(name, duration, sample_fn, volume=0.75):
    count = int(RATE * duration)
    data = bytearray()
    for i in range(count):
        t = i / RATE
        envelope = min(1.0, t * 90.0) * max(0.0, 1.0 - t / duration)
        value = max(-1.0, min(1.0, sample_fn(t, i) * envelope * volume))
        data.extend(struct.pack("<h", int(value * 30000)))
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        wav.writeframes(bytes(data))


def tone_sequence(notes, step, duty_mix=1.0):
    def sample(t, _i):
        index = min(int(t / step), len(notes) - 1)
        phase = 2.0 * math.pi * notes[index] * t
        return square(phase) * duty_mix
    return sample


def main():
    os.makedirs(OUT, exist_ok=True)
    rng = random.Random(1988)
    write("ui", 0.045, lambda t, _i: square(2 * math.pi * (760 + t * 900) * t), 0.35)
    write("count", 0.075, lambda t, _i: square(2 * math.pi * 520 * t), 0.40)
    write("go", 0.16, tone_sequence([523, 659, 784], 0.052), 0.45)
    write("bounce", 0.055, lambda t, _i: square(2 * math.pi * (310 + t * 1300) * t), 0.25)
    write("slap", 0.10, lambda t, _i: 0.65 * square(2 * math.pi * (210 - t * 900) * t) + 0.35 * rng.uniform(-1, 1), 0.60)
    write("power", 0.20, lambda t, _i: 0.7 * square(2 * math.pi * (150 + t * 700) * t) + 0.3 * rng.uniform(-1, 1), 0.72)
    write("out", 0.34, tone_sequence([330, 262, 196, 131], 0.082), 0.52)
    write("double", 0.22, tone_sequence([147, 147, 110], 0.07), 0.48)
    write("victory", 0.78, tone_sequence([392, 523, 659, 784, 659, 784, 1047], 0.105), 0.45)
    print("8-bit sound effects written to Assets/Audio")


if __name__ == "__main__":
    main()
