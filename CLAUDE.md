# CLAUDE.md — Peak Week (native macOS coaching console)

## What this is
A SwiftUI macOS app for a solo powerlifting coach using block periodization.
Client roster → generate 4- or 5-day programs (full meet prep / single blocks /
off-season) → customize per client → edit weekly → **deliver each week's plan to
the client** (share sheet, PDF, or scheduled auto-send via Messages/Mail).
Data persists as JSON at `~/Library/Application Support/PeakWeek/data.json`
(schema-versioned, auto-backed-up to `data.json.bak` before every write).

## Working on it
1. Build: `./build.sh` (assembles PeakWeek.app) or `swift build` for iteration.
2. Test: `swift test` — the suite locks the trusted engine numbers; keep it green.
3. **Engine defaults are sacred**: percentages, rep schemes, block allocation math,
   RPE table values, attempt %s (91/97/101.5 standard), and exercise load modifiers
   are a direct port of a fully tested implementation. Add configurability AROUND
   them (opt-in profiles/settings); never silently change a default. A client with
   no settings must program byte-identically forever.
4. Any persisted-model change needs tolerant decoding (`decodeIfPresent` + defaults
   in a hand-written `init(from:)`) and a migration test — old data.json files and
   backups must always open.

## Architecture
Two targets share one core: `Sources/PeakWeekCore` (pure-Foundation engine +
models, builds for macOS AND iOS) and `Sources/PeakWeek` (the Mac app, which
re-exports Core via CoreExport.swift). The iPhone client app lives in
`ios/PeakWeekClient` (XcodeGen `ios/project.yml`; `ios/release.sh` archives +
uploads to TestFlight — bump CURRENT_PROJECT_VERSION in project.yml each run).
Its backend is `supabase/` (pw_* schema migration + peakweek-api edge function,
RLS-on/zero-policies service-role design, deployed to the lemon-tree project).
- `Models.swift` — Codable types (Client, Program, Week, DayPlan, Slot, AppData
  with schemaVersion + slot-reference migration)
- `Engine.swift` — seed exercise catalogue, RTS RPE table, block allocation, day
  templates, program builder (library-resolved + exclusion substitution), attempt
  selection, plain-text week export (with weeks-out header)
- `ExerciseLibrary.swift` — editable, persisted exercise library; UUID identity;
  seedKey ("pool:index") maps legacy refs; archive/soft-delete rules
- `ClientSettings.swift` — attempt risk profiles, per-lift training-max % and
  intensity offsets, exclusions, notes
- `Delivery.swift` — delivery prefs, send log records, pure schedule math
  (send moments, catch-up policy: only latest due week sends)
- `SendBridge.swift` — AppleScript bridges to Messages/Mail (dry-run injectable)
- `Store.swift` — AppStore: debounced persistence, backup rotation, decode-failure
  write-freeze, delivery pass runtime, approval queue
- `WeekExporter.swift` — styled attributed text + paginated PDF (CTFramesetter)
- `PeakWeekApp.swift` — app entry, theme, sidebar roster, Deliveries badge, Settings scene
- `ClientView.swift` — setup, delivery prefs, coaching options, timeline, sections
- `WeekView.swift` — week/day/slot editing, Send menu, meet card, RPE chart
- `SettingsView.swift` / `DeliveriesView.swift` — library editor, send log/queue
- `Styles.swift` — square design language (no rounded corners anywhere)
- `SyncService.swift` — Mac side of the client pipe: poll inbox → idempotent
  ingest → video download BEFORE ack; publishes each week on send; mints
  one-use pairing codes (`PairingSheet.swift` shows code + `peakweek://` QR)
- `InboxView.swift` + `Notifier.swift` — review client submissions, anomaly
  notifications; `TrendsView.swift` — e1RM trends with client/flag badges
- Core pipeline types: `Submission`/`Ingest`/`AnomalyCheck` (wire format +
  ingest rules), `PublishedWeek` (structured week render the phone displays)

## Domain rules baked in (do not break)
- Full prep 10–16 wks: ~40% accumulation / ~40% transmutation / ~24% realization
  (incl. meet week); deload inserted between acc→trans at 12+ wks
- Linear progression: main-lift % climbs linearly within each block
- Last heavy deadlift 10–14 days out; openers (~92% singles) 7–10 days out
- Meet week: light technique Mon/Tue only; attempts standard = 91% / 97% / 101.5%
  (conservative 89.5/94.5/100, aggressive 92.5/97.5/104 — opt-in per client)
- 5-day adds a Day 5 to accumulation and transmutation ONLY (taper = fewer days)
- Loads round to 5 lb / 2.5 kg; variation loads = comp 1RM × % × modifier
- Delivery never double-sends (send log is the source of truth) and catch-up after
  downtime sends only the latest due week

## Extension points (Rick plans more training options)
When adding a new training style/option, the seams are:
- **New program shapes**: `StartPhase` enum (Models.swift) + `Engine.buildProgramLegacy`
  block allocation + `Engine.dayTemplates` per-phase templates. Follow the pattern:
  templates speak (pool, seed-index); `resolveSlots` maps to library UUIDs.
- **New phase-loading schemes** (e.g. RPE-anchored presets, DUP): spec'd in
  docs/product-spec.md §A2/P1-2 — ship as OPT-IN presets, factory defaults frozen
  by GoldenTests.testAbsolutePhasePins + testLibraryBuilderIdenticalToLegacyEverywhere.
- **Per-client knobs**: ClientSettings.swift (attempt profiles, per-lift settings) —
  additive optional fields with decodeIfPresent, always.
- **Program structure edits**: Program.renumberAndRegroup + Store.adjustSendRecords
  keep numbering/blocks/delivery coherent — reuse them for any structural feature.
- Coach policies already encoded: deloads only between trans→real, never
  back-to-back; custom exercises auto-save to library as accessories.
After every feature: swift test green → copy the release build to
/Applications/PeakWeek.app (Dock launches that copy) → git push.

## Product docs
`docs/product-spec.md` (prioritized roadmap; P0 shipped, P1/P2 next) + four research reports.
