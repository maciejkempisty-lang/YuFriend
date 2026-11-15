#!/usr/bin/env python3
"""Prepare downloaded ElevenLabs one-shots without altering their source files.

Example: python3 tools/prepare_sfx.py --prefix A_single_soft_padded --stem paw_wood --count 4 --max-duration 0.16
"""

import argparse
import array
import hashlib
import json
import math
from pathlib import Path
import re
import shutil
import sys
import wave

ROOT = Path(__file__).resolve().parents[1]
DESTINATION = ROOT / "assets/audio/sfx"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def prepare(source, target, max_duration=None):
    with wave.open(str(source), "rb") as reader:
        channels, width, rate, frames, _, _ = reader.getparams()
        if width != 2 or rate != 48000 or channels not in (1, 2):
            raise ValueError(f"Expected 48 kHz PCM16 mono/stereo source: {source.name}")
        values = array.array("h", reader.readframes(frames))
        if sys.byteorder != "little":
            values.byteswap()
    mono = [sum(values[i:i + channels]) / channels / 32768 for i in range(0, len(values), channels)]
    source_peak = max(abs(sample) for sample in mono)
    source_rms = math.sqrt(sum(sample * sample for sample in mono) / len(mono))
    dc = sum(mono) / len(mono)
    mono = [sample - dc for sample in mono]
    peak = max(abs(sample) for sample in mono)
    if peak < 0.0001:
        raise ValueError(f"Source is effectively silent: {source.name}")
    # Relative threshold retains quiet decays. Padding protects the onset and tail.
    threshold = max(0.000015, peak * 10 ** (-55 / 20))
    active = [index for index, sample in enumerate(mono) if abs(sample) >= threshold]
    start = max(0, active[0] - round(rate * 0.01))
    end = min(len(mono), active[-1] + 1 + round(rate * 0.06))
    if max_duration is not None:
        end = min(end, start + round(rate * max_duration))
    mono = mono[start:end]
    # Avoid magnifying the noise floor of quiet generations without limit.
    gain = min(10 ** (12 / 20), 10 ** (-3 / 20) / peak)
    fade_in, fade_out = round(rate * 0.001), round(rate * (0.02 if max_duration is not None else 0.006))
    pcm = array.array("h")
    for index, sample in enumerate(mono):
        envelope = min(1.0, index / fade_in, (len(mono) - 1 - index) / fade_out)
        pcm.append(round(max(-1.0, min(1.0, sample * gain * envelope)) * 32767))
    output_peak = max(abs(sample) for sample in pcm) / 32768
    output_rms = math.sqrt(sum((sample / 32768) ** 2 for sample in pcm) / len(pcm))
    if sys.byteorder != "little":
        pcm.byteswap()
    with wave.open(str(target), "wb") as writer:
        writer.setparams((1, 2, rate, len(mono), "NONE", "not compressed"))
        writer.writeframes(pcm.tobytes())
    return {
        "source_file": source.name,
        "source_sha256": digest(source),
        "source_channels": channels,
        "source_duration_seconds": frames / rate,
        "source_mono_peak_dbfs": round(20 * math.log10(source_peak), 3),
        "source_mono_rms_dbfs": round(20 * math.log10(source_rms), 3),
        "output_sha256": digest(target),
        "output_duration_seconds": len(mono) / rate,
        "output_peak_dbfs": round(20 * math.log10(output_peak), 3),
        "output_rms_dbfs": round(20 * math.log10(output_rms), 3),
        "removed_dc": dc,
        "gain_db": round(20 * math.log10(gain), 3),
        "trim_start_samples": start,
        "trim_end_samples": frames - end,
        "fade_in_samples": fade_in,
        "fade_out_samples": fade_out,
        "max_duration_seconds": max_duration,
        "format": "PCM16 mono 48000 Hz",
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--prefix", required=True)
    parser.add_argument("--stem", required=True)
    parser.add_argument("--count", type=int, required=True)
    parser.add_argument("--single", action="store_true", help="Do not append _01 to a single output filename")
    parser.add_argument("--first-variant", type=int, default=1, help="First downloaded variant to use (output numbering still starts at 01)")
    parser.add_argument("--max-duration", type=float, help="Keep the first contact only, with a 20 ms fade-out")
    parser.add_argument("--downloads", type=Path, default=Path.home() / "Downloads")
    args = parser.parse_args()
    if not re.fullmatch(r"[a-z_]+", args.stem) or args.count not in range(1, 5):
        parser.error("Use a lowercase underscore stem and 1-4 variants.")
    if args.single and args.count != 1:
        parser.error("--single requires --count 1")
    if args.max_duration is not None and not 0.03 <= args.max_duration <= 3:
        parser.error("--max-duration must be between 0.03 and 3 seconds")
    DESTINATION.mkdir(parents=True, exist_ok=True)
    sources = DESTINATION / "source"
    sources.mkdir(exist_ok=True)
    (sources / ".gdignore").touch()
    manifest_path = DESTINATION / "processing.json"
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {
        "provider": "ElevenLabs Sound Effects v3",
        "processing_script": "tools/prepare_sfx.py",
        "notes": "Technical processing only; acoustic suitability requires listening review. Source recordings preserved byte-for-byte.",
        "files": {},
    }
    for index in range(1, args.count + 1):
        variant = args.first_variant + index - 1
        candidates = sorted(args.downloads.glob(f"{args.prefix}_#{variant}-*.wav"))
        if not candidates:
            raise FileNotFoundError(f"Missing variant {index} for {args.prefix}")
        source = candidates[0]  # Timestamp suffix: preserve the earliest download if duplicated.
        filename = args.stem + ("" if args.single else f"_{index:02d}") + ".wav"
        target = DESTINATION / filename
        entry = prepare(source, target, args.max_duration)
        preserved = sources / filename
        shutil.copyfile(source, preserved)
        entry["preserved_source"] = str(preserved.relative_to(ROOT))
        manifest["files"][filename] = entry
        print(f"{filename}: {entry['output_duration_seconds']:.3f}s, peak {entry['output_peak_dbfs']:.1f} dBFS, rms {entry['output_rms_dbfs']:.1f} dBFS")
    manifest_path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")


if __name__ == "__main__":
    main()
