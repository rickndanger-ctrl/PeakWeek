# Powerlifting Coaching Doctrine — Skill Reference

The complete mental model for an AI coaching assistant supporting meet prep. Grounded in the PeakWeek repo research (`/Users/richardholguin/dev/powerlifting-trainer/docs/research-science.md`, `docs/research-practice.md`) and verified/extended with primary sources. The frozen PeakWeek engine (acc 4x6@67-75, trans 4x4@77-86, real 87-93% singles/doubles, deload 62%, meet week 60/55%, attempts 91/97/101.5%, last heavy DL 10-14d, openers 7-10d) is the trusted baseline; where doctrine differs from the engine, this document says so explicitly so the assistant can advise without contradicting the shipped product.

---

## 1. Block Periodization Doctrine

### 1.1 Why blocks work (the causal model)

- **Verkhoshansky's Long-Term Delayed Training Effect (LTDE):** concentrated loading deliberately depresses performance during the block; fitness expresses only after the load is removed. Fatigue during accumulation is *the intended state*, not a bug. The realization phase unmasks fitness — it does not add it. This is why volume, never intensity, is cut first in a taper.
- **Issurin's residual training effects:** maximal strength residual is **30 ± 5 days**. A strength quality decays within ~a month of not being trained. Hard constraint: no block may leave a needed quality untrained for longer than its residual. For powerlifting (everything is a strength quality) blocks run longer than Issurin's generic 2–4 weeks — commonly 4–6.
- **Honest caveat:** head-to-head studies (Painter et al. 2012/2018) show block trends better than DUP for strength/RFD but *no statistically significant superiority*. Block periodization is a defensible organizing framework, not proven doctrine. Don't oversell it; don't panic-switch a lifter off it either.

### 1.2 The three phases

| Parameter | Accumulation | Transmutation | Realization |
|---|---|---|---|
| Purpose | Muscle CSA, work capacity, weak-point correction | Convert mass/capacity into specific strength; RFD, coordination | Dissipate fatigue, express fitness, calibrate attempts |
| Duration | 4–6 wk | 4–6 wk | 2–4 wk **absolute** (incl. taper) — never a % of prep length |
| Intensity | 65–80% (defensible floor ~72% for 6s; 6@67% is RPE ~4 = junk) | 77–88% (top of band is where the work happens) | 87–95%+; peaking studies used 90–95% |
| Reps | 5–10 | 3–6 | 1–3, mostly 1–2 |
| Weekly sets/comp lift | 8–16, ramping toward MRV | 6–12 | 3–6 |
| RPE | 5–7 early → 8 late | 7 → 9 late | 7–9 singles, rarely 10 |
| Frequency | SQ 2–3 / BP 2–3 / DL 1–2 (METD default: 2/3/1) | same | tapering to 1× each |
| Exercise breadth | Widest — variations far from comp lifts | Narrowing — close variations only | Comp lifts, comp commands, comp gear; accessories near zero |
| Progression | Volume-led: +1–2 sets/wk; load +2.5–5%/wk decelerating | Load-led: +2.5–5%/wk, sets flat or descending | Intensity climbs while sets fall |

**PeakWeek engine note:** the engine runs linear % ramps within fixed set/rep schemes. The known audit findings: acc floor of 67% is sub-stimulative week 1; trans floor 77% wastes week 1; realization ceiling of 93% means the lifter never takes a true RPE 9 single. An assistant should treat engine weeks 1 of each block as intentional ramp-in weeks, and should flag when a lifter's prep has *no* single above 93% before attempt selection (see §3).

### 1.3 Transitions between phases

- Move acc→trans when volume tolerance is built and e1RMs are flat-to-rising under fatigue — typically on schedule, not by feel. Block boundaries are where deloads live (PeakWeek inserts deloads at the trans→real boundary).
- Move trans→real 2–4 weeks out from the meet, *absolute*, regardless of prep length. A 20-week prep does not earn a 5-week peak — that is detraining (max-strength residual is ~30 days and taper research caps at ~2 weeks taper + ≤7 days cessation).
- Specificity monotonically rises: any programming that *adds* variation distance late (new exercises inside 3–4 weeks out) is wrong. Injuries requiring swaps must resolve back to the comp lift by ~3–4 weeks out or attempt expectations get revised down.

### 1.4 Deloads (Bell et al. 2025, NSCA SCJ; survey n=246)

- **Step reduction only** (tapers may be step or exponential; deloads never progressive).
- Volume down **40–60%** (moderate need; 25–45% light, 60–90% heavy), via fewer sets and/or reps. Load down ~10% and/or +1–3 RIR. **Frequency unchanged.**
- Duration **5–7 days**; every **4–8 weeks** (athletes actually do ~every 5.6 wk for ~6.4 days). Reactive deloads may be a single session.
- Evidence honesty: no RCTs; consensus-derived. Some elite coaches think every-4-weeks is too frequent. Treat frequency as a dial, and skip a scheduled deload if readiness is genuinely high.
- **Red flag:** adjacent/back-to-back deload weeks (PeakWeek deliberately prevents this) and deloading straight into a taper — the taper *is* the fatigue-dissipation event; a deload 1–2 weeks before taper start doubles the detraining exposure.

### 1.5 Taper and meet week (Travis et al. 2020; Pritchard survey n=364; Frontiers 2021 RCT)

- Volume −30 to −50% (small-to-moderate beats >50%; never exceed −70%). Intensity either held ≥85% (neuromuscular retention) or reduced in comp week. Step taper preserved Type IIA fibre size (+11%); exponential taper served the **deadlift far better (+8% vs +1%)** — the deadlift wants a longer, gentler taper.
- Per-lift last heavy (>85%) session: **DL 10–14d out** (survey median 7–10, elite up to 2.5wk — bigger/stronger = longer), **SQ 7–10d**, **BP 4–7d**. Load on that final heavy session: **90–92.5% ≈ opener weight** — this is the *opener-confirmation single*.
- Distinguish two events the phrase "openers 7–10 days out" conflates: (1) opener-confirmation single at 90–92.5%, 7–10d out; (2) **meet-week primer singles** at 70–80% SQ/BP, 70–75% DL, 4–6d out, purely motor-pattern maintenance. PeakWeek's meet week at 60/55% is a conservative primer; defensible, at the light end.
- Training cessation: 2–7 days fine; **>7 days costs 1–4% of max strength**. Survey: DL ~5.8d, SQ ~4.1d, BP ~3.9d.
- Meet-week template (Saturday meet): Mon/Tue primer singles; **no deadlifts after Tuesday**; Wed active recovery; Thu rest/travel; Fri weigh-in, rack heights, attempt cards. Accessories eliminated. Light training beats total rest.
- Planned overreach (+50–150% volume-load the week before taper begins) is evidence-supported (+6.4% bench in one trial) but optional and only for experienced lifters.

---

## 2. Autoregulation

### 2.1 RPE fluency (Tuchscherer/RTS convention)

RPE anchored to reps-in-reserve: 10 = 0 RIR; 9.5 = maybe 1 more; 9 = 1 RIR; 8.5 = 1–2; 8 = 2; 7 = 3; 6 = 4. Logged to the half point. The load–reps–RPE triple re-derives a daily max every session.

**RPE → %1RM table (memorize; this is the engine's table too):**

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

Internal consistency: one rep or half an RPE point ≈ same % step (3@10 = 92.2% = 1@8). Caveat: population-average; individual rep-max profiles vary widely — fit the table to the athlete over time from logged triples.

### 2.2 e1RM math

`e1RM = load ÷ table%(reps, RPE)`. Example: 190 kg × 4 @8 → 190 / 0.837 = **227 kg e1RM**. The e1RM trendline per lift is the single best "is it working" signal; judge it block-over-block, not week-over-week (Emerging Strategies principle: don't chase weekly noise).

### 2.3 When % beats RPE, and vice versa

**RPE wins:** variable readiness (sleep, stress, weight cut, travel); stale/unknown 1RM; low-rep near-failure sets (accuracy is highest at RPE 9, low reps); experienced honest athletes; automatic volume regulation via fatigue percents.

**% wins:** novices (measurably inaccurate at RIR under heavy load — have them *log* RPE but not drive load with it); high-rep sets (accuracy degrades); prescriptions far from failure (RPE 7 rated worse than RPE 9); deliberately submaximal work (deloads, speed work, primers — an honest RPE would drag load up); athletes with RPE inflation/deflation habits.

**Professional default = hybrid:** "% band with RPE cap" — e.g. `4×4 @ 80–84%, cap sets at RPE 8, stop adding sets at 9`. Evidence: RPE ≥ % by a small margin (Helms 2018: ~72–79% chance of small advantage; Graham & Cleather 2019 significant for squat; 2025 network meta: APRE > RPE > VBT > %, all gaps modest). PeakWeek prescribes % with an RPE-cap instruction in the coach line — consistent with this doctrine.

### 2.4 Fatigue percents (RTS volume autoregulation)

- **Load drop:** top set at target RPE, drop bar 3–7% (canonical 5%), repeat sets until the reduced load hits the same RPE.
- **Repeats:** same load/reps until RPE ceiling reached.
- **Rep drops:** hold load, cut reps — highest average intensity, most neural.
Built-in progression: fitter athletes need more sets to reach the same fatigue percent — volume self-scales.

---

## 3. Attempt Selection Doctrine

### 3.1 The numbers (of projected meet max — define the reference max explicitly: best gym single, this-block e1RM at RPE 9, or projected max give materially different answers)

| Profile | Opener | Second | Third |
|---|---|---|---|
| Conservative | 89–90% | 94–95% | 99–101% |
| **Standard (engine default)** | **91%** | **97%** | **101.5%** |
| Aggressive | 92–93% | 97–98% | 103–105% |

Validation: IPF Worlds 2012–2019 — successful thirds were preceded by openers at 91% and seconds at 96% *of the third*. Engine's 91/97/101.5 → opener = 89.7% of third, second = 95.6% of third: near-optimal, slightly conservative on the opener (correct direction of error).

### 3.2 Rules with near-universal agreement

- Opener = "a weight you could triple on a bad day" ≈ single @7.5–8. It exists to keep you in the meet and acclimate to commands. **9/9 beats a bigger 6/9 total** — ~50% of all thirds are missed at world level; winners average 8.46/9.
- **Never take a PR as a second.** The second exists to calibrate the third within 2.5–5 kg.
- Miss an opener → **repeat it**, never jump.
- Choose the third from *observed* second-attempt bar speed/video, not feel.
- Jumps: ~5–7.5% SQ/DL, 3–5% BP. Round to 2.5 kg; never propose a sub-minimum (2.5 kg) jump.
- Lift-specific biases: **DL opener more conservative** (~85–88%, end-of-day fatigue); **BP third more conservative** (highest miss + command-failure rate, 53%+ misses at worlds).
- Bomb-out guard: flag any opener above ~95% of the last confirmed heavy single. If prep never included a single ≥93% (the frozen engine's ceiling), the second attempt is technically unvalidated — bias attempt selection conservative and lean harder on second-attempt bar speed.

### 3.3 In-meet adjustment (the decision tree, precomputed on the handler card)

```
Second attempt RPE ≤8.5 (fast, crisp)  → third = second + 2.5–5%  (top of range)
Second attempt RPE 9–9.5 (slow, honest) → third = second + 1.5–2.5% (bottom of range)
Second attempt RPE 10 / grind / miss    → repeat, or minimum +2.5 kg only if made
Missed opener                           → repeat opener exactly
```
Logistics: next attempt due within **~1 minute** of the previous attempt — the tree must be precomputed in three variants (conservative/plan/aggressive) per lift, in kilos with plate breakdowns. Fourth attempts exist in some feds for records only (don't count toward total).

---

## 4. Weak-Point Diagnosis → Exercise Selection

### 4.1 Diagnostic discipline first

The visible sticking point often reflects a positional break *earlier* in the lift (JTS caveat): "hips shot up off the floor" presents as a lockout miss but is an off-the-floor problem. Diagnose from video (0.5× speed), not from where the bar stopped. Weak-point variation work lives in accumulation/transmutation; the last 3–6 weeks are for comp-lift specificity.

### 4.2 Failure point → fix taxonomy

| Lift | Failure point | Primary variation fixes | Muscle builders |
|---|---|---|---|
| Bench | Off the chest | Long-pause bench (2–3ct), Spoto press, wide-grip, dips | Flyes, incline DB press |
| Bench | Mid-range (10–15 cm up; the common raw sticking point) | Spoto, tempo bench, pin press at sticking height | Incline, OHP (shoulders/upper chest) |
| Bench | Lockout | Close-grip, 1–2 board press, floor press, high pin press | Triceps: JM press, skullcrushers, pushdowns |
| Squat | Out of the hole | Pause squat, tempo squat, pin/dead squat from bottom | Front squat, hack squat, leg press; hip thrust |
| Squat | Mid-thigh / "good-morning squat" (chest drops) | Pin squat at sticking point, SSB squat, tempo descent, good mornings | Back extensions, upper-back rows |
| Deadlift | Off the floor | Deficit pulls (2–3"), paused DL below knee, halting DL | Leg press (quads), rows (lats) |
| Deadlift | Lockout / knees | Block pulls (knee height, supramax), RDL, heavy holds | Hip thrust, shrugs, rows, glute/ham work |

### 4.3 Load modifiers — the variation library (variation load = comp 1RM × program% × mod)

Verified against PRS "What Percentages Of Your 1RM To Use On Variations" (Bryce Krawczyk lineage) and cross-checked with the PeakWeek engine's shipped mods. Engine values in **bold** where they exist; they all sit inside the defensible source ranges.

**Squat pool:** Comp squat **1.00** · Pause squat **0.90** (PRS 0.92–0.94 — engine slightly conservative, fine) · High-bar **0.92** (PRS 0.90–0.975) · SSB **0.87** (PRS 0.875–0.90) · Front squat **0.82** (PRS 0.80–0.875) · Tempo squat **0.85** (PRS 0.875–0.925 — engine conservative) · Pin squat **0.88** (PRS 0.875–0.90) · Box squat **0.92**.

**Bench pool:** Comp bench **1.00** · Close-grip **0.92** (PRS 0.96–0.98 — engine deliberately conservative; acceptable, sets will come in under-RPE) · Spoto **0.93** (PRS 0.925–0.95) · Larsen **0.90** (PRS 0.90–0.95) · Tempo bench **0.90** (PRS 0.90–0.97) · Incline **0.85** · 2-board **1.02** (PRS 1.00–1.075) · Feet-up **0.92** (PRS 0.90–0.95).

**Deadlift pool:** Comp DL **1.00** · Paused DL **0.88** (PRS pause-off-floor 0.90–0.95 — engine conservative) · Deficit (2") **0.90** (PRS 0.90–0.95; conventional only — do not prescribe sumo deficits) · Block pull (2") **1.05** (PRS 0.975–1.075; sumo lifters and short arms gain most) · RDL **0.75** (PRS 0.75–0.85) · Snatch-grip **0.80** · SLDL **0.80** · Opposite-stance **0.85**.

**Conjugate-style movements worth having in ANY library** (currently accessories/absent in the engine; recommended mods with sources):

| Movement | Mod (× comp 1RM) | Basis |
|---|---|---|
| **Floor press** | 0.90–0.95 of bench (default 0.92) | Practitioner consensus ~93–95% of bench (StrengthLog comparison; removes leg drive + shortens ROM — the effects roughly cancel). Westside max-effort staple for lockout/triceps. |
| **1–2 board press** | 1.00–1.075 of bench (engine's 1.02 is right) | PRS; overload + lockout. 3-board runs higher still (~1.05–1.10) — supramax overload only. |
| **Low pin press (½–1" off chest)** | 0.925–0.95 of bench | PRS; kills stretch reflex, off-the-chest strength. High pin press (near lockout) is overload: 1.00–1.10. Pin height must be specified in every prescription. |
| **Deficit deadlift (2")** | 0.90–0.95 | PRS; off-the-floor strength; conventional pullers only. |
| **Block pull (knee height)** | 1.00–1.10 | PRS rack-pull-below-knee 1.00–1.10; supramax lockout + posterior-chain volume. Height matters: 2" blocks ≈ 0.975–1.075, knee height ≈ 1.00–1.10. |
| **Good morning** | RPE-only, or 0.35–0.50 of *squat* 1RM | Catalyst Athletics: 20–40% of best squat; Bill Starr rule-of-thumb 50%. Westside: always triples, never singles. Too form-sensitive for tight % prescription — the engine's RPE-only (mod nil) treatment is correct; if a mod is forced, 0.40 is the defensible midpoint. |

General modifier doctrine: modifiers are *starting estimates* — individual anthropometry moves them ±3–5% (femur length for high-bar/pin squat, arm length for block pulls, touch style for Spoto). Track e1RM per variation; the variation-to-comp e1RM *ratio drifting* is itself diagnostic (pause squat e1RM falling relative to comp squat = bottom-position erosion).

---

## 5. Warm-Up Protocols

### 5.1 Gym-day ramp (percentages of the day's top set, rounded to 2.5 kg / 5 lb)

`bar × 5–10 → 40% × 5 → 60% × 5 → 80% × 3 → (90% × 1 when top set ≥ ~85% 1RM) → work sets.`
Reps fall as load rises: fives to 60%, triples 60–80%, singles above 80–90%. With RPE prescriptions, back-calculate the expected top load from current e1RM and use the ramp as the readiness probe: "your 80% single should feel @6; if it's @7.5, today's @8 will be lighter than planned."

### 5.2 Meet-day back room (timing counts attempts, not minutes)

- Set counts: SQ 5–8 warm-up sets, BP 4–6, DL 5–7. Last warm-up ≈ **90% of the opener** (~25 kg under opener for SQ/DL, ~10–15 kg under for BP). Example ramp to a 200 lb opener: 75×5, 95×5, 120×3, 140×1, 160×1, 180×1.
- Clock math: ~1 min/attempt, flights of 12–14 → a flight runs ~45–60 min/lift. Triggers: start warming up **when the prior flight begins that lift**; 4th-to-last warm-up when they start seconds; 3rd-to-last halfway through seconds; 2nd-to-last at the start of thirds; **last warm-up halfway through their thirds (~5–8 min before you lift)**. Flight A: general prep 45 min before start, bar work 30 min, last warm-up 5 min out. Space own sets 5–7 min.
- Handler card contents: full warm-up list with kilo plate breakdowns per side, opener, second/third in three variants with the decision rule attached, rack heights, gear notes, 1-minute attempt-submission reminder. Precompute everything — shared racks (3–5 lifters working in) leave no time for arithmetic.

---

## 6. Programming Red Flags (what the assistant must catch)

1. **Junk volume:** any main-lift set landing below ~RPE 5 for a trained lifter (e.g. 6 reps @67% ≈ RPE 4). Week-1 ramp-in is acceptable *once*; multiple sub-RPE-5 weeks are wasted training. Cross-check every %×reps prescription against the RPE table.
2. **Fatigue masking:** prescribed @8 repeatedly coming in @9.5 = loads mis-calibrated or fatigue accumulating; @8 coming in @6.5 = sandbagging or peaking early. Always cross-reference wellness before acting: bad RPEs + 5 h sleep + work crisis → leave the program alone, cut a backoff set; bad RPEs with good sleep → programming problem.
3. **Missing taper / proportional taper:** realization scaled as a % of prep length (>4 weeks of peaking on long preps = detraining; <10 days from last hard week to platform = under-recovered). Clamp 2–4 weeks absolute.
4. **Adjacent deloads** or deload immediately before the taper. Also: no deload anywhere in a 6+ week block.
5. **Volume cut >70% in taper** — explicit detraining threshold. And >7 days total cessation (costs 1–4% strength).
6. **Heavy deadlift too late:** any pull >85% inside 7 days, or any deadlift after Tuesday of meet week (Saturday meet).
7. **Unvalidated attempts:** opener chosen with no single ≥90% in the last 3 weeks; second attempt above anything ever touched in the block; planned PR second.
8. **Specificity inversion:** new exercise variations, high variation load, or heavy accessory work inside 3–4 weeks out; comp commands (pause, depth, reset pulls) not enforced in realization.
9. **No volume progression in accumulation:** flat sets across a whole block means load is the only progressing variable — the block's purpose (progressive volume toward MRV) is unmet.
10. **RPE-driven loading for a novice**, or RPE prescriptions on high-rep accessory work where accuracy is poor.
11. **Missed sessions > bad sessions:** compliance gaps change the plan more than poor performances. Never stack missed volume onto the next week during meet prep — skip it.
12. **Bodyweight drift:** trendline projecting >3–5% over the class limit inside 2 weeks (water cut ceiling for 24-h weigh-in; much lower for 2-h/IPF) — escalate, don't program around it silently.
13. **e1RM trending down across a full block** (not a week) — the block hypothesis failed; next block must change, per Emerging Strategies review discipline.

---

## 7. Communication: How Plans Are Written to Lifters

- **Coordinate system is weeks-out**, everywhere ("6 weeks out"), not calendar dates. Every artifact anchors to the meet date.
- **A prescription line carries:** exercise (with variation + setup: bar, stance, grip, pin/board height), sets×reps, intensity (%, RPE, absolute, or hybrid "80% cap @8"), load-drop instruction if any, tempo/pause counts, rest, the computed expected load ("~150 kg should be @8"), one coach cue, film-this-set flag. PeakWeek's PDF footer convention — "loads rise week to week — trust the percentages, cap sets at the listed RPE" — is the correct tone: directive, brief, pre-empting the obvious question.
- **Cues: external > internal, one at a time.** Squat: "spread the floor," "big air," "push the floor away," "chest through." Bench: "break the bar," "press yourself away from the bar," "drive your feet." Deadlift: "push the floor away," "pull the slack out," "bend the bar around your shins," "hips through." Write "only think about X this week" — never stack cues. Keep a per-lifter list of cues that have landed.
- **Check-in replies are short, personal, and reference specifics** from their week (a set, a video timestamp, a comment they made). Generic replies lose clients. Video feedback: 1–2 cues max, timestamped.
- **Explain the why in one sentence when the plan looks strange** ("this week feels light on purpose — we're letting the last block show up"). Lifters comply with tapers they understand and sabotage ones they don't.
- **Meet-day communication is precomputed, not improvised:** the handler card holds the decision tree; mid-attempt shouting is limited to the lifter's one known cue word and commands ("press!"). Attempt changes are the coach's arithmetic, delivered as a single number to the table within the 1-minute window.
- **Block review notes** (Emerging Strategies): each block ends with a written hypothesis/outcome line ("high-frequency bench: e1RM +4 kg — keep") — this is how 30 clients' histories become individualized doctrine.

---

## Key sources
Repo: `/Users/richardholguin/dev/powerlifting-trainer/docs/research-science.md`, `docs/research-practice.md`, `Sources/PeakWeek/Engine.swift` (shipped mods), `Sources/PeakWeek/ExerciseLibrary.swift`.
External: Travis et al. 2020 *Sports* (taper review); Frontiers Physiol 2021 (step vs exponential taper RCT); Pritchard/Travis 2022 JSCR (n=364 taper survey); Bell et al. 2025 NSCA SCJ (deloading); Issurin 2008/2015 (block periodization, residuals); Helms 2018 Frontiers (RPE vs %); Androulakis-Korakakis 2021 (minimum effective dose, 2/3/1 frequency); IPF attempt analyses (BMC 2022); [PRS variation percentages](https://prsontheplatform.com/2018/06/07/what-percentages-of-your-1rm-to-use-on-variations/); [StrengthLog floor press vs bench](https://www.strengthlog.com/floor-press-vs-bench-press/); [Catalyst Athletics good morning](https://www.catalystathletics.com/exercise/183/Good-Morning/); [Westside good morning doctrine](https://www.westside-barbell.com/blogs/the-blog/the-powerlifting-good-morning); JTS weak-point series; RTS/Tuchscherer (RPE table, fatigue percents, Emerging Strategies).