"""Regenerate every game sound into assets/sounds/.

Usage (from the repository root, needs ffmpeg on PATH):
    python tools/audio/build.py
"""

import pathlib
import subprocess
import sys
import tempfile

sys.path.insert(0, str(pathlib.Path(__file__).parent))

from music import SONGS, render  # noqa: E402
from sfx import EFFECTS  # noqa: E402

OUTPUT = pathlib.Path(__file__).resolve().parents[2] / "assets" / "sounds"


def encode(wav_path, target):
    codec = ["-c:a", "libvorbis", "-q:a", "5"] if target.suffix == ".ogg" else \
            ["-c:a", "libmp3lame", "-q:a", "3"]
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav_path), *codec,
                    "-map_metadata", "-1", str(target)], check=True)


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    jobs = [(name, recipe) for name, recipe in EFFECTS.items()]
    jobs += [(name, lambda song=song: render(song)) for name, song in SONGS.items()]
    with tempfile.TemporaryDirectory() as tmp:
        for name, recipe in jobs:
            wav = pathlib.Path(tmp) / (pathlib.Path(name).stem + ".wav")
            recipe().write(str(wav))
            encode(wav, OUTPUT / name)
            print("built", name)


if __name__ == "__main__":
    main()
