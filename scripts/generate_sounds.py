#!/usr/bin/env python3
"""
Generate the 4 PEELED game sound effects as small mono 22.05 kHz WAV files
using only the Python stdlib. Output goes into Peeled/app/assets/audio/.

Sound design intent (kept tasteful, short, mobile-friendly):

  peel_pop.wav      — 180 ms percussive pop. Filtered noise + a quick
                       pitch-down sine "boop". Instant feedback for a tap.
  reveal_chime.wav  — 900 ms major-7 arpeggio (C E G B). Three soft bell
                       partials per note, gentle decay. The "yes!" moment
                       after a successful peel.
  miss_whoosh.wav   — 420 ms airy descent: low-passed noise sweeping down
                       in pitch, no transient. The "not this time" sigh.
  open_fanfare.wav  — 1500 ms triumphant rise: held bass, ascending major
                       triad with shimmering harmonics. Big-win cue when a
                       package opens completely.
"""
import math
import struct
import wave
from pathlib import Path
from random import Random

OUT_DIR = Path(__file__).resolve().parent.parent / "Peeled" / "app" / "assets" / "audio"
OUT_DIR.mkdir(parents=True, exist_ok=True)
SR = 22050
RNG = Random(0xC0FFEE)


def envelope(n, attack=0.005, decay=0.0, sustain=1.0, release=0.05):
    """Simple AHR envelope returning a list of length n in [0..1]."""
    out = [0.0] * n
    a = max(1, int(SR * attack))
    r = max(1, int(SR * release))
    s_end = n - r
    for i in range(n):
        if i < a:
            out[i] = i / a
        elif i < s_end:
            out[i] = sustain
        else:
            out[i] = sustain * max(0.0, 1.0 - (i - s_end) / r)
    return out


def low_pass(samples, alpha=0.15):
    """One-pole IIR low-pass to round off harshness."""
    y = 0.0
    out = [0.0] * len(samples)
    for i, x in enumerate(samples):
        y = y + alpha * (x - y)
        out[i] = y
    return out


def normalize(samples, peak=0.85):
    m = max(1e-9, max(abs(x) for x in samples))
    g = peak / m
    return [x * g for x in samples]


def write_wav(path, samples):
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = b"".join(
            struct.pack("<h", max(-32767, min(32767, int(s * 32767))))
            for s in samples
        )
        w.writeframes(frames)


def sine(freq, n, phase=0.0):
    return [math.sin(2 * math.pi * freq * (i / SR) + phase) for i in range(n)]


def add(a, b):
    n = max(len(a), len(b))
    a = a + [0.0] * (n - len(a))
    b = b + [0.0] * (n - len(b))
    return [x + y for x, y in zip(a, b)]


# -----------------------------------------------------------------------------
# 1. peel_pop.wav (180 ms)
# -----------------------------------------------------------------------------
def make_pop():
    n = int(SR * 0.18)
    env = envelope(n, attack=0.001, sustain=1.0, release=0.16)
    # noise burst, gently low-passed
    noise = [(RNG.random() * 2 - 1) for _ in range(n)]
    noise = low_pass(noise, alpha=0.35)
    # pitch-down sine boop: 700 Hz -> 220 Hz
    boop = []
    for i in range(n):
        t = i / n
        f = 700 * (1 - t) + 220 * t
        boop.append(math.sin(2 * math.pi * f * (i / SR)))
    mix = [0.55 * b + 0.35 * nz for b, nz in zip(boop, noise)]
    samples = [m * e for m, e in zip(mix, env)]
    return normalize(samples, peak=0.9)


# -----------------------------------------------------------------------------
# 2. reveal_chime.wav (900 ms, Cmaj7 arpeggio)
# -----------------------------------------------------------------------------
def make_chime():
    notes_hz = [523.25, 659.25, 783.99, 987.77]  # C5 E5 G5 B5
    note_len = int(SR * 0.18)
    sustain = int(SR * 0.45)
    total = note_len * len(notes_hz) + sustain
    out = [0.0] * total
    for idx, f in enumerate(notes_hz):
        start = idx * note_len
        n = total - start
        env = envelope(n, attack=0.005, sustain=1.0, release=0.7)
        # 3 partials for a soft bell sound
        s = sine(f, n)
        s = [a + 0.45 * b for a, b in zip(s, sine(f * 2, n))]
        s = [a + 0.2 * b for a, b in zip(s, sine(f * 3.0, n, phase=math.pi / 4))]
        for i in range(n):
            out[start + i] += 0.4 * s[i] * env[i]
    return normalize(out, peak=0.85)


# -----------------------------------------------------------------------------
# 3. miss_whoosh.wav (420 ms)
# -----------------------------------------------------------------------------
def make_whoosh():
    n = int(SR * 0.42)
    env = envelope(n, attack=0.05, sustain=1.0, release=0.35)
    # Pink-ish noise (low-passed white noise twice)
    noise = [(RNG.random() * 2 - 1) for _ in range(n)]
    noise = low_pass(noise, alpha=0.18)
    noise = low_pass(noise, alpha=0.4)
    # Pitch-shaped via amplitude modulation that descends.
    out = []
    for i in range(n):
        t = i / n
        # Slow descending tonality blended with the noise.
        warp = 0.7 + 0.3 * math.sin(2 * math.pi * (140 * (1 - t) + 60 * t) * (i / SR))
        out.append(noise[i] * warp * env[i])
    return normalize(out, peak=0.7)


# -----------------------------------------------------------------------------
# 4. open_fanfare.wav (1500 ms, ascending major triad with shimmer)
# -----------------------------------------------------------------------------
def make_fanfare():
    n = int(SR * 1.5)
    env = envelope(n, attack=0.02, sustain=1.0, release=0.6)
    # Bass C3
    bass = sine(130.81, n)
    # Triad C4 E4 G4 entering staggered
    triad = [0.0] * n
    voices = [(261.63, 0.0), (329.63, 0.18), (392.00, 0.36)]
    for f, delay in voices:
        s = sine(f, n)
        # Add a gentle 2nd harmonic for sparkle.
        s = [a + 0.35 * b for a, b in zip(s, sine(f * 2, n))]
        d = int(SR * delay)
        for i in range(n - d):
            triad[i + d] += s[i]
    # Shimmer (slow vibrato on a high partial)
    shimmer = []
    for i in range(n):
        t = i / SR
        vib = 1.0 + 0.005 * math.sin(2 * math.pi * 5 * t)
        shimmer.append(math.sin(2 * math.pi * 1568 * vib * t))
    mix = [
        0.35 * b + 0.45 * tr + 0.12 * sh
        for b, tr, sh in zip(bass, triad, shimmer)
    ]
    samples = [m * e for m, e in zip(mix, env)]
    return normalize(samples, peak=0.85)


def main():
    print(f"Writing to {OUT_DIR}")
    write_wav(OUT_DIR / "peel_pop.wav", make_pop())
    write_wav(OUT_DIR / "reveal_chime.wav", make_chime())
    write_wav(OUT_DIR / "miss_whoosh.wav", make_whoosh())
    write_wav(OUT_DIR / "open_fanfare.wav", make_fanfare())
    for p in sorted(OUT_DIR.glob("*.wav")):
        print(f"  {p.name}: {p.stat().st_size:,} bytes")


if __name__ == "__main__":
    main()
