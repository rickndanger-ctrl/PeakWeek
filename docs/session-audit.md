# Session-structure audit (2026-08-03)

Verified by a 20-agent audit fleet against docs/session-structures.md + the powerlifting skill doctrine.

## Applied fixes

### 21 pressing vs 9 pulling sets; Day 5 adds a press, no pull
Weekly presses: Comp Bench 4x8 (D2) + Spoto 3x8 + OHP 3x10 + CGB 4x3 (D4) + Comp Bench 4x5 (D4) + DB Shoulder Press 3x12 (D5) = 21 sets. Weekly pulls: Lat Pulldown 3 + Barbell Row 3 + Chest-Supported Row 3 = 9 sets (2.33:1). The factory 5-day solves this exact slot correctly — its Day 5 adds Pull-Up 3x8, giving 14:12. DUP's Day 5 instead adds a third pressing accessory, worsening the template's already bench-heavy tilt. 9 total back sets is also below the ~10-set priority-group floor for lats/mid-back in an accumulation phase.
**Action:** On DUP 5-day Day 5, replace DB Shoulder Press 3x12 RPE 8 with Pull-Up 3x8 RPE 8 (or Seated Cable Row 3x12 RPE 8). Result: pulls 9→12, presses 21→18, matching the factory 5-day pattern. Accessory-only change; mains untouched.

### Hypertrophy Day 2: Lat Pulldown (compound) dead last, after isolation
All three hypertrophy weeks, both 4- and 5-day (lines 214-220, 244-250, 274-280, 558-564, 595-601, 632-638): Day 2 order is CGB -> Incline -> Dip -> DB Shoulder Press -> Tricep Pushdown -> Lat Pulldown. The only pull slot on this push-heavy day sits behind an isolation triceps slot, violating compound-before-isolation, and gets the most-fatigued position in a 19-21 set session. Every other hypertrophy day orders compounds before isolations correctly.
**Action:** Swap slots 5 and 6 on Hypertrophy Day 2: Lat Pulldown 3x12 fifth, Tricep Pushdown 3x15 last. Pure accessory reorder, no set/rep/RPE changes.

### DUP 5-day Day 5 adds only push and redundant posterior chain, zero pull
DUP 5-day Day 5 (Squat strength) accessories are Back Extension 3x10, Hip Thrust 3x10, DB Shoulder Press 3x12. The DB Shoulder Press is the week's second vertical-press slot (OHP 3x10 already on Day 2, same pattern, adjacent rep zone), and Back Extension 3x10 + Hip Thrust 3x10 duplicate Day 3's Glute-Ham Raise 3x10 + RDL hinge work in the exact same rep zone. Net effect: the 5th day pushes the week to ~21 pressing sets vs 9 pulling sets (worst ratio of any program, ~2.3:1) while adding no new movement pattern. This directly violates the coach's balanced pull/push and no-redundant-slots priorities. Contrast with the factory 5-day Day 5, which correctly adds Pull-Up + GHR + Skull Crusher.
**Action:** DUP 5-day Day 5: replace DB Shoulder Press 3x12 with Pull-Up 3x8 (mirrors factory 5-day Day 5 and gives the week a second vertical pull). Optionally also replace Back Extension 3x10 with Face Pull 3x12 to break the triple-hinge redundancy with Day 3.

## Open considerations (coach decides)

### Lats/mid-back at 9 weekly sets, below the 10-set priority floor
Both 4-day accumulation templates carry exactly 3 pulling slots x 3 sets = 9 weekly back sets (factory: Lat Pulldown, Barbell Row, Chest-Supported Row; DUP: same three). Pressing is 14 (factory) / 18 (DUP). Lats/mid-back are on the powerlifting priority list; 9 sets sits just under the ~10-20 landmark for a priority group in a volume phase, while every other priority group clears 10 (quads 11-13, glutes 15-17, hams 10-13, chest 11-15).
**Option:** Bump one pulling slot from 3 to 4 sets in 4-day accumulation — cleanest is Barbell Row 3x10 -> 4x10 on Day 3 (it feeds deadlift directly). Brings back to 10 sets with zero new slots. DUP 4-day would benefit slightly more given its 18 pressing sets.

### Zero direct biceps sets in any template, including 12-wk hypertrophy off-season
Indirect coverage exists (Lat Pulldown, Pull-Up, rows: ~6-15 indirect sets/wk depending on template). Acceptable in meet prep (specificity, limited slot budget). But the hypertrophy off-season is explicitly the weak-point mass phase, and direct elbow-flexor work is the standard insurance for distal biceps tendon health under heavy deadlifts — 12 weeks with 0 direct sets is the one place the omission bites.
**Option:** Add one curl slot in hypertrophy templates only: e.g. DB Curl 3x12 RPE 8 appended to Day 3 (Hinge) after Seated Cable Row, both 4- and 5-day. Meet-prep templates: leave as-is.

### Zero direct trunk work across every template and phase
All core stimulus is isometric via squats/deadlifts (7-14 heavy axial sets/wk in strength phases — defensible maintenance). In the hypertrophy off-season, where axial loading is lighter-relative (60-72%) and the stated purpose is CSA and work capacity, 0 direct sets for 12 weeks is the weakest link. Not a red-flag violation, and many competent PL programs run this way; it is a coach-preference call.
**Option:** If Rick wants coverage: hanging leg raise or ab-wheel 3x10-12 as a final slot on one day per week in hypertrophy (Day 5 fits; it currently ends on JM Press). Strength/realization phases: acceptable omission, no change.

### Quads at ~26 weekly sets (wk1), ~28 at wk3 ramp — above the 10-20 landmark
Quad-primary count wk1: High-Bar 4 + Pause 3 + Leg Press 3 + Lunge 3 + Leg Ext 3 (D1) + SSB 4 + Box Squat 3 + Bulgarian Split Squat 3 (D5) = 26 sets, nearly all RPE 8+. Glute-involved volume exceeds 30 sets. Per-session split is tolerable (16 on D1, 10 on D5), and a dedicated mass phase can justify high-teens-to-low-20s, but 26-28 is where marginal sets go junk and recovery cost compounds over a 4-wk meso. Also note Walking Lunge (D1) and Bulgarian Split Squat (D5) are near-duplicate unilateral slots — acceptable since they land on different days, but they are the natural trim point.
**Option:** If trimming: drop Box Squat 3x8 from Day 5 (most redundant with SSB same day) or cap Leg Extension at 2x15, landing quads ~22-23. If Rick wants a deliberate quad specialization block, leave it — but exclude the D5 slots from the 3->4 accessory ramp so wk3 doesn't push past 28.

### Wk3 'acc ramp' bumps only 2 of 4 accessory slots per day vs doctrine's '4 slots x 3->4 sets'
SKILL.md describes hypertrophy accessory volume as 'doubled (4 slots x 3->4 sets/day)'. The wk3 dump shows exactly 2 slots per day at 4 sets (D1: Leg Press, Lunge; D2: Dip, DB Shoulder Press; D3: Barbell Row, GHR; D4: Pull-Up only — actually 1 slot; D5: BSS only). Either the ramp completes at wk4 (not shown in the dump) or the engine under-delivers the documented ramp. Pure accounting discrepancy — needs the wk4 emission to adjudicate.
**Option:** Verify wk4 output: if all 4 accessory slots reach 4 sets by wk4, doc and engine agree and this is 'fine'; if not, either fix the ramp schedule or amend SKILL.md wording. No slot change proposed until verified.

### Hypertrophy 5-day Day 5: Good Morning after unilateral/glute fatigue
Day 5 (lines 579-585 and later weeks): Safety Bar Squat -> Box Squat -> Bulgarian Split Squat -> Hip Thrust -> Good Morning -> JM Press. Good Morning is a spinal-loading compound hinge performed at slot 5 on erectors already fatigued by two squat variations plus split squats; technique breakdown risk at RPE 7.5 x10 is real. Compound-before-isolation also argues for it earlier.
**Option:** Move Good Morning to slot 3 (after Box Squat, before Bulgarian Split Squat) on Hypertrophy Day 5. Accessory reorder only. Same logic applies more mildly to Wave/Transmutation Day 5 (Pause Squat -> Barbell Row -> Good Morning, lines 403-406, 520-523, 542-545) where GM follows row-induced erector fatigue — lower priority since it is only 3 slots.

### Transmutation Day 4: Pull-Up after JM Press
Factory/Wave transmutation Day 4 (lines 77-80, 180-183, 399-402, 516-519): Close-Grip Bench -> JM Press -> Pull-Up. The compound pull sits behind the elbow-dominant JM Press. Minor — pull-up performance is barely affected by triceps fatigue — but it breaks the compound-accessory-before-isolation-adjacent convention the rest of the engine follows.
**Option:** Swap Day 4 slots 2 and 3: Pull-Up 3x8 before JM Press 3x8. Cosmetic consistency fix; skip if the coach prefers pressing slots contiguous.

### 4-day accumulation: Barbell Row and Chest-Supported Row are same pattern + same rep zone
In both Factory acc 4-day and DUP 4-day, Barbell Row 3x10 (Day 3) and Chest-Supported Row 3x10 (Day 4) are the same horizontal-row pattern in the identical rep zone, while vertical pulling has only one slot (Lat Pulldown 3x12) and total upper pull is 9 sets vs 14-18 pressing sets. One of these row slots is buying nothing the other doesn't. The pairing is partially defensible (BB row loads erectors on DL day, CSR spares them the day after), so this is a judgment call, but converting one to a vertical pull closes the bigger gap.
**Option:** Factory acc 4-day and DUP 4-day, Day 4: swap Chest-Supported Row 3x10 for Pull-Up 3x8 (the factory 5-day already makes exactly this choice on Day 5). If lat pulldown fatigue on Day 2 is a concern, keep CSR but move it to a different rep zone (3x8) at minimum.

### Accumulation weeks run ~1.6-2.3:1 press-to-pull; 9 pull sets is the floor everywhere
Weekly upper-pull sets are pinned at 9 (Lat Pulldown, Barbell Row, CSR) across factory 4-day (vs 14 press + 3 triceps), DUP 4-day (vs 18 press + 3 triceps), and DUP 5-day (vs 21 press). Press dominance is normal in powerlifting since bench frequency is the point (METD 2/3/1 means 3 bench exposures), but the coach's stated priority is balanced pull/push and only the factory 5-day (12 pull via Day 5 Pull-Up) approaches it. Main-lift numbers are frozen, so the only lever is accessory selection.
**Option:** If the coach wants closer to 1:1.5, add one pull slot per 4-day accumulation week without touching mains: Factory Day 4's Leg Extension 3x12 (a quad isolation parked on a bench day, with quads already served by Leg Press + two squat slots) is the natural slot to convert to Face Pull or Rear-Delt Row 3x12. Otherwise accept the ratio as sport-normal and note it.

### Hyp 5-day stacks a third triceps isolation while no program anywhere has elbow flexion
Hypertrophy 5-day Day 5 adds JM Press 3x12 on top of Skull Crusher 3x12 (Day 4, same elbow-extension pattern, identical rep zone) and Tricep Pushdown 3x15 (Day 2) — 9 weekly sets of triceps isolation beyond five pressing mains. Meanwhile there is not a single direct biceps/curl slot in any program in the entire suite, including the off-season hypertrophy block whose stated purpose is mass and weak points. Rows and pull-ups cover biceps indirectly, but in a doubled-volume off-season block one curl slot is standard for elbow health and pulling weak points. Also minor: Seated Cable Row 3x12 (Day 3) and Chest-Supported Row 3x12 (Day 4) are same pattern + same rep zone in the hyp week.
**Option:** Hyp 5-day Day 5: swap JM Press 3x12 for EZ-Bar or DB Curl 3x12 (JM's lockout-builder role is already covered twice over in this phase). Optionally differentiate the hyp rows by making Chest-Supported Row 3x8-10 or a single-arm DB row.

### No accessory volume progression within accumulation (red flag 9, accessory-side)
Factory accumulation week 1 and week 4 are byte-identical on accessories (3x10/3x12 throughout); DUP wk1 vs wk2 likewise. Only main-lift %/load ramps (67->75%), i.e. the block progresses load-led, but accumulation doctrine is volume-led with weekly sets ramping. Since main-lift slots are frozen, accessory sets are the only available volume lever — and the engine already owns the mechanic: the hypertrophy scheme ramps selected accessories 3->4 sets at week 3 ('acc ramp'). However, factory golden tests must stay byte-identical, so this cannot be a silent factory change.
**Option:** Offer an opt-in 'accessory acc-ramp' toggle (same mechanic as the hypertrophy wk3 ramp): in accumulation weeks 3-4 (and DUP weeks 4-6), raise the two accessory slots from 3 to 4 sets. Factory default unchanged; coach enables per block.

### RPE targets prescribed on high-rep accessories (red flag 10)
Every 12-15-rep accessory in the dump carries an RPE prescription (Tricep Pushdown 3x12 @ 8.5, Leg Extension 3x15 @ 8.5, Lat Pulldown 3x12 @ 8.0, etc.). The doctrine's own red-flag list says RPE is unreliable on high-rep accessory work — rep-in-reserve accuracy degrades badly past ~8 reps. Sets/reps and RPE 8-8.5 intent are phase-correct; only the prescription language is the issue. This is display/labeling, not loading math, so it is squarely a coach-preference call.
**Option:** For accessory slots at 10+ reps, render the target as RIR ('leave 2 in reserve') or a plain rep target instead of an RPE number; keep RPE tags on main lifts and sub-8-rep secondaries. No set/rep/order changes.

## Audited healthy
- No direct side-delt or calf work — acceptable omissions for powerlifting
- All eight priority groups covered weekly with healthy numbers (esp. 5-day)
- Deliberate accessory narrowing matches phase math exactly
- Squat/deadlift interference spacing is healthy across all templates
- Session length: all sessions well under the 25-set cap
- Realization, deload, and meet-week sessions correctly strip accessories
- Main -> secondary -> compound -> isolation ordering holds everywhere else
- Hypertrophy doubling claim verified and volume well-distributed
- Factory and Wave 5-day Day 5s add meaningful, gap-filling work
- Transmutation accessory selection is correctly pull-dominant
- Deload, realization, and meet-week minimal coverage is appropriate
- Hamstring:quad is balanced in every phase
- Accessory volume tapers correctly across phases (factory prep, 4- and 5-day)
- No late accessory novelty — red flag 8 clean across the entire dump
- Realization accessory RPE correctly lightened; meet week correctly bare
- DUP and wave schemes keep their host phase's accessory intent
- Hypertrophy off-season honors its accessory doctrine including intra-meso ramp
- Deload week introduces two accessories not used in the surrounding blocks (4-day factory)

## Round 2 — coach's decisions applied (2026-08-03)

- **Core on squat days** (new CORE pool: Ab Wheel Rollout, Hanging Leg Raise,
  Cable Crunch, Plank): accumulation D1 3×10, transmutation D1 2×10 (phase-
  tapered), DUP D1 3×10, hypertrophy D1 3×12 + D5 3×12. Realization/meet: none.
- **Biceps, off-season only** (new ARMS pool: DB/EZ-Bar/Hammer Curl): hypertrophy
  hinge day 3×12; 5-day D5 curls REPLACE the third triceps slot (JM Press) —
  coach's fatigue-aware call keeps meet prep curl-free.
- **Barbell Row 3×10 → 4×10** in accumulation D3 (factory + DUP): 10 direct
  weekly back sets. Note: deadlift/RDL are counted as hinge, not rowing —
  their isometric lat/erector loading is real but not row-equivalent.
- **RIR for ALL accessories** (coach's preference): accessory slots render
  reps-in-reserve everywhere — texts ("· 2 RIR"), PDFs (EFFORT column), and
  the editor (RIR field, converting to stored RPE). Percentage work keeps RPE.
- Open items the coach parked: hyp 5-day quad ceiling (kept as a deliberate
  specialization; weekly rep-range edits already exist per-week in the editor),
  remaining minor reorders.
