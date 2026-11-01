"""Sound effect recipes. Each function returns a rendered Track."""

from synth import Track, note_freq, square, triangle, saw


def jump():
    t = Track(0.3)
    t.add_tone(0, 0.16, 260, lambda p: square(p, 0.25), 0.4, freq_end=620,
               decay=0.08, sustain=0.5, release=0.08)
    return t


def hurt():
    t = Track(0.35)
    t.add_tone(0, 0.18, 420, lambda p: square(p, 0.5), 0.35, freq_end=140, release=0.1)
    t.add_noise(0, 0.12, 0.25, smoothing=0.3, seed=1)
    return t


def dead():
    t = Track(1.6)
    for i, n in enumerate(["A4", "F4", "D4", "A3"]):
        t.add_tone(i * 0.18, 0.16, note_freq(n), lambda p: square(p, 0.5), 0.3,
                   freq_end=note_freq(n) * 0.97, release=0.06)
    t.add_tone(0.72, 0.6, note_freq("D3"), triangle, 0.45, freq_end=note_freq("D2"),
               release=0.25, vibrato=0.02)
    return t


def explosion():
    t = Track(1.4)
    t.add_noise(0, 1.3, 0.8, smoothing=0.85, decay_power=2.2, seed=2)
    t.add_tone(0, 0.5, 90, triangle, 0.6, freq_end=35, release=0.2)
    return t


def coin():
    t = Track(0.35)
    t.add_tone(0, 0.06, note_freq("B5"), lambda p: square(p, 0.5), 0.3, release=0.02)
    t.add_tone(0.06, 0.18, note_freq("E6"), lambda p: square(p, 0.5), 0.3,
               decay=0.12, sustain=0.4, release=0.08)
    return t


def potion():
    t = Track(0.8)
    for i, n in enumerate(["D5", "F#5", "A5", "D6"]):
        t.add_tone(i * 0.08, 0.1, note_freq(n), triangle, 0.45, release=0.05)
    t.add_tone(0.32, 0.3, note_freq("D6"), lambda p: square(p, 0.125), 0.15,
               release=0.15, vibrato=0.01)
    return t


def punch():
    t = Track(0.2)
    t.add_noise(0, 0.12, 0.7, smoothing=0.75, decay_power=1.5, seed=3)
    t.add_tone(0, 0.08, 150, triangle, 0.7, freq_end=60, release=0.04)
    return t


def slash():
    t = Track(0.25)
    t.add_noise(0, 0.18, 0.5, smoothing=0.05, decay_power=1.2, seed=4)
    t.add_tone(0, 0.12, 1400, saw, 0.12, freq_end=500, release=0.05)
    return t


def footsteps():
    """Seamless loop: one step every 0.27 s (matches the run animation pace)."""
    step = 0.27
    t = Track(step * 8)
    for i in range(8):
        t.add_noise(i * step, 0.06, 0.5 if i % 2 == 0 else 0.4,
                    smoothing=0.8, decay_power=2.0, seed=10 + i)
    return t


EFFECTS = {
    "jump.mp3": jump,
    "male_hurt.mp3": hurt,
    "dead.mp3": dead,
    "explosion.mp3": explosion,
    "pickup.mp3": coin,
    "pickup_life.ogg": potion,
    "punch.mp3": punch,
    "slash.mp3": slash,
    "running.mp3": footsteps,
}
