"""Synthesizes the kiosk's doorbell ringtones into assets/ringtones/*.wav.

Pure additive synthesis (no samples, so no licensing): bell and chime
partials with exponential decays, a soft room reverb, normalised to the
same loudness so the volume slider means the same thing for each tone.
Run from the repo root: python3 tool/make_ringtones.py
"""
import wave

import numpy as np

SR = 22050
OUT = 'assets/ringtones'


def note(name):
    names = {'C': -9, 'D': -7, 'E': -5, 'F': -4, 'G': -2, 'A': 0, 'B': 2}
    n = names[name[0]] + (1 if '#' in name else 0)
    octave = int(name[-1])
    return 440.0 * 2 ** ((n + (octave - 4) * 12) / 12)


def env(t, attack, decay):
    a = np.clip(t / attack, 0, 1) if attack > 0 else 1
    return a * np.exp(-t / decay)


def bell(f, dur, decay=1.6, bright=1.0):
    """A tuned chime bar / tubular bell: hum, fundamental, minor third,
    fifth, octave and a few inharmonic upper partials."""
    t = np.arange(int(dur * SR)) / SR
    partials = [(0.5, 0.35, 1.3), (1.0, 1.0, 1.0), (1.19, 0.30 * bright, 0.7), (1.5, 0.22 * bright, 0.6),
                (2.0, 0.40 * bright, 0.5), (2.76, 0.18 * bright, 0.3), (3.4, 0.10 * bright, 0.2), (5.4, 0.06 * bright, 0.12)]
    out = np.zeros_like(t)
    for ratio, amp, d in partials:
        out += amp * np.sin(2 * np.pi * f * ratio * t + np.random.rand() * 6) * env(t, 0.002, decay * d)
    return out


def marimba(f, dur):
    t = np.arange(int(dur * SR)) / SR
    out = np.sin(2 * np.pi * f * t) * env(t, 0.003, 0.45)
    out += 0.25 * np.sin(2 * np.pi * f * 4 * t) * env(t, 0.001, 0.08)
    out += 0.08 * np.sin(2 * np.pi * f * 10 * t) * env(t, 0.001, 0.03)
    return out


def soft(f, dur):
    t = np.arange(int(dur * SR)) / SR
    out = np.sin(2 * np.pi * f * t) + 0.18 * np.sin(2 * np.pi * f * 2 * t) + 0.06 * np.sin(2 * np.pi * f * 3 * t)
    return out * env(t, 0.06, 0.9)


def beep(f, dur):
    t = np.arange(int(dur * SR)) / SR
    out = np.sin(2 * np.pi * f * t) + 0.2 * np.sin(2 * np.pi * f * 3 * t)
    edge = np.clip(np.minimum(t, dur - t) / 0.004, 0, 1)
    return out * edge


def sequence(events, length):
    out = np.zeros(int(length * SR))
    for start, sound in events:
        i = int(start * SR)
        n = min(len(sound), len(out) - i)
        out[i:i + n] += sound[:n]
    return out


def reverb(x, mix=0.18):
    out = x.copy()
    for delay, gain in [(0.029, 0.5), (0.037, 0.45), (0.041, 0.4), (0.053, 0.35)]:
        d = int(delay * SR)
        y = np.zeros_like(x)
        for k in range(1, 12):
            if d * k >= len(x):
                break
            y[d * k:] += x[:len(x) - d * k] * gain ** k
        out += mix * y / 4
    return out


def save(name, x):
    x = reverb(x)
    fade = int(0.05 * SR)
    x[-fade:] *= np.linspace(1, 0, fade)
    # Same loudness for every tone (RMS), with peaks kept below clipping.
    x *= 0.18 / np.sqrt(np.mean(x ** 2))
    x *= min(1, 0.95 / np.max(np.abs(x)))
    with wave.open(f'{OUT}/{name}.wav', 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype('<i2').tobytes())


np.random.seed(7)
save('dingdong', sequence([(0, bell(note('E5'), 2.6)), (0.55, bell(note('C5'), 2.4))], 3.0))
save('westminster', sequence([(i * 0.6, bell(note(n), 2.4, 1.8)) for i, n in enumerate(['E5', 'C5', 'D5', 'G4'])], 4.4))
save('tres_tons', sequence([(i * 0.28, bell(note(n), 2.2, 1.4, 0.7)) for i, n in enumerate(['C5', 'E5', 'G5'])], 2.9))
save('carrilhao', sequence([(i * 0.22, bell(note(n), 2.6, 2.0, 1.2)) for i, n in enumerate(['G5', 'F5', 'E5', 'D5', 'C5'])], 3.6))
save('marimba', sequence([(i * 0.16, marimba(note(n), 0.9)) for i, n in enumerate(['G5', 'E5', 'C5', 'E5', 'G5', 'C6'])], 1.9))
save('suave', sequence([(0, soft(note('A4'), 2.2)), (0.7, soft(note('D5'), 2.2))], 3.1))
save('digital', sequence([(b * 0.55 + i * 0.065, beep([1046.5, 1318.5][i % 2], 0.055)) for b in range(3) for i in range(6)], 1.75))
