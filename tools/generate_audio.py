#!/usr/bin/env python3
"""Original 16-bit-era arcade sound design: layered FM, sampled percussion,
filtered noise and short stereo echoes. No third-party recordings."""
import math
import os
import random
import struct
import wave

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "Assets", "Audio")
RATE = 44100
TAU = math.tau

def write(name, duration, voice, gain=0.7, echo=0.055):
    rng = random.Random(1988 + sum(map(ord, name)))
    mono = []
    smooth_noise = 0.0
    for i in range(int(duration * RATE)):
        t = i / RATE
        smooth_noise = 0.64 * smooth_noise + 0.36 * rng.uniform(-1, 1)
        attack = min(1.0, t / 0.002)
        tail = min(1.0, max(0.0, (duration - t) / 0.025))
        mono.append(voice(t, smooth_noise) * gain * attack * tail)
    data = bytearray()
    for i, dry in enumerate(mono):
        def delay(seconds):
            k = i - int(seconds * RATE)
            return mono[k] if k >= 0 else 0
        left = dry * 0.80 + delay(echo) * 0.14
        right = dry * 0.80 + delay(echo * 1.35) * 0.14
        for sample in (left, right):
            data.extend(struct.pack("<h", int(math.tanh(sample) * 30000)))
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as wav:
        wav.setnchannels(2)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        wav.writeframes(data)

def fm(t, frequency, index=1.2, decay=8):
    return math.sin(TAU * frequency * t + index * math.exp(-decay*t) * math.sin(TAU * frequency * 2*t))

def pluck(t, frequency):
    return (fm(t, frequency, 1.8, 20) * 0.6 + math.sin(TAU * frequency * 0.5 * t) * 0.25) * math.exp(-14*t)

def tune(notes, step):
    def sample(t, noise):
        index = min(int(t/step), len(notes)-1)
        local = t - index * step
        return pluck(local, notes[index]) + 0.13 * pluck(local, notes[index] * 1.5)
    return sample

def slap(t, noise, power=False):
    # A low rubber thump, a sharp handclap, then a springy comic tail.
    thump = math.sin(TAU * (135*t - 190*t*t)) * math.exp(-23*t)
    clap = noise * 2.2 * math.exp(-65*max(0, t-0.012))
    spring = fm(t, 195 if power else 275, 2.6, 18) * math.exp(-17*t)
    return 0.48*thump + 0.60*clap + 0.22*spring

def main():
    os.makedirs(OUT, exist_ok=True)
    write("ui", 0.12, lambda t,n: pluck(t, 880), 0.4)
    write("count", 0.18, lambda t,n: pluck(t, 523), 0.5)
    write("go", 0.34, tune([523,659,784,1047], 0.075), 0.65)
    write("bounce", 0.15, lambda t,n: math.sin(TAU*(180*t-220*t*t))*math.exp(-28*t) + n*math.exp(-70*t)*0.6, 0.65, 0.022)
    write("slap", 0.24, lambda t,n: slap(t,n), 0.95, 0.038)
    write("power", 0.38, lambda t,n: slap(t,n,True) + 0.3*math.sin(TAU*65*t)*math.exp(-10*t), 1.0, 0.062)
    write("out", 0.52, lambda t,n: fm(t, max(65, 310-380*t),2.1)*math.exp(-5*t)*0.7 + n*math.exp(-32*t), 0.72)
    write("double", 0.32, tune([196,185,147], 0.09), 0.55)
    write("victory", 1.25, tune([392,523,659,784,659,784,1047,1047],0.145), 0.65)
    write("dribble", 0.12, lambda t,n: math.sin(TAU*(145*t-220*t*t))*math.exp(-35*t) + n*math.exp(-65*t)*0.3, 0.48,0.018)
    write("steal", 0.24, tune([784,988,1175],0.065), 0.55)
    write("toss", 0.45, lambda t,n: n*math.sin(math.pi*t/0.45)*0.65 + fm(t,240+t*550,0.7)*math.exp(-8*t)*0.25, 0.55)
    write("jump", 0.25, lambda t,n: fm(t,180+t*900,0.7)*math.exp(-12*t), 0.4)
    print("13 original stereo 44.1 kHz / 16-bit arcade effects written to Assets/Audio")

if __name__ == "__main__":
    main()
