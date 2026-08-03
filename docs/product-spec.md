# Peak Week — Product Specification v2

**Product:** Peak Week, a native SwiftUI macOS app for a solo powerlifting coach (owner-operated, ~5–30 clients).
**Owner directives:** (1) professional-level coaching tool, (2) highly customizable, (3) every week's plan must be sendable to each client.
**Governing constraint:** the existing engine's defaults (percentages, rep schemes, block allocation, RPE table, attempt %s of 91/97/101.5) are tested and trusted. This spec **adds configurability around them** and layers options on top. No existing default changes silently. Where the science disputes a default (Report 1 §8), the correction ships as a **selectable profile or configurable range whose factory setting equals today's behavior** — except for outright arithmetic bugs, which are called out explicitly.

---

## A. Domain requirements

The coaching rules the app must encode, with the configurable ranges the science supports. Each item states: the rule, the default (unchanged unless flagged), and the configurable range with citation.

### A1. Block structure (accumulation → transmutation → realization → meet)

- **Rule:** Programs are organized as sequenced blocks: accumulation (volume/hypertrophy, widest exercise variety), transmutation (intensity/specificity), realization (taper/peak, comp lifts only), meet week. This ordering is the Verkhoshansky/Issurin model and is well supported as an organizing framework for powerlifting (Report 1 §1.1–1.3).
- **Default:** current allocation math unchanged (realization = clamp(round(n×0.24), 3, 4); deload inserted iff n ≥ 12; remainder split acc/trans — Report 4 §1.2).
- **Bug to fix (not a preference):** Report 1 §8.1 flags that the *specified* proportions sum to 104%. The shipped Swift code allocates deterministically week-by-week, so verify `allocateBlocks(n)` output sums exactly to `n` for every n in 8–24 and add a unit test asserting it. If any n produces a mismatch, that is a defect, not a default.
- **Configurable range (P1):** independent phase-length sliders (acc/trans/real) validated to sum to the prep length; realization selectable as **absolute weeks clamped 2–4** derived from lifter profile rather than proportional — Report 1 §8.1 shows proportional realization detrains on ≥20-wk preps (taper literature is absolute: 1–2 wk taper + 2–7 d cessation, Travis et al. 2020, Report 1 §4.1). Factory setting = current proportional math.
- **Honesty requirement:** block periodization is not proven superior to DUP (Painter 2012; meta-analyses, Report 1 §1.4). Any in-app coaching copy must present it as a framework, not settled science.

### A2. Phase loading parameters

All defaults unchanged; each becomes an editable band with science-backed presets.

| Phase | Current default (keep) | Science-supported configurable range | Citation |
|---|---|---|---|
| Accumulation | 4×6 @ 67–75% | Intensity band editable; offer a "Corrected (RPE-anchored)" preset of **72–80% for 6s** because 6 @ 67% ≈ RPE 4 on the Tuchscherer table (junk volume for trained lifters). Optional weekly set ramp (e.g. 3→4→5→6) per RP/summated-microcycle practice. | Report 1 §8.2, §2.1, §2.3 |
| Transmutation | 4×4 @ 77–86% | Preset "Corrected": **80–88% for 4s**; optional set taper (5→4→4→3) and top-set + back-off structure (back-offs at ~80–90% of top set, supported by METD back-off finding). | Report 1 §8.3, §2.2 |
| Realization | singles/doubles @ 87–93% | Ceiling extendable to **88–97%**; optional "top single" event at RPE 8.5–9 (≈94–95.5%) at 2–3 weeks out to calibrate attempts — peaking studies used 90–95% in final weeks. | Report 1 §8.4, §4.2 |
| Deload | 1 week when n ≥ 12 (keep) | Frequency every 4–8 wk; duration 5–7 d; step reduction of volume by tier (low ≤25–45% / moderate 40–60% / high 60–90%), load −~10%, frequency unchanged. | Bell et al. 2025, Report 1 §3.2; survey §3.3 |

### A3. Taper and meet week

- **Per-lift last-heavy timing:** default DL 10–14 d out (current, defensible-conservative), SQ 7–10 d, BP 4–7 d; each independently configurable. Survey median 7–10 d; elite practice up to 2.5 wk (Report 1 §4.3–4.4, §8.6). Deadlift responded far better to a longer/exponential taper (+8% vs +1%, Frontiers 2021, Report 1 §4.2) — surface this in helper text.
- **Two distinct opener events (Report 1 §4.6, §8.7):** (1) *opener-confirmation single* at 90–92.5%, 7–10 d out — this is what today's "openers 7–10 days out" template means and it stays; (2) *meet-week primer singles* at 70–80% SQ/BP, 70–75% DL, 4–6 d out. Model them separately; the meet-week template should include primers, rest/travel day, weigh-in day.
- **Training cessation:** per-lift, defaults DL ~6 d / SQ ~4 d / BP ~4 d; warn above 7 d (costs 1–4% strength, Report 1 §4.1).
- **Taper dials (P1):** model (step/exponential/linear), length (7–28 d), volume cut (30–70% with warning above 70%; 41–60% is the ES sweet spot), intensity policy (maintain ≥85% vs reduce) — all ranges from Report 1 §4.1/§4.4/§7.

### A4. Attempt selection

- **Default 91 / 97 / 101.5% stays** — it is the best-calibrated default in the engine, matching IPF successful-third data (Report 1 §8.5).
- **Add (P0-adjacent, cheap):** risk profiles — conservative (89–90/94–95/99–101), standard (current), aggressive (92–93/97–98/103–105) (Report 1 §6.3); per-lift overrides (more conservative DL opener ~80–88%, more conservative BP third given 53–55% third-attempt miss rates); **plate rounding to 2.5 kg / 5 lb loadable increments** and minimum-jump enforcement (Report 1 §6.4); explicit, coach-selectable **reference max definition** (gym 1RM vs projected meet max vs e1RM) (Report 1 §8.5).
- **Adaptive third (P1):** decision rule keyed to second-attempt RPE (≤8.5 → +2.5–5%; 9–9.5 → +1.5–2.5%; 10 → minimum jump), per Report 1 §6.2–6.3. Doctrine to encode in copy: 9/9 conservative beats 6/9 aggressive; never PR on a second; repeat a missed opener.

### A5. Prescription model

A prescription line must carry (Report 2 §2.3): exercise (with variation lineage), sets×reps (incl. AMRAP), intensity as **%1RM, RPE target, absolute load, or hybrid "% capped at RPE"**, tempo/pause, rest, equipment/setup notes, a coach cue, and a "film this" flag. The hybrid %-with-RPE-cap form is the professional default (Report 1 §5.6). Current `Slot` fields (sets/reps/pct/rpe) remain valid; new fields are additive and optional.

### A6. Autoregulation layer (P1/P2)

- RPE→% table: keep the engine's Tuchscherer table as the display default; make it **coach-tunable per rep range** (the Calgary Barbell revised-sheet feature, Report 3 Part 1 §8) and eventually per-athlete fitted from logged (load, reps, RPE) triples (Report 1 §5.2).
- e1RM per lift per session, computed from logged sets via the RPE table, trended over time — the single most-cited disqualifier of general tools for powerlifting (Report 3 §1 complaints, RTS section). Requires logging (P1).
- Novice guard: RIR-based load selection is inaccurate in novices; allow disabling RPE-driven progression per client (Report 1 §5.6).

### A7. Per-client individualization

Per-lift frequency (sane default 2 SQ / 3 BP / 1 DL, per METD literature, Report 1 §2.2), per-lift intensity offsets (DL often runs 2.5–5% lower at equal RPE), per-lift progression increments, equipment/federation profile, weight class and bodyweight trend, weak-point tags driving accessory suggestions (JTS taxonomy, Report 2 §4.2), injury swap ladders (Report 2 §3.2). Individual response differences are the core of professional practice (Emerging Strategies; the Brett Gibbs example, Report 2 §0, §3.1).

### A8. Delivery

Every week's plan must be exportable as plain text (exists), **shareable via Messages/Mail**, and **renderable as a branded PDF** — the "flexible delivery, not a captive client app" strategy: meet clients in the WhatsApp/iMessage/Sheets workflow they already have (Report 3 Part 2 §3.8). The stitched spreadsheet stack is the real incumbent, and its weak point is delivery/logging, not programming freedom.

---

## B. Prioritized roadmap

### P0 — must-have for professional use (build now, ship iteratively)

Ordered by build sequence. Item 0 is a hard prerequisite for everything touching the model (Report 4 §4.1–4.3).

**P0.0 Persistence safety + schema versioning** *(prerequisite, ~1 day)*
- What: write `data.json.bak` before each save; surface decode failures with an alert offering Restore instead of silently starting empty; add `schemaVersion` to `AppData`; debounce saves (current didSet writes on every keystroke).
- Why: Report 4 verified that any new non-optional field bricks decode, and the store then **overwrites the file with empty state on first mutation** — a routine model change would torch the roster. Report 3 found "data disappears / saves fail" is the #1 complaint class across all incumbents; reliability is itself a market differentiator.
- Notes: version peek via a tiny `struct VersionPeek: Decodable { var schemaVersion: Int? }` decode before full decode; `Store.save()` copies existing file to `.bak` first; wrap saves in a 1 s `Timer`/Combine debounce plus save-on-quit (`NSApplication.willTerminateNotification`).

**P0.1 Input validation**
- What: clamp RPE 5–10 step 0.5, sets/reps ≥ 1, pct 0–110 in `SlotRow`.
- Why: web build already constrains these; Swift fields accept RPE 47 (Report 4 §2.4, gap #1). Professional tools don't emit garbage prescriptions.
- Notes: `TextField` + `.onChange` clamp, or `Stepper`/formatter with bounds; trivial.

**P0.2 Week delivery: share sheet (Messages/Mail) + PDF + copy** *(directive #3)*
- What: on every week row: Copy (exists), **Share** (Messages, Mail, AirDrop via system share UI), and **Export PDF**. Also "Export full program PDF" at client level. PDF is a clean branded one-pager: client name, week number + phase, weeks-out to meet, day tables with exercise/sets×reps/%→load/RPE, coach notes, attempts on meet week.
- Why: this is the owner's non-negotiable directive and the highest value-per-effort item in the codebase (Report 4 §3d). A polished weekly PDF is "the pro-tool signature deliverable" (Report 4 gap #6) and matches how the market actually works — clients live in iMessage/WhatsApp/Mail, not a captive app (Report 3 §3.8).
- Notes: macOS 13 floor already set (Report 4 §4). `ShareLink(item: weekText)` works directly with the existing `Engine.weekToText` string; for richer sharing use `NSSharingServicePicker` anchored to the toolbar button. For PDF: add `Engine.weekToAttributed(...)`/`weekToHTML(...)` beside `weekToText` so formatting stays UI-free, render via `NSPrintOperation` to PDF or a dedicated printable SwiftUI view through `ImageRenderer` → `CGContext`. Share the generated PDF file URL through the same ShareLink.

**P0.3 Customizable exercise library** *(directive #2)*
- What: user-editable exercise catalogue — add/rename/delete exercises, set the load modifier (or accessory/RPE-only), organize into pools including custom pools ("Shoulders", "Arms"). Generated programs and the slot picker use the library.
- Why: `Engine.pools` is hardcoded; `Slot` references exercises by **(enum, array index)**, so any edit today silently corrupts every saved program (Report 4 §3a, §4.5). Every credible competitor has a customizable library with custom entries (Report 3 table stakes #5); the current "custom" free-text escape hatch loses computed loads.
- Notes: make `Exercise` Codable with stable `UUID`; move catalogue into `AppData.exerciseLibrary` seeded from current defaults on first run; `Slot` gains `exerciseID` (migration from `exIdx` in §C). Engine templates switch from index references to seeded-exercise IDs resolved by stable seed keys. Built-in seeds are marked so Reset-to-defaults is possible; deleting an in-use exercise prompts and downgrades affected slots to custom-text rather than corrupting.

**P0.4 Per-client programming customization** *(directive #1/#2)*
- What, phase 1 (achievable now): per-client **max overrides and progression settings** — per-lift training max vs true max, unit-correct rounding increment; **attempt profile** (conservative/standard/aggressive + per-lift % overrides + reference-max choice + plate rounding, defaults exactly 91/97/101.5 and current rounding); **per-lift last-heavy-day settings** (defaults exactly today's 10–14 d DL etc.); exercise exclusions (injury/equipment) that filter generation and the picker; free-form client notes (equipment, federation, cues that work).
- Why: "the coach's real product is the adjustment, not the template" (Report 2 §0); per-lift, per-client parameters are the universal customization coaches need (Report 2 §3.1); the engine is already parameterized and `Client` already separates setup from program, making this additive (Report 4 §3c). Attempt configurability ranges are directly science-backed (Report 1 §6, §8.5).
- Notes: all new `Client` fields optional (Codable trap, Report 4 §4.1); `buildProgram` gains a `settings` parameter defaulting to values that reproduce current output byte-for-byte (add a golden-file test asserting that). Attempt math extends `Engine.attempts(max:)` with a profile struct defaulting to current constants.

**P0.5 kg↔lb true conversion + meet date anchoring (lite)**
- What: converting a client's unit converts stored maxes (today it only relabels — Report 4 gap #5). Add optional `meetDate` on the client; show "X weeks out" in the client header and week rows.
- Why: weeks-out is the universal coordinate system of meet prep — "display weeks-out everywhere" (Report 2 §0); unit relabeling is a correctness trap. Cheap, and it makes the PDF/share output dramatically more professional ("Week 9 — 3 weeks out — Realization").
- Notes: `meetDate: Date?` optional field; weeks-out computed from `totalWeeks` and week index counting back from meet date; no calendar engine needed yet.

### P1 — next

1. **Coach-entered session logging + e1RM trends.** `SlotResult` (actual load/reps/RPE/note) keyed by slot UUID; per-lift e1RM computed from the existing RPE table; Swift Charts trendline; prescribed-vs-actual RPE deltas. Why: the RTS data model is the professional backbone and the most-cited disqualifier of general tools (Report 3 §1, RTS section; Report 2 §1.1–1.2). Forces regeneration-preserving-IDs work (match weeks by `num`) — design in P0 data model, build here (Report 4 §3e, §4 UUID section).
2. **Phase-parameter editor.** Expose the per-phase intensity bands, set schemes, and set-ramp options of §A2 as editable data with "Factory (current)" and "RPE-anchored (corrected)" presets. Why: Report 1 §8.2–8.4 corrections must be available without changing defaults; this is the halfway point to full template editing.
3. **Taper/meet-week configurability.** Per-lift last-heavy and cessation dials, primer-single event, meet-week template (per §A3). Why: the strongest disagreement space in the literature — must be ranges, not constants (Report 1 §7).
4. **Adaptive attempt planner + meet-day card.** Conservative/plan/aggressive trees per lift, second-attempt-RPE decision rules, warm-up list with kilo plate math and flight-count-based timing, printable/PDF handler card (Report 2 §5.2; Report 1 §6). Extends the P0 PDF pipeline.
5. **Deload configurability.** Frequency/duration/magnitude tiers per §A2; reactive one-session deload insertion (Report 1 §3).
6. **Weekly check-in record.** Coach-entered per-week wellness (bodyweight, sleep, stress, soreness, notes) + bodyweight-vs-class trendline (Report 2 §1.1, §3.4).

### P2 — later

1. **Editable day/program templates + template library** — reify `dayTemplates` as data with an evaluator; the largest engine rework, lands on the same data model as the library and phase params (Report 4 §3b).
2. **Program analytics for block review** — tonnage, average intensity, e1RM delta per block, hypothesis/outcome note (Emerging Strategies workflow, Report 2 §6).
3. **Video review** — local AVFoundation frame-step/slow-mo/side-by-side; drag-and-drop ingestion (Report 3 §3.6).
4. **Warm-up generator** for gym days (ramp % steps parameterized per client, Report 2 §5.1).
5. **Cue library** taggable per lifter, insertable into slot notes (Report 2 §4.1).
6. **Weak-point → accessory suggestion table** behind the exercise picker (Report 2 §4.2).
7. **Multi-meet season timeline**; meets snap blocks backward from dates (Report 2 §3.5).
8. **Client-side channel** (CloudKit share / lightweight web view / check-in ingestion) — a different product tier; design the results model for sync now, build never before demand (Report 4 gap #14).
9. **Alternative organizing models** (DUP/emergent) as generation options (Report 1 §1.4).

**Explicitly out of scope** (Report 3 §4): billing/payments, marketplaces, team/facility features, white-label client apps, nutrition/meal planning, wearables, AI program generation, CRM/marketing.

### Ship order within P0
P0.0 → P0.1 → P0.2 (delivery ships with zero model risk) → P0.3 → P0.4 → P0.5. This matches Report 4's recommended sequence (2 → 1 → 3 → 6, then the models-v2 arc).

---

## C. Data model changes

All changes are additive and optional-by-default. Schema version bumps 1 → 2. Existing files decode without loss; new fields use `decodeIfPresent` with nil/default fallbacks.

### C1. New and changed types

```swift
// ── AppData (changed) ────────────────────────────────────────
struct AppData: Codable {
    var schemaVersion: Int = 2                    // absent in v1 files
    var clients: [Client] = []
    var exerciseLibrary: ExerciseLibrary = .seeded()   // absent in v1 files

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion  = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        clients        = try c.decodeIfPresent([Client].self, forKey: .clients) ?? []
        exerciseLibrary = try c.decodeIfPresent(ExerciseLibrary.self, forKey: .exerciseLibrary) ?? .seeded()
    }
}

// ── Exercise library (new; replaces static Engine.pools as source of truth) ──
struct ExerciseLibrary: Codable {
    var pools: [ExercisePool]
    static func seeded() -> ExerciseLibrary { /* built from current Engine catalogue */ }
}

struct ExercisePool: Codable, Identifiable {
    var id: UUID
    var key: String            // stable seed key: "squat", "bench", ... or "custom-<uuid>"
    var label: String          // editable display name
    var builtin: Bool          // seeded pools can be renamed but not deleted
    var exercises: [Exercise]
}

struct Exercise: Codable, Identifiable {       // was non-Codable, no id
    var id: UUID
    var seedKey: String?       // non-nil for built-ins; lets templates + migration find them
    var name: String
    var mod: Double?           // nil = accessory (RPE-only), unchanged semantics
    var isArchived: Bool = false   // soft-delete keeps old programs resolvable
}

// ── Slot (changed) ───────────────────────────────────────────
struct Slot: Codable, Identifiable {
    var id: UUID
    var pool: String           // was LiftPool raw value; now the pool `key` (decodes old raws 1:1)
    var exerciseID: UUID?      // NEW canonical reference
    var exIdx: Int?            // legacy; retained for decode, nilled after migration
    var custom: String?
    var sets: Int
    var reps: Int
    var pct: Double?
    var rpe: Double
    var note: String?          // NEW optional per-slot coach cue
    var filmThis: Bool?        // NEW optional "film this set" flag
}
```

Note on `LiftPool`: replace the closed enum in *persisted* data with the string `key` (raw values are identical, so old JSON decodes unchanged). The enum survives internally for `Maxes.value(for:)` mapping via `key`. This removes the "unknown raw value kills the whole decode" failure (Report 4 §4.4) and enables custom pools.

```swift
// ── Per-client customization (new, all optional on Client) ───
struct Client: Codable, Identifiable {
    // existing fields unchanged: id, name, unit, maxes, setupPhase, setupWeeks, fiveDay, program
    var meetDate: Date?                       // NEW
    var settings: ClientSettings?             // NEW
    // custom init(from:) with decodeIfPresent for the two new fields
}

struct ClientSettings: Codable {
    var attempts: AttemptProfile?             // nil = engine defaults (91/97/101.5, current rounding)
    var perLift: [String: LiftSettings]?      // keyed by pool key "squat"/"bench"/"deadlift"
    var excludedExerciseIDs: Set<UUID>?       // injury/equipment exclusions
    var notes: String?                        // equipment, federation, cues
    var phaseOverrides: PhaseParameters?      // P1; nil = factory engine behavior
}

struct AttemptProfile: Codable {
    enum Risk: String, Codable { case conservative, standard, aggressive }
    var risk: Risk = .standard
    var opener: Double?      // nil = derived from risk; standard = 91.0
    var second: Double?      //                        standard = 97.0
    var third: Double?       //                        standard = 101.5
    var referenceMax: ReferenceMax = .gymMax     // .gymMax reproduces current behavior
    var roundToPlate: Bool = false               // false = current rounding behavior
    var minJump: Double?                         // kg/lb minimum increment
    enum ReferenceMax: String, Codable { case gymMax, projectedMeetMax, e1RM }
}

struct LiftSettings: Codable {
    var trainingMaxPct: Double?      // e.g. 95 = program off 95% of entered 1RM
    var intensityOffset: Double?     // additive % offset for this lift's prescriptions
    var lastHeavyDaysOut: ClosedRangeBox?   // Codable wrapper {lower, upper}; nil = engine default
    var attemptOverride: AttemptProfile?    // per-lift attempt tweaks (e.g. conservative DL opener)
}

// ── P1 forward declarations (define now so migration happens once) ──
struct PhaseParameters: Codable { /* per-phase intensity band, sets, reps, setRamp, preset id */ }

struct WeekLog: Codable {                     // P1: attach to Week via optional field
    var results: [UUID: SlotResult]           // keyed by Slot.id
    var checkIn: CheckIn?
}
struct SlotResult: Codable {
    var setsDone: [SetResult]                 // per-set granularity
}
struct SetResult: Codable { var load: Double?; var reps: Int?; var rpe: Double?; var note: String? }
struct CheckIn: Codable { var bodyweight: Double?; var sleep: Double?; var stress: Int?; var soreness: Int?; var note: String? }
```

`Week` gains `var log: WeekLog?` (optional, decodeIfPresent) in P1; defining the shape now means the v2 migration is the only migration.

### C2. Migration strategy (never loses data)

1. **Before anything else ships:** `Store.save()` copies the current `data.json` to `data.json.bak` (rotating one generation) before writing. On decode failure, the app shows an alert with Restore-from-backup — it never proceeds to an empty `AppData` that would overwrite on first mutation (fixes Report 4 §4.2).
2. **Version peek:** decode `{schemaVersion?}` alone first. `nil` → v1.
3. **v1 → v2 migration (pure function, unit-tested against a captured real v1 fixture):**
   - Copy the incoming file to `data-v1-backup-<date>.json` in Application Support before migrating (belt and braces beyond `.bak`).
   - Build `ExerciseLibrary.seeded()` from the current static catalogue **in the exact current array order**, recording `(poolKey, index) → exerciseID`.
   - For every `Slot`: `exerciseID = map[(pool, exIdx)]`; if `custom != nil` leave `exerciseID` nil (custom mode unchanged); if `exIdx` is out of bounds (shouldn't happen; catalogue is append-only) fall back to `custom = "Exercise"` rather than dropping the slot.
   - `pool` string carries over verbatim (raw values unchanged). All other fields copy through. `exIdx` is kept in the struct for one release (decode-only), then dropped from encoding.
   - Set `schemaVersion = 2`, save, done. Old fields never removed from disk until a successful v2 save completes.
4. **Forward safety:** every persisted struct that can grow gets a hand-written `init(from:)` using `decodeIfPresent` (the Codable trap is verified empirical behavior — Report 4 §4.1). New enum-like values persist as strings with `unknown`-tolerant decoding.
5. **Restore path:** `importBackup` runs the same version-peek + migrate pipeline, and reports *which* step failed instead of a generic "file not valid" (also the hook where web-build backups could later be adapted — Report 4 §2 notes the formats differ).
6. **Regeneration + future logging:** when `program != nil` and any `WeekLog` exists, regeneration matches new weeks to old by `num` and carries `log` forward, warning about weeks that no longer exist. Until logging ships, current regenerate behavior is unchanged.

### C3. Engine changes (behavior-preserving)

- `Engine.buildProgram(...)` gains `library: ExerciseLibrary` and `settings: ClientSettings?` parameters. With `settings == nil` and the seeded library, output is **identical** to today — enforced by a golden-file test that snapshots a generated program per StartPhase/length combination before the refactor and asserts equality after.
- `Engine.attempts(max:)` becomes `attempts(max:profile:unit:)`; `profile = nil` → exactly 91/97/101.5 with current rounding.
- New pure functions beside `weekToText`: `weekToAttributed(...)` / `weekToHTML(...)` for the PDF pipeline; `programToText(...)` for whole-program export.

---

## D. UX design (P0 features in the existing UI)

The app keeps its `NavigationSplitView` shell (sidebar roster → client detail) and iron/plate theme. P0 features land as follows.

### D1. Week delivery — week rows + toolbar (P0.2)
- **Week row header** (WeekView): the existing "Copy week" button becomes a compact segmented cluster: **Copy** · **Share** (SF Symbol `square.and.arrow.up`, opens the system share picker → Messages/Mail/AirDrop/Save) · **PDF** (`doc.richtext`, saves via `NSSavePanel` defaulting to `~/Downloads/<Client> – Week 07.pdf`, or drag the icon out as a file). Keep the 1.6 s "Copied ✓"/"Shared ✓" feedback pattern.
- **Client toolbar**: an "Export…" menu — *Share Current Week*, *Export Week as PDF…*, *Export Full Program PDF…*, *Copy Full Program*. Add `⌘E` (Export PDF) and `⌘⇧C` (Copy week) as `.keyboardShortcut`s and mirror them in a **File menu** via `Commands` — native macOS convention: everything clickable has a menu-bar + shortcut equivalent.
- **Convention notes**: use `ShareLink`/`NSSharingServicePicker` anchored to the button (share pickers on macOS are popovers, not sheets); PDFs render in the app's typography so the artifact is recognizably "Peak Week."

### D2. Customizable exercise library — Settings window + in-context (P0.3)
- **Primary home: a real Settings window** (`Settings` scene, `⌘,`) with tabs: **General** (units default, backup) · **Exercise Library** · **Attempts** (app-wide default profile). Native two-pane library editor: pools list on the left (reorderable, `+` for custom pool), exercise table on the right (name, load-mod %, accessory toggle) with inline editing, `+`/`–` footer buttons, and a "Restore Built-ins" button. Built-in entries show a badge and can be renamed/archived but not hard-deleted.
- **In-context escape hatch:** the SlotRow exercise picker gains a final item "New Exercise…" that opens a small popover (name, pool, mod) and inserts it into the library — coaches customize mid-edit, not by planning ahead. This upgrades the current "✎ Custom exercise…" free-text path: free text stays for one-offs, library entries get computed loads.
- **Deletion safety:** archiving an in-use exercise keeps it resolvable in existing programs (shown dimmed "(archived)"); a destructive delete prompts with the count of affected slots.

### D3. Per-client customization — ClientView setup panel (P0.4)
- The existing setup panel (name, unit, maxes, phase, weeks, 4/5-day) gains a disclosure group **"Coaching Options"** (collapsed by default so the current flow is untouched) containing:
  - **Attempts** box: risk-profile segmented control (Conservative / Standard / Aggressive; Standard pre-selected = current numbers), per-lift override fields shown as computed kg/lb next to each %, "round to plates" toggle, reference-max popup. Live-updating attempt preview (the MeetCard numbers change as you type — same instant-recalc pattern the app already uses for slot loads).
  - **Per-lift** grid (SQ/BP/DL rows): training-max %, intensity offset, last-heavy days-out range steppers (pre-filled with engine defaults, shown grayed until edited — "default unless touched" pattern).
  - **Exclusions**: token field of excluded exercises (autocompleting from the library).
  - **Notes**: free-text (federation, equipment, cues).
- **Regeneration rule:** options changes mark the program stale with a subtle "Settings changed — Regenerate to apply" banner rather than mutating silently; attempts, however, apply live (they're derived display, not program structure).
- A small "⚙ per-client settings differ from defaults" indicator dot on the sidebar row tells the coach at a glance who's customized.

### D4. Meet date + weeks-out (P0.5)
- **Setup panel**: optional `DatePicker` "Meet date" (compact, graphical popover — native macOS control).
- **Client header**: "MEET IN 5 WEEKS — Sat Nov 14" next to the barbell timeline; the timeline gets a subtle "you are here" marker on the current week once dates exist.
- **Week rows**: right-aligned secondary label "3 wks out" alongside the existing block-week meta; also included in text/PDF exports.
- **Sidebar**: roster rows sort-option "By meet date" and show a small countdown badge for clients ≤ 4 weeks out — the beginnings of the cross-client command center the market lacks (Report 3 §3.5).

### D5. Reliability surfaces (P0.0/P0.1)
- Decode failure → modal alert: "Peak Week couldn't read its data file" with **Restore Backup…** / **Reveal in Finder** / **Quit** — never a silent empty roster.
- Data menu gains "Restore Automatic Backup (.bak)" beside the existing manual Backup/Restore.
- Field validation is quiet: values clamp on commit (no error dialogs), matching the web build's min/max behavior.

### D6. Native conventions checklist (applies across P0)
`Settings` scene + `⌘,` · menu-bar `Commands` mirroring all toolbar actions with shortcuts · `NSSavePanel`/`NSOpenPanel` for all file I/O (already the pattern) · popover-anchored share picker · drag-out of PDF icons as file promises · destructive actions via `confirmationDialog` (already the pattern) · disclosure groups for progressive complexity · undo support (`UndoManager` registration for slot edits) as a fast-follow — "undo that always works" is called out as a native-app differentiator (Report 3 §3.1) · accessibility labels on plates/week headers/slot fields to close the gap vs the web build (Report 4 §2.3).

---

### Appendix: default-preservation ledger
Every number the engine ships today and where this spec touches it:

| Default | Status in this spec |
|---|---|
| acc 4×6 @ 67–75% | Unchanged; "RPE-anchored" preset (72–80%) added P1 as opt-in (Report 1 §8.2) |
| trans 4×4 @ 77–86% | Unchanged; opt-in preset 80–88% P1 (Report 1 §8.3) |
| real singles/doubles @ 87–93% | Unchanged; opt-in ceiling extension + top-single event P1 (Report 1 §8.4) |
| Block allocation math | Unchanged; add sum-to-n unit test (bug check only) |
| Deload iff n ≥ 12 | Unchanged; configurable policy P1 |
| RPE table | Unchanged; coach-tunable P1 |
| Attempts 91/97/101.5 | Unchanged as "Standard"; profiles/overrides/rounding added P0 as opt-in (Report 1 §8.5 endorses keeping it) |
| Last heavy DL 10–14 d | Unchanged default; per-lift dials P0/P1 (Report 1 §8.6) |
| Openers 7–10 d out | Unchanged; primer-single event added as a *separate* P1 event, not a replacement (Report 1 §4.6) |
| Text export format | Unchanged; PDF/HTML added beside it |
