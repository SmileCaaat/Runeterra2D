from __future__ import annotations

import math
import random
import struct
import wave
from pathlib import Path

SAMPLE_RATE = 48_000
OUTPUT_DIR = Path(__file__).resolve().parents[2] / "assets" / "audio" / "combat"


def _write_wav(path: Path, samples: list[float], peak: float = 0.92) -> None:
    maximum = max(abs(sample) for sample in samples) or 1.0
    gain = peak / maximum
    pcm = bytearray()
    for sample in samples:
        shaped = math.tanh(sample * gain * 1.15) / math.tanh(1.15)
        pcm.extend(struct.pack("<h", int(max(-1.0, min(1.0, shaped)) * 32767)))
    with wave.open(str(path), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(SAMPLE_RATE)
        output.writeframes(pcm)


def _synthesize_attack() -> list[float]:
    duration = 0.34
    count = int(duration * SAMPLE_RATE)
    rng = random.Random(0xA771AC)
    samples: list[float] = []
    phase = 0.0
    previous_noise = 0.0
    high_pass = 0.0
    smoothed = 0.0

    for index in range(count):
        t = index / SAMPLE_RATE
        progress = t / duration
        attack = min(1.0, t / 0.025)
        envelope = attack * (1.0 - progress) ** 1.8
        frequency = 920.0 * (1.0 - progress) ** 2 + 130.0
        phase += math.tau * frequency / SAMPLE_RATE

        noise = rng.uniform(-1.0, 1.0)
        high_pass = 0.94 * (high_pass + noise - previous_noise)
        previous_noise = noise
        smoothed += 0.24 * (high_pass - smoothed)
        air_pulse = 0.65 + 0.35 * math.sin(math.tau * (7.0 * t + 13.0 * t * t))
        tonal_edge = math.sin(phase) * math.exp(-5.0 * t)
        samples.append((0.78 * smoothed * air_pulse + 0.22 * tonal_edge) * envelope)
    return samples


def _synthesize_hit() -> list[float]:
    duration = 0.28
    count = int(duration * SAMPLE_RATE)
    rng = random.Random(0xB17F00D)
    samples: list[float] = []
    low_phase = 0.0
    previous_noise = 0.0

    for index in range(count):
        t = index / SAMPLE_RATE
        progress = t / duration
        low_frequency = 145.0 - 78.0 * progress
        low_phase += math.tau * low_frequency / SAMPLE_RATE
        thump = math.sin(low_phase) * math.exp(-15.0 * t)

        noise = rng.uniform(-1.0, 1.0)
        crack = (noise - previous_noise) * math.exp(-48.0 * t)
        previous_noise = noise
        wood = (
            math.sin(math.tau * 235.0 * t)
            + 0.55 * math.sin(math.tau * 430.0 * t + 0.4)
            + 0.25 * math.sin(math.tau * 790.0 * t + 1.1)
        ) * math.exp(-19.0 * t)
        tail = rng.uniform(-1.0, 1.0) * 0.08 * (1.0 - progress) * math.exp(-7.0 * t)
        samples.append(0.72 * thump + 0.48 * crack + 0.34 * wood + tail)
    return samples


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    attack_path = OUTPUT_DIR / "garen_attack_swing.wav"
    hit_path = OUTPUT_DIR / "training_dummy_hit.wav"
    _write_wav(attack_path, _synthesize_attack(), 0.86)
    _write_wav(hit_path, _synthesize_hit(), 0.92)
    print(f"Wrote {attack_path}")
    print(f"Wrote {hit_path}")


if __name__ == "__main__":
    main()
