# Training options roadmap (Rick, 2026-08-03)

Coach's list, in his words: "undulated training, wave training, conjugated,
hypertrophy off seasons." All ship as **opt-in program types/schemes** — the
existing block-periodization engine and its numbers stay frozen (golden tests).

## 1. Undulating training (DUP)
Vary the stimulus day-to-day within each week instead of linearly across blocks.
- Classic shape per main lift each week: hypertrophy day (~4×8 @ 65-72%),
  power day (~6×3 @ 75-82%), strength day (~3×5 @ 80-87%), undulating weekly.
- Engine: a new scheme selector on program setup (Linear blocks — factory — vs
  DUP). DUP gets its own `dayTemplates` set; weekly progression nudges each
  day's band upward. Research basis: report 1 §1.4 (DUP comparable or better
  than block in several trials — present as equal-citizen option, not upgrade).
- Reuses: library resolution, per-client settings, delivery — untouched.

## 2. Wave training (wave loading)
3-week waves within a block: e.g. 4×6 @ 70 → 4×5 @ 75 → 4×4 @ 80, reset higher
(+2.5%) for the next wave. Optionally intra-session waves for peaking.
- Engine: a per-block **progression scheme** (linear — factory — vs 3-wave).
  Replaces the `lerp(start, end, t)` with a wave function over `weekInBlock`.
- UI: scheme picker inside Custom Phase Lengths panel per phase.

## 3. Conjugate (Westside)
Max-effort + dynamic-effort structure with rotating exercise variations.
- Week shape: ME lower (work to top single/triple on a VARIATION, rotated
  weekly), ME upper, DE lower (waves 50-55-60% + accommodating resistance
  note), DE upper; accessories target weak points.
- Engine: biggest build. Needs an exercise-rotation policy over library pools
  (pick next non-excluded variation each week — the UUID library makes this
  natural), ME "work up to" prescription type (no fixed sets×reps@%: new
  Slot display form), DE wave percentages.
- Slot model already carries optional pct/rpe — add an optional
  `prescription` style (fixed / workUpTo / wave) additively.

## 4. Hypertrophy off-season
A volume-first off-season distinct from the current strength off-season.
- Shape: 8-12+ rep ranges on main-lift variations (65-75% bands), double the
  accessory slots, wider exercise variety, optional 6-day split, deload every
  4-5 wks.
- Engine: new `StartPhase` case (`hypertrophy`) with its own allocation +
  templates. StartPhase is persisted by rawValue — additive case is
  decode-safe for existing files.

## Sequencing suggestion
Wave (small: progression function) → DUP (template set) → hypertrophy
off-season (new phase) → conjugate (new prescription forms + rotation policy).
Each lands with: research pass against the reports, opt-in UI, golden tests
untouched, new absolute pins for the new scheme's numbers, PDF/text export
verified, push to GitHub, copy build to /Applications.
