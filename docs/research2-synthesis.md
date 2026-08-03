# PeakWeek — Distilled Knowledge & Implementation Spec

=== ARTIFACT 1: SKILL.md ===

Write the following to `~/.claude/skills/powerlifting/SKILL.md`:

```markdown
---
name: powerlifting
description: Expert powerlifting coaching + block periodization knowledge for programming, peaking, attempt selection, and the PeakWeek macOS app (frozen engine numbers, taper math, scheme selection, weak-point taxonomy).
---

# Powerlifting Coaching Skill

Reference-grade doctrine for meet-prep coaching and for working on PeakWeek
(`/Users/richardholguin/dev/powerlifting-trainer`). The engine's shipped numbers are
**frozen and trusted** — advise around them, never contradict them silently.

## 0. PeakWeek frozen engine (never change these)

- Block periodization: **acc 4×6 @ 67–75% linear** · **trans 4×4 @ 77–86% linear** ·
  **realization 87–93% singles/doubles** · **deload 62%** · **meet week 60/55%**.
- RTS/Tuchscherer RPE table (`Engine.rpeTable`). Attempts **91 / 97 / 101.5%**.
- **Last heavy DL 10–14 d out; openers 7–10 d out.** 4- or 5-day weeks.
- Exercise pools with load modifiers: `variation load = comp 1RM × program% × mod`.
- Where things live: `Sources/PeakWeek/Engine.swift` (templates, RPE table, allocation;
  realization/meet templates ~lines 216–272), `Sources/PeakWeek/ExerciseLibrary.swift`
  (pools + mods), `docs/product-spec.md`, `docs/research-science.md`,
  `docs/research-practice.md`, `docs/roadmap-training-options.md`.
- New schemes are **opt-in per-phase progression schemes**, equal citizens, never
  "upgrades." Factory golden tests must stay byte-identical.

## 1. Block doctrine (the causal model)

- **LTDE (Verkhoshansky):** concentrated loading depresses performance on purpose;
  fitness expresses only after load is removed. Accumulation fatigue is the intended
  state. The taper unmasks fitness — it does not add it. Hence: cut **volume first,
  intensity last**.
- **Residuals (Issurin):** maximal strength residual **30 ± 5 days**. Hard rules:
  realization block ≤ ~28–30 d absolute (never a % of prep length); no needed quality
  untrained past its residual.
- **Honesty:** block vs DUP head-to-heads trend pro-block but are not significant
  (Painter 2012/2018). Framework, not proven doctrine.

### Phase math

| | Accumulation | Transmutation | Realization |
|---|---|---|---|
| Purpose | CSA, work capacity, weak points | Convert to specific strength, RFD | Dissipate fatigue, express, calibrate attempts |
| Duration | 4–6 wk | 4–6 wk | **2–4 wk absolute** (incl. taper) |
| Intensity | 65–80% (defensible floor ~72% for 6s; 6@67 ≈ RPE 4 = ramp-in only) | 77–88% | 87–95%+ |
| Reps | 5–10 | 3–6 | 1–3 |
| Weekly sets/lift | 8–16 ramping | 6–12 | 3–6 |
| RPE | 5–7 → 8 | 7 → 9 | 7–9, rarely 10 |
| Frequency | SQ 2–3 / BP 2–3 / DL 1–2 (METD optimum **2/3/1**) | same | → 1× each |
| Exercise breadth | widest | close variations | comp lifts + commands only |
| Progression | volume-led | load-led | intensity up, sets down |

Deloads (Bell 2025): **step reduction only**, volume −40–60%, load −~10% and/or +1–3
RIR, frequency unchanged, 5–7 d, every 4–8 wk. Red flags: adjacent deloads; a deload
immediately before the taper (the taper IS the fatigue-dissipation event).

## 2. RPE / e1RM

RPE = 10 − RIR; log to halves. **Table (% of 1RM):**

| Reps | @10 | @9.5 | @9 | @8.5 | @8 | @7.5 | @7 |
|---|---|---|---|---|---|---|---|
| 1 | 100 | 97.8 | 95.5 | 93.9 | 92.2 | 90.7 | 89.2 |
| 2 | 95.5 | 93.9 | 92.2 | 90.7 | 89.2 | 87.8 | 86.3 |
| 3 | 92.2 | 90.7 | 89.2 | 87.8 | 86.3 | 85.0 | 83.7 |
| 4 | 89.2 | 87.8 | 86.3 | 85.0 | 83.7 | 82.4 | 81.1 |
| 5 | 86.3 | 85.0 | 83.7 | 82.4 | 81.1 | 79.9 | 78.6 |
| 6 | 83.7 | 82.4 | 81.1 | 79.9 | 78.6 | 77.4 | 76.2 |
| 8 | 78.6 | 77.4 | 76.2 | 75.1 | 73.9 | 72.8 | 71.7 |
| 10 | 73.9 | 72.8 | 71.7 | 70.7 | 69.6 | 68.6 | 67.6 |

`e1RM = load ÷ table%(reps, RPE)` (190×4@8 → 190/0.837 = 227). Judge the e1RM trend
**block-over-block**, never week-over-week.

**RPE wins:** variable readiness, stale 1RM, honest experienced athletes, low-rep
near-failure sets. **% wins:** novices (log RPE, don't drive load with it), high-rep
work, deliberately submaximal work (deloads/speed/primers). **Professional default =
hybrid**: "% band with RPE cap" — exactly what PeakWeek prescribes.

## 3. Peaking & taper (the FFM-derived calendar)

One master dial: **τ₂ (fatigue decay), default 12 d, clamp [8,18]**. τ₁ ≈ 30 d
(strength residual) — never exposed, used only to cap realization length. Laws
(validated Busso-model simulation reproducing Thomas & Busso 2005):

1. **Taper duration ≈ 1.6 × τ₂** (τ₂ sets length; τ₁ sets cut depth).
   `d_opt ≈ τ₂ × (2.6 − 0.018 × cut%)`.
2. **The peak is flat and asymmetric:** loss ≈ `0.19·Δ²` % of taper gain when Δ days
   too SHORT, `0.10·Δ²` when too LONG. ±3 d is essentially free. When in doubt, taper
   longer — but never extend *complete cessation* (>7 d costs **1–4% of 1RM** outright;
   that clock is separate and hard).
3. **Overreach ⇒ deeper + longer:** add ~5–8 d and ~8–12 pp of cut (caps 28 d / 70%).

**Day-offset rules** (`offset = clamp(round(coef × τ₂), lo, hi)`; τ₂=12 defaults):

| Event | coef | clamp | @τ₂=12 |
|---|---|---|---|
| Taper start | 1.70 | 14–28 | −20 d |
| Top calibration single (RPE 8.5–9, 93–96%) | 1.50 | 14–24 | −18 |
| Last heavy DL (90–92.5% = opener confirm) | 0.92 | 8–16 | −11 |
| Last heavy SQ (90–92.5%) | 0.75 | 6–12 | −9 |
| Last heavy BP (90–92.5%) | 0.50 | 4–9 | −6 |
| Last DL touch (primer 70–75%) | 0.48 | 4–7 | −6 |
| Last SQ touch (primer 75–80%) | 0.34 | 3–6 | −4 |
| Last BP touch (primer 75–80%) | 0.33 | 3–6 | −4 |
| Full cessation | day after last touch | 2–7 | −3 |

Volume: cumulative cut **40–60%** (never <25% or >70%); three stages T1 −30% / T2 −50%
/ T3 −70–75%. Intensity: hold ≥85% through last-heavies, then 70–80% meet week; peak
intensity lands 8 ± 3 d out. Taper set/reps: **3×2 SQ, 3×3 BP, 3×1 DL**. The deadlift
wants a *longer, gentler* (exponential) taper — step taper gave DL +1% vs +8%
exponential. Per-lift last-heavy ratios DL:SQ:BP = 1.00:0.82:0.55; cessation
5.8/4.1/3.9 d (survey means). Meet week (Sat meet): primers Mon/Tue, **no deadlifts
after Tuesday**, Wed active recovery, Thu rest/travel, Fri weigh-in/rack heights/cards.

**Short runway (3–6 wk):** the strength you have is the strength you'll express; the
taper (+3.2–4.4% of total) is worth 2–4× the training block — cut order: accumulation
→ accessories → variation breadth → frequency above 2/3/1 → deloads → overreach →
**never the taper**. Realization is always ~3 wk absolute. Decision input that matters
most: **arrival fatigue** — fatigued ⇒ τ₂+2, all-taper; fresh/undertrained ⇒ τ₂−1,
train harder longer, taper less (a taper from below the tolerance ceiling *costs*
performance — Thomas & Busso).

**Caveats to carry:** the FFM is ill-conditioned and poorly identifiable per-athlete
(Sci Rep 2025); use it as the derivation of calendar rules + penalty geometry, never
as a live "fitness 87 / fatigue 34" dashboard.

## 4. Attempt selection

Reference max must be explicit (gym single vs block e1RM@9 vs projected).

| Profile | Opener | Second | Third |
|---|---|---|---|
| Conservative | 89–90% | 94–95% | 99–101% |
| **Standard (engine)** | **91** | **97** | **101.5** |
| Aggressive | 92–93% | 97–98% | 103–105% |

IPF validation: successful thirds preceded by openers at 91% and seconds at 96% *of
the third* — engine is near-optimal, slightly conservative on the opener (correct
direction). Rules: opener = triple-on-a-bad-day (single @7.5–8); **never a PR
second**; miss an opener → repeat it; third from observed second-attempt bar speed;
jumps ~5–7.5% SQ/DL, 3–5% BP, 2.5 kg rounding; DL opener more conservative (85–88%),
BP third more conservative (53% miss rate). **9/9 beats a bigger 6/9** (winners avg
8.46/9; ~50% of thirds missed at worlds). Bomb-out guard: flag openers >~95% of last
confirmed heavy single; with no single ≥93% in the block the second is unvalidated —
bias conservative. In-meet tree (precompute 3 variants/lift, ~1-min submission window):
second @≤8.5 → +2.5–5%; @9–9.5 → +1.5–2.5%; @10/grind/miss → repeat or min jump;
missed opener → repeat exactly.

## 5. Scheme selection (linear · wave · DUP · hypertrophy)

Meta-analytic truth: linear ≈ undulating for strength and hypertrophy; the only
directional edge is undulation in **trained** lifters, mostly **bench**. Present all
schemes as fit-to-lifter tools. Pick linear for: novices, meets close (realization is
always linear into the taper), lifters who can't RPE honestly, coaches wanting
auditability. Pick wave for: week-5–6 linear collapse (fatigue masking), stale 1RM,
variable readiness. Pick DUP for: trained lifters, bench-centric goals, boredom.
Pick hypertrophy off-season for: no meet on calendar, weak-point mass phases.

**Wave (transmutation, 3-step waves, 4 sets):** reps 5/4/3 (DL 4/3/2); final wave
pinned to factory ceilings — SQ **79/82.5/86**, BP **78/81.5/85**, DL **80/83.5/87**;
each earlier wave −2.5% per step; RPE caps 7/7.5/8 (DL 8 flat). N not divisible by 3:
truncate wave 1 from the front so the block always ends on the full top wave.
Secondaries stay on the factory lerp. Self-deloading (drop-back every 3rd week).

**DUP (accumulation) zones:** H 4×8 @ 65→71 (cap 7) · P 4×3 @ 68→72 (cap 6.5,
bar-speed) · S 4×5 @ 75→81 (cap 7.5) · S-DL 4×4 @ 76→82 (cap 7.5). Order each lift's
weekly exposures **H → P → S** (Zourdos: HPS beat HSP in powerlifters). 4-day: bench
gets true DUP (D2 H, D4 P+S), squat alternates H/S weekly on D1 + P secondary, DL = S
+ RDL-H within-day. 5-day: squat true DUP (D1 H+P, D5 S). Progression = factory lerp
over the block; optional volume ramp (H slots 3→5 sets); optional RPE-led variant
gated behind the novice guard.

**Hypertrophy off-season (8–12 wk, no meet):** main-lift *variations* (mods scale
loads), meso spine 4×12 @ 60–63 → deload (factory 62% week verbatim) → 4×10 @ 64–68 →
deload → 4×8 @ 70–72. Secondary variation 3×8 @ main−2. Accessory volume doubled
(4 slots × 3→4 sets/day). Guard: 12s above ~63% or 10s above ~68% blow past RPE 8 —
bands are deliberately capped. Re-test/re-estimate 1RM before %-based strength work
resumes.

## 6. Weak-point → exercise taxonomy (with load modifiers)

Diagnose from 0.5× video, not where the bar stopped ("hips shot up" presents as a
lockout miss but is an off-the-floor problem). Variation work belongs in acc/trans;
last 3–6 wk are comp-specific.

| Lift | Failure point | Fixes | Builders |
|---|---|---|---|
| BP | Off chest | Long-pause bench, Spoto, wide-grip, dips | Flyes, incline DB |
| BP | Mid-range | Spoto, tempo, pin press at sticking height | Incline, OHP |
| BP | Lockout | Close-grip, 1–2 board, floor press, high pin | JM press, skulls, pushdowns |
| SQ | Hole | Pause, tempo, pin/dead squat | Front squat, hack, leg press, hip thrust |
| SQ | Mid-thigh / GM-squat | Pin squat, SSB, tempo descent, good mornings | Back ext, rows |
| DL | Floor | Deficit (conv only), paused below knee, halting | Leg press, rows |
| DL | Lockout | Block pulls, RDL, heavy holds | Hip thrust, shrugs, glute/ham |

**Modifiers** (engine values; all inside PRS-defensible ranges): SQ — pause 0.90,
high-bar 0.92, SSB 0.87, front 0.82, tempo 0.85, pin 0.88, box 0.92. BP — close-grip
0.92, Spoto 0.93, Larsen 0.90, tempo 0.90, incline 0.85, 2-board 1.02, feet-up 0.92.
DL — paused 0.88, deficit 0.90, block pull(2") 1.05, RDL 0.75, snatch-grip 0.80, SLDL
0.80, opposite-stance 0.85. Conjugate adds: floor press 0.92, low pin press 0.9375,
high pin press ~1.05, knee-height block pull 1.05, good morning RPE-only (nil mod; if
forced, 0.40 × squat). Modifiers are starting estimates (±3–5% by anthropometry);
variation-to-comp e1RM ratio drift is itself diagnostic.

## 7. Red flags (catch these)

1. Junk volume: main-lift sets below ~RPE 5 for a trained lifter beyond one ramp-in week.
2. Fatigue masking: @8 repeatedly arriving @9.5 (or @6.5) — cross-check wellness first.
3. Proportional/missing taper: realization scaled as % of prep; clamp 2–4 wk absolute.
4. Adjacent deloads, or deload immediately pre-taper; no deload in a 6+ wk block.
5. Taper volume cut >70%; total cessation >7 d (costs 1–4% strength).
6. Heavy pull inside 7 d, or any DL after Tuesday of (Saturday-)meet week.
7. Unvalidated attempts: no ≥90% single in last 3 wk; second above anything touched; PR second.
8. Specificity inversion: new variations/heavy accessories inside 3–4 wk out; commands not enforced in realization.
9. No volume progression in accumulation.
10. RPE-driven loading for a novice; RPE on high-rep accessories.
11. Missed sessions: never stack missed volume onto the next week in meet prep — skip.
12. Bodyweight trending >3–5% over class limit inside 2 wk — escalate.
13. e1RM down across a full block → block hypothesis failed; next block must change.

## 8. Warm-ups & communication

Gym ramp: bar → 40%×5 → 60%×5 → 80%×3 → (90%×1 when top ≥85%) → work; use the 80%
single as a readiness probe. Meet day: count attempts not minutes — SQ 5–8 / BP 4–6 /
DL 5–7 warm-up sets, last ≈ 90% of opener, last warm-up halfway through their thirds
(~5–8 min out). Handler card: warm-ups with kilo plate breakdowns, attempts in 3
variants + decision rule, rack heights, 1-minute reminder.

Coordinate system is **weeks-out**. A prescription line carries: exercise + setup,
sets×reps, intensity (hybrid "80% cap @8"), expected load ("~150 should be @8"), one
external cue ("spread the floor," "break the bar," "push the floor away" — one at a
time), film-this flag. Explain strange-looking weeks in one sentence ("light on
purpose — letting the last block show up"). End each block with a written
hypothesis/outcome line.
```

=== ARTIFACT 2: IMPLEMENTATION SPEC ===

All code-facing. Frozen surface untouched: block allocation, acc/trans/real/deload/meet %s, RPE table, attempts, pool mods, factory golden tests.

## A. Flexible day-one anchoring semantics

1. **`programDayOne`**: coach-chosen calendar date. Persist as `yyyy-MM-dd` + named timezone (e.g. `America/Los_Angeles`), never epoch. Default: today, or `meetDate − 7×totalWeeks + 1` when meet-anchored.
2. **Week N (1-based)** = half-open interval `[dayOne + 7(N−1), dayOne + 7N)` in *calendar days*. `weekIndex(d) = floor(daysBetween(dayOne, d)/7) + 1`; `weekStart(N) = dayOne + 7(N−1) days`; span = exactly `7×totalWeeks` days. All arithmetic via `Calendar.date(byAdding:.day,...)` / `dateComponents([.day],...)` — never seconds, never `weekOfYear`.
3. **Positional day slots**: template day k (0…6) → `weekStart(N) + k`. No Mon–Sun names anywhere; display "Week 3 · Day 2" + concrete date. No partial first weeks; no calendar snapping.
4. **Send moment** per client: `sendAt(N) = weekStart(N) − sendLeadDays` at `sendTimeOfDay` local (defaults 1 d, 18:00; avoid 01:00–03:00). Delivery rotates with the anchor automatically.
5. **Meet alignment**:
   - **Strategy A (default when meetDate set)**: `dayOne = meetDate − 7×totalWeeks + 1`; meet day = last day of week `totalWeeks`; `weeksOut(N) = totalWeeks − N` exact.
   - **Strategy B (dayOne fixed)**: `totalDays = daysBetween(dayOne, meetDate)+1`; `rem = totalDays mod 7`. rem 0 → aligned. rem 1–3 → extended final segment of 7+rem days, extra light days *before* the taper events. rem 4–6 → bridge partial week of `rem` ramp-in days at the *front*, renumber so final week ends on meet day. Invariant: **last ~14 days always laid out backward from meetDate by days-out; slack goes to the front.**
   - **Strategy C (truncated final week)**: explicit override only; warn whenever any last-heavy/opener window becomes unsatisfiable.
6. **Re-anchoring**: `dayOne += δ`, δ ∈ (−6…+6), forward-only; past weeks keep ledger dates; prefer positive δ (extra rest day) in UI hint.
7. **Ops**: dedupe key `(clientID, programGenerationID, weekN)`; write-ahead delivery ledger with frozen date snapshots; reconciliation ("should week N be sent now?"), not timers; catch-up sends **current week only**, older marked `superseded`; >24 h late → coach confirm; regenerate mints new generationID; bounded retries → `failed` dead-letter state; per-client delivery history visible.
8. **Golden tests**: Wed dayOne/12-wk/Sat meet (Strategy A) event days-out; same with Monday meet; rem=2 and rem=5; DST Mar/Nov `weekStart(N+1)−weekStart(N) == 7 days`; Feb 28–Mar 1 (leap/non-leap), Dec 29–Jan 4; sleep-over-two-send-times → exactly one send.

## B. Peaking projection algorithm

**Inputs** (`PeakProjectionInput`): meetDate, startDate, sessionCalendar (date + lifts trained), bodyweightKg, trainingAgeYears, ageYears, equipment, plannedWeightCutPct, arrivalFatigue (fresh/normal/fatigued), phaseWeeks, deloadWeeks, daysPerWeek, overreachWeekPlanned, peakBlockWeeklyVolume.

**τ₂ derivation** (clamp [8,18]; surface as "Fatigue clearance: fast/typical/slow" profile + advanced numeric override; never surface τ₁):
```
τ₂ = 12
   + BW: >120 → +4 · 100–120 → +2.5 · 83–100 → +1 · 66–83 → 0 · ≤66 → −1
   + trainingAge: <1y → −3 · 1–3 → −1.5 · 3–7 → 0 · >7 → +1.5
   + age: 40s +1 · 50s +2 · 60+ +3
   + equipment: single-ply +1 · multi-ply +2
   + weightCut >3% BW → +1
   + arrival: fresh −1 · fatigued +2
```
τ₁ = 30 fixed; single use: `realizationMaxDays = min(28, τ₁)`.

**Day-offset rules**: table in Artifact 1 §3 (coef/clamp per event). Meet-week primer loads: **75–80% SQ/BP, 70–75% DL** (raise from the current 60/55 template when this scheme is active); top calibration single ~94% RPE 8.5–9 at −1.5τ₂.

**Snapping**: for each event furthest-out first — target = meetDate − offset; candidates = sessions inside `[meetDate−hi, meetDate−lo]` training that lift, strictly later than the lift's prior event; pick argmin |date−target|; tie-break **earlier for SQ/DL, later for BP** (asymmetric penalty: too-short is the 0.19Δ² branch; bench has the shortest residual and highest technical-decay risk). Empty window → nearest outside session + flag `.noSessionInWindow`. Repair invariants: topSingle > lastHeavyDL ≥ lastHeavySQ ≥ lastHeavyBP (days-out); lastHeavy(X) > lastTouch(X); on violation push back one session, else flag `.scheduleCannotSatisfyOrdering`. cessationStart = day after last touch; taperStart snaps **forward** (never start the cut early). 5-day splits must actively **delete** meet-week sessions past cessation, not lighten them.

**Volume schedule** (× peakBlockWeeklyVolume): step ladder 0.70 → 0.50 (days L−7…8) → 0.28 (7…4) → 0 (3…0); exponential option `v(d)=exp(−1.2(L−d)/L)` when overreach programmed. Overreach: place at [L+7, L+1] @ +50–150% VL, then taperStart += 6 d and final cut +10 pp, caps 28 d / 70%.

**Quality warnings** — continuous: per event, `loss = 0.19·s²` if s=T−A>0 (too close), `0.10·x²` if x=A−T>0 (too far), min 100; `lossLift = 0.20·loss(top) + 0.50·loss(lastHeavy) + 0.30·loss(lastTouch)`; kg cost = lossLift × achievableGain (SQ 4.5% / BP 3.5% / DL 4.3%) × 1RM. Hard deductions: cessation >7 d **−25**; ≥14 d **−50**; DL cessation <3 d −20; taper >28 d −20; <10 d −20; cut >70% −15; <25% −15; no ≥90% single within 21 d −15 ("opener unvalidated"); never reaches 93% −10 ("second unvalidated"); no preceding overload −10; realization >τ₁ −20. `peakQuality = clamp(100 − Σ, 0, 100)`; A 90+ / B 75–89 / C 60–74 / D <60. UI: grade + per-lift Δ timeline + single highest-value fix; blocking validation on the 7-day cessation ceiling. Ship the methodology-caveat note (FFM = derivation, not live simulator).

## C. Scheme tables

### C1. Wave transmutation — weeks 1..N generalization

Constants: sets = 4 everywhere. Reps: SQ/BP {5,4,3}, DL {4,3,2}. **Final-wave pins**: SQ {79, 82.5, 86} · BP {78, 81.5, 85} · DL {80, 83.5, 87}. RPE caps: steps 1/2/3 = 7.0/7.5/8.0 (DL 8.0 flat).

```
W       = ceil(N / 3)                      // number of waves
skip    = 3·W − N                          // steps dropped from wave 1's front
g(week) = week + skip                      // global step index, 1-based
wave    = ceil(g / 3);  step = ((g−1) mod 3) + 1
pct(lift, week) = finalPin[lift][step] − 2.5 × (W − wave)
reps(lift, step) = repScheme[lift][step]
```
Block always *ends* on the full top wave (86/85/87), so realization and attempt math chain unchanged. Truncated openers land at RPE ≤ 7. Secondary slots keep the **factory lerp** untouched (pause squat 2×3 @ 70→76, Spoto 3×4 @ 70→76, block pull 2×3 @ 72→78, close-grip D4 4×5 @ 70→76, 5-day pause squat 3×5 @ 68→74). Implementation: replace `lerp(start,end,t)` with the wave function for the 3 comp-lift primary slots only; bypass integer rounding of pct (Slot.pct is Double; halves survive `weekToText`). Deload logic unchanged. Golden pins: {79/82.5/86, 78/81.5/85, 80/83.5/87} and offsets {−2.5, −5, −7.5}.

Worked N=6 (SQ): 76.5/80/83.5 then 79/82.5/86. N=8 opens 4×4 @ 77.5 — within 0.5 of factory week 1 (4×4 @ 77).

### C2. DUP accumulation — weekly templates

Zone bands, progressed by the factory lerp `pct(w) = lerp(lo, hi, (w−1)/(N−1))`:
H = 4×8 @ 65→71 (cap 7.0) · P = 4×3 @ 68→72 (cap 6.5, "max bar speed" note) · S = 4×5 @ 75→81 (cap 7.5) · S-DL = 4×4 @ 76→82 (cap 7.5).

**4-day** (slot pool · exercise · sets×reps · band/RPE):

| Day | Slot | Prescription |
|---|---|---|
| 1 SQ | squat pool · Competition Squat | **alternates weekly**: odd wks H 4×8 @ 65→71; even wks S 4×5 @ 75→81 (each parity evaluates the lerp at its own weeks) |
| 1 | squat pool · Pause Squat (0.90) | P 4×3 @ 68→72 |
| 1 | accessory · Leg Press / Lying Leg Curl | 3×10 RPE 8 each |
| 2 BP | bench pool · Competition Bench | H 4×8 @ 65→71 |
| 2 | bench pool · Spoto (0.93) | 3×8 @ 60→65 (7.5) |
| 2 | accessory · OHP 3×10 RPE 8 · Lat Pulldown 3×12 RPE 8 | |
| 3 DL | dead pool · Competition Deadlift | S-DL 4×4 @ 76→82 |
| 3 | dead pool · RDL (0.75) | H-hinge 3×8 @ 55→60 (7.5) |
| 3 | accessory · Barbell Row 3×10 RPE 8 · GHR 3×10 RPE 8 | |
| 4 BP2 | bench pool · Close-Grip (0.92) | P 4×3 @ 68→72 (speed primer first) |
| 4 | bench pool · Competition Bench | S 4×5 @ 75→81 |
| 4 | accessory · Chest-Supported Row 3×10 RPE 8 · Pushdown 3×12 RPE 8.5 | |

Zone map: BP full H→P→S; SQ all three zones per 2 weeks; DL S + hinge-H weekly (coach variant: alternate DL main odd 4×6 @ 70→74 / even 4×3 @ 80→84).

**5-day**: Days 2/3/4 identical; squat becomes true HPS —
Day 1: Competition Squat H 4×8 @ 65→71 · Pause Squat P 3×3 @ 68→72 · Leg Press, Leg Curl 3×10 RPE 8.
Day 5: Competition Squat S 4×5 @ 75→81 · Back Extension 3×10 · Hip Thrust 3×10 · DB Shoulder Press 3×12, RPE 8.

Options (off by default): volume ramp — H slots sets 3→4→4→5→5→5 across 6 wk; RPE-led — hold band midpoint, cap +0.5/2 wk, gated behind novice guard. Deloads: factory policy unchanged. Golden pins: zone bands {65–71, 68–72, 75–81, 76–82}.

### C3. Hypertrophy off-season day templates (new `StartPhase.hypertrophy`, additive rawValue)

Meso spine (main variation slots; deload = **factory deload template verbatim**):
12-wk: wks 1–4 4×12 @ 60/61/62/63 · wk 5 deload · wks 6–9 4×10 @ 64/65/67/68 · wk 10 deload · wks 11–12 4×8 @ 70/72. 10-wk: meso1 · deload · meso2 · wk10 bridge 4×8 @ 70. 8-wk: meso1 · deload · 4×10 @ 65/67/68. 9/11-wk: extend meso 2 with 66; 11-wk keeps wk-10 deload + one meso-3 week @ 71. **Secondary variation = 3×8 @ main−2.** Accessories: double progression to rep-target top under cap, then first two accessories/day 3→4 sets in meso weeks 3–4; reset after deload.

| Day | Slots (pool exercise (mod) — scheme) |
|---|---|
| 1 SQ | High-Bar (0.92) **main** · Pause Squat (0.90) 2° 3×8 @ main−2 · Leg Press 3→4×12 @8 · Walking Lunge 3→4×12 @8 · Leg Extension 3×15 @8.5 · Leg Curl 3×12 @8 |
| 2 BP | Close-Grip (0.92) **main** · Incline (0.85) 2° · Dip 3→4×10 @8 · DB Shoulder Press 3→4×12 @8 · Pushdown 3×15 @8.5 · Lat Pulldown 3×12 @8 |
| 3 DL | RDL (0.75) **main** · Snatch-Grip (0.80) 2° · Barbell Row 3→4×10 @8 · GHR 3→4×10 @8 · Seated Cable Row 3×12 @8 · Back Extension 3×12 @8 |
| 4 BP2 | Larsen (0.90) **main** · Feet-Up (0.92) 2° · Pull-Up 3→4×8 @8 · Chest-Supported Row 3×12 @8 · OHP 3×10 @7.5 · Skull Crusher 3×12 @8 |
| 5 SQ2 (5-day only) | SSB (0.87) **main** · Box Squat (0.92) 2° · Bulgarian Split Squat 3→4×10 @8 · Hip Thrust 3×10 @8 · Good Morning 3×10 @7.5 · JM Press 3×12 @8 |

Golden pins: meso spine {60–63, 64–68, 70–72}, secondary −2. First post-off-season block must re-test/re-estimate 1RM.

## D. Conjugate-inspired exercises to APPEND to seed pools (shortlist)

| Name | Pool | Mod | Why |
|---|---|---|---|
| Floor Press | bench | 0.92 | Westside ME staple; lockout/triceps without leg drive (consensus ~93–95% of bench). |
| Low Pin Press (½–1" off chest) | bench | 0.94 | Kills stretch reflex — off-the-chest strength; pin height must appear in the prescription line. |
| High Pin Press (near lockout) | bench | 1.05 | Supramax lockout overload; pairs with the board press already in the pool. |
| Block Pull (knee height) | deadlift | 1.05 | Supramax lockout + posterior-chain volume (2" blocks already exist; knee height is the distinct overload variant). |
| Halting Deadlift (to below knee) | deadlift | 0.88 | Off-the-floor position strength; complements paused DL. |
| Good Morning | squat (accessory-style) | nil (RPE-only; 0.40 × squat if a mod is forced) | Westside posterior-chain staple; too form-sensitive for tight % — always triples, never singles. |

## E. Coach-facing copy (one paragraph per scheme)

**Linear (factory).** One variable moves: the load climbs a fixed percentage ramp each week at constant sets and reps, straight into the peak. It's the most predictable and auditable scheme — you can read week 6 off the plan in January — and it's the best fit for newer lifters, for realization blocks (a monotonic ramp into a taper is exactly what the peaking research validates), and for anyone whose last linear block delivered. Trust the percentages; cap sets at the listed RPE.

**Wave.** Three-week mini-cycles: reps fall and weight rises for three weeks, then the bar drops back and the next wave starts slightly heavier than the last one did. The drop-back sheds fatigue while fitness sticks, so the top of every wave is hit fresher than a straight ramp would allow — and every third week is a visible win. Same destination as the linear block (the final wave tops out at the exact same weights), different route. Best for experienced lifters whose week 5–6 always seems to collapse.

**Undulating (DUP).** Instead of grinding one rep zone for weeks, each lift sees different jobs across the week — a volume day, a speed day, a strength day, in that order. Research says it's on par with linear overall, with a possible edge for trained lifters and for bench specifically; its biggest practical win is freshness, both physical and mental. Loads still follow percentage bands with RPE caps, so nothing about the plan gets vague — the stimulus just varies day to day instead of month to month.

**Hypertrophy off-season.** No meet on the calendar means the goal changes: build muscle now, convert it to strength later. Main work shifts to close variations of the competition lifts at higher reps and moderate loads, accessory volume roughly doubles, and a light week lands about every fifth week. Reps step down and weights step up across each four-week block. Expect the bar to feel lighter than meet prep — that's the point — and expect a re-test of your max before the next percentage-based strength block.