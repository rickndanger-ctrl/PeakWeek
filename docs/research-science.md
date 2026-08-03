# Block Periodization for Powerlifting — Exhaustive Research Report

**Purpose:** drive feature design for a professional coaching app. Section 8 audits the current engine defaults against the literature and enumerates the options a pro coach would expect to vary.

---

## 0. Executive verdict on the current engine (detail in §8)

| Current default | Verdict | Headline issue |
|---|---|---|
| acc ~40% / trans ~40% / real ~24% of weeks | **Partly defensible** | (a) sums to 104%; (b) realization scaled *proportionally* to prep length, but the taper literature is *absolute* (1–2 wk + 2–7 d cessation). A 20-wk prep gets 4.8 wk of realization → detraining risk. |
| acc 4×6 @ 67–75% | **Bottom of band is not defensible** | 6 reps @ 67% ≈ RPE 4 (~6 RIR) on the Tuchscherer table — non-stimulative junk volume for a trained lifter. Band should start ≥72%. |
| trans 4×4 @ 77–86% | **Top defensible, bottom soft** | 4 @ 77% ≈ RPE 5.5; 4 @ 86% ≈ RPE 9. Fine as a ramp, but week 1 is a wasted week. |
| real singles/doubles @ 87–93% | **Under-ceilinged** | A single @ 93% ≈ RPE 8.3; the athlete never touches a genuine heavy single. Peaking studies used 90–95% for primary lifts, and coaches near-universally want one ~RPE 9 single (≈95–97%) to calibrate attempts. |
| attempts 91 / 97 / 101.5% | **Defensible, near-optimal** | Matches IPF championship data (successful thirds were preceded by openers at 91% and seconds at 96% *of the third*) and coach consensus. Needs lift-specific and risk-profile variants. |
| last heavy DL 10–14 d out | **Defensible but conservative** | Survey median of 364 raw powerlifters: 7–10 days. Practitioner range spans 7 d → 2.5 wk. Must be per-lift and per-athlete. |
| openers 7–10 d out | **Defensible under one reading, wrong under another** | Matches the survey's "final heavy session at 90.0–92.5% 1RM, 7–10 d out". But it must be distinguished from meet-week *primer* singles (typically 4–6 d out at 70–80%). |
| **No deload appears in the model** | **Gap** | Consensus: 5–7 d, every 4–8 wk, step reduction. Missing entirely from the phase math. |
| **No autoregulation layer** | **Gap** | RPE loading beats fixed % by a small margin in trained lifters (Helms 2018; Graham & Cleather 2019) and is the professional default. |

---

## 1. Scientific basis

### 1.1 Verkhoshansky — conjugate sequence system and the Long-Term Delayed Training Effect (LTDE)

Yuri Verkhoshansky's work with elite track-and-field jumpers is the origin point. He concentrated a large volume of barbell strength work into a compressed cycle ("concentrated unidirectional loading"). Athletes got **weaker during the block** — then, after the concentrated strength work ceased and was replaced by lower-volume specific work, performance rose sharply, reportedly up to ~30% above baseline in his subjects. He named this the **Long-Term Delayed Training Effect (LTDE)**.

The **Conjugate-Sequence System (CSS)** follows: training means are sequenced so that the morpho-functional reconstruction produced by block A becomes the substrate on which block B's training effect is built. Block A's concentrated strength load temporarily depresses neuromuscular function; block B exploits the delayed effect as work capacity rebounds.

**The programming implication for a coaching app:** fatigue is not an accident of the accumulation block — it is *the intended state*, and the realization block exists to unmask fitness, not to add it. This is why volume, not intensity, is cut first in a taper.

**Known limitation (Issurin's critique, 2015 review):** Verkhoshansky never accounted for residual training effects. If a strength block is followed by a 6–12 week block of another quality, maximal strength decays substantially — the residual for maximal strength is only about **30 ± 5 days**.

### 1.2 Issurin — Block Periodization (BP), multi-targeted version

Vladimir Issurin (Wingate Institute) formalized the modern model. Key structural claims from *Block Periodization: Breakthrough in Sport Training* and his reviews (*J Sports Med Phys Fitness* 2008; *Sports Medicine* 2015):

- **Mesocycle-block duration: 2–4 weeks.** Highly concentrated workloads on a *minimal number of compatible* abilities.
- **Three block types form a training "stage" of ~2 months**, ending in a competition or trial.
- **Annual cycle = 5–7 such stages**, depending on the competition calendar.
- **Compatibility rule:** non-compatible modalities are separated into different blocks, because concurrent training of basic abilities and high-intensity specific work produces conflicting physiological responses — the stress mechanism suppresses homeostatic regulation and degrades the basic-ability training.

**Residual training effects table (Issurin & Lustig 2004; reproduced widely):**

| Ability | Residual duration |
|---|---|
| Aerobic endurance | 30 ± 5 days |
| **Maximal strength** | **30 ± 5 days** |
| Anaerobic glycolytic endurance | 18 ± 4 days |
| Strength endurance | 15 ± 5 days |
| Maximal (alactic) speed | 5 ± 3 days |

**This is the hard constraint on block length for powerlifting.** Maximal strength residual ≈ 30 days means a strength/transmutation block cannot be followed by more than ~4 weeks of non-strength work before decay. For powerlifting — where nearly everything is a strength quality — the residual concern is mostly about *hypertrophy residuals* and *technical/specific* residuals rather than a true conflict, which is why powerlifting BP blocks are commonly *longer* than Issurin's 2–4 weeks.

### 1.3 Phase definitions and physiological rationale

**Accumulation.** Target: basic abilities — muscle cross-sectional area, work capacity, general coordination, weak-point correction. Governed by **homeostatic regulation** (Bernard, Cannon). Extensive, voluminous, moderate intensity. Physiologically: stimulates protein synthesis and mitochondrial biogenesis, predominantly with slow-twitch fibre involvement in the endurance context; in strength sport the analogue is myofibrillar hypertrophy and connective-tissue/work-capacity development. Highest exercise variety, lowest specificity.

**Transmutation.** Target: convert accumulated non-specific potential into event-specific preparedness. Governed by **stress adaptation** (Selye) — high-intensity glycolytic and high-tension work triggers a genuine stress response. Volume drops, intensity and specificity rise. Physiologically: adaptive modification in fast-twitch glycolytic and oxidative-glycolytic fibres; in powerlifting, rate-of-force-development, intermuscular coordination, and load-specific motor pattern refinement.

**Realization.** Target: recovery and peaking. Not a new stimulus — it is fatigue dissipation so that previously built adaptation can express itself. Physiologically, the peaking/taper literature reports: accentuated stress-related and myogenic gene expression, increased muscle glycogen, and increases in **Type IIA fibre size (+11% after a step taper)** with a shift toward IIA myosin isoforms (Travis/Bazyler lineage; Frontiers in Physiology 2021).

### 1.4 Honest evidence caveat — do NOT oversell BP in the app's marketing copy

- Head-to-head **block vs. daily undulating periodization** in D-I track athletes: trends favoured block for strength and RFD, but **no statistically significant differences** (Painter et al., *J Strength Cond Res* 2012 / follow-up 2018).
- Broader meta-analyses find **no difference between linear and undulating models** for upper- or lower-body strength, and negligible differences for hypertrophy.
- Issurin's own 2015 *Sports Medicine* review distinguishes two BP versions: the **concentrated unidirectional (CU)** model (Verkhoshansky's) which did *not* improve sport-specific performance in combat/team sports or elite swimming; and the **multi-targeted BP** model, which showed superiority over traditional preparation across 28 studies in endurance, team, dual, strength/power and recreational populations. He explicitly notes successful application of multi-targeted BP to **powerlifters, bodybuilders and judo athletes**.

**Design implication:** BP is a defensible, well-supported *organising framework*, not a proven superior model. The app should let a coach choose the organising model (block / DUP / conjugate / hybrid) rather than hard-coding block as the only truth.

---

## 2. Concrete programming guidelines per phase (powerlifting)

### 2.1 Consolidated parameter table

| Parameter | Accumulation | Transmutation | Realization |
|---|---|---|---|
| **Typical duration (powerlifting)** | 4–6 wk (Issurin's generic 2–4 wk is commonly extended for PL because abilities trained are narrow) | 4–6 wk | 2–4 wk (incl. taper) |
| **Intensity, main lifts** | 60–80% 1RM; most sources 65–75% | 75–90% 1RM; most 80–87.5% | 87–95%+ 1RM; peaking studies used **90–95%** for primary lifts |
| **Reps/set, main lifts** | 5–10 (commonly 6–10) | 3–6 (commonly 3–5) | 1–3, predominantly 1–2 |
| **Sets/session, main lift** | 3–5 work sets, progressing | 3–5 work sets | 3–5 total (e.g. 1×1 + 3×2) |
| **Weekly sets per competition lift** | ~8–16 (start near MEV, ramp toward MAV/MRV) | ~6–12 | ~3–6 |
| **RIR / RPE target** | 3–5 RIR (RPE 5–7) early → 1–3 RIR late | 2–3 RIR (RPE 7–8) → RPE 8–9 late | RPE 7–9 on singles; rarely RPE 10 |
| **Frequency per lift** | 2–3× / wk | 2–3× / wk (squat/bench), 1–2× DL | 1–2× / wk, tapering to 1× |
| **Exercise selection breadth** | Widest: 3–5 accessories per movement pattern, variations far from comp lifts (SSB, tempo, pause, RDL, high-rep upper back, etc.) | Narrowing: variations *close* to comp lifts (pause squat, close-grip, deficit/block pulls), 1–3 accessories per lift | Narrowest: comp-command lifts only, comp gear, comp technique; accessories near-zero |
| **Week-to-week progression** | Volume-led: +1–2 sets/wk, or double progression; load +2.5–5% (or 5–10 lb) per week | Load-led: +2.5–5% per week, holding sets; reps may drop 6→5→4→3 | Intensity-led then volume-cut: singles climb ~2.5–5% while total sets fall |

**Sources for the ranges:** the accumulation 50–75% / transmutation 75–90% / realization 90%+ framing is the standard practitioner statement; the concrete 4×8–12 @ 65–75% → 4×3–5 @ 80–90% → 3×1–3 @ 90–95% template is a common published powerlifting implementation (Grinder Gym; also matches the JTS/Israetel phase parameters of 5–10 reps hypertrophy, 3–6 reps strength, 1–3 reps peaking). The 90–95% figure for the realization/step-taper week comes directly from the controlled study (Frontiers 2021).

### 2.2 Frequency — what the evidence supports

- **Volume-equated, frequency does not matter much.** Grgic et al. meta-analysis: higher frequency → greater strength gains overall, but **in the volume-equated subgroup the frequency effect disappeared**. No additional benefit from 2 → 4 sessions when volume is matched.
- Bench press shows the cleanest dose–response, with 3×/wk producing the largest gains; lower-body gains were similar at 2 vs 3×/wk.
- Practical rationale for spreading volume: avoids the RPE spike that follows large single-session squat volumes.
- **Minimum effective dose for powerlifters** (Androulakis-Korakakis et al., *Front Sports Act Living* 2021): ~**3–6 working sets of 1–5 reps per week per powerlift**, spread over **1–3 sessions**, at **>80% 1RM**, **RPE 7.5–9.5**, for **6–12 weeks**, produces strength gains. Their optimal weekly frequency pattern was **2 (squat) – 3 (bench) – 1 (deadlift)**. Adding **2–3 back-off sets at ~80% of the single's load** meaningfully improved outcomes vs. the bare minimum. Accessories, when used: **1–3 per powerlift at RPE 7–9, ~6–10 reps**.

**Design implication:** the app should treat 2/3/1 (SQ/BP/DL) as a sane default frequency and expose per-lift frequency, because deadlift frequency is the single biggest individual-difference lever in powerlifting.

### 2.3 Week-to-week progression rates

- Common published progression: **+2.5–5% load per week**, or **+2.5–5 kg per week**, holding reps.
- Progression must **decelerate** — 5 kg wk1→2, then 2.5 kg thereafter is the standard advice; you cannot add 5 kg indefinitely.
- Volume progression alternative: **+1–2 sets per exercise per week** at constant load (the RP "summated microcycle": start near MEV, add sets and load weekly for ~4 weeks, deload week 5).
- Double progression (work bottom→top of the rep range, then add load) is the standard accumulation-block mechanism.
- Israetel/JTS hypertrophy-phase specific: **+5–10 lb per week**, deload every 4–6 weeks by halving reps while keeping load heavy.

---

## 3. Deload science

The strongest current source is **Bell, Darragh, Travis, Rogerson & Nolan (2025), "A Practical Approach to Deloading: Recommendations and Considerations for Strength and Physique Sports," NSCA *Strength & Conditioning Journal***, which supersedes the older blog-tier guidance. Its Table 3 is directly implementable.

### 3.1 Definition and boundary vs. taper

| | Taper | Deload |
|---|---|---|
| Position | Immediately before competition | Anywhere in the program; also reactively |
| Objective | Peak performance | Restore readiness for the *next* block |
| Approach | Progressive (exponential) **or** step | **Step only** |

### 3.2 Recommended deload parameters (Bell et al. 2025, Table 3)

- **Approach:** a single step reduction in total training load at the start of the deload (not progressive).
- **Volume reduction, scaled to recovery need:**
  - Low recovery need: **≤25–45%** below the previous block's normal volume
  - Moderate: **40–60%**
  - High: **60–90%**
  - Achieved via (a) fewer reps/set, (b) fewer sets/session, or both; and/or by cutting accessory exercises.
- **Frequency:** generally **unchanged**. Reduce sessions only under extreme fatigue; under extreme fatigue, precede the deload with short-term training cessation.
- **Intensity:** reduce **absolute or relative load by ~10% of RM** while holding reps; and/or increase RIR by **1–3** (i.e. reduce effort, moving further from failure). May be applied alone or combined with the volume cut.
- **Exercise selection:** more technique focus, fewer accessories; retain some sport-specific exercises or their derivatives; optionally rotate to bands/BFR/isometrics/bodyweight to relieve monotony.
- **Duration:** **5–7 days** for structured deloads. Longer/harder preceding blocks warrant a longer deload plus **2–5 days of training cessation**. **Reactive deloads may be a single session.**
- **Periodicity:** **every 4–8 weeks** when preplanned; plus autoregulated "lighter days" as needed.

### 3.3 What athletes actually do (Rogerson/Bell survey, *Sports Med Open* 2024, n=246 competitive strength/physique athletes, 63.4% powerlifters)

- Deload duration: **6.4 ± 1.7 days**
- Deload interval: **every 5.6 ± 2.3 weeks**
- Motivations: reduce fatigue 92.3%, prepare for next cycle 64.6%, enhance performance 59.8%
- Method: volume down (reps/set **and** sets/week), **frequency unchanged**, load down, effort down via increased RIR
- Approach: pre-planned, often combined with autoregulation; triggered by stalled performance, soreness, joint aches

### 3.4 Important honesty caveats

- The 2025 review states plainly that high-quality experimental evidence for deloading is largely **absent**; the recommendations are consensus + survey + Delphi-derived, not RCT-derived.
- The **risk of non-functional overreaching from prolonged hard training without deloading is low**; several high-performance strength coaches believe athletes tolerate higher relative intensities than their habitual training without harm. Some commentators argue deloading every few weeks is **too frequent** and may suppress gains by diluting concentrated loading.
- One controlled trial found a 1-week deload (~85% volume reduction) was **no different from 1 week of complete cessation** for squat velocity or VL thickness; another found 1 week of cessation produced **6% smaller Smith-machine squat 1RM gains** than training through (measured 4 weeks later).

**Design implication:** deload frequency should be a coach-controlled dial with a "skip if readiness is high" autoregulated branch, not a hard every-4-weeks rule. The app should also support the *reactive single-session* deload.

---

## 4. Tapering and peaking for a meet

### 4.1 Primary review — Travis, Mujika, Gentles, Stone & Bazyler (2020), "Tapering and Peaking Maximal Strength for Powerlifting Performance: A Review," *Sports* 8(9):125

**Headline recommendations:**

1. **Volume:** reduce by **30–70%**. Sub-finding: **small-to-moderate reductions (~30 to ≤50%) outperform larger reductions (>50 to ≤70%)**, particularly over 2 weeks. Do not exceed 70% — detraining risk.
2. **Duration:** **1–2 weeks of taper**, followed by **2–7 days of training cessation**. Optimal taper duration may be **≤2 weeks**.
3. **Intensity:** either **maintain ≥85% 1RM** (when neuromuscular adaptation is the priority) **or reduce intensity**, particularly in competition week. Studies maintaining intensity produced **+1–6%**; studies reducing intensity produced **+2–10%**. Intensity increases should not exceed ~15%.
4. **Model:** prioritise **step or exponential**. Step tapers improve maximal strength at least as much as other models.
5. **Training cessation:** 2–7 days is sufficient to maintain or improve performance. **>7 days costs 1–4% of maximal strength**; ≥14 days produces clear decrements (−0.9% to −1.7%).
6. **Lift-specific:** research suggests recovery times are actually *similar* across squat/bench/deadlift, but **elite practice removes the deadlift entirely for 1–2 weeks**, while squat and bench cessation is typically 2–7 days.
7. **Planned overreach before the taper** is effective: one protocol increased volume by **107%** pre-taper, then cut **67%** in the final week and produced a **+6.4% bench press** improvement.

**Study table (from the review):**

| Study | Taper duration | Volume change | Outcome |
|---|---|---|---|
| Häkkinen et al. 1991 | 7 d | −50% | Squat improved |
| Williams 2017 | 7 d | −67% (after +107% overreach) | Bench +6.4% (+8.1 kg) |
| Godawa et al. 2012 | 14 d | slight ↑ | Squat +2.3–5.9%; Bench +1.8–2.1%; DL +3.8–4.8% |
| Pritchard et al. 2016 | 17 d | −58.9% | — |
| Grgic & Mikulic 2017 | 18 d | −50.5% | — |
| Andre et al. 2017 | 28 d | −58.7% | All lifts improved; 7 state records |

Aggregate: tapers with **31.6–67.0% volume reductions over 7–28 days** produced squat **+2.3–5.9%**, bench **+1.8–6.4%**, deadlift **+3.8–4.8%**, total **+3.2–4.4%**.

### 4.2 Controlled trial — step vs. exponential taper (Frontiers in Physiology, 2021)

- **n = 16 powerlifters**, 6-week peaking program, 3 d/wk.
- **Week 1 overreach (both groups): volume-load +150%, 7×5 @ 77.5–87.5%.**
- **Step taper:** 1 week (final week), volume −~50%, **intensity held at 90–95%** on primary lifts, format **1×1 + 3×2**, accessories cut.
- **Exponential taper:** 3 weeks, progressive −~50%, intensity decayed **87.5% → 70–85%**.
- **Outcomes:** squat +8% (step) / +10% (expo); bench +10% / +9%; **deadlift +1% (step) / +8% (expo)**; total +7% / +10%.
- **Morphology:** VL CSA +3.2% (step) vs +1.4% (expo); **Type IIA fibre size +11% with step taper only**, plus a shift toward IIA isoforms.
- **Authors' recommendation:** a 1-week overreach at ≥150% volume-load followed by a step **or** exponential taper with ~50% volume reduction over 1–3 weeks.
- **Key asymmetry for the app:** the deadlift responded much better to the longer exponential taper (+8% vs +1%). This is direct evidence that **the deadlift wants a longer taper than the squat and bench.**

### 4.3 What real powerlifters do — Pritchard/Travis et al. (2022), "Characterizing the Tapering Practices of United States and Canadian Raw Powerlifters," *JSCR* (n = 364)

- **Model:** predominantly a **step taper over 7–10 days**.
- **Volume reduction: 41–50%**, with varied intensity handling.
- **Last heavy (>85% 1RM) session:**
  - **Back squat: 7–10 days out**
  - **Deadlift: 7–10 days out**
  - **Bench press: <7 days out**
- **Load on those final heavy sessions: 90.0–92.5% 1RM** (i.e., approximately opener weight).
- **Final training session of each lift** (meet week) reduced to **75–80% 1RM for squat and bench, 70–75% for deadlift**.
- **Set/rep in the taper:** most frequently **3×2 (squat)**, **3×3 (bench)**, **3×1 (deadlift)**.
- **Training cessation before competition:** deadlift **5.8 ± 2.5 d**, squat **4.1 ± 1.9 d**, bench **3.9 ± 1.8 d**.

Related: the meta-analytic taper literature (endurance-derived but cited across strength) finds the largest effect sizes at **41–60% volume reduction**.

### 4.4 Practitioner models — where sources disagree

| Source | Taper length | Last heavy DL | Last heavy SQ | Last heavy BP |
|---|---|---|---|---|
| Pritchard/Travis survey (n=364) | 7–10 d | 7–10 d | 7–10 d | <7 d |
| Travis et al. review | 1–2 wk + 2–7 d cessation | DL may be removed 1–2 wk out | 2–7 d cessation | 2–7 d cessation |
| Stronger by Science | — | SQ/DL final heavy 5–10 d out | 5–10 d | 4–7 d |
| Israetel / JTS | Elite 308 lb: **4 wk**; masters 198 lb: **3 wk**; novice 97 lb: **2 wk** | ~2.5 wk out (elite) | ~2 wk out (elite, moderate-heavy) | ~1.5 wk out (elite) |
| Rob Palmer (practitioner synthesis) | step 1–2 wk (−50%); linear 3–4 wk (85/70/50/30%); exponential 2–3 wk | 10–14 d | 7–10 d | 4–6 d |

**Consensus core:** deadlift first and longest, bench last and shortest, squat in between. **Disagreement is on magnitude** — 7 days (survey median) vs 10–14 days (practitioner) vs 2.5 weeks (elite superheavyweight). The app must expose this as a range, not a constant.

**Bell et al. 2025 taper table (Table 1), for completeness:**
- Volume: **−30 to −60%**
- Intensity: maintain **≥85% 1RM** if prioritising neuromuscular adaptation; alternatively reduce **~25–30%** if recovery dominates
- Duration: **1–2 wk taper + 2–7 d training cessation**
- Approach: progressive **or** step

Taper prevalence in strength sports: 78% of Highland Games athletes, 87% of strongmen, 99% of hybrid-sport athletes, 99% of weightlifters. Effective tapers yield **~2–8%** strength improvement — but note this is the combined result of the preceding block *and* the taper.

### 4.5 Meet-week protocol (practitioner consensus, Saturday meet)

- **Mon/Tue (5–6 d out):** light squat, bench, deadlift — opener weight or slightly below, 1–2 singles, nothing more. Some coaches use singles at 80–85% of the goal third attempt at 5–6 days out. Survey data supports 75–80% (SQ/BP) and 70–75% (DL) for these final sessions.
- **Deadlift rule:** do not pull after Tuesday. A Tuesday opener-weight pull before a Saturday meet gives 3 clear days — the practical minimum.
- **Wednesday:** active recovery only — walking, mobility, sleep.
- **Thursday:** complete rest / travel.
- **Friday:** weigh-in (if 24 h), equipment check, rack heights, opener cards.
- **Accessories:** eliminate or reduce to 1–2 exercises on the first two days, 1–2 sets, very light.
- **Light training beats total rest** for dropping fatigue while preserving tissue quality and technique (Israetel/JTS position).

### 4.6 Opener timing — resolving the ambiguity

Two distinct events are frequently conflated, and the app must model them separately:

1. **Last heavy / "opener-confirmation" single** — ~90–92.5% 1RM, **7–10 days out** (survey), i.e. the athlete's final touch of near-opener weight. This is what validates the opener choice.
2. **Meet-week primer singles** — 70–80% 1RM (or opener-minus), **4–6 days out**, purely to preserve motor pattern.

A default of "openers 7–10 days out" is correct for (1) and wrong for (2).

---

## 5. RPE-based autoregulation

### 5.1 The RTS / Tuchscherer system

Mike Tuchscherer (*The Reactive Training Manual*, 2008; later *RTS Emerging Strategies*) adapted Borg's RPE to resistance training by anchoring it to **repetitions in reserve (RIR)**:

- RPE 10 = 0 RIR (true max)
- RPE 9.5 = could *maybe* do 1 more
- RPE 9 = 1 RIR
- RPE 8.5 = 1–2 RIR
- RPE 8 = 2 RIR
- RPE 7 = 3 RIR
- RPE 6 = 4 RIR

The load–reps–RPE triple lets you back out a **daily training max** from any work set — that is the core value proposition: the reference max is re-derived each session instead of being assumed.

### 5.2 The RPE → %1RM table (Tuchscherer / RTS; also used by Helms)

| Reps | RPE 10 | 9.5 | 9 | 8.5 | 8 | 7.5 | 7 |
|---|---|---|---|---|---|---|---|
| 1 | 100% | 97.8 | 95.5 | 93.9 | 92.2 | 90.7 | 89.2 |
| 2 | 95.5 | 93.9 | 92.2 | 90.7 | 89.2 | 87.8 | 86.3 |
| 3 | 92.2 | 90.7 | 89.2 | 87.8 | 86.3 | 85.0 | 83.7 |
| 4 | 89.2 | 87.8 | 86.3 | 85.0 | 83.7 | 82.4 | 81.1 |
| 5 | 86.3 | 85.0 | 83.7 | 82.4 | 81.1 | 79.9 | 78.6 |
| 6 | 83.7 | 82.4 | 81.1 | 79.9 | 78.6 | 77.4 | 76.2 |
| 7 | 81.1 | 79.9 | 78.6 | 77.4 | 76.2 | 75.1 | 73.9 |
| 8 | 78.6 | 77.4 | 76.2 | 75.1 | 73.9 | 72.8 | 71.7 |
| 9 | 76.2 | 75.1 | 73.9 | 72.8 | 71.7 | 70.7 | 69.6 |
| 10 | 73.9 | 72.8 | 71.7 | 70.7 | 69.6 | 68.6 | 67.6 |

Note the internal consistency: each step of one rep or half an RPE point is worth roughly the same ~1.5–3% of 1RM at the top of the table, compressing as reps rise. (3 reps @ RPE 10 = 92.2% = 1 rep @ RPE 8.)

**Caveat the app should surface:** this is a single population-average table. Individual rep-max profiles differ substantially — some lifters do 8 reps at their "5RM percentage." Professional practice is to *fit the table to the athlete* over time from logged (load, reps, RPE) triples.

### 5.3 Fatigue percents and volume autoregulation

RTS's second mechanism regulates **volume** rather than load. Three variants:

- **Load drops:** hit an initial set to a target RPE (e.g. 500×5 @9), drop the bar weight by the prescribed fatigue percent (e.g. 5% → 475), and repeat sets at that load until RPE returns to the initial target. Reaching the target = "5% fatigue reached." Best for morphological adaptation; slightly favours power expression.
- **Repeats:** same load, same reps, every set; RPE climbs as fatigue accumulates; stop at the prescribed RPE ceiling. Enhances work capacity at lower RPEs; trains grinding at higher RPEs.
- **Rep drops:** hold load, reduce reps per set. Emphasises neurological adaptation, produces higher average intensity with fewer total reps and fewer sets.

Published examples use **5%** as the canonical fatigue percent; practitioners commonly work in the **4–10%** range. Tuchscherer's stated principle: the training effect is governed mostly by (a) the number of reps performed and (b) the RPE they're performed at.

**Built-in progression:** as the athlete becomes better conditioned, more sets are required to reach the same fatigue percent — volume auto-increases without the coach editing anything. This is an elegant feature for an app to implement natively.

### 5.4 RTS Emerging Strategies (the later, more individualised system)

- Bottom-up rather than top-down: the plan *emerges* from the athlete's logged response, instead of being imposed as "X weeks accumulation, Y weeks transmutation, Z weeks realization."
- Core constructs: **Developmental Block**, **Pivot Block**, and **Time to Peak** — all individualised.
- Notably, Tuchscherer's later position minimises the classical peaking phase: train up to the meet with a few days off, with little formal peaking. **This directly contradicts the taper literature** and is worth exposing as a selectable philosophy rather than pretending consensus exists.

### 5.5 Evidence: does RPE beat fixed percentages?

- **Helms et al. (2018), *Frontiers in Physiology* 9:247** — 8 weeks, resistance-trained males, squat + bench 3×/wk DUP, sets and reps matched, only load assignment differed. Gains: bench +9.64 kg (%1RM group) vs +10.70 kg (RPE); squat +13.91 vs +17.05 kg; total +23.55 vs +27.75 kg. Magnitude-based inference: **79% / 57% / 72% chance of a small effect-size advantage** for RPE in squat / bench / total. Conclusion: **both work; RPE may confer a small advantage in a majority of individuals.**
- **Graham & Cleather (2019/2021)** — 12 weeks, RIR-based load selection produced **significantly greater** front squat and back squat 1RM increases than fixed percentage loading; the proposed mechanism is that RPE sustains a *higher* effective intensity (percentages under-load on good days).
- **Helms et al. (2018), *JSCR*** — RPE also works as a **volume** autoregulation tool within a periodized program.
- **2025 network meta-analysis** (*J Exerc Sci Fit*, autoregulated RT for maximal strength) — SUCRA ranking: **APRE 93.0% > RPE 66.8% > velocity-based 27.0% > percentage-based 13.2%**. No moderate/large effect-size differences between interventions for back squat 1RM, i.e. the ranking is real but the practical gap is modest.

### 5.6 When RPE beats fixed percentages (and when it does not)

**RPE wins when:**
- Day-to-day readiness varies (sleep, stress, cut/weight-making, travel, in-season).
- The reference 1RM is stale, unknown, or was set under different conditions.
- Sets are near failure and reps are low — accuracy is highest at RPE 9 and in low-rep sets.
- The athlete is experienced and honest.
- You want automatic volume regulation (fatigue percents).

**Fixed percentages win when:**
- The lifter is a novice. Novices are **less accurate** selecting squat 1RM loads via RIR — largely attributable to poorer neuromuscular control under heavy loads rather than poor rating ability per se. Recommendation: novices should *record* RIR for practice but **not base load progression on it** until accuracy improves.
- Reps are high — RPE-RIR accuracy degrades as reps increase, limiting usefulness at low %1RM.
- Predictions are further from failure (RPE 7 is rated less accurately than RPE 9).
- The program deliberately requires *submaximal* effort (deloads, technique work, speed work) where an honest RPE would push load up.
- Psychological factors dominate — RPE inflation/deflation is the primary practical failure mode of RTS.

**Best practice (and the right app default): hybrid.** Prescribe a percentage *range* with an RPE cap/stop, e.g. "4×4 @ 80–84%, stop the set at RPE 8, stop adding sets at RPE 9." This is what most professional coaches actually write.

---

## 6. Attempt selection

### 6.1 Competition data

- **IPF World Classic Championships 2012–2019 analysis** (Ferland/Comtois lineage; also *BMC Sports Sci Med Rehabil* 2022, "What are the odds?"): lifters who **successfully completed their third attempt** had, on average, opened at **91% of that third attempt** and taken a second at **96% of it**.
- **2016 IPF Classic Worlds:** **~50% of all third attempts are missed** — squat 46%, bench 53%, deadlift 55%.
- **Winners averaged 8.46 successful attempts out of 9**, versus **6.66 for the average lifter**. 57% of world-level medallists went 8/9.
- Third-attempt success probability peaks between ~0.5–0.8 depending on weight class, vs 0.75–1.00 for second attempts near PB.

**The single most important design implication:** going 9/9 with conservative numbers reliably beats 6/9 with aggressive ones. The optimisation target is *expected total*, not *maximum possible total*.

### 6.2 Practitioner percentage recommendations (of best gym / projected 1RM)

| Source | Opener | Second | Third |
|---|---|---|---|
| PowerliftingToWin | ~90% (≈ x1 @ RPE 7.5–8) | ~95% (≈ x1 @ RPE 9) | 97.5–102.5%, chosen from how the second moved |
| The Strength Athlete | 90–92% | 95–97% ("never take a PR as a second") | 100–105% by experience level |
| PowerliftingTechnique / general consensus | 88–93%; a comfortable 3RM (~90–92%) | 93–97%; a weight giving genuine information (96–98% in some framings) | 100–103% |
| Della Nave | A weight you'd make 10/10 with a cold; **DL opener ~80% of expected max** | ~90% of that day's ceiling | 100–102.5% |
| "Foolproof" heuristic | 91% | 96% | 100% |

**Rules with near-universal agreement:**
- The opener is a warm-up you happen to get judged on; it exists to keep you in the meet and to acclimatise to commands/environment.
- **Never take a PR as a second attempt.** The second's purpose is to inform the third.
- If you miss an opener, **repeat it** — do not jump.
- Choose the third from *observed* second-attempt bar speed (video/coach), not from feel.
- Third-attempt conditional rule: second harder than expected → bottom of the range (97.5%); easier than expected → top (102.5%).
- Deadlift openers should be *more* conservative than squat/bench because they come at the end of a long day, on accumulated fatigue.
- Bench thirds warrant extra conservatism — highest miss rate and highest technical/command failure rate.

### 6.3 Conservative vs. aggressive strategy — when each is right

**Conservative (89–90 / 94–95 / 99–101%)**
- First meet, or first meet in a new federation with unfamiliar commands
- Qualifying total is the goal (need the total banked)
- Bodyweight cut, poor training block, illness, or high life stress
- Athlete with a history of technical misses (depth, press command, hitching)
- Team competition where the total counts

**Standard (91 / 96 / 101%)** — the default; matches the IPF successful-third pattern.

**Aggressive (92–93 / 97–98 / 103–105%)**
- Chasing a record where second place has the same value as fifth
- Late in the flight, already know the number needed to win
- Athlete with a long history of hitting competition PRs and outperforming gym numbers
- Deadlift only, where the last attempt decides the meet

**Adaptive third:** the professional practice is a *decision rule*, not a number — e.g. `if second_attempt_rpe <= 8.5 → third = second + 2.5–5%; if 9–9.5 → +1.5–2.5%; if 10 → repeat or +2.5 kg minimum`.

### 6.4 Mechanics the app must model

- **Rounding to loadable increments** — 2.5 kg (IPF/kg meets), 5 lb (US pound meets). A computed 101.5% is meaningless if it doesn't land on a plate.
- **Minimum next-attempt increment** — typically 2.5 kg; the app must never propose a sub-minimum jump.
- **Attempt-change rules** — openers are declared before the flight; second/third attempts must be submitted within ~1 minute of the previous attempt. The app should surface a countdown / pre-computed decision tree so the coach isn't doing arithmetic under pressure.
- **Record attempts** — some federations allow a fourth attempt for records only, not counting toward total.
- **Bombing-out protection** — an explicit flag when the opener exceeds a threshold relative to the last confirmed heavy single.

---

## 7. Where the sources genuinely disagree (present as ranges, not truths)

| Question | Range across credible sources |
|---|---|
| Taper length | 7 days (survey mode) → 2 weeks (review optimum) → 3–4 weeks (elite/large lifters, JTS) |
| Volume reduction in taper | 30–50% (review's preferred) / 41–50% (survey) / 41–60% (meta ES peak) / up to 70% (upper bound) |
| Intensity in taper | Maintain ≥85% (better for neuromuscular retention) vs reduce ~25–30% (better raw % improvements: +2–10% vs +1–6%) |
| Last heavy deadlift | 7 days → 2.5 weeks |
| Step vs exponential | Step: better Type IIA/CSA outcomes and equal-or-better strength. Exponential: better deadlift outcome (+8% vs +1%) and better isometric peak force |
| Is a peaking phase needed at all? | Classical BP: yes, 2–4 wk. Tuchscherer's Emerging Strategies: essentially no — train up to the meet, take a few days off |
| Deload frequency | Every 4–8 wk (consensus) vs "every few weeks is too often and suppresses gains" (high-performance coaches) |
| Is BP superior? | Trends favour it; **no statistically significant superiority** over DUP in head-to-head strength studies |

---

## 8. Audit of the current engine defaults

### 8.1 Phase proportions: acc 40% / trans 40% / real 24%

**Problems:**
1. **Sums to 104%.** Either the meet week is double-counted or there's a rounding/spec bug. Deterministic phase math must sum to exactly the prep length.
2. **No deload is represented.** Consensus is 5–7 days every 4–8 weeks. On a 16-week prep with a 6.4-week accumulation block, at least one intra-block deload is mandatory by every source cited here. Right now the model appears to run 6+ weeks of accumulation with no fatigue release.
3. **Proportional realization is the wrong shape.** The taper literature is *absolute*: 1–2 weeks of taper + 2–7 days of cessation, with practitioner extension to 3–4 weeks only for large/elite lifters. At 24%:
   - 8-wk prep → 1.9 wk realization ✓ (good)
   - 12-wk prep → 2.9 wk ✓ (good)
   - 16-wk prep → 3.8 wk (only right for a big elite lifter)
   - 20-wk prep → 4.8 wk ✗ (exceeds every recommendation; detraining risk)
   
   **Fix:** compute realization from lifter attributes (bodyweight, training age, absolute strength, equipped vs raw) with a hard clamp of **2–4 weeks**, and let accumulation/transmutation absorb the remainder.
4. **Accumulation and transmutation should not always be equal.** Novices and lifters coming off a layoff want a longer accumulation; peaking-focused and advanced lifters want a longer transmutation. A 50/50 split is a defensible default but should be a slider.

**What is defensible:** the ordering, the ~2-month-per-stage scale (matches Issurin), and the 40/40/20-ish shape for a 10–14 week prep.

### 8.2 Accumulation: 4×6 @ 67–75%

**Not defensible at the bottom of the band.** Cross-referencing the Tuchscherer table:
- 6 reps @ 75% ≈ RPE 6.5–7 (~3.5–4 RIR)
- 6 reps @ 71% ≈ RPE ~5 (~5 RIR)
- 6 reps @ 67% ≈ below RPE 4 (~6+ RIR)

For a trained powerlifter, 6 @ 67% is not a stimulus — it is a warm-up set. The lowest RPE-6 value in the entire published table is 67.6% *at 10 reps*. Prescribing 6 reps at that load places week 1 of the block below any meaningful effort threshold.

**Recommended band:** **72–80%** for 6 reps, corresponding to roughly RPE 6 → RPE 8.5 across the block. Or, better, define the block in RPE terms and let the percentages fall out.

**Second problem: fixed 4 sets.** At a 2×/week frequency that is a flat 8 sets/week for the whole block. The accumulation block's entire physiological purpose is progressive volume accumulation toward MRV. Every serious volume framework (RP volume landmarks; summated microcycles) ramps sets weekly: e.g. 3→4→5→6 sets, then deload. **The engine has no volume progression at all — only load progression.** This is the largest single programming gap.

**Third: rep scheme is static.** Accumulation blocks typically undulate (e.g. 8/6/10 across the week) or run double progression. 6 reps flat for 5–6 weeks is monotonous and leaves the hypertrophy stimulus narrow.

### 8.3 Transmutation: 4×4 @ 77–86%

- 4 reps @ 77% ≈ RPE 5.5; 4 reps @ 83.7% = RPE 8; 4 reps @ 86% ≈ RPE 9.
- **The top of the band is exactly right.** The bottom wastes week 1.
- **Recommended band: 80–88%** for 4 reps (RPE ~6.5 → 9.5), or an RPE-capped ramp: week1 RPE 7, week2 RPE 7.5, week3 RPE 8, week4 RPE 8.5–9.
- 4 sets held flat again — transmutation should typically *reduce* sets as load climbs (e.g. 5→4→4→3), or hold sets and cut reps 5→4→3.
- Missing: the option of top-set + back-off structure (a single heavy top set at RPE 8–9 plus 2–3 back-offs at ~80–90% of the top set), which is the dominant modern intermediate/advanced pattern and is supported by the METD literature's back-off finding.

### 8.4 Realization: singles/doubles @ 87–93%

- Single @ 87% ≈ RPE 6; single @ 92.2% = RPE 8; single @ 93% ≈ RPE 8.3
- Double @ 89.2% = RPE 8; double @ 92.2% = RPE 9; double @ 93% ≈ RPE 9.3
- **Verdict: the ceiling is too low.** The step-taper arm of the controlled 6-week peaking study used **90–95% on primary lifts** in the final week (1×1 + 3×2). The survey's *final heavy session* was at **90.0–92.5%** — but that was the *last* heavy session at the end of a block that went heavier earlier.

**The concrete consequence:** with a 91% opener and a 97% second, an athlete peaked on this engine has never touched anything above 93% in training and has never taken a genuine RPE 9 single. They will walk onto the platform with an *unvalidated* second attempt. Almost every coach in the sources above wants at least one **95–100% single at RPE 9** somewhere in the realization block (typically 2–3 weeks out) precisely to calibrate attempts.

**Recommended:** realization band **88–97%**, with an explicit "top single" event configurable at 2–3 weeks out targeting RPE 8.5–9 (≈93.9–95.5%), then descending to opener weight at the 7–10 day mark.

### 8.5 Attempts 91 / 97 / 101.5%

**This is the best-calibrated default in the engine.** Cross-check:
- Relative to the third: opener = 91/101.5 = **89.7%** of third; second = 97/101.5 = **95.6%** of third. IPF successful-third data: **91%** and **96%**. The engine is very slightly more conservative on the opener — which is the correct direction of error.
- Against practitioner consensus (opener 88–93%, second 93–97%, third 97.5–105%), all three sit inside range; the second is at the top of its range.

**What's missing:**
1. **Lift-specific defaults.** Deadlift openers should be more conservative (multiple sources: ~80–88% for DL vs 90–92% for SQ/BP) because of end-of-day fatigue; bench thirds should be more conservative (53–55% miss rates on bench and deadlift thirds).
2. **Rounding to loadable increments** and enforcement of the 2.5 kg minimum jump.
3. **Adaptive third** based on second-attempt RPE / bar speed, not a fixed 101.5%.
4. **Risk profile selection** (conservative / standard / aggressive), which shifts all three.
5. **"Reference max" definition.** 91% *of what* — best gym single ever, best single this block, projected meet max, or e1RM from the last RPE-9 set? These give materially different numbers. This must be explicit and coach-selectable.

### 8.6 Last heavy deadlift 10–14 days out

**Defensible, on the conservative end.** It sits between the survey median (7–10 d) and the elite practitioner recommendation (2.5 wk), and matches the common 10–14 d practitioner figure. It's also supported by the controlled study's finding that **deadlift responded far better to the longer exponential taper (+8%) than the step taper (+1%)**.

**But it must not be a constant.** Required variation: by lifter bodyweight and absolute strength (bigger/stronger → longer), by conventional vs sumo, by deadlift-specific recovery history, and by whether the lifter deadlifts 1× or 2× weekly.

### 8.7 Openers 7–10 days out

**Correct if it means "final heavy session at ~opener weight"** — this is exactly the survey finding (final heavy >85% session 7–10 d out, at 90.0–92.5% 1RM).

**Incorrect if it means the last time the athlete touches the bar heavy before the meet.** Meet week should still include primer singles at 70–80% (SQ/BP) and 70–75% (DL) at 4–6 days out, per both the survey's "final training session of each lift" data and universal practitioner protocol.

**Also missing:** explicit **training cessation** modelling — the survey's per-lift cessation (DL 5.8 ± 2.5 d, SQ 4.1 ± 1.9 d, BP 3.9 ± 1.8 d) and the review's 2–7 day recommendation with a hard warning above 7 days (costs 1–4% of maximal strength).

---

## 9. Options a professional coach will expect to vary

### 9.1 Macro / structure
- **Organising model:** block / DUP / conjugate / hybrid / RTS-style emergent
- **Prep length** and **phase split** (independent sliders for acc / trans / real, validated to sum to 100%)
- **Realization length:** absolute weeks (2–4), auto-suggested from lifter profile, with clamp
- **Meet count:** single-peak vs multi-peak season (Issurin: 5–7 stages/year); ability to chain preps
- **Athlete profile drivers:** training age, bodyweight class, absolute strength, sex, masters/junior, drug-tested status, raw / single-ply / multi-ply, weight-cut magnitude
- **Deload policy:** frequency (every 3–8 wk), duration (3–7 d), magnitude tier (low ≤25–45% / moderate 40–60% / high 60–90%), preplanned vs autoregulated vs hybrid; reactive single-session deload
- **Planned overreach:** on/off, magnitude (+50% to +150% volume-load), placement (1 week before taper start)

### 9.2 Per-phase loading
- Intensity band per phase, **per lift** (deadlift often runs 2.5–5% lower than squat at equal RPE)
- Rep scheme per phase (fixed / undulating / double progression / top-set+backoff / cluster)
- Sets per session **and** weekly set ramp (e.g. 3→4→5→6) with MEV/MAV/MRV anchors
- Frequency per lift (default 2 SQ / 3 BP / 1 DL, per the METD literature)
- Weekly progression rule: %-based (+1 to +5%/wk), absolute (+2.5/+5 kg/wk), rep-based, or RPE-target-based; with decelerating-increment support
- Reference max definition: true 1RM / training max (% of 1RM) / e1RM from logged RPE sets / projected meet max
- Rounding: 2.5 kg / 1.25 kg / 5 lb / 2.5 lb; microplate availability

### 9.3 Autoregulation
- Loading mode: fixed % / RPE only / **% band with RPE cap** (recommended default) / velocity-based
- RPE→% table: default Tuchscherer table, **per-athlete fitted table** learned from logged (load, reps, RPE)
- RPE caps per phase and per exercise
- Fatigue-percent volume regulation: method (load drop / repeats / rep drop) and magnitude (4–10%)
- Readiness inputs: sleep, soreness, bodyweight, session RPE, warm-up bar speed; and their effect (adjust load, adjust sets, trigger reactive deload)
- Novice guard: disable RPE-driven progression below a configured experience threshold, per the accuracy literature — log RIR for practice only

### 9.4 Exercise selection
- Specificity taper curve: number of variations and their "distance" from the comp lift per phase
- Accessory count and volume per phase, with automatic elimination order during taper (accessories cut first, comp lifts last)
- Variation library with tagging (weak-point: off-the-floor / lockout / bottom-position / speed)
- Comp-command enforcement flag by phase (paused bench, depth, full reset deadlift, comp gear) — should be forced ON in realization

### 9.5 Taper / peak
- Taper model: step / exponential (fast or slow decay) / linear / hybrid
- Taper length: 7 / 10 / 14 / 21 / 28 days
- Volume reduction: 30 / 40 / 50 / 60 / 70% with a warning above 70%
- Intensity policy: maintain ≥85% vs reduce ~25–30% (with the trade-off surfaced: +1–6% vs +2–10% observed)
- **Per-lift last-heavy day** (independent DL / SQ / BP dials, defaults 10–14 / 7–10 / 4–7 days)
- **Per-lift training cessation** (defaults DL ~6 d, SQ ~4 d, BP ~4 d; hard warning above 7 d)
- Meet-week template: primer-single day(s), load (70–80% SQ/BP, 70–75% DL), rest/travel days, weigh-in type (2 h vs 24 h), same-day-weigh-in adjustments
- Federation/schedule inputs: flight order, expected session length, warm-up room timing

### 9.6 Attempts
- Risk profile: conservative / standard / aggressive (shifting all three attempts)
- Independent per-lift opener/second/third percentages
- Reference max per lift
- Adaptive third: decision tree keyed to second-attempt RPE or bar velocity
- Federation rules: minimum increment, attempt-change window, fourth-attempt/record rules
- Bomb-out risk indicator when the opener exceeds a threshold vs the last confirmed heavy single
- Total-optimisation view: expected total under each risk profile, using published attempt success probabilities (thirds ~45–55% success; seconds ~75–100% near PB)

---

## 10. Recommended default changes (minimum viable corrections)

1. **Fix the 104% phase sum.**
2. **Insert deloads:** 5–7 days, every 4–6 weeks, step reduction of 40–60% volume + ~10% load, frequency unchanged.
3. **Raise the accumulation floor:** 4–6×6 @ **72–80%** (not 67–75%), with a weekly set ramp.
4. **Raise the transmutation floor:** 4×4 @ **80–88%** (not 77–86%), with sets descending as load climbs.
5. **Raise the realization ceiling:** **88–97%**, and add an explicit **top single at RPE 8.5–9 (≈94–95.5%), 2–3 weeks out**.
6. **Clamp realization to 2–4 weeks absolute**, derived from lifter profile rather than as a fixed % of prep length.
7. **Split "openers 7–10 days out"** into two modelled events: last-heavy/opener-confirmation at 7–10 d (90–92.5%) and meet-week primer singles at 4–6 d (70–80%).
8. **Make last-heavy timing per-lift**, defaulting DL 10–14 d / SQ 7–10 d / BP 4–7 d, with per-lift cessation.
9. **Keep attempts at 91/97/101.5% as the "standard" profile**, but add conservative/aggressive profiles, lift-specific overrides (more conservative DL opener, more conservative BP third), plate rounding, and an adaptive third rule.
10. **Add an RPE layer** — at minimum, an RPE cap alongside every percentage prescription, with the Tuchscherer table as the conversion default and per-athlete fitting over time.

---

## Sources

**Peer-reviewed**
- [Issurin VB. Benefits and Limitations of Block Periodized Training Approaches to Athletes' Preparation: A Review. *Sports Medicine* (2015)](https://paulogentil.com/pdf/Benefits%20and%20Limitations%20of%20Block%20Periodized%20Training%20Approaches%20to%20Athletes%27%20Preparation%20-%20A%20Review.pdf)
- [Issurin VB. Block periodization versus traditional training theory: a review. *J Sports Med Phys Fitness* (2008)](https://pubmed.ncbi.nlm.nih.gov/18212712/)
- [Issurin VB. Block Periodization: Breakthrough in Sport Training (book)](https://complementarytraining.com/block-periodization-breakthrough-in-sport-training/)
- [Issurin & Lustig. Klassifikation, Dauer und praktische Komponenten der Resteffekte von Training. *Leistungssport* (2004)](https://coachsci.sdsu.edu/csa/vol161/issurin.htm) — residual training effects table
- [Issurin VB. Biological Background of Block Periodized Endurance Training: A Review. *Sports Medicine* (2019)](https://pubmed.ncbi.nlm.nih.gov/30411234/)
- [Travis SK, Mujika I, Gentles JA, Stone MH, Bazyler CD. Tapering and Peaking Maximal Strength for Powerlifting Performance: A Review. *Sports* 8(9):125 (2020)](https://pmc.ncbi.nlm.nih.gov/articles/PMC7552788/)
- [Travis SK et al. Skeletal Muscle Adaptations and Performance Outcomes Following a Step and Exponential Taper in Strength Athletes. *Frontiers in Physiology* (2021)](https://www.frontiersin.org/journals/physiology/articles/10.3389/fphys.2021.735932/full)
- [Pritchard HJ / Travis SK et al. Characterizing the Tapering Practices of United States and Canadian Raw Powerlifters. *J Strength Cond Res* (2022)](https://pubmed.ncbi.nlm.nih.gov/34846328/)
- [Bell L, Darragh IAJ, Travis SK, Rogerson D, Nolan D. A Practical Approach to Deloading: Recommendations and Considerations for Strength and Physique Sports. *NSCA Strength & Conditioning Journal* (2025)](https://doras.dcu.ie/31501/1/a_practical_approach_to_deloading__recommendations.203(2).pdf)
- [Bell L / Rogerson D et al. Deloading Practices in Strength and Physique Sports: A Cross-sectional Survey. *Sports Medicine – Open* (2024)](https://sportsmedicine-open.springeropen.com/articles/10.1186/s40798-024-00691-y)
- [Helms ER, Byrnes RK, et al. RPE vs. Percentage 1RM Loading in Periodized Programs Matched for Sets and Repetitions. *Frontiers in Physiology* 9:247 (2018)](https://www.frontiersin.org/journals/physiology/articles/10.3389/fphys.2018.00247/full)
- [Helms ER et al. RPE as a Method of Volume Autoregulation Within a Periodized Program. *J Strength Cond Res* (2018)](https://pubmed.ncbi.nlm.nih.gov/29786623/)
- [Zourdos MC, Helms ER et al. Novel Resistance Training-Specific RPE Scale Measuring Repetitions in Reserve; and Efficacy of the RIR-Based RPE Scale (novice vs experienced accuracy)](https://journals.lww.com/nsca-jscr/fulltext/2019/02000/efficacy_of_the_repetitions_in_reserve_based.5.aspx)
- [Helms ER et al. Application of the Repetitions in Reserve-Based RPE Scale for Resistance Training. *NSCA SCJ*](https://www.ovid.com/jnls/nsca-scj/fulltext/10.1519/ssc.0000000000000218~application-of-the-repetitions-in-reserve-based-rating-of)
- [Methods for Regulating and Monitoring Resistance Training (review)](https://pmc.ncbi.nlm.nih.gov/articles/PMC7706636/)
- [Autoregulated resistance training for maximal strength enhancement: A systematic review and network meta-analysis. *J Exerc Sci Fit* (2025)](https://pubmed.ncbi.nlm.nih.gov/40791980/)
- [Androulakis-Korakakis P et al. The Minimum Effective Training Dose Required for 1RM Strength in Powerlifters. *Front Sports Act Living* (2021)](https://www.frontiersin.org/journals/sports-and-active-living/articles/10.3389/fspor.2021.713655/full)
- [Grgic J et al. Effect of Resistance Training Frequency on Gains in Muscular Strength: A Systematic Review and Meta-Analysis](https://pubmed.ncbi.nlm.nih.gov/29470825/)
- [Effects of training frequency on muscular strength for trained men under volume matched conditions. *PeerJ* (2021)](https://peerj.com/articles/10781/)
- [Painter KB et al. Strength gains: block versus daily undulating periodization weight training among track and field athletes. *IJSPP* (2012)](https://pubmed.ncbi.nlm.nih.gov/22173008/)
- [Resting Hormone Alterations and Injuries: Block vs. DUP Weight-Training among D-1 Track and Field Athletes (2018)](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5969203/)
- [What are the odds? Identifying factors related to competitive success in powerlifting. *BMC Sports Sci Med Rehabil* (2022)](https://bmcsportsscimedrehabil.biomedcentral.com/articles/10.1186/s13102-022-00505-2)
- [Phase-Specific Changes in RFD and Muscle Morphology Throughout a Block Periodized Training Cycle in Weightlifters](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC6628423/)
- [High-Performance Strength Coaches' Perceptions of Planned Overreaching. *Front Sports Act Living* (2022)](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC9108365/)
- [Overreaching and Overtraining in Strength Sports and Resistance Training: A Scoping Review](https://shura.shu.ac.uk/26176/1/Overreaching%20and%20Overtraining%20in%20Strength%20Sports%20and%20Resistance%20Training.%20A%20Scoping%20Review.pdf)

**Practitioner / methodological**
- [Verkhoshansky — Sport Strength Training Methodology compendium (conjugate sequence, LTDE)](http://www.verkhoshansky.com/Portals/0/Book/Verkhoshansky_Forum.pdf)
- [Moments in Sports Science History: Long Term Delayed Training Effects & Planned Over-reaching](https://www.just-fly-sports.com/moments-in-sports-science-history-long-term-delayed-training-effects-planned-over-reaching/)
- [Tuchscherer M — Reactive Training Systems (RTS)](https://store.reactivetrainingsystems.com/pages/mike-tuchscherer)
- [Tuchscherer M — Fatigue Percents Revisited (RTS)](https://store.reactivetrainingsystems.com/blogs/advanced-concepts/fatigue-percents-revisited)
- [Tuchscherer M — Emerging Strategies interview (RTS)](https://store.reactivetrainingsystems.com/blogs/default-blog-1/powerlifting-emerging-strategies-an-interview-with-mike-tuchscherer)
- [PowerliftingToWin — A Review of Mike Tuchscherer's Reactive Training Systems](https://www.powerliftingtowin.com/a-review-of-mike-tuchscherers-reactive-training-systems-rts/)
- [Tuchscherer/Helms RPE → %1RM chart (full table)](https://fitnessvolt.com/rpe-training/rpe-chart/)
- [Israetel M / Juggernaut Training Systems — Peaking for Powerlifting](https://www.jtsstrength.com/peaking-powerlifting/)
- [Juggernaut Training Systems — Periodization for Powerlifting: The Definitive Guide](https://www.jtsstrength.com/periodization-powerlifting-definitive-guide/)
- [Israetel M — Scientific Principles of Strength Training (RP)](https://rpstrength.com/products/rp-pl-book)
- [Renaissance Periodization — Training Volume Landmarks (MV/MEV/MAV/MRV)](https://rpstrength.com/blogs/articles/training-volume-landmarks-muscle-growth)
- [Stronger by Science — Tapering and Peaking: Why and How](https://www.strongerbyscience.com/tapering/)
- [Stronger by Science — How to taper for powerlifting success](https://www.strongerbyscience.com/taper-for-powerlifting/)
- [Stronger by Science — Research Spotlight: How do powerlifters taper?](https://www.strongerbyscience.com/research-spotlight-taper/)
- [Stronger by Science — Overshooting, Undershooting, Or Just Right? (RIR accuracy)](https://www.strongerbyscience.com/reps-in-reserve/)
- [Stronger by Science — How to Choose the Right Load Progression Strategy](https://www.strongerbyscience.com/weekly-load-progression/)
- [Rob Palmer — Tapering in Powerlifting](https://robpalmer949.substack.com/p/tapering-in-powerlifting)
- [The Strength Athlete — Attempt selection, part II](https://www.thestrengthathlete.com/blog/attempt-selection-2)
- [The Strength Athlete — Understanding the taper: reviewing recent research](https://www.thestrengthathlete.com/blog/understanding-the-taper)
- [PowerliftingToWin — How to Pick Your Attempts at a Powerlifting Meet](https://www.powerliftingtowin.com/how-to-pick-your-attempts-at-a-powerlifting-meet/)
- [Della Nave — Powerlifting Attempt Selection for Not Dummies](https://www.dellanave.com/powerlifting-attempt-selection-for-not-dummies/)
- [PowerliftingTechnique — How To Pick Attempts For Powerlifting](https://powerliftingtechnique.com/how-to-pick-attempts-for-powerlifting/)
- [Grinder Gym — Block Periodization for Powerlifting (concrete template)](https://grindergym.com/block-periodization-for-powerlifting/)
- [Grinder Gym — Functional Overreaching for Strength Athletes](https://grindergym.com/pushing-your-limits-functional-overreaching-for-strength-athletes/)
- [Bonvec Strength — 5 Things Powerlifters Should Do During Meet Week](https://bonvecstrength.com/2023/02/02/5-things-powerlifters-should-do-during-meet-week/)
- [Bonvec Strength — Choosing the Weight on the Bar: Percentage, RPE and RIR](https://bonvecstrength.com/2020/06/24/choosing-the-weight-on-the-bar-percentage-rpe-and-rir-part-1/)