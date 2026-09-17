#!/usr/bin/env python3
"""Create five original, seamless 16-bit-era arcade tracks.

The stems are synthesized here: FM lead, triangle bass, chord pad, arpeggio,
kick, snare and hats. No samples, recordings, or third-party compositions.
"""
from array import array
import math
import os
import random
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "Assets", "Audio", "Music")
RATE = 44100
TAU = math.tau

TRACKS = [
    ("schoolyard_sprint", 132, 0, [0, 5, 3, 4], [0, 2, 4, 7, 9, 7, 4, 2]),
    ("county_line_clash", 118, 7, [0, 3, 5, 4], [0, 4, 7, 9, 7, 4, 2, 4]),
    ("capital_circuit", 140, 2, [0, 4, 5, 3], [0, 2, 7, 5, 9, 7, 4, 2]),
    ("city_lights", 126, 9, [0, 5, 2, 4], [0, 7, 9, 11, 9, 7, 4, 2]),
    ("world_final", 148, 5, [0, 3, 4, 5], [0, 4, 5, 7, 11, 9, 7, 4]),
]

def hz(midi):
    return 440.0 * 2.0 ** ((midi - 69) / 12.0)

def tri(phase):
    return 2.0 * abs(2.0 * ((phase / TAU) % 1.0) - 1.0) - 1.0

def saw(phase):
    return 2.0 * ((phase / TAU) % 1.0) - 1.0

def chord_tone(t, notes):
    value = 0.0
    for n in notes:
        f = hz(n)
        value += math.sin(TAU*f*t) + 0.25*math.sin(TAU*f*2*t)
    return value / len(notes)

def render(name, bpm, root, progression, melody):
    bars = 12
    beat_len = 60.0 / bpm
    duration = bars * 4 * beat_len
    frames = int(duration * RATE)
    rng = random.Random(1988 + root)
    left, right = array("h"), array("h")
    noise = 0.0
    # The progression repeats every four bars, so the complete file loops.
    for i in range(frames):
        t = i / RATE
        beat = t / beat_len
        bar = int(beat / 4)
        beat_in_bar = beat % 4
        step = int(beat * 4) % 16
        step_t = (beat * 4) % 1.0
        chord_root = 48 + root + progression[bar % 4]
        chord = [chord_root, chord_root + 4, chord_root + 7]

        # Warm stereo pad with slow opposing movement.
        pad_env = 0.5 - 0.5 * math.cos(min(1.0, beat_in_bar / 0.45) * math.pi)
        pad_l = chord_tone(t, chord) * (0.11 + 0.025*math.sin(TAU*t/7)) * pad_env
        pad_r = chord_tone(t + 0.0035, [n + 12 for n in chord]) * 0.085 * pad_env

        # Rounded bass, one note per beat with a little octave motion.
        bass_note = chord_root - 12 + (12 if int(beat) % 4 == 3 else 0)
        bass_phase = TAU * hz(bass_note) * t
        bass_env = math.exp(-2.8 * (beat % 1.0))
        bass = (0.72*tri(bass_phase) + 0.28*math.sin(bass_phase)) * 0.24 * bass_env

        # Bright arpeggio panned left/right per sixteenth.
        arp_note = chord[step % 3] + 12 + (12 if step in [7, 15] else 0)
        arp_phase = TAU * hz(arp_note) * t
        arp = (math.sin(arp_phase + 0.8*math.sin(arp_phase*2)) + 0.22*tri(arp_phase*2))
        arp *= 0.12 * math.exp(-5.2*step_t)
        arp_pan = -0.45 if step % 2 == 0 else 0.45

        # A short call-and-response lead in bars 2 and 4 of each phrase.
        phrase = bar % 4
        lead = 0.0
        lead_pan = 0.0
        if phrase in [1, 3] and int(beat_in_bar*2) < len(melody):
            mstep = int(beat_in_bar*2)
            note = 72 + root + melody[mstep]
            local = (beat_in_bar*2) % 1.0
            phase = TAU * hz(note) * t
            vibrato = 0.7 * math.sin(TAU*5.2*t)
            lead = math.sin(phase + vibrato + 1.4*math.exp(-5*local)*math.sin(phase*2))
            lead *= 0.16 * math.exp(-1.7*local)
            lead_pan = 0.30 if phrase == 1 else -0.30

        # Sample-free drum machine.
        sub = beat % 1.0
        kick = math.sin(TAU*(95 - 48*min(sub, 0.18))*t) * math.exp(-19*sub) * (0.32 if int(beat)%2 == 0 else 0.23)
        noise = 0.58*noise + 0.42*rng.uniform(-1, 1)
        snare_pos = abs(beat_in_bar - round(beat_in_bar))
        on_backbeat = int(beat_in_bar) in [1, 3]
        snare = noise * math.exp(-27*sub) * (0.23 if on_backbeat else 0.0)
        hat_local = (beat*2) % 1.0
        hat = noise * math.exp(-55*hat_local) * (0.055 if int(beat*2)%2 == 0 else 0.035)

        music_l = pad_l + bass + arp*(1-arp_pan)*0.7 + lead*(1-lead_pan)*0.65 + kick + snare*0.85 + hat
        music_r = pad_r + bass + arp*(1+arp_pan)*0.7 + lead*(1+lead_pan)*0.65 + kick + snare + hat*0.8
        # Gentle master saturation provides cohesion and headroom.
        music_l = math.tanh(music_l*1.25) * 0.72
        music_r = math.tanh(music_r*1.25) * 0.72
        left.append(int(max(-1, min(1, music_l))*32767))
        right.append(int(max(-1, min(1, music_r))*32767))

    # Very short wrap crossfade removes oscillator phase clicks at the loop.
    fade = int(0.06 * RATE)
    for i in range(fade):
        a = i / fade
        li, ri = left[i], right[i]
        left[i] = int(left[-fade+i]*(1-a) + li*a)
        right[i] = int(right[-fade+i]*(1-a) + ri*a)
    interleaved = array("h")
    for l, r in zip(left, right):
        interleaved.append(l)
        interleaved.append(r)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as wav:
        wav.setnchannels(2)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        wav.writeframes(interleaved.tobytes())
    print(f"{name}: {duration:.1f}s")

def main():
    os.makedirs(OUT, exist_ok=True)
    for track in TRACKS:
        render(*track)
    print("Five original stereo arcade music loops written to Assets/Audio/Music")

if __name__ == "__main__":
    main()
