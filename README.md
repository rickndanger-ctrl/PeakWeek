# Peak Week — native Mac app

## Build it (one time, ~2 minutes)
Open Terminal, drag this folder onto the window after typing `cd `, press Enter, then:

    ./build.sh

Or simpler — open this folder in Claude Code and say: **"Read CLAUDE.md and build this."**

If Terminal says Swift is missing, run `xcode-select --install`, accept the popup,
then run `./build.sh` again.

## Use it
Everything from the web version, now native:
- Client roster in the sidebar — add lifters with their maxes
- Pick phase (full prep / accumulation / strength / peaking / off-season), length, and **4-day or 5-day** weeks
- Generate → full block-periodized program with linear weekly progression
- Every exercise swappable, every set/rep/%/RPE editable, loads recalc live
- "Copy week" → formatted text on your clipboard, ready to paste to a lifter
- Meet week shows opener / second / third for all three lifts
- Data menu (toolbar): Backup, Restore, and Reveal data file

## Where your data lives
`~/Library/Application Support/PeakWeek/data.json` — saved automatically on every
change. Hit **Backup** in the Data menu weekly anyway. Time Machine covers this
file too if you have it on.
