#!/usr/bin/env python3
"""Render and upload every script that has not been posted yet.

    python3 run.py              # pull, render, upload everything pending
    python3 run.py --dry-run    # render only, upload nothing
    python3 run.py --one        # stop after the first pending script

Safe to run on a schedule: already-uploaded scripts are recorded in
youtube/build/uploaded.json and skipped forever after.
"""

import argparse
import json
import subprocess
import sys
import traceback
from datetime import datetime, timezone
from pathlib import Path

import config as C


def log(msg: str) -> None:
    print(f"[{datetime.now().strftime('%H:%M:%S')}] {msg}", flush=True)


def load_state() -> dict:
    if C.STATE_FILE.exists():
        try:
            return json.loads(C.STATE_FILE.read_text())
        except json.JSONDecodeError:
            log("uploaded.json was unreadable; treating everything as unposted")
    return {}


def save_state(state: dict) -> None:
    C.STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    C.STATE_FILE.write_text(json.dumps(state, indent=2, sort_keys=True))


def git_pull() -> None:
    """Pick up scripts the scheduled jobs pushed since the last run."""
    try:
        subprocess.run(["git", "-C", str(C.REPO), "pull", "--ff-only", "--quiet"],
                       check=True, capture_output=True, timeout=120)
        log("pulled latest scripts")
    except subprocess.CalledProcessError as e:
        log(f"git pull failed ({e.stderr.decode().strip()[:120]}) — using local scripts")
    except (subprocess.TimeoutExpired, FileNotFoundError):
        log("git pull unavailable — using local scripts")


REQUIRED = ("title", "hook", "specimen", "tell", "answer")


def pending(state: dict) -> list[tuple[str, dict]]:
    if not C.SCRIPTS_DIR.exists():
        return []
    out = []
    for path in sorted(C.SCRIPTS_DIR.glob("*.json")):
        key = path.stem
        if key in state:
            continue
        try:
            script = json.loads(path.read_text())
        except json.JSONDecodeError as e:
            log(f"skipping {path.name}: not valid JSON ({e})")
            continue
        missing = [f for f in REQUIRED if not script.get(f)]
        if missing:
            log(f"skipping {path.name}: missing {', '.join(missing)}")
            continue
        out.append((key, script))
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true", help="render but do not upload")
    ap.add_argument("--one", action="store_true", help="stop after the first script")
    ap.add_argument("--no-pull", action="store_true", help="skip git pull")
    args = ap.parse_args()

    if not args.no_pull:
        git_pull()

    state = load_state()
    todo = pending(state)
    if not todo:
        log("nothing pending")
        return 0
    log(f"{len(todo)} script(s) pending")

    import build  # imported late so --help works without Pillow installed

    failures = 0
    for key, script in todo:
        try:
            log(f"building {key}: {script['title']}")
            video = build.build_video(script, C.BUILD_DIR / key)
            size_mb = video.stat().st_size / 1e6
            log(f"  rendered {video.name} ({size_mb:.1f} MB)")

            if args.dry_run:
                log("  dry run — not uploading")
            else:
                import upload
                vid = upload.upload(video, script)
                state[key] = {
                    "video_id": vid,
                    "url": f"https://youtube.com/shorts/{vid}",
                    "title": script["title"],
                    "uploaded_at": datetime.now(timezone.utc).isoformat(),
                }
                save_state(state)
                log(f"  uploaded → https://youtube.com/shorts/{vid}")
        except Exception:
            failures += 1
            log(f"  FAILED on {key}")
            traceback.print_exc()
        if args.one:
            break

    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
