#!/usr/bin/env python3
"""P5-05 程序化音效生成：五类基础音效（发射/击碎/合成/通关/失败）。
纯标准库合成 16bit mono 22050Hz WAV，无外部素材、无许可风险。
用法：python3 tools/gen_sfx.py
"""
import math
import os
import struct
import wave

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "sfx")


def write_wav(name: str, samples: list[float]) -> None:
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        frames = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767)) for s in samples)
        w.writeframes(frames)
    print(f"wrote {path} ({len(samples) / RATE:.2f}s)")


def tone(freq: float, dur: float, decay: float = 8.0, volume: float = 0.5) -> list[float]:
    n = int(RATE * dur)
    return [volume * math.sin(2 * math.pi * freq * i / RATE) * math.exp(-decay * i / n) for i in range(n)]


def sweep(f0: float, f1: float, dur: float, decay: float = 6.0, volume: float = 0.5) -> list[float]:
    n = int(RATE * dur)
    out = []
    phase = 0.0
    for i in range(n):
        f = f0 + (f1 - f0) * i / n
        phase += 2 * math.pi * f / RATE
        out.append(volume * math.sin(phase) * math.exp(-decay * i / n))
    return out


def concat(*parts: list[float]) -> list[float]:
    out: list[float] = []
    for p in parts:
        out.extend(p)
    return out


def mix(a: list[float], b: list[float]) -> list[float]:
    n = max(len(a), len(b))
    return [(a[i] if i < len(a) else 0.0) + (b[i] if i < len(b) else 0.0) for i in range(n)]


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    write_wav("fire", tone(880, 0.12, 10.0))
    write_wav("shatter", mix(sweep(1200, 400, 0.18, 8.0, 0.4), tone(2400, 0.06, 20.0, 0.2)))
    write_wav("merge", mix(tone(660, 0.15, 8.0), tone(990, 0.15, 8.0)))
    write_wav("win", concat(tone(523, 0.18, 4.0), tone(659, 0.18, 4.0), tone(784, 0.3, 4.0)))
    write_wav("lose", sweep(440, 220, 0.6, 3.0))


if __name__ == "__main__":
    main()
