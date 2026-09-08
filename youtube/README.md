# Real or Machine — autonomous channel

A daily guessing game plus the content pipeline that feeds a YouTube Shorts channel.

Viewers read a short passage and decide whether a person or a machine wrote it,
then learn the specific tell. Every "human" specimen is genuine public-domain
writing (pre-1930) with a real attribution; every "machine" specimen is written
fresh by an AI for the game. No scraped text, no copyright exposure.

## Live pages
- Game: https://claude.ai/code/artifact/79e4a7e8-8a5c-42b8-872d-f60a4aa4cbeb
- Production desk: https://claude.ai/code/artifact/e02a6468-51e7-4650-8904-2d31a03820c7

`game.html` and `desk.html` are the sources for those two pages. Republishing
either one to its URL updates the live page in place.

## Scheduled jobs (all times US Eastern)
| Slot | Fires | Does |
|---|---|---|
| Morning | 7:00am | Writes one Short script to the desk |
| Afternoon | 1:00pm | Writes one Short script (the argumentative one) |
| Evening | 7:00pm | Writes one Short script, then adds two new specimens to the game |

Each run appends a document to the desk's `scripts` collection. The desk page
reads that collection live, so new scripts appear without a redeploy.

## Script schema (`scripts/<YYYY-MM-DD>-<slot>`)
date, slot, createdAt, posted, answer ("human" | "ai"), specimen, attribution,
hook, tell, title, caption, cta, tags[]

## Game corpus
`CORPUS` in `game.html`. Entries are `{c, src, by?, t, tell}` — `src` is
`"human"` or `"ai"`, `by` is the attribution (human entries only), `tell`
allows `<b>` on the giveaway phrase. Five specimens per day, date-seeded, so
every player sees the same set.

## The video pipeline (`pipeline/`)
Runs on the Mac, not in the cloud, so the YouTube credentials never leave the
machine. `run.py` pulls the repo, finds any script in `scripts/` that has not
been posted, renders it to a vertical mp4, uploads it, and records the video id
in `build/uploaded.json` so it is never posted twice.

| File | Does |
|---|---|
| `config.py` | Paths, palette, fonts, timings, privacy setting |
| `frames.py` | Draws each scene as a 1080x1920 PNG (verse keeps its own line breaks) |
| `voice.py` | Narration via macOS `say`; durations via ffprobe |
| `build.py` | Frames + narration into one mp4; each scene lasts as long as its line |
| `upload.py` | OAuth and resumable upload to YouTube |
| `run.py` | The orchestrator — `--dry-run` renders without uploading |
| `auth.py` | One-time browser authorisation |
| `SETUP.md` | Click-by-click Google Cloud setup |

Needs `brew install ffmpeg` and `pip3 install -r pipeline/requirements.txt`.
Secrets live in `~/.realormachine/`, outside the repo. `build/` is git-ignored.

Scheduled with launchd (`com.realormachine.pipeline.plist`) half an hour after
each writing job, so the script has landed before the renderer looks for it.
