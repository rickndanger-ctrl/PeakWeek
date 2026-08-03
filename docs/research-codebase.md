# PeakWeek — Swift App Audit & Extensibility Report

Sources read in full: `~/dev/powerlifting-trainer/Sources/PeakWeek/{Models,Engine,Store,PeakWeekApp,ClientView,WeekView}.swift` (1,431 lines total). Reference web build skimmed: `~/Downloads/PeakWeek_1.html` (227 KB — a single-file bundled React 19 app; application code extracted and beautified from the minified bundle, engine and UI component read in full).

---

## 1. Complete feature inventory — Swift app

### 1.1 Data model (`Models.swift`, all Codable except `Exercise`)

| Type | Fields | Notes |
|---|---|---|
| `Unit` (enum) | `lb` / `kg` | Rounding step: 5 lb / 2.5 kg. Switching units does **not** convert stored maxes — only label + rounding change. |
| `Phase` (enum) | `acc, trans, real, deload, meet` | Carries display copy: `label`, `sub`, `blurb` (coaching prose baked into the enum). |
| `StartPhase` (enum) | `full, acc, trans, real, offseason` | Carries per-track `minWeeks/maxWeeks/defaultWeeks` (e.g. full: 10–16, def 12). |
| `LiftPool` (enum) | `squat, bench, deadlift, quads, hams, back, press` | Closed set; group labels for the picker. |
| `Exercise` (struct) | `name`, `mod: Double?` | **Not Codable, not stored** — lives only in the static catalogue. `mod` = load modifier vs comp-lift 1RM; `nil` = accessory (RPE-only). |
| `Slot` | `id: UUID`, `pool`, `exIdx: Int`, `custom: String?`, `sets`, `reps`, `pct: Double?`, `rpe` | Exercise referenced by **(pool, array index)** into the static catalogue. `custom != nil` switches to free-text mode (no computed load). `pct == nil` = accessory. |
| `DayPlan` | `id: UUID`, `title`, `slots: [Slot]` | |
| `Week` | `id: UUID`, `num`, `phase`, `weekInBlock`, `blockLen`, `note`, `days` | `note` = per-week coach notes, included in text export. |
| `Block` | `phase`, `weeks` | Used only for the barbell timeline. |
| `Program` | `startPhase`, `totalWeeks`, `fiveDay`, `createdAt: Date`, `blocks`, `weeks` | |
| `Maxes` | `squat`, `bench`, `deadlift` (Doubles) | `value(for:)` returns 0 for accessory pools. |
| `Client` | `id: UUID`, `name`, `unit`, `maxes`, `setupPhase`, `setupWeeks`, `fiveDay`, `program: Program?` | Setup params live on the client, separate from the generated program. |
| `AppData` | `clients: [Client]` | Root persisted object. |

### 1.2 Engine capabilities (`Engine.swift`, pure static namespace — no UI dependencies)

- **Exercise catalogue**: 7 pools, 44 exercises. Main-lift variants carry load modifiers (0.75–1.05); accessories are RPE-only.
- **RPE → %1RM table**: RTS/Tuchscherer style, 8 rep rows (1,2,3,4,5,6,8,10) × 7 RPE columns (7–10). Display-only — not used in load computation.
- **Block allocation**: `allocateBlocks(n)` — realization = clamp(round(n×0.24), 3, 4); deload week inserted iff n ≥ 12; remainder split ~evenly acc/trans. `allocateOffSeason(n)` — acc / 1-wk deload / trans.
- **Day templates** (`dayTemplates`): hardcoded 4-day (optionally 5-day) splits per phase. Loads linearly interpolated across the block via `lerp(startPct, endPct, t)` where `t = i/(weeks-1)`. Peaking templates branch on `weeksOut` (≥3 / ==2 / ==1: openers), with coached titles ("LAST HEAVY DEADLIFT (10–14 days out)", "Squat OPENER (single @ ~92%)"). Meet week = technique primer + rest. 5-day adds a second squat day to acc/trans only.
- **Program builder** (`buildProgram`): assembles weeks from blocks; on meet tracks (full/real) the last realization week is re-badged `meet`; blocks list rewritten to show a 1-wk meet plate.
- **Derived values**: `slotLoad` = round(1RM × pct/100 × exercise mod) to unit step (min one step); returns nil for custom/accessory/zero-max. `attempts(max:)` = opener 91% / second 97% / third 101.5%.
- **Plain-text week export** (`weekToText`): header, numbered slot lines (`sets×reps @ pct% → load · RPE`), rest-day copy, meet-day attempts, coach notes, RPE guide footer. The only outbound format.

### 1.3 UI surfaces (macOS-only; SwiftUI + AppKit)

- **Root** (`PeakWeekApp` / `ContentView`): `NavigationSplitView` — sidebar roster (name, S/B/D summary line, program status) + detail. Dark "iron/plate" theme (hardcoded colors). Toolbar: New Client (+), Data menu (Backup… / Restore… / Reveal data file in Finder). Placeholder hero when nothing selected.
- **New client sheet**: name, lb/kg segmented, three 1RM fields.
- **ClientView**: editable setup panel (name inline, unit, 3 maxes, phase picker with auto-default weeks, length stepper clamped to phase bounds, 4/5-day); Generate/Regenerate with destructive confirmation; **barbell timeline** (blocks as colored plates, width ∝ weeks, click scrolls to section via `ScrollViewReader`); phase sections with blurb; delete-client with confirmation; RPE chart toggle.
- **WeekView**: collapsible week rows (WK 01, block-week meta, "has coach notes" flag), per-week **Copy week** to `NSPasteboard` with 1.6 s "Copied ✓" feedback; adaptive `LazyVGrid` of **DayCards**; per-week coach-notes field; **MeetCard** (attempt boxes per lift with coaching copy) on meet weeks.
- **SlotRow**: exercise `Picker` grouped by pool + "✎ Custom exercise…" escape hatch (with "↩︎ list" to return); editable sets / reps / % / RPE fields; live computed load (`→ 315 lb`) that recalculates instantly when maxes change; remove-slot ×; Add exercise (defaults to back/3×10 @ RPE 8).
- **RPEChartView**: modal sheet with full RPE→% grid.

### 1.4 Persistence (`Store.swift`)

- Single JSON file: `~/Library/Application Support/PeakWeek/data.json` — ISO8601 dates, pretty-printed, sorted keys, atomic writes.
- **Save on every mutation** via `data.didSet` (guarded by a `loading` flag during load).
- Manual backup (`NSSavePanel`, date-stamped filename) / restore (`NSOpenPanel`) / reveal-in-Finder.
- `binding(for: UUID)` bridges the store to SwiftUI via hand-rolled `Binding` with index lookup.
- All decoding via `try?` — failures are silent (see §4, this is the biggest risk in the file).

---

## 2. HTML version feature inventory — deltas vs Swift

The web build is the same product: identical engine constants, templates, block math, attempt %s, RPE table, text-export format (the Swift file even says "direct port of the browser engine"). Feature-level, the Swift app is at or above parity. What the HTML version has that Swift lacks:

1. **Runs anywhere / mobile-usable**: viewport meta + responsive CSS (`@media (max-width:600px)` collapses the plate bar, hides roster status), auto-fit grids. The Swift app is a 1000×680-min macOS window.
2. **Distinct typography/branding**: Google Fonts — Anton display, Inter body, JetBrains Mono. Swift approximates with system fonts + weights; the Anton "display" look is lost.
3. **Accessibility affordances**: `aria-label`/`aria-expanded` on plates, week headers, slot inputs; `prefers-reduced-motion` support; visible focus outlines. The Swift app relies on defaults and has no explicit accessibility work.
4. **Input constraints in markup**: RPE input clamped `min:5 max:10 step:0.5`, sets/reps `min:1`, week-length `min/max` on the number input. Swift's `TextField(value:format:)` fields accept any number (RPE 47 is typeable; only the week stepper is clamped).
5. **Micro-interactions**: plate hover lift animation, inline "click again to confirm" regenerate pattern (Swift uses a native confirmation dialog — arguably better), clickable "Peak Week" logo as home button.
6. **Single-screen roster→client flow** with breadcrumb back button (vs split view — a wash, not a gap).
7. **Week-expansion keyed by week number** (survives regeneration numbering); Swift keys by UUID so regeneration collapses all but week 1 — behaviorally near-identical.

Things the Swift version has that the web lacks (for completeness): native file-panel backup/restore vs blob-download/file-input; durable file storage vs evictable `localStorage` (`peakweek-v1` key); reveal-in-Finder; persistent sidebar roster; native dialogs and keyboard shortcuts.

**Important compatibility note**: the two versions' backups are **not interchangeable**, despite identical domain shape. The web version uses 8-char random-string ids, a nested `setup: {startPhase, weeks, fiveDay}` object, a per-week `t` field, and `createdAt` as ISO string. Swift requires UUID-format `id`, flat `setupPhase/setupWeeks/fiveDay`, and will fail decode on a web backup (silently — restore just reports "file not valid").

---

## 3. Architecture assessment — extensibility

Overall: the codebase is small, clean, and well-layered — pure value-type models, a pure static engine, a single store, thin views. The engine/UI separation is genuinely good (e.g. `weekToText` is a view-independent seam). The two structural weaknesses that dominate every extension below are: **(1) exercise identity is (enum, array-index) into a hardcoded catalogue**, and **(2) persistence has no versioning and fails silently**.

### (a) User-customizable exercise pools — **poor today; moderate refactor**
- `Engine.pools` is a static `[LiftPool: [Exercise]]`; `Exercise` isn't Codable; `Slot` stores `exIdx: Int`.
- Any user edit to a pool (insert/delete/reorder) silently re-points every saved `Slot` at the wrong exercise, or out-of-bounds (`exercise(for:)` → nil → the slot renders as generic "Exercise" and loses its load).
- `LiftPool` is a closed enum whose raw value is stored in every slot — users can't add a category ("shoulders", "arms") without a code change, and an unknown raw value in JSON throws, killing the entire `AppData` decode.
- **Required**: make `Exercise` Codable with a stable `id: UUID`; change `Slot` to reference `exerciseID` (keep `exIdx` decode for migration); move the catalogue into `AppData` (seeded from defaults on first run); either give `LiftPool` an `unknown`/custom-string escape or replace it with a `PoolID` string. This touches Models, Engine (templates reference indices in ~60 places — swap to referencing seeded default exercises by name/id), and the SlotRow picker. Doable in a day or two, but it **requires the migration machinery from §4 first**.

### (b) Editable day templates — **hardest structural change**
- Templates are *code*, not data: `dayTemplates(phase:t:weeksOut:fiveDay:)` is a 145-line switch with lerp endpoints inline. A coach cannot alter the generated split, exercise choices, or progression ramps without recompiling.
- Mitigating factor: generated programs are fully editable afterwards (add/remove/edit slots, retitle no — titles are fixed), so "template editing" today = "regenerate then hand-edit every week," which the regenerate confirmation explicitly warns will destroy.
- **Required**: reify a `SlotTemplate {poolRef, exerciseRef, sets, reps, startPct, endPct, rpe}` / `DayTemplate` / `PhaseTemplate` Codable model; rewrite `dayTemplates` as data interpreted by a small evaluator (`pct = lerp(start, end, t)`); ship the current templates as the seeded default; add a template editor UI. The peaking branch (`weeksOut` 3/2/1) needs template-per-weeks-out. This is the biggest engine rework but the payoff is that (a), (b) and (c) all land on the same data model.

### (c) Per-client programming parameters — **easy, with one trap**
- `Client` already carries setup (`setupPhase`, `setupWeeks`, `fiveDay`) separate from the program, and `buildProgram` takes them as arguments — adding parameters (squat frequency, intensity offsets, exercise exclusions, bodyweight/class, meet date) is additive plumbing.
- The trap is Codable: **adding any non-optional field to `Client` breaks decoding of every existing data file** (verified: Swift's synthesized `Decodable` throws `keyNotFound` even when the property has a default value). New fields must be `Optional`, or the type needs a custom `init(from:)` using `decodeIfPresent`. Given §4's silent-failure store, shipping this without a migration story means users' rosters vanish.

### (d) Sending weekly plans to clients — **best-positioned feature**
- `Engine.weekToText(client:program:week:)` is exactly the right seam: pure, complete (attempts, notes, RPE guide), already used by clipboard copy.
- **Share sheet / Mail / Messages**: `NSSharingServicePicker` (or specific `NSSharingService(named: .composeEmail/.composeMessage)`) over the existing string — an afternoon of work. Caveat: needs an anchor view; SwiftUI on macOS wants `ShareLink` (macOS 13+) which works directly with the string — trivial.
- **PDF export**: two viable paths — (1) render an `NSAttributedString`/HTML version of the week and print to PDF via `NSPrintOperation`, or (2) build a dedicated SwiftUI "printable week" view and use `ImageRenderer` (macOS 13+) → `CGContext` PDF. Recommend adding `weekToHTML`/`weekToAttributed` beside `weekToText` in the engine to keep the formatting logic UI-free. A "whole program PDF" is the same loop.
- No architectural obstacles; this is the highest value-per-effort item in §5.

### (e) Client check-in data (logged RPE/loads) — **largest gap, model-level**
- Nothing in the model represents *performed* work: `Slot` is prescription-only; there is no per-set granularity, no dates (`Week.num` only, `Program.createdAt` is the sole timestamp), no e1RM history, no notion of "current week."
- Minimum viable: `SlotResult {slotID, actualLoad, actualReps, actualRPE, note}` stored per week (keyed by `Slot.id` — this is where UUID identity earns its keep, and why regeneration nuking all UUIDs becomes a real problem: logged results would orphan). Plus calendar anchoring (`Week.startDate` or `Program.meetDate` back-computed).
- The deeper issue is *ingestion*: the app is single-device, coach-only, file-based. Check-ins imply either the coach transcribing from texts (works today with just the model + UI change) or a client-side channel (shared file, CloudKit share, or a backend) — a different product tier. Recommend designing the results model now (so migrations happen once) and shipping coach-entered logging first.

---

## 4. Concrete refactoring risks

### Codable / persistence (migration strategy is a prerequisite, not an option)
1. **Any new non-optional stored property on any persisted struct breaks decode of existing files.** Verified empirically: `var newField: String = "x"` on a struct still throws `keyNotFound` on old JSON — Swift's synthesized `Decodable` ignores property defaults. Safe patterns: `Optional` fields, custom `init(from:)` with `decodeIfPresent`, or a `@DefaultCodable`-style property wrapper.
2. **Silent data loss on decode failure** (`Store.swift:30` `try? dec.decode` and `ClientView` never sees an error): if decode throws, `data` stays a fresh empty `AppData`, and the *first subsequent mutation* (e.g. adding a client) **overwrites `data.json` with the empty state** via `didSet` save. Combined with risk 1, a routine model change torches the user's roster. Mitigations, in order: write `data.json.bak` before every save (or on first save per launch); surface decode failure to the user instead of showing an empty roster; only then do schema work.
3. **No schema version field** in `AppData` — there is no hook on which to write a migration. Add `var schemaVersion: Int` (via `decodeIfPresent`, defaulting to 1) plus a pre-decode peek, before any other model change.
4. **Enums encode raw strings**: adding a `Phase`/`StartPhase`/`LiftPool` case is forward-safe, but files written by a newer app then fail in an older app; renaming/removing a case bricks decode. `LiftPool` sits in every slot — the riskiest of the three.
5. **`Slot.exIdx` is positional**: even without user-editable pools, *reordering or trimming the built-in catalogue in code* silently corrupts every saved program (wrong exercise, wrong `mod`, wrong loads). Treat the catalogue arrays as append-only until IDs land.
6. **Restore path shares all of the above**: `importBackup` also `try?`-decodes and gives only a generic "file not valid" — it's where web-version backups die (id format / nested `setup` mismatch, §2).
7. **Save-per-keystroke**: `didSet` re-encodes the whole `AppData` (pretty-printed + sorted) and hits disk on every character typed in any field. Fine at 10 clients; with logging data (§3e) it needs debouncing — an easy change now (`.debounce` on a subject, or save-on-quit + timer), painful later.

### UUID identity map (what depends on ids staying stable)
- `Client.id`: sidebar selection (`List(selection:)` tag), `store.binding(for:)` index lookup, `.id(id)` on `ClientView` (intentionally recreates all `@State` — expansion, scroll — on client switch).
- `Week.id`: `expandedWeeks: Set<UUID>` (@State), `ForEach` identity inside sections.
- `DayPlan.id` / `Slot.id`: `ForEach($week.days)` / `ForEach($day.slots)` binding identity; slot removal `removeAll { $0.id == slot.id }`.
- Consequences: **regeneration mints all-new UUIDs**, orphaning anything future that keys off week/slot ids (logged results, per-week attachments) — a regenerate-preserving-ids (match by `num`) strategy will be needed once logging exists. Any duplicate-week/duplicate-client feature must remint ids or `ForEach` breaks with duplicate-identity crashes. `Hashable` conformances include `id`, so value-equal weeks are never hash-equal — fine today, surprising later.

### SwiftUI patterns in use (and their sharp edges)
- **Single `ObservableObject` store, whole-app value graph, hand-rolled bindings**: `store.binding(for:)` and `ClientView.weekBinding(_:)` do index lookups in closures with graceful-degradation fallbacks (`Client(name: "")`, a dummy `Week`). Those fallbacks mask logic errors (a stale index silently edits nothing / renders a phantom). Fine at this scale; replace with `@Observable` + direct references or identified collections if the model deepens.
- Every keystroke publishes the entire `AppData` → every visible view re-evaluates. `LazyVGrid` + collapsed weeks keep this cheap now; program-wide expansion plus logging data would make typing latency noticeable. 
- `WeekView` receives `client` as a plain `let` — correct only because any client change re-renders `ClientView`; if `WeekView` were ever given its own store access, stale-copy bugs appear.
- `onChange(of:)` single-parameter form and `NavigationSplitView` set a macOS 13 floor; `ShareLink`/`ImageRenderer` (§3d) fit that floor.
- Minor: `copiedWeek` reset uses `DispatchQueue.asyncAfter` against `@State` — benign race if the user switches clients within 1.6 s (state is recreated by `.id(id)`, so no crash, just dead code path). `RPEChartView`'s data comes straight from `Engine.rpeTable` — good precedent of engine-as-single-source.

---

## 5. Gap list vs a professional coaching tool — ranked by implementation cost (cheapest first)

| # | Gap | Cost | Notes |
|---|---|---|---|
| 1 | **Input validation/clamping** (RPE 5–10 step 0.5, sets/reps ≥ 1, % 0–110) | Trivial | Web version already constrains these; Swift fields accept anything. |
| 2 | **Persistence safety**: `.bak` before save, decode-failure alert, schema version field | Trivial–small | Prerequisite for every model change in this list (§4.1–4.3). |
| 3 | **Share sheet / Mail / Messages for a week** | Small | `ShareLink` over existing `weekToText` output (§3d). |
| 4 | **Copy whole program / per-day copy / duplicate week** | Small | Loops over existing seams; duplicate must remint UUIDs. |
| 5 | **kg↔lb actual conversion of maxes** on unit switch | Small | Today it just relabels. |
| 6 | **PDF export (week + full program)** | Small–medium | `weekToAttributed`/HTML in Engine + `NSPrintOperation` or `ImageRenderer` (§3d). Branded printable is the pro-tool signature deliverable. |
| 7 | **Calendar anchoring**: meet date on client, dated weeks, "current week" highlight, countdown | Medium | Model change (needs #2 first); unlocks #10. |
| 8 | **Custom exercise pools with load modifiers** | Medium | ID-based exercise refs + catalogue in AppData + migration of `exIdx` (§3a). |
| 9 | **Per-client programming parameters** (frequency, intensity offsets, exercise exclusions, weight class) | Medium | Additive once #2/#8 exist (§3c); engine already parameterized. |
| 10 | **Coach-entered session logging** (actual load/reps/RPE per slot, compliance flags, e1RM calc from the existing RPE table) | Medium–large | New results model keyed by Slot UUIDs; forces regenerate-id-stability work (§4 UUID section). |
| 11 | **Editable program/day templates + saved template library** | Large | Reify templates as data + evaluator + editor UI (§3b). |
| 12 | **Progress analytics** (tonnage, intensity distribution, e1RM trend — Swift Charts) | Medium *after* #10 | Worthless before logging exists. |
| 13 | **Attempt-planning tools** (per-lift manual attempt overrides, kg-plate rounding for meets, 9-attempt card export) | Medium | Attempts are currently fixed 91/97/101.5% with no override. |
| 14 | **Client-facing delivery channel** (client app/web view, check-in submission, or CloudKit-shared data) | Very large | Different product tier; everything above is local/manual until this. Design the results model (#10) with sync in mind. |
| 15 | **Practice-of-business features** (billing, messaging, roster groups, multi-coach) | Very large / out of scope | Standard in TrueCoach/TrainHeroic-class tools; not on this codebase's path. |

**Recommended sequence**: 2 → 1 → 3 → 6 (ship value fast, zero model risk), then 8 → 9 → 7 → 10 as one coherent "models v2" arc behind a schema-version bump, with 11/12 following once v2 is stable.