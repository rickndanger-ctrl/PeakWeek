# CLAUDE.md — Peak Week (native macOS build)

## What this is
A SwiftUI macOS app: a powerlifting coaching console using block periodization.
Client roster → generate 4- or 5-day programs (full meet prep / single blocks / off-season)
→ edit weekly → copy formatted week text to send to lifters.
Data persists as JSON at `~/Library/Application Support/PeakWeek/data.json`.

## Your job (local Claude Code)
1. Run `./build.sh` in this folder.
2. **If the build fails**: read the compiler errors and fix them with the smallest
   possible change. The engine logic in `Engine.swift` is a direct port of a fully
   tested JavaScript implementation — its numbers, templates, and algorithms are
   correct by design. Do NOT change percentages, rep schemes, block allocation math,
   RPE table values, or exercise load modifiers while fixing compile errors.
   Compile issues, if any, will be SwiftUI API-level (view modifiers, bindings,
   availability) — fix those only.
3. Rebuild until `PeakWeek.app` is produced, then offer to install to /Applications.
4. Smoke-test: launch the app, add a client named "Test" with maxes 405/275/495 lb,
   generate a 12-week full prep, confirm: 5 blocks appear on the barbell timeline
   (Accumulation, Deload, Transmutation, Realization, Meet Week), week 1 Day 1 shows
   Competition Squat 4×6 @ 67% → 270 lb, and "Copy week" puts text on the clipboard.
   Then delete the test client.

## Architecture
- `Models.swift` — Codable data types (Client, Program, Week, DayPlan, Slot, enums)
- `Engine.swift` — pools with load modifiers, RTS RPE table, block allocation,
  day templates (incl. 5-day variants for acc/trans), program builder, attempt
  selection, plain-text week export
- `Store.swift` — AppStore (ObservableObject), JSON persistence, backup/restore panels
- `PeakWeekApp.swift` — entry, theme, sidebar roster, new-client sheet
- `ClientView.swift` — client setup, generate/regenerate, barbell timeline, sections
- `WeekView.swift` — week/day/slot editing, meet attempts card, RPE chart

## Domain rules baked in (do not break)
- Full prep 10–16 wks: ~40% accumulation / ~40% transmutation / ~24% realization
  (realization includes meet week); deload inserted between acc→trans at 12+ wks
- Linear progression: main-lift % climbs linearly within each block
- Last heavy deadlift 10–14 days out; openers (~92% singles) 7–10 days out
- Meet week: light technique Mon/Tue only; attempts = 91% / 97% / 101.5%
- 5-day adds a Day 5 to accumulation and transmutation ONLY (taper = fewer days)
- Loads round to 5 lb / 2.5 kg; variation loads = comp 1RM × % × modifier
