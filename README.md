# Peak Week — powerlifting coaching console for Mac

A native SwiftUI app for coaching powerlifters with block periodization:
build each lifter's meet prep, customize everything, and send every week's
plan straight to their phone.

## Build it (one time, ~2 minutes)
Open Terminal, drag this folder onto the window after typing `cd `, press Enter, then:

    ./build.sh

Or simpler — open this folder in Claude Code and say: **"Read CLAUDE.md and build this."**

If Terminal says Swift is missing, run `xcode-select --install`, accept the popup,
then run `./build.sh` again.

Run the test suite any time with `swift test` (57 tests lock the programming math).

## Program
- Client roster in the sidebar — lifters with maxes (lb/kg with true conversion), meet date, and countdown
- Pick phase (full prep / accumulation / strength / peaking / off-season), length, **4-day or 5-day** weeks
- Generate → block-periodized program with linear weekly progression; every week shows its weeks-out
- Every exercise swappable, every set/rep/%/RPE editable, loads recalc live

## Customize (Coaching Options + ⌘,)
- **Exercise library** (Settings, ⌘,): rename anything, tune load modifiers, archive
  what you don't use, add your own exercises — saved programs follow along by identity,
  never by position
- **Attempt profiles** per client: Conservative / Standard / Aggressive risk presets
  (Standard = the classic 91 / 97 / 101.5) plus explicit per-attempt overrides
- **Per-lift programming**: training-max %, intensity offset (e.g. −2.5% for a deadlift
  that runs hot)
- **Exclusions**: injury/equipment bans swapped out at generation
- Client notes: federation, equipment, cues

## Deliver
- **Send menu on every week**: share as text or PDF (Messages / Mail / AirDrop), save PDF, copy
- **Auto-send**: pick a day + time per client (e.g. Sunday 6 PM) and each week's plan
  goes out via Messages or Mail — with *review before sending* on by default, deliveries
  queue behind the paperplane toolbar icon for one-click approval
- Full send log: every delivery recorded; missed weeks never spam (only the latest
  due week goes out after downtime)

## Where your data lives
`~/Library/Application Support/PeakWeek/data.json` — debounce-saved on every change,
with an automatic `data.json.bak` safety copy rotated before each write. If the file
is ever unreadable the app freezes writes and offers one-click restore — it will
never overwrite data it couldn't read. Manual Backup/Restore lives in the Data menu.
