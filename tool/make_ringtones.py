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
    # Peaks above that (a pluck's attack) are rounded off rather than the
    # whole tone turned down.
    x = 0.95 * np.tanh(x / 0.95)
    with wave.open(f'{OUT}/{name}.wav', 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype('<i2').tobytes())


def pluck(f, dur, decay=0.996):
    """Karplus-Strong plucked string (the harp)."""
    n = int(dur * SR)
    period = int(SR / f)
    # A softened noise burst: a warmer pluck, less hiss.
    buf = np.convolve(np.random.uniform(-1, 1, period + 6), np.ones(6) / 6, 'valid')[:period]
    out = np.zeros(n)
    for i in range(n):
        out[i] = buf[i % period]
        buf[i % period] = decay * 0.5 * (out[i] + buf[(i + 1) % period])
    return out * env(np.arange(n) / SR, 0.006, dur)


def fm_bell(f, dur, ratio=3.5, index=2.5, decay=1.2):
    """Glassy FM bell — the modern, clean chime sound."""
    t = np.arange(int(dur * SR)) / SR
    mod = index * np.exp(-t / (decay * 0.4)) * np.sin(2 * np.pi * f * ratio * t)
    return np.sin(2 * np.pi * f * t + mod) * env(t, 0.003, decay)


def xylo(f, dur):
    t = np.arange(int(dur * SR)) / SR
    out = np.sin(2 * np.pi * f * t) * env(t, 0.001, 0.35)
    out += 0.5 * np.sin(2 * np.pi * f * 3.93 * t) * env(t, 0.001, 0.06)
    return out


def kalimba(f, dur):
    t = np.arange(int(dur * SR)) / SR
    out = np.sin(2 * np.pi * f * t) * env(t, 0.002, 0.7)
    out += 0.3 * np.sin(2 * np.pi * f * 5.4 * t) * env(t, 0.001, 0.05)
    out += 0.15 * np.sin(2 * np.pi * f * 2 * t) * env(t, 0.002, 0.3)
    return out


def triangle_hit(f, dur):
    t = np.arange(int(dur * SR)) / SR
    out = np.zeros_like(t)
    for r, a, d in [(1, 1, 1.4), (2.76, 0.6, 1.0), (5.4, 0.4, 0.7), (8.9, 0.25, 0.5)]:
        out += a * np.sin(2 * np.pi * f * r * t + r) * env(t, 0.001, d)
    return out


def square(f, dur, decay=0.25):
    """8-bit square, band-limited to a few odd harmonics."""
    t = np.arange(int(dur * SR)) / SR
    out = sum(np.sin(2 * np.pi * f * k * t) / k for k in (1, 3, 5, 7, 9))
    edge = np.clip(np.minimum(t, dur - t) / 0.003, 0, 1)
    return out * edge * np.exp(-t / decay)


def bubble(f, dur=0.12):
    t = np.arange(int(dur * SR)) / SR
    glide = f * (1 + 0.9 * t / dur)
    phase = 2 * np.pi * np.cumsum(glide) / SR
    return np.sin(phase) * env(t, 0.004, 0.05)


def pad(f, dur):
    """Soft detuned synth pad note with a slow swell."""
    t = np.arange(int(dur * SR)) / SR
    out = sum(np.sin(2 * np.pi * f * d * t) for d in (0.997, 1.0, 1.003)) / 3
    out += 0.25 * np.sin(2 * np.pi * f * 2 * t)
    a = np.clip(t / 0.25, 0, 1)
    return out * a * np.exp(-t / 1.4)


def trill(f1, f2, dur, rate=16):
    """The building intercom's electronic warble: two tones alternating."""
    t = np.arange(int(dur * SR)) / SR
    sel = (np.floor(t * rate) % 2).astype(bool)
    phase = 2 * np.pi * np.cumsum(np.where(sel, f2, f1)) / SR
    out = np.sin(phase) + 0.25 * np.sin(3 * phase)
    edge = np.clip(np.minimum(t, dur - t) / 0.01, 0, 1)
    return out * edge


def mech_bell(dur, rate=22):
    """An electric bell: a hammer striking a gong many times a second."""
    out = np.zeros(int((dur + 0.8) * SR))
    for k in range(int(dur * rate)):
        hit = bell(1250, 0.8, 0.5, 1.4) * (0.7 + 0.3 * np.random.rand())
        i = int(k / rate * SR)
        out[i:i + len(hit)] += hit[:len(out) - i]
    return out


np.random.seed(7)
save('dingdong', sequence([(0, bell(note('E5'), 2.6)), (0.55, bell(note('C5'), 2.4))], 3.0))
save('westminster', sequence([(i * 0.6, bell(note(n), 2.4, 1.8)) for i, n in enumerate(['E5', 'C5', 'D5', 'G4'])], 4.4))
save('tres_tons', sequence([(i * 0.28, bell(note(n), 2.2, 1.4, 0.7)) for i, n in enumerate(['C5', 'E5', 'G5'])], 2.9))
save('carrilhao', sequence([(i * 0.22, bell(note(n), 2.6, 2.0, 1.2)) for i, n in enumerate(['G5', 'F5', 'E5', 'D5', 'C5'])], 3.6))
save('marimba', sequence([(i * 0.16, marimba(note(n), 0.9)) for i, n in enumerate(['G5', 'E5', 'C5', 'E5', 'G5', 'C6'])], 1.9))
save('suave', sequence([(0, soft(note('A4'), 2.2)), (0.7, soft(note('D5'), 2.2))], 3.1))
save('digital', sequence([(b * 0.55 + i * 0.065, beep([1046.5, 1318.5][i % 2], 0.055)) for b in range(3) for i in range(6)], 1.75))

# Intercomunicador: what building-entry monitors play.
save('portaria', sequence([(b * 0.55, trill(800, 1000, 0.42)) for b in range(3)], 1.75))
save('trrrim', sequence([(0, mech_bell(1.1))], 2.0))
save('melodia', sequence([(i * 0.2, bell(note(n), 1.6, 0.9, 0.9)) for i, n in enumerate(['C6', 'G5', 'E5', 'G5', 'C6', 'E6'])], 2.4))
save('dois_toques', sequence([(b * 0.9 + i * 0.22, fm_bell(note(n), 1.0, 2.0, 1.2, 0.6)) for b in range(2) for i, n in enumerate(['A5', 'E5'])], 2.4))
# Modernos: smart-doorbell style tones.
save('harpa', sequence([(i * 0.07, 0.6 * pluck(note(n), 1.8)) for i, n in enumerate(['C4', 'E4', 'G4', 'C5', 'E5', 'G5', 'C6', 'E6'])], 2.4))
save('xilofone', sequence([(i * 0.11, xylo(note(n), 0.6)) for i, n in enumerate(['C5', 'D5', 'E5', 'G5', 'A5', 'C6', 'G5', 'C6'])], 1.6))
save('triangulo', sequence([(i * 0.45, triangle_hit(1660, 1.6)) for i in range(3)], 2.6))
save('kalimba', sequence([(i * 0.18, kalimba(note(n), 1.2)) for i, n in enumerate(['E5', 'G5', 'B5', 'E6', 'D6', 'B5'])], 2.3))
save('vidro', sequence([(i * 0.32, fm_bell(note(n), 1.8, 3.5, 1.6)) for i, n in enumerate(['E6', 'B5', 'G#5'])], 2.6))
save('bolhas', sequence([(i * 0.13, bubble(f)) for i, f in enumerate([520, 660, 590, 780, 700, 940])], 1.1))
save('pulsar', sequence([(i * 0.12, fm_bell(note(n), 0.9, 1.0, 1.6, 0.35)) for i, n in enumerate(['A4', 'C#5', 'E5', 'A5', 'E5', 'C#5', 'A5'])] + [(0, 0.5 * pad(note('A3'), 2.2))], 2.3))
save('retro', sequence([(i * 0.1, square(note(n), 0.09 if i < 5 else 0.4)) for i, n in enumerate(['E5', 'G5', 'E6', 'C6', 'D6', 'G6'])], 1.2))
save('aurora', sequence([(i * 0.45, pad(note(n), 2.2)) for i, n in enumerate(['D4', 'F#4', 'A4', 'D5'])], 3.6))
