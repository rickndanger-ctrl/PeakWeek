"""Narration via macOS `say`, plus duration probing via ffprobe."""

from __future__ import annotations

import json
import shutil
import subprocess
from pathlib import Path

import config as C


class MissingTool(RuntimeError):
    pass


def require(tool: str, install_hint: str) -> str:
    path = shutil.which(tool)
    if not path:
        raise MissingTool(f"`{tool}` is not installed. {install_hint}")
    return path


def _voices() -> set[str]:
    try:
        out = subprocess.run(["say", "-v", "?"], capture_output=True, text=True, timeout=20)
        return {line.split()[0] for line in out.stdout.splitlines() if line.strip()}
    except Exception:
        return set()


def pick_voice() -> str:
    installed = _voices()
    if not installed:
        return C.VOICE
    for name in (C.VOICE, C.FALLBACK_VOICE):
        if name in installed:
            return name
    return sorted(installed)[0]


def speak(text: str, out: Path, voice: str | None = None) -> Path:
    """Render narration to an AIFF file. Returns the path."""
    require("say", "It ships with macOS — this pipeline needs to run on your Mac.")
    out.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        ["say", "-v", voice or pick_voice(), "-r", str(C.VOICE_RATE), "-o", str(out), text],
        check=True,
    )
    return out


def duration(path: Path) -> float:
    """Length of an audio or video file in seconds."""
    require("ffprobe", "Install with: brew install ffmpeg")
    out = subprocess.run(
        ["ffprobe", "-v", "quiet", "-print_format", "json", "-show_format", str(path)],
        capture_output=True, text=True, check=True,
    )
    return float(json.loads(out.stdout)["format"]["duration"])
