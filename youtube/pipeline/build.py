"""Assemble a script's frames and narration into a vertical mp4."""

import subprocess
from pathlib import Path

import config as C
import frames
import voice


def build_video(script: dict, work: Path) -> Path:
    """Render frames, narrate them, and mux into work/short.mp4."""
    voice.require("ffmpeg", "Install with: brew install ffmpeg")
    work.mkdir(parents=True, exist_ok=True)

    scenes = frames.build_scenes(script, work / "frames")
    chosen = voice.pick_voice()

    # Narrate each speaking scene; a scene lasts as long as its line, floored by
    # its minimum so the countdown and the answer card never flash past.
    audio_dir = work / "audio"
    for i, sc in enumerate(scenes):
        if sc["say"]:
            aiff = voice.speak(sc["say"], audio_dir / f"{i:02d}.aiff", chosen)
            sc["audio"] = aiff
            sc["dur"] = max(sc["min"], voice.duration(aiff) + C.SCENE_PAD)
        else:
            sc["audio"] = None
            sc["dur"] = sc["min"]

    # Video track: a concat list of stills with explicit durations.
    concat = work / "frames.txt"
    lines = []
    for sc in scenes:
        lines.append(f"file '{sc['png'].resolve()}'")
        lines.append(f"duration {sc['dur']:.3f}")
    lines.append(f"file '{scenes[-1]['png'].resolve()}'")  # concat needs the last frame twice
    concat.write_text("\n".join(lines) + "\n")

    silent = work / "silent.mp4"
    subprocess.run([
        "ffmpeg", "-y", "-f", "concat", "-safe", "0", "-i", str(concat),
        # No -vsync here: ffmpeg 7 rejects it alongside -r, and -r alone already
        # gives a constant-frame-rate track, which is what YouTube wants.
        "-r", str(C.FPS), "-pix_fmt", "yuv420p",
        "-c:v", "libx264", "-preset", "medium", "-crf", "20",
        "-movflags", "+faststart",
        str(silent),
    ], check=True, capture_output=True)

    # Audio track: narration placed at each scene's start offset, padded to length.
    total = sum(sc["dur"] for sc in scenes)
    spoken = [(sc, off) for sc, off in _offsets(scenes) if sc["audio"]]
    if not spoken:
        silent.replace(work / "short.mp4")
        return work / "short.mp4"

    inputs, filters, labels = [], [], []
    for n, (sc, off) in enumerate(spoken):
        inputs += ["-i", str(sc["audio"])]
        filters.append(f"[{n}:a]adelay={int(off * 1000)}|{int(off * 1000)},aresample=44100[a{n}]")
        labels.append(f"[a{n}]")
    filters.append(f"{''.join(labels)}amix=inputs={len(labels)}:normalize=0[mixed]")
    filters.append(f"[mixed]apad,atrim=0:{total:.3f}[out]")

    narration = work / "narration.m4a"
    subprocess.run(
        ["ffmpeg", "-y", *inputs, "-filter_complex", ";".join(filters),
         "-map", "[out]", "-c:a", "aac", "-b:a", "192k", str(narration)],
        check=True, capture_output=True,
    )

    out = work / "short.mp4"
    subprocess.run([
        "ffmpeg", "-y", "-i", str(silent), "-i", str(narration),
        "-c:v", "copy", "-c:a", "aac", "-shortest", str(out),
    ], check=True, capture_output=True)
    return out


def _offsets(scenes):
    t = 0.0
    for sc in scenes:
        yield sc, t
        t += sc["dur"]
