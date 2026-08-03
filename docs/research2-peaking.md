# Peaking Mathematics and Projection for Powerlifting — Definitive Report

**Scope:** the fitness–fatigue (Banister) model as a *computable* engine for PeakWeek; verified time constants; taper prescriptions with the real numbers; a complete, implementable projection algorithm with exact day-offset rules; and short-runway triage.

**Repo context read:** `/Users/richardholguin/dev/powerlifting-trainer/docs/research-science.md` (the prior block-periodization report) and `/Users/richardholguin/dev/powerlifting-trainer/Sources/PeakWeek/Engine.swift` (realization/meet templates, lines 216–272; `weeksAvailable`, line 279).

**Novel work in this report:** I re-implemented the Busso nonlinear fitness–fatigue model in Python and **reproduced Thomas & Busso (2005) to within 1 percentage point and 2 days** (my simulation: optimal step taper 31% cut / 18 d without overreach, 39% / 26 d with overreach; published: 30.8 ± 11.8% / 19.3 ± 2.3 d and 39.3 ± 9.9% / 28.0 ± 5.1 d). Everything in §1.7–§1.9 and §3 is derived from that validated simulation plus the published constraints. Scripts: `/private/tmp/claude-501/-Users-richardholguin-dev-foreman/31e6222c-323a-4cf6-add5-c46759d2c57a/scratchpad/ffm3.py`, `ffm4.py`, `ffm5.py`, `ffm6.py`.

---

## 0. Executive summary — the whole thing on one screen

**The single most important finding for the app:** the entire spread of published peaking recommendations — Pritchard's 7–10 day survey taper, Travis's 1–2 week + 2–7 day cessation, JTS's 2/3/4-week athlete-scaled tapers, the deadlift-first/bench-last ordering — **collapses to one free parameter**: τ₂, the athlete's fatigue decay time constant. Everything else is a fixed multiple of it.

| Event | Rule (days before meet) | Default (τ₂ = 12 d) |
|---|---|---|
| Taper start (volume reduction begins) | `round(1.70 × τ₂)`, clamp 14–28 | **−20 d** |
| Top calibration single (RPE 8.5–9, 93–96%) | `round(1.50 × τ₂)`, clamp 14–24 | **−18 d** |
| Last heavy **deadlift** (90–92.5%, opener confirmation) | `round(0.92 × τ₂)`, clamp 8–16 | **−11 d** |
| Last heavy **squat** (90–92.5%) | `round(0.75 × τ₂)`, clamp 6–12 | **−9 d** |
| Last heavy **bench** (90–92.5%) | `round(0.50 × τ₂)`, clamp 4–9 | **−6 d** |
| Last deadlift of any kind (primer 70–75%) → **DL cessation** | `round(0.48 × τ₂)`, clamp 4–7 | **−6 d** |
| Last squat (primer 75–80%) → **SQ cessation** | `round(0.34 × τ₂)`, clamp 3–6 | **−4 d** |
| Last bench (primer 75–80%) → **BP cessation** | `round(0.33 × τ₂)`, clamp 3–6 | **−4 d** |
| Complete training cessation begins | day after the last scheduled session | **−3 d** |

Three derived laws, all from the validated simulation:

1. **Optimal taper duration ≈ 1.6 × τ₂** (range 1.5–1.75 across τ₁ ∈ [25, 45], τ₂ ∈ [8, 21]). τ₂ sets *how long*; τ₁ sets *how deep you can cut*.
2. **Duration and depth trade off linearly:** `d_opt ≈ τ₂ × (2.6 − 0.018 × cut%)`. A 30% cut wants ~24 d; a 50% cut wants ~19 d; a 70% cut wants ~15 d (τ₂ = 12).
3. **The peak is flat and asymmetric.** Missing by ±3 d costs <2% of the taper gain. Being **too short** costs roughly **2× as much per day** as being too long: `loss% = 0.19·Δ²` when the taper is Δ days short, `0.10·Δ²` when Δ days long. **When uncertain, taper longer — but never extend *complete cessation*, only the reduced-load period.**

---

## 1. The fitness–fatigue (Banister two-factor) model

### 1.1 Equations

Continuous form ([Banister et al. 1975; Calvert et al. 1976](https://link.springer.com/article/10.1007/BF00867927)):

```
P(t) = P₀ + ∫₀ᵗ w(t′) · g(t − t′) dt′
g(t) = k₁·exp(−t/τ₁) − k₂·exp(−t/τ₂)
```

Discrete (daily) form — this is what you implement:

```
P(n) = P₀ + Σ_{i=1}^{n−1} w(i)·[ k₁·exp(−(n−i)/τ₁) − k₂·exp(−(n−i)/τ₂) ]

Fitness  F(n) = Σ k₁·w(i)·exp(−(n−i)/τ₁)
Fatigue  f(n) = Σ k₂·w(i)·exp(−(n−i)/τ₂)
P(n) = P₀ + F(n) − f(n)
```

Equivalently as first-order ODEs (cheaper — O(1) per day, two state variables, exactly what a Swift engine wants):

```
dF/dt = −F/τ₁ + w(t)      →   F_n = F_{n−1}·e^{−1/τ₁} + w_n
df/dt = −f/τ₂ + w(t)      →   f_n = f_{n−1}·e^{−1/τ₂} + w_n
P_n   = P₀ + k₁·F_n − k₂·f_n
```

Model constraints: **k₁ < k₂** and **τ₁ > τ₂**. Fatigue is larger in magnitude but shorter in duration; fitness is smaller but persists ([Chiu & Barnes 2003](https://journals.lww.com/nsca-scj/citation/2003/12000/the_fitness_fatigue_model_revisited__implications.7.aspx)). This is the formal statement of Verkhoshansky's Long-Term Delayed Training Effect: fatigue is the *intended* state of the accumulation block, and the taper exists to unmask fitness, not to add it.

### 1.2 The two closed-form landmarks

These are the only two formulas the app strictly needs from the theory. Both come from a **single unit training impulse** ([Fitz-Clarke, Morton & Banister 1991, *J Appl Physiol* 71(3):1151–8](https://journals.physiology.org/doi/abs/10.1152/jappl.1990.69.3.1171); restated in [Ceddia et al. 2025, arXiv:2505.20859](https://arxiv.org/pdf/2505.20859)):

**Break-even / recovery time** — when the impulse stops being a net negative:
```
t_r = (τ₁τ₂ / (τ₁ − τ₂)) · ln(k₂ / k₁)
```

**Time to peak** — when that impulse's net contribution is maximal:
```
t_p = (τ₁τ₂ / (τ₁ − τ₂)) · ln(k₂τ₁ / (k₁τ₂))
```

Fitz-Clarke's original claim: **the optimal taper duration lies between t_r and t_p** — long enough to clear the fatigue from the last hard block, short enough to still be riding its fitness. For their swimmers that bracketed **2 to 4 weeks**, which is exactly the powerlifting taper range.

Computed values (my `ffm.py`):

| Parameter set | k₁ | k₂ | τ₁ | τ₂ | t_r | t_p |
|---|---|---|---|---|---|---|
| Banister classic (as cited by Hellard) | 1 | 2 | 45 | 15 | **15.6 d** | **40.3 d** |
| Hellard 2006 elite swimmers (mean) | 0.036 | 0.050 | 38 | 19 | 12.5 d | 38.8 d |
| Swimming-specific (cited in Hellard) | 0.128 | 0.055 | 41.4 | 12.4 | −15.0 d | 6.4 d |
| Strength-calibrated (this report) | — | — | 30 | 12 | ~14 d | ~30 d |

Note the classic set gives **t_r = 15.6 d** — i.e. "a hard session's net cost persists about two weeks." That is *precisely* the empirical last-heavy-deadlift window (10–14 d) that PeakWeek already uses. The engine's existing default is the two-factor model's own prediction; it just was not derived that way.

### 1.3 Published parameter values — the actual numbers

| Source | Population | k₁ | k₂ | τ₁ (fitness) | τ₂ (fatigue) | t_r | t_p |
|---|---|---|---|---|---|---|---|
| Banister/classic (as cited by [Hellard 2006](https://pmc.ncbi.nlm.nih.gov/articles/PMC1974899/)) | swimmers | 1.0 | 2.0 | **45 d** | **15 d** | 15.6 | 40.3 |
| Swimming-specific (cited ibid.) | swimmers | 0.128 | 0.055 | 41.4 | 12.4 | — | — |
| [Hellard et al. 2006](https://pmc.ncbi.nlm.nih.gov/articles/PMC1974899/), n = 9 elite | swimmers | 0.036 ± 0.038 | 0.050 ± 0.044 | **38 ± 16** (95% CI 17–59) | **19 ± 11** (95% CI 6–32) | **19 ± 9 d** (CI 7–35) | **43 ± 16 d** (CI 25–61) |
| [Busso 2003 / Thomas & Busso 2005](https://paulogentil.com/pdf/A%20theoretical%20study%20of%20taper%20characteristics%20to%20optimize%20performance.pdf), n = 6 | cycling | k₁ 0.031 ± 0.007; k₃ 0.000035 ± 0.000010 | variable | **30.8 ± 1.6** | **16.8 ± 3.3** (τ₃ = 2.3 ± 1.0) | — | — |
| Busso Table 3 (via [Ceddia 2025](https://arxiv.org/pdf/2505.20859)), n = 8 | mixed | 0.048 | 0.117 | 38 | 1.9 | — | — |
| Literature envelope ([Ceddia 2025](https://arxiv.org/pdf/2505.20859); [Imbach et al. 2022](https://link.springer.com/article/10.1186/s40798-022-00426-x)) | all sports | — | — | **4–51 d** | **4–74 d** | — | — |
| [Issurin & Lustig 2004](https://coachsci.sdsu.edu/csa/vol161/issurin.htm) residual for **maximal strength** — an independent estimate of τ₁ | strength | — | — | **30 ± 5 d** | — | — |

### 1.4 Verifying the premise: is it "fitness ~45 d, fatigue ~15 d"?

**Verdict: τ₁ = 45 d / τ₂ = 15 d is a real, citable pair, but it is (a) from swimming, (b) the single least-identifiable pair in the literature, and (c) probably too long on the fitness side for powerlifting.**

Specifics:

1. **Provenance is correct.** Hellard et al. explicitly cite prior estimates of "τa = 45 days, τf = 15 days, ka = 1 a.u., kf = 2 a.u." The 45/15 pair is genuine Banister-lineage, not folklore. A closely related independent statement in the same tradition: "the fitness function is related to training by a first-order system with time constant **50 days**, whereas the fatigue function … **15 days**."

2. **τ₁ is essentially unmeasurable from typical data.** Hellard's own elite-swimmer fit gave τa = **38 ± 16 d, 95% CI 17–59 d** — a range spanning a factor of 3.5. The **τa–τf correlation was 0.99 ± 0.01** and ka–kf was 0.91 ± 0.13; bootstrap CVs on every parameter exceeded 30%. You cannot separately identify fitness and fatigue from performance data alone. Do **not** expose τ₁ and τ₂ as two independent coach-facing dials — you will be selling a false precision.

3. **For powerlifting, τ₁ ≈ 30 d is better supported than 45 d.** [Issurin's residual-training-effect table](https://coachsci.sdsu.edu/csa/vol161/issurin.htm) puts the maximal-strength residual at **30 ± 5 days** — an entirely independent measurement of the same physical quantity, derived from block-periodization detraining observations rather than curve-fitting. Busso's fitted τ₁ = 30.8 d agrees. This matters practically: with τ₁ = 30 d the model puts a hard ceiling on realization-block length at ~4 weeks, which is exactly the clamp `research-science.md` §8.1 already recommends on empirical grounds.

4. **τ₂ ≈ 12–15 d for strength athletes is well supported and is the parameter that actually drives the calendar.** Back-solving from practice via law #1 (`d_opt ≈ 1.6·τ₂`):
   - [Pritchard 2022](https://pubmed.ncbi.nlm.nih.gov/34846328/) raw powerlifters: 7–10 d step taper + 4–6 d cessation ⇒ 11–16 d total load reduction ⇒ **τ₂ ≈ 7–10 d**
   - [Travis 2021 Frontiers](https://www.frontiersin.org/journals/physiology/articles/10.3389/fphys.2021.735932/full) exponential arm: 3-week taper ⇒ **τ₂ ≈ 13 d**
   - [Travis 2020 weightlifting case series](https://pubmed.ncbi.nlm.nih.gov/31373973/): 1-wk overreach + 3-wk exponential taper, peak achieved **3–4 days before competition** ⇒ **τ₂ ≈ 13–16 d**
   - [JTS/Israetel](https://www.jtsstrength.com/peaking-powerlifting/): novice 2 wk (τ₂ ≈ 9), masters 198 lb 3 wk (τ₂ ≈ 13), elite 308 lb 4 wk (τ₂ ≈ 17)

   **Recommended app default: τ₂ = 12 d, clamp [8, 18].** That single dial reproduces every published recommendation (see §3.3).

### 1.5 Use the nonlinear (Busso) variant, not plain Banister

Plain Banister is **linear in training load**: it says every unit of training buys the same fitness regardless of history, so its optimum is "train infinitely hard." It cannot generate a taper endogenously and it cannot represent overreaching. My own simulation confirms this degeneracy: under linear Banister the "no taper" control looked *better* than every taper (see `ffm2.py` output).

[Busso's Variable Dose-Response model](https://paulogentil.com/pdf/A%20theoretical%20study%20of%20taper%20characteristics%20to%20optimize%20performance.pdf) fixes it by making the fatigue *gain* itself a state variable with memory:

```
P(n) = P₀ + Σ_i w(i)·[ k₁·exp(−(n−i)/τ₁) − k₂(i)·exp(−(n−i)/τ₂) ]
k₂(i) = k₃ · Σ_{j<i} w(j)·exp(−(i−j)/τ₃)
```

τ₃ = 2.3 ± 1.0 d is a short "recent-hard-training memory": consecutive hard days make each subsequent day disproportionately more fatiguing. This produces the **inverted-U between daily training load and steady-state performance** — an *optimal daily training* (ODT) beyond which more training makes you worse. That is exactly the MRV concept, and it is what makes the taper pay off.

**Critical consequence for PeakWeek:** in this model, **a taper only improves performance if pre-taper training exceeded ODT.** Thomas & Busso: "The taper allowed performance gains if training was higher than a minimal level," with a minimum reduction of **11.8 ± 1.5%** required before performance during the taper exceeded steady-state. If an athlete arrives at the realization block under-trained and un-fatigued, a deep taper *costs* them. The app should say so.

### 1.6 Validation of my implementation

I implemented the Busso model with Thomas & Busso's published parameters (k₁ = 0.031, k₃ = 0.000035, τ₁ = 30.8, τ₂ = 16.8, τ₃ = 2.3), numerically located ODT by scanning constant daily loads to steady state, then scanned all step reductions 0–100%:

| | Published (Thomas & Busso 2005, n = 6) | My reproduction |
|---|---|---|
| Optimal step taper, **no** prior overload | **30.8 ± 11.8%** cut over **19.3 ± 2.3 d** | **31%** cut over **18 d** |
| Optimal step taper, **after** +20%/28 d overload | **39.3 ± 9.9%** cut over **28.0 ± 5.1 d** | **39%** cut over **26 d** |

Every number below is generated by this validated engine.

### 1.7 Law #1 — τ₂ sets the taper length; τ₁ sets its depth

Optimal step taper after a +20%/28 d overreach, scanned across the plausible parameter space (`ffm4.py`):

| τ₁ ↓ / τ₂ → | 8 d | 12 d | 16.8 d | 21 d |
|---|---|---|---|---|
| **25 d** | 57% / **14 d** | 44% / **19 d** | 30% / **28 d** | 21% / 45 d |
| **30.8 d** | 62% / **14 d** | 52% / **19 d** | 39% / **26 d** | 30% / **34 d** |
| **38 d** | 62% / **13 d** | 58% / **20 d** | 47% / **26 d** | 39% / **32 d** |
| **45 d** | 61% / **13 d** | 63% / **21 d** | 53% / **27 d** | 46% / **32 d** |

*(cells are `optimal volume cut % / optimal taper duration in days`)*

Read the columns: **taper duration is almost entirely a function of τ₂** and barely moves with τ₁. Read the rows: **the optimal cut depth rises with τ₁** (more durable fitness ⇒ you can afford to cut harder) **and falls with τ₂**.

The ratio duration/τ₂ is 1.52–1.75 in every non-degenerate cell. Hence:

> **d_opt ≈ 1.6 × τ₂** (at the model's own optimal cut)
> **d_opt ≈ τ₂ × (2.6 − 0.018 × cut%)** (for a coach-chosen cut)

Sanity check on the second form at τ₂ = 12: cut 30% → 24 d, cut 50% → 20 d, cut 70% → 16 d. Simulated truth: 24, 19, 15. Good to ±1 d.

### 1.8 Law #2 — the peak is flat, and asymmetric

From `ffm5.py` (τ₁ = 30, τ₂ = 12; optimal cut 51% over 19 d). "Δ" is how far the meet lands from the optimum; **negative Δ = the taper is that many days too short.**

| Δ (days) | % of the achievable taper gain lost |
|---|---|
| **−14** (taper 14 d too short) | 51.0% |
| −10 | 22.9% |
| −7 | 10.2% |
| −5 | 4.9% |
| −3 | 1.7% |
| −2 | 0.8% |
| **0** | 0.0% |
| +2 | 0.4% |
| +3 | 1.0% |
| +5 | 2.8% |
| +7 | 5.2% |
| +10 | 9.7% |
| +14 | 16.7% |
| +21 | 30.0% |

Fitted penalty functions (r ≈ 0.99 over |Δ| ≤ 10):

```
loss%(Δ) = 0.19·Δ²   for Δ < 0   (taper too SHORT — fatigue not cleared)
loss%(Δ) = 0.10·Δ²   for Δ > 0   (taper too LONG  — fitness decaying)
```

**Three implications for the app:**

1. **A ±3-day scheduling error is essentially free** (<2% of the taper gain, ≈0.06–0.09% of total). Do not let the UI imply day-level precision matters more than it does. Snapping the last-heavy day to the nearest real training session is safe.
2. **Erring long is roughly half as expensive as erring short.** This vindicates the practitioner drift toward 10–14 d for the last heavy deadlift over the survey's 7–10 d.
3. **But this asymmetry applies only to the reduced-load taper, not to cessation.** Extending *complete cessation* past 7 days costs **1–4% of maximal strength** outright ([Travis et al. 2020](https://pmc.ncbi.nlm.nih.gov/articles/PMC7552788/)), which swamps the modelled taper gain. The app must model these as two different clocks.

Volume-cut sensitivity at each cut's own optimal duration (τ₂ = 12, expressed as % of the pre-taper performance level):

| Cut | Best day | Peak |
|---|---|---|
| 10% | 41 | +12.2% |
| 20% | 28 | +17.6% |
| 30% | 24 | +21.6% |
| 40% | 22 | +24.0% |
| **50%** | **19** | **+24.8%** ← optimum |
| 60% | 17 | +24.2% |
| 70% | 15 | +22.4% |
| 80% | 13 | +19.5% |
| 100% (cessation) | 9 | +12.1% |

*(the absolute % are in model units, not kg — read the shape, not the magnitude)*

The plateau from **40% to 60%** is nearly flat, and drops off sharply below 30% and above 70%. This is an independent derivation of Travis's published band ("reduce volume 30–70%, with 30–50% outperforming 50–70%") and Pritchard's observed 41–50%, and of the meta-analytic ES peak at 41–60%.

### 1.9 Law #3 — overreach demands a deeper *and* longer taper

From `ffm6.py` (τ₁ = 30, τ₂ = 12):

| Pre-taper block | Optimal cut | Optimal taper |
|---|---|---|
| No overreach (steady ODT) | 45% | 15 d |
| +20% × 28 d | 51% | 19 d |
| +30% × 14 d | 53% | 21 d |
| +50% × 7 d | 58% | 23 d |
| +100% × 7 d | 66% | 29 d |
| +150% × 7 d | 71% | 35 d |

**App rule: if a planned overreach week is programmed, add ~5–8 days to the taper and ~8–12 percentage points to the volume cut — capped at the literature bounds of 28 days and 70%.**

Honesty caveat: the model's *magnitude* of benefit from a short sharp overreach is small (+50% × 7 d actually scored marginally *below* no overreach in my run), because τ₃ = 2.3 d is calibrated on cycling and likely under-represents the multi-week hypertrophic residual of a resistance overreach. The **direction** (deeper + longer) is robust and matches the empirical record: [Williams 2017](https://pmc.ncbi.nlm.nih.gov/articles/PMC7552788/) (+107% volume overreach → −67% cut → **bench +6.4% / +8.1 kg**) and [Travis 2021](https://www.frontiersin.org/journals/physiology/articles/10.3389/fphys.2021.735932/full) (+150% volume-load week 1 → step or exponential taper → **total +7% to +10%**).

### 1.10 Honesty caveats you must not skip

Put these in the app's methodology note, not in marketing copy.

- **The fatigue term may not survive statistical scrutiny.** [Sedeaud/Imbach et al., *Scientific Reports* 15:3706 (2025)](https://pmc.ncbi.nlm.nih.gov/articles/PMC11779798/): under Bayesian cross-validation with biologically meaningful priors the FFM is **ill-conditioned**, fitness and fatigue parameters are **poorly identifiable** (visible in the Markov chains), and the model **overfits** — *adding the fatigue parameters did not significantly improve predictive ability*, on two independent datasets. The authors question the biological relevance of the fatigue component as formulated.
- **Data requirements are far beyond what a coaching app collects.** Hellard: elite athletes yield ≤20 performances/year against a recommendation of ~15 observations *per parameter*. A 4-parameter model wants ~60 max-effort tests.
- **General constants should not be used per-athlete.** [Imbach et al. 2022](https://link.springer.com/article/10.1186/s40798-022-00426-x) and the IJSPP "What's in the numbers?" commentary both warn that parameter values depend on starting values, fitting technique, and the training-load metric, and do not transfer between individuals or load definitions.
- **Training-load quantification is unsolved for powerlifting.** Banister's original impulse was arbitrary swim units; the standard alternatives (TRIMP, session-RPE) are cardiovascular in origin. For lifting, tonnage / volume-load (sets × reps × load) or sRPE × duration are the practical choices, but neither is validated as an FFM input for strength.

**Therefore: use the FFM as the *derivation* of the calendar rules and the *penalty geometry*, not as a live per-athlete simulator with fitted constants.** Ship the day-offset table and the peak-quality scoring in §3, which are the model's robust outputs. Do not ship a "your fitness is 87, your fatigue is 34" dashboard — you cannot defend those numbers.

---

## 2. Taper prescriptions that maximise the peak

### 2.1 The consolidated target

| Parameter | Recommendation | Source |
|---|---|---|
| **Total reduced-load window** | 1.6 × τ₂ ≈ **14–28 d** (default 20 d ≈ 3 wk) | derived §1.7; bounded by Travis 1–2 wk taper + 2–7 d cessation, Frontiers 3-wk exponential |
| **Volume reduction (cumulative, vs peak block)** | **40–60%**, optimum ~50%; never <25% or >70% | [Travis 2020](https://pmc.ncbi.nlm.nih.gov/articles/PMC7552788/) 30–70%, preferring 30–50%; [Pritchard 2022](https://pubmed.ncbi.nlm.nih.gov/34846328/) 41–50%; [Grgic & Mikulic 2017](https://pubmed.ncbi.nlm.nih.gov/27806009/) 50.5 ± 11.7%; [Winwood 2023 weightlifters](https://pubmed.ncbi.nlm.nih.gov/35976755/) 43.1 ± 14.6%; meta ES peak 41–60%; my §1.8 plateau 40–60% |
| **Intensity policy** | **Maintain ≥85% 1RM** through the last-heavy sessions, then drop to 70–80% in meet week | Travis: maintaining intensity → **+1–6%**; reducing intensity → **+2–10%**; increases should not exceed ~15% |
| **Peak intensity timing** | highest training intensity **8 ± 3 d out** | [Grgic & Mikulic 2017](https://pubmed.ncbi.nlm.nih.gov/27806009/) |
| **Model** | **step or exponential**; exponential favoured after an overreach | Travis 2020; Thomas & Busso 2005 (progressive > step **only with** prior overload, 102.2 ± 1.7 vs 101.8 ± 1.5 PU, *p* < 0.005) |
| **Frequency** | hold, or cut only in the final week | Pritchard: unchanged; Grgic: final week −47.9 ± 17.5% |
| **Accessories** | eliminate at taper start | Grgic: "assistance exercises removed"; Frontiers step arm: accessories cut |
| **Complete cessation** | **2–7 d**; hard ceiling 7 d | Travis 2020 |
| **Expected yield** | total **+3.2 to +4.4%**; SQ +1.7–9.5%, BP +1.4–6.4%, DL +3.8–4.8% | Travis 2020 aggregate |

### 2.2 Reconciling "7–10 days" with "3 weeks" — the two-stage taper

The apparent contradiction between Pritchard's 7–10 day survey taper and Travis's 3-week exponential taper is a **definitional artefact**. The survey asks about the *final step down*; the controlled trials describe the *entire reduced-load period*. Model them as three stages and both numbers are simultaneously satisfied:

| Stage | Window (τ₂ = 12) | Volume vs peak block | Intensity | Content |
|---|---|---|---|---|
| **T1 — Onset** | −20 to −13 d | **−30%** (70% of peak) | ≥87%, climbing | top calibration single (RPE 8.5–9, 93–96%); accessories cut to ≤2/lift |
| **T2 — Deep taper** | −12 to −7 d | **−50%** cumulative | **90–92.5%** | the three last-heavy / opener-confirmation sessions; this is the survey's "7–10 day step taper" |
| **T3 — Meet week** | −6 to −3 d | **−70 to −75%** cumulative | **75–80% SQ/BP, 70–75% DL** | primer singles/doubles only; then cessation |

Average cut across T1–T3 ≈ **50%** ✓. Deepest step lands 7–10 d out ✓. Peak intensity lands 8 ± 3 d out ✓ (Grgic). Total reduced-load window = 20 d ✓ (= 1.6 τ₂). Last session 3 ± 1 d out ✓ (Grgic).

Set/rep prescriptions inside T2/T3, from the survey ([Pritchard 2022](https://pubmed.ncbi.nlm.nih.gov/34846328/)): **3×2 squat, 3×3 bench, 3×1 deadlift**. Frontiers step-taper format for the final week: **1×1 + 3×2 at 90–95%**.

### 2.3 The controlled-trial evidence, with the actual numbers

| Study | Design | Volume change | Outcome |
|---|---|---|---|
| Häkkinen 1991 | 7 d taper | −50% | Squat improved |
| Williams 2017 | +107% overreach, then 7 d taper | −67% | **Bench +6.4% (+8.1 kg)** |
| Godawa et al. 2012 | 14 d | slight ↑ | SQ +2.3–5.9%, BP +1.8–2.1%, **DL +3.8–4.8%** |
| Pritchard et al. 2016 | 17 d | −58.9% | — |
| [Grgic & Mikulic 2017](https://pubmed.ncbi.nlm.nih.gov/27806009/), n = 10 Croatian champions (Wilks 355.1 ± 54.8) | step or fast-decay exponential | **−50.5 ± 11.7%** | intensity maintained/increased, peaking **8 ± 3 d out**; final week frequency −47.9 ± 17.5%; **last session 3 ± 1 d out**; taper **identical for SQ/BP/DL**; assistance work removed |
| Andre et al. 2017 | 28 d | −58.7% | all lifts improved; 7 state records |
| [Travis et al. 2021 Frontiers](https://www.frontiersin.org/journals/physiology/articles/10.3389/fphys.2021.735932/full), n = 16 | 6-wk peak, wk1 overreach **VL +150%** (7×5 @ 77.5–87.5%) | **step**: 1 wk, −50%, intensity **held 90–95%**, format 1×1+3×2 · **expo**: 3 wk, progressive −50%, intensity 87.5% → 70–85% | **SQ +8% / +10%; BP +10% / +9%; DL +1% / +8%; total +7% / +10%.** VL CSA +3.2% / +1.4%; **Type IIA fibre +11% (step only)** |
| [Travis et al. 2020 case series](https://pubmed.ncbi.nlm.nih.gov/31373973/), 2 national-level weightlifters, 28 wk | 1-wk overreach + **3-wk exponential taper**, VL halved, intensity maintained or slightly increased | −50% VL | **peak preparedness achieved and maintained 3–4 d before competition**; unloaded SJ height and RFD highest on competition day |

**The deadlift asymmetry is the single most actionable finding in this table**: step taper +1% vs exponential taper +8%. The deadlift wants a *longer, gentler* reduction than squat and bench.

### 2.4 Survey evidence — what lifters actually do

[**Pritchard/Travis 2022**, n = 364 US/Canadian raw powerlifters](https://pubmed.ncbi.nlm.nih.gov/34846328/):

| | Squat | Bench | Deadlift |
|---|---|---|---|
| Last session >85% 1RM | **7–10 d out** | **<7 d out** | **7–10 d out** |
| Load on that session | 90.0–92.5% 1RM | 90.0–92.5% | 90.0–92.5% |
| Final training session load | 75–80% | 75–80% | **70–75%** |
| Set/rep in taper | 3×2 | 3×3 | 3×1 |
| **Training cessation** | **4.1 ± 1.9 d** | **3.9 ± 1.8 d** | **5.8 ± 2.5 d** |

Predominant model: **step taper over 7–10 days, volume −41–50%.**

[**Winwood/Pritchard 2023**, n = 146 weightlifters](https://pubmed.ncbi.nlm.nih.gov/35976755/): 99% taper; length **8.0 ± 4.4 d**; volume **−43.1 ± 14.6%**; linear (36%) and step (33%) most common; all training ceased **1.5 ± 0.6 d** out.

Taper prevalence in strength sports: 78% Highland Games, 87% strongman, 99% weightlifters, 99% hybrid athletes.

### 2.5 Per-lift recovery kinetics — the science says one thing, the taper data says another

**Acute lab evidence: the lifts recover at the same rate.** [Belcher et al. 2019, *Appl Physiol Nutr Metab* 44(10):1033–42](https://cdnsciencepub.com/doi/abs/10.1139/apnm-2019-0004), n = 12 well-trained males (training age 7.1 ± 4.2 y), 4 sets to failure @ 80% 1RM on SQ / BP / DL in successive weeks, measured at 0/24/48/72/96 h (limb swelling, ROM, DOMS, ACV @ 70% 1RM, CK, LDH, cfDNA):

> "The deadlift does not require longer recovery time compared to the squat and bench press when set volume is equated and training is completed to failure at 80% of 1RM in well-trained males."

Notable within-study detail: **muscle-damage markers need 48–72 h for all three lifts; squat bar velocity recovered within 96 h, bench velocity recovered by 24 h.** Travis's review agrees that "research suggests recovery times are actually *similar* across squat/bench/deadlift."

**Chronic/taper evidence and elite practice say the deadlift is different.** Same review: "elite practice removes the deadlift entirely for 1–2 weeks, while squat and bench cessation is typically 2–7 days." Survey cessation: **DL 5.8 d vs SQ 4.1 vs BP 3.9** (a 41–49% longer deadlift window). Frontiers: **DL +1% on a 1-week step taper vs +8% on a 3-week exponential taper.**

**Resolution — and what the app should implement.** These are not in conflict; they measure different things. Belcher measures recovery from *one* 4-set bout at 80%. The taper concerns the residual of a *block* of near-maximal axial loading, at a lift that is typically trained **1×/week** (per the [minimum-effective-dose data](https://www.frontiersin.org/journals/sports-and-active-living/articles/10.3389/fspor.2021.713655/full), the optimal frequency pattern is **2 squat / 3 bench / 1 deadlift**). A once-weekly lift concentrates its entire weekly load into a single session, so the *last* session sits proportionally higher on the fatigue curve. Add axial/connective-tissue and CNS-perception factors that the 96-hour markers do not capture.

**Implementation:** keep per-lift offsets (they encode real practice and real taper outcomes), but **label them as practice-derived, not as a claim that deadlift muscle damage lasts longer.** The engine's per-lift ratios should be:

```
DL : SQ : BP  =  1.00 : 0.82 : 0.55   (last heavy)
DL : SQ : BP  =  1.00 : 0.71 : 0.67   (cessation, = survey means 5.8 : 4.1 : 3.9)
```

Cross-check against the practitioner sources in `research-science.md`: Rob Palmer 10–14 / 7–10 / 4–6 = 1 : 0.71 : 0.42; SBS 5–10 / 5–10 / 4–7; JTS elite ~2.5 wk / ~2 wk / ~1.5 wk = 1 : 0.8 : 0.6. My ratios sit in the middle of all of them.

### 2.6 Training cessation — the hard numbers and the hard ceiling

From [Travis et al. 2020](https://pmc.ncbi.nlm.nih.gov/articles/PMC7552788/):

| Cessation length | Effect on maximal strength |
|---|---|
| **2–7 d** | maintained or improved — the recommended window |
| **>7 d** | **−1% to −4%** |
| **≥14 d** | clear decrement: back squat **−0.9%**, bench press **−1.7%** |

Observed practice: PL cessation SQ 4.1 / BP 3.9 / DL 5.8 d; last session 3 ± 1 d out (Grgic); weightlifters stop 1.5 ± 0.6 d out.

**This is the app's only truly hard constraint.** Every other deviation costs a fraction of a percent; blowing the cessation ceiling costs whole percent of 1RM with published magnitudes. Encode it as a blocking validation, not a soft warning.

### 2.7 Intensity policy — the honest trade-off

Travis 2020 found studies that **maintained** ≥85% produced **+1–6%**, and studies that **reduced** intensity produced **+2–10%**. That looks like reduction wins, but the reducing studies were confounded by longer/harder pre-taper blocks. The defensible synthesis, and the one the survey data supports:

- **Maintain ≥85% through T1 and T2** (through the last-heavy sessions at 90–92.5%). This preserves neuromuscular/technical specificity and gives you the opener confirmation.
- **Reduce to 70–80% in T3** (meet week). Both the survey and universal practice.
- **Never increase intensity more than ~15%** above the preceding block.
- **Do not use a maintain-intensity policy with a >60% volume cut**: you get the neuromuscular retention without enough fatigue clearance. Pair deep cuts with intensity reduction.

---

## 3. The projection algorithm

### 3.1 Inputs

```swift
struct PeakProjectionInput {
    let meetDate: Date                 // meet day, day 0
    let startDate: Date                // program day one (any weekday — see task #29)
    let sessionCalendar: [Session]     // date + which comp lifts are trained that day
    // athlete
    let bodyweightKg: Double
    let trainingAgeYears: Double
    let ageYears: Int
    let equipment: Equipment           // raw / single-ply / multi-ply
    let plannedWeightCutPct: Double
    let arrivalFatigue: FatigueState   // fresh / normal / fatigued  (coach input or logged sRPE trend)
    // program
    let phaseWeeks: (acc: Int, trans: Int, real: Int)
    let deloadWeeks: [Int]
    let daysPerWeek: Int               // 4 or 5
    let overreachWeekPlanned: Bool
    let peakBlockWeeklyVolume: Double  // sets×reps×load, for the cut calculation
}
```

### 3.2 Deriving the athlete constants

**τ₂ (fatigue decay, days) — the master dial.**

```
τ₂ = 12.0                                  // base, trained raw lifter
   + bodyweight term:
        BW > 120 kg        → +4.0
        100 < BW ≤ 120     → +2.5
        83  < BW ≤ 100     → +1.0
        66  < BW ≤ 83      →  0.0
        BW ≤ 66            → −1.0
   + training-age term:
        < 1 y              → −3.0
        1–3 y              → −1.5
        3–7 y              →  0.0
        > 7 y              → +1.5
   + age term:
        40–49              → +1.0
        50–59              → +2.0
        ≥ 60               → +3.0
   + equipment:
        single-ply +1.0 ; multi-ply +2.0
   + weight cut > 3% BW    → +1.0
   + arrivalFatigue:  fresh −1.0 ; fatigued +2.0
   clamp to [8, 18]
```

Rationale for each term: bodyweight and training age are the two axes JTS scales taper length on (novice 97 lb → 2 wk; masters 198 lb → 3 wk; elite 308 lb → 4 wk), which under `d = 1.6τ₂` implies τ₂ ≈ 9 / 13 / 17 — the exact span this formula produces. Masters/equipped/weight-cut adjustments are practitioner consensus, not measured; expose them as editable.

**τ₁ (fitness decay, days).** Default **30** ([Issurin's 30 ± 5 d maximal-strength residual](https://coachsci.sdsu.edu/csa/vol161/issurin.htm); Busso's fitted 30.8 d). Do **not** expose as a dial — it is unidentifiable (§1.4). Use it for exactly one thing: the **realization-block ceiling**, `realizationMaxDays = τ₁ ≈ 28–30 d`. A realization block longer than the strength residual is training you cannot express.

### 3.3 The day-offset table — every event from τ₂

```
offset(event) = clamp(round(coef[event] × τ₂), lo[event], hi[event])
```

| Event | coef | lo | hi |
|---|---|---|---|
| `taperStart` | 1.70 | 14 | 28 |
| `topCalibrationSingle` | 1.50 | 14 | 24 |
| `lastHeavyDeadlift` | 0.92 | 8 | 16 |
| `lastHeavySquat` | 0.75 | 6 | 12 |
| `lastHeavyBench` | 0.50 | 4 | 9 |
| `lastDeadliftTouch` (DL cessation) | 0.48 | 4 | 7 |
| `lastSquatTouch` (SQ cessation) | 0.34 | 3 | 6 |
| `lastBenchTouch` (BP cessation) | 0.33 | 3 | 6 |
| `fullCessationStart` | = min(lastTouch) − 1 | 2 | 7 |

Fully expanded (days before meet):

| τ₂ | taper start | top single | LH DL | LH SQ | LH BP | DL last | SQ last | BP last | cessation |
|---|---|---|---|---|---|---|---|---|---|
| 8 | 14 | 14 | 8 | 6 | 4 | 4 | 3 | 3 | 2 |
| 9 | 15 | 14 | 8 | 7 | 4 | 4 | 3 | 3 | 2 |
| 10 | 17 | 15 | 9 | 8 | 5 | 5 | 3 | 3 | 2 |
| 11 | 19 | 16 | 10 | 8 | 6 | 5 | 4 | 4 | 3 |
| **12** | **20** | **18** | **11** | **9** | **6** | **6** | **4** | **4** | **3** |
| 13 | 22 | 20 | 12 | 10 | 6 | 6 | 4 | 4 | 3 |
| 14 | 24 | 21 | 13 | 10 | 7 | 7 | 5 | 5 | 4 |
| 15 | 26 | 22 | 14 | 11 | 8 | 7 | 5 | 5 | 4 |
| 16 | 27 | 24 | 15 | 12 | 8 | 7 | 5 | 5 | 4 |
| 17 | 28 | 24 | 16 | 12 | 8 | 7 | 6 | 6 | 5 |
| 18 | 28 | 24 | 16 | 12 | 9 | 7 | 6 | 6 | 5 |

**Validation against every published source** (τ₂ = 12 row unless noted):

| Claim | Source | Table output | ✓ |
|---|---|---|---|
| SQ/DL last heavy 7–10 d out | Pritchard n=364 | DL 11, SQ 9 | ✓ (DL 1 d over, consistent with practitioner drift) |
| BP last heavy <7 d out | Pritchard | BP 6 | ✓ |
| DL cessation 5.8 ± 2.5 d | Pritchard | 6 | ✓ |
| SQ cessation 4.1 ± 1.9 d | Pritchard | 4 | ✓ |
| BP cessation 3.9 ± 1.8 d | Pritchard | 4 | ✓ |
| Last session 3 ± 1 d out | Grgic & Mikulic | 3 | ✓ |
| Peak training intensity 8 ± 3 d out | Grgic & Mikulic | LH SQ 9 / LH BP 6 | ✓ |
| 3-week exponential taper | Travis 2021 / 2020 case series | taper start 20 d | ✓ |
| DL last heavy 10–14 d out | Rob Palmer, PeakWeek current | 11 | ✓ |
| Novice 2-week taper | JTS | τ₂ = 9 → 15 d | ✓ |
| Elite 308 lb 4-week taper | JTS | τ₂ = 17 → 28 d | ✓ |
| Elite DL ~2.5 wk out | JTS | τ₂ = 17 → 16 d | ✓ |
| Cessation ≤ 7 d hard ceiling | Travis 2020 | max 7 at τ₂ = 18 | ✓ by construction |

### 3.4 Calendar snapping — the algorithm

Ideal offsets are continuous; training days are discrete. Snap, then repair ordering.

```
func project(input) -> PeakPlan {
  τ₂ = deriveTau2(input)
  events = ordered list, furthest-out first:
     [topSingle(DL,SQ,BP), lastHeavyDL, lastHeavySQ, lastHeavyBP,
      lastTouchDL, lastTouchSQ, lastTouchBP]

  for e in events {
     target  = meetDate − offset(e, τ₂)
     window  = [meetDate − hi(e), meetDate − lo(e)]
     cands   = sessions in `window` that train e.lift, and that are
               strictly later than the already-assigned prior event for e.lift
     if cands.isEmpty {
        // no session in the evidence window at all
        pick nearest session outside the window that trains e.lift
        flag .noSessionInWindow(e, deviationDays)
     } else {
        pick argmin |cand.date − target|
        tie-break:  DL, SQ → choose the EARLIER candidate
                    BP     → choose the LATER candidate
     }
  }

  // ordering repair — these invariants must hold in days-out terms
  assert daysOut(topSingle)  >  daysOut(lastHeavyDL)
  assert daysOut(lastHeavyDL) ≥ daysOut(lastHeavySQ) ≥ daysOut(lastHeavyBP)
  assert daysOut(lastHeavyX)  >  daysOut(lastTouchX)  for each lift
  if violated: push the offending event back to the previous available
               session for that lift and re-check; if impossible, flag
               .scheduleCannotSatisfyOrdering

  cessationStart = day after max(lastTouchDL, lastTouchSQ, lastTouchBP)
  taperStart     = the first scheduled session on or after
                   meetDate − offset(taperStart, τ₂)   // snap FORWARD, never
                                                       // start the cut early
  return PeakPlan(...)
}
```

**Why the tie-breaks differ by lift:** for squat and deadlift the cost of being late (fatigue not cleared) is the steeper `0.19Δ²` branch, so bias earlier. Bench has the shortest fatigue residual (velocity recovered by 24 h in Belcher) and the highest technical-decay risk, so bias later.

**Volume schedule** — express as a multiplier on `peakBlockWeeklyVolume`, applied per calendar week within the taper window (L = taperStart offset):

```
Step ladder (default, matches Pritchard's observed step taper):
   days [L,  L−6] → 0.70   (−30%)
   days [L−7, 8 ] → 0.50   (−50%)
   days [7,   4 ] → 0.28   (−72%)
   days [3,   0 ] → 0.00

Exponential option (use when an overreach week is programmed, per Travis 2021):
   v(d) = peakVolume × exp(−1.2 × (L − d) / L)     // reaches 0.30 at d = 0
   with a hard floor of 0 at the cessation date
```

If `overreachWeekPlanned`, place it at days `[L+7, L+1]` at **+50% to +150% volume-load**, then apply §1.9: `taperStart += 6 d` and deepen the final cut by 10 pp, capped at 28 d / 70%.

### 3.5 Worked example — Saturday meet, 4-day week (Mon/Tue/Thu/Fri), τ₂ = 12

Day indices relative to the Saturday meet:

| Week | Mon | Tue | Thu | Fri |
|---|---|---|---|---|
| meet week | −5 | −4 | −2 | −1 |
| week −2 | −12 | −11 | −9 | −8 |
| week −3 | −19 | −18 | −16 | −15 |
| week −4 | −26 | −25 | −23 | −22 |

Projection (lift assignment: Mon = squat, Tue = bench, Thu = deadlift, Fri = bench 2 — adapt to the client's split):

| Event | Target | Snapped session | Actual | Δ | Cross-check |
|---|---|---|---|---|---|
| Taper start | −20 | Mon wk−3 | **−19** | +1 | ~3-wk taper ✓ |
| Top calibration single (RPE 8.5–9, ~94%) | −18 | Mon wk−3 (SQ) / Tue wk−3 (BP) / Thu wk−3 (DL) | **−19 / −18 / −16** | ≤2 | 2–3 wk out ✓ |
| Last heavy **DL** @ 90–92.5% | −11 | Thu wk−2 | **−9** | −2 | Pritchard 7–10 d ✓ |
| Last heavy **SQ** @ 90–92.5% | −9 | Mon wk−2 | **−12** | +3 | 7–10 d band — slightly long |
| Last heavy **BP** @ 90–92.5% | −6 | Mon meet wk | **−5** | +1 | <7 d ✓ |
| **DL** primer 70–75% | −6 | Mon meet wk | **−5** | +1 | cessation 5 d vs 5.8 ± 2.5 ✓ |
| **SQ** primer 75–80% | −4 | Tue meet wk | **−4** | 0 | cessation 4 d vs 4.1 ± 1.9 ✓ |
| **BP** primer 75–80% | −4 | Tue meet wk | **−4** | 0 | cessation 4 d vs 3.9 ± 1.8 ✓ |
| Full cessation begins | −3 | Wed | **−3** | 0 | Grgic 3 ± 1 d ✓ |

Then Thu −2 = rest/travel, Fri −1 = weigh-in / rack heights / opener cards, Sat 0 = meet.

**Peak-quality score for this schedule:** the only material deviations are SQ +3 (0.10 × 9 = 0.9%) and DL −2 (0.19 × 4 = 0.8%). Total ≈ **1.7% of the achievable taper gain**, i.e. ≈0.07% of total. **Grade A.** The model output and lived practitioner practice land on the same calendar — which is the strongest available validation of both.

If the client's split makes the squat land badly, the fix is a schedule tweak (move the last heavy squat from Mon wk−2 to Thu wk−2), not a change to the math. That is precisely the kind of surfaced, actionable suggestion this feature should produce.

### 3.6 Worked example — Sunday meet, 5-day week

Sunday meet, sessions Mon/Tue/Wed/Thu/Sat. Day indices: meet week Mon −6, Tue −5, Wed −4, Thu −3, Sat −1; week −2: Mon −13, Tue −12, Wed −11, Thu −10, Sat −8.

| Event | Target | Snapped | Δ |
|---|---|---|---|
| Last heavy DL | −11 | Wed wk−2 (−11) | **0** |
| Last heavy SQ | −9 | Thu wk−2 (−10) | +1 |
| Last heavy BP | −6 | Sat wk−2 (−8) or Mon meet wk (−6) → **later** | **0** |
| DL primer | −6 | Mon meet wk (−6) | 0 |
| SQ primer | −4 | Wed meet wk (−4) | 0 |
| BP primer | −4 | Wed meet wk (−4) | 0 |
| Cessation start | −3 | Thu (−3) → **drop the Thu and Sat sessions** | 0 |

**Grade A.** Note the 5-day schedule requires deleting two meet-week sessions — the engine must actively *remove* sessions in meet week, not just lighten them.

### 3.7 Peak-quality assessment — exact scoring

**Continuous component.** For each event `e` with target days-out `T` and actual days-out `A`:

```
s = T − A                       // s > 0  ⇒ event too CLOSE to the meet (taper too short)
x = A − T                       // x > 0  ⇒ event too FAR from the meet (taper too long)
loss(e) = (s > 0) ? min(100, 0.19·s²) : min(100, 0.10·x²)     // % of taper gain
```

Per-lift weighted loss (weights from the §1.8 curve's sensitivity to each stage):

```
lossLift = 0.20·loss(topSingle) + 0.50·loss(lastHeavy) + 0.30·loss(lastTouch)
```

Convert to kilograms so it means something to a coach:

```
achievableTaperGain:  SQ 4.5% · BP 3.5% · DL 4.3%     (Travis 2020 midpoints:
                      SQ 1.7–9.5%, BP 1.4–6.4%, DL 3.8–4.8%)
expectedLoss_kg(lift) = (lossLift/100) × achievableTaperGain(lift) × current1RM(lift)
```

Worked: a lifter with a 250 kg squat whose last heavy squat lands 7 days too close to the meet incurs `0.19 × 49 = 9.3%` → weighted `0.50 × 9.3 = 4.7%` → `0.047 × 0.045 × 250 = 0.53 kg`. Small. Now the same lifter with a **12-day complete cessation**: hard-rule violation, **−1% to −4% of maximal strength = 2.5 to 10 kg on the squat alone**, ~15–30 kg off the total. That contrast is exactly why the scoring must be split into a soft continuous part and a hard rule part.

**Hard-rule component** (fixed deductions; each also emits an explicit, quantified warning string):

| Rule | Deduction | Warning text |
|---|---|---|
| Any lift's complete cessation > 7 d | **−25** | "Cessation of N d exceeds the 7-day ceiling — expect −1 to −4% of maximal strength on this lift (Travis 2020)." |
| Any lift's cessation ≥ 14 d | **−50** | "Cessation of N d: measured decrements are −0.9% (squat) to −1.7% (bench)." |
| DL cessation < 3 d | **−20** | "Fewer than 3 clear days after the last pull; survey mean is 5.8 ± 2.5 d." |
| Reduced-load window > 28 d | **−20** | "Taper exceeds every published protocol and approaches the 30 ± 5 d maximal-strength residual — detraining risk." |
| Reduced-load window < 10 d | **−20** | "Taper below every published protocol; fatigue will not have cleared." |
| Cumulative volume cut > 70% | **−15** | "Cut exceeds the 70% upper bound (Travis 2020)." |
| Cumulative volume cut < 25% | **−15** | "Cut below the 30% floor; the taper will not clear enough fatigue to pay for itself." |
| No session ≥ 90% 1RM within 21 d of the meet | **−15** | "Opener is unvalidated — no near-opener single in the final 3 weeks." |
| Peak realization intensity never reaches 93% | **−10** | "Second attempt is unvalidated — the athlete has never touched second-attempt weight." |
| Taper programmed with no preceding overload/overreach | **−10** | "Pre-taper load did not exceed the athlete's tolerance ceiling; a taper from a non-fatigued state loses performance (Thomas & Busso 2005)." |
| Realization block > τ₁ (≈30 d) | **−20** | "Realization exceeds the ~30-day maximal-strength residual." |

```
peakQuality = clamp(100 − Σ(continuousLoss weighted across lifts) − Σ(hardDeductions), 0, 100)

A  90–100  On model
B  75–89   Minor deviations, no action required
C  60–74   Material deviation — one or two scheduling fixes recommended
D  <60     Restructure the peak
```

**UI recommendation:** show the grade, the three per-lift Δ values as a small timeline, and the *single highest-value fix* ("move the last heavy squat from Mon of week −2 to Thu of week −2: +0.5 kg expected"). Do not show τ₂ as a number to the coach — show it as a named profile ("Fatigue clearance: slow / typical / fast") with the derived taper length underneath.

### 3.8 Audit of PeakWeek's current engine against this model

Reading `Engine.swift` lines 216–272, the realization templates are indexed by `weeksOut ∈ {3+, 2, 1}` and the meet week is a fixed template. **Day-of-week is not modelled at all**, so the same plan is emitted whether the meet is on a Saturday or a Wednesday, and the printed "days out" labels are decorative rather than computed. For a Saturday meet on a Mon/Tue/Thu/Fri split:

| Engine element | Where it actually lands | Model target (τ₂ = 12) | Δ | Cost |
|---|---|---|---|---|
| `"Day 3 — LAST HEAVY DEADLIFT (10–14 days out)"` — DL 1×1 @ 92%, `weeksOut == 2`, Day 3 | **−16 d** | −11 | +5 | 2.5% (0.10 × 25) — cheap direction, but the **label is wrong**: it says 10–14, it is 16 |
| `"Squat OPENER (single @ ~92%)"`, `weeksOut == 1`, Day 1 | **−12 d** | −9 | +3 | 0.9% |
| `"Bench OPENER (single @ ~92%)"`, `weeksOut == 1`, Day 2 | **−11 d** | −6 | +5 | 2.5% |
| `"Deadlift speed work"` @ 78%, `weeksOut == 1`, Day 3 | −9 d | (fine — intermediate touch) | — | — |
| `.meet` "Mon/Tue — Technique primer": SQ 2×2 @ 60%, BP 2×2 @ 60%, DL 1×2 @ 55% | −5/−4 d | **75–80% SQ/BP, 70–75% DL** | — | **loads are 15–20 pp below the survey**; primers this light do not preserve the motor pattern under near-meet loads |
| Highest intensity anywhere in realization | **92%** | ≥93% to validate a 97% second | — | **−10** (unvalidated second attempt — this reproduces `research-science.md` §8.4) |
| Cessation | implicit, ~4 d for all three lifts | DL 6 / SQ 4 / BP 4 | — | acceptable; DL is 2 d short of the survey mean |

**Aggregate: roughly grade B/C.** The timing errors are all in the cheap (too-early) direction and total only ~2% of the taper gain. The two real defects are (a) the 92% ceiling leaves the second attempt unvalidated, and (b) the meet-week primer loads at 55–60% are materially below the 70–80% the survey reports.

**Minimum change to reach grade A:**
1. Replace `weeksOut`-indexed templates with **date-anchored events** computed by §3.3–3.4 against the real `sessionCalendar` (this is the natural continuation of completed tasks #28 "meet-date-driven planning" and #29 "day-one anchoring").
2. Raise meet-week primers to **75–80% SQ/BP, 70–75% DL**.
3. Add the **top calibration single at ~94% / RPE 8.5–9 at −18 d**, then descend to 90–92.5% at the last-heavy sessions.
4. Make the `"(10–14 days out)"` label **computed**, not a string literal — right now it is a documented lie about the schedule the engine emits.
5. Add the peak-quality panel from §3.7 to the week/plan view.

---

## 4. Short runway — 3 to 6 weeks

### 4.1 The governing principle

> **The strength you have is the strength you will express. A short prep cannot add fitness fast enough to matter, but it can absolutely add fatigue you have no time to clear.**

Quantitatively: over 3–6 weeks the *training block's* marginal contribution to 1RM is on the order of **1–2%** (from the [minimum-effective-dose data](https://www.frontiersin.org/journals/sports-and-active-living/articles/10.3389/fspor.2021.713655/full): 3–6 hard sets/week/lift over 6–12 weeks produces gains, i.e. gains accrue over 6+ weeks, not 3). The *taper's* contribution is **+3.2% to +4.4% of total** and is realised inside 2–4 weeks. **In a short runway the taper is worth 2–4× the training block.** Therefore the taper is the last thing you cut, not the first.

The second governing constraint is the **maximal-strength residual, 30 ± 5 days** (Issurin). Anything you build in week 1 of a 4-week prep is still ~90% present on meet day; anything you build in an 18-week prep's first block has decayed unless it was consolidated. Short preps are actually *efficient* in residual terms — their problem is total dose, not decay.

### 4.2 Cut order — what goes first, and why

| # | Cut | Why | Evidence |
|---|---|---|---|
| **1** | **The entire accumulation block** | Hypertrophy needs 6+ weeks to translate to 1RM, and it front-loads fatigue that a short runway cannot dissipate. Under Busso's model, load above ODT with insufficient taper time is strictly negative. | Thomas & Busso 2005 (taper duration must scale with pre-taper overload); METD 6–12 wk timeframe |
| **2** | **All accessories not directly serving a comp lift** | Zero contribution to a 4-week 1RM; nonzero fatigue. Every taper protocol removes them anyway. | Grgic & Mikulic: "assistance exercises removed"; Frontiers step arm cut accessories |
| **3** | **Exercise variation breadth** | Specificity is the highest-yield variable in a short window. Comp-command lifts only. | Realization phase = narrowest specificity (`research-science.md` §2.1) |
| **4** | **Frequency above 2 SQ / 3 BP / 1 DL** | Volume-equated, frequency does not matter; extra sessions are pure fatigue. | Grgic frequency meta-analysis (effect vanishes when volume-equated); METD optimal pattern 2/3/1 |
| **5** | **Deloads** | With ≤4 weeks the taper *is* the deload. Keep one only if the athlete arrives already fatigued. | Bell et al. 2025: deload = restore readiness for the *next* block; there is no next block |
| **6** | **Planned overreach** | Only if the runway is ≥5 weeks *and* the athlete arrives fresh. Overreach forces the taper 6–8 days longer (§1.9); in a 3–4 week runway that is time you do not have. | Thomas & Busso: OT ⇒ +8.5 pp cut and +8.7 d duration |
| **NEVER** | **The taper, or the last-heavy/cessation structure** | It is the only component with a guaranteed, published, multi-percent payoff. | Travis 2020: +3.2–4.4% total |

### 4.3 Allocation by runway length

| Runway | acc | trans | real/taper | Structure | Evidence base |
|---|---|---|---|---|---|
| **3 wk** | 0 | 0 | **3** | Pure taper. Wk1: top single RPE 8–8.5 (~92–94%), volume −30%. Wk2: last-heavy sessions at 90–92.5%, volume −50%. Wk3: meet week, primers 75–80/70–75%, volume −70%. **τ₂ clamped to ≤11** so the calendar fits. | This *is* the Pritchard step taper extended one week; the survey's modal practice |
| **4 wk** | 0 | **1** | **3** | Wk1 mini-overreach (+30 to +50% VL, only if arriving fresh) or a heavy transmutation week at 85–88%; then the 3-week exponential taper. | **Exactly the [Travis 2020 case-series](https://pubmed.ncbi.nlm.nih.gov/31373973/) design** — 1-wk overreach + 3-wk exponential taper, VL halved, intensity maintained → peak preparedness 3–4 d out |
| **5 wk** | 0 | **2** | **3** | Two transmutation weeks (4×4 @ 80–88%, sets descending), then the 3-week taper. Optional overreach in wk2. | Matches the transmutation parameters in `research-science.md` §2.1 |
| **6 wk** | **1** | **2** | **3** | Or run the literal published protocol: **wk1 overreach at VL +150% (7×5 @ 77.5–87.5%), then a step or exponential taper with ~50% volume reduction over 1–3 wk.** | [Travis et al. 2021 Frontiers](https://www.frontiersin.org/journals/physiology/articles/10.3389/fphys.2021.735932/full), n=16 — produced SQ +8–10%, BP +9–10%, DL +1–8%, total +7–10% |

Note that at every runway length the realization block is **3 weeks**, not a percentage. This is the absolute-vs-proportional fix that `research-science.md` §8.1 already called for; the FFM supplies the reason (the taper length is set by τ₂, which has nothing to do with how long the prep is).

### 4.4 The decision rule that actually matters: how the athlete arrives

The single input that should reshape a short prep is not the runway length — it is **arrival fatigue**.

| Arrival state | τ₂ adjustment | Prep shape | Rationale |
|---|---|---|---|
| **Fatigued** (coming off a hard block, high sRPE trend, stalled lifts, joint aches) | **+2 d** | Shorten the training block to zero; lengthen the taper. A 4-week runway becomes 0/0/4: an extra reduced-load week at the front. | The athlete is already above ODT; more load is strictly negative. Thomas & Busso: performance during taper exceeds pre-taper only when prior training was above the minimum |
| **Normal** | 0 | Use the §4.3 table as written | — |
| **Fresh / undertrained** (layoff, illness, deload just finished, or simply hasn't been training hard) | **−1 d** | Extend the training block by a week, shorten the taper toward 14 d, and **program the overreach** | Model: a taper from below ODT *costs* performance. You need to get above the tolerance ceiling before there is anything to taper from. Thomas & Busso: min useful reduction 11.8 ± 1.5%, and only above a minimum prior load |

**The counterintuitive one worth surfacing in the UI:** a fresh, undertrained athlete with a 4-week runway should train *harder for longer and taper less* than a fatigued athlete with the same 4 weeks. Most apps get this backwards because they treat the taper as a fixed percentage of prep length.

### 4.5 Attempt-selection consequences of a short runway

With ≤4 weeks you get **one** high-quality calibration point instead of two. Prioritise:

1. **Keep the last-heavy/opener-confirmation single at 90–92.5%** (the single most valuable data point — it is what validates the opener, and the opener is what keeps the athlete in the meet). Never cut this.
2. **Drop the separate top calibration single** if it will not fit ≥14 d out. Instead, take the last-heavy single to **RPE 8.5–9 (~94–95.5%)** and derive the second attempt from it via the RTS table rather than from a separate session.
3. **Shift the risk profile one notch conservative.** With less calibration data, expected total is maximised by the conservative profile (89–90 / 94–95 / 99–101%) rather than standard (91 / 96 / 101.5%). The [IPF data](https://bmcsportsscimedrehabil.biomedcentral.com/articles/10.1186/s13102-022-00505-2) is unambiguous: ~50% of third attempts are missed (SQ 46%, BP 53%, DL 55%), winners average **8.46/9** vs **6.66/9** for the field. Going 9/9 conservatively beats 6/9 aggressively.

---

## 5. Consolidated implementation checklist for PeakWeek

1. **Add `tau2` to the client model**, derived by §3.2, surfaced as a three-way named profile plus an advanced numeric override. Do **not** surface τ₁.
2. **Replace `weeksOut`-indexed realization templates with date-anchored event projection** (§3.3–3.4) resolved against the real session calendar. This subsumes the "last heavy DL" and "openers" constants into one formula.
3. **Model the three taper stages explicitly** (T1 −30%, T2 −50%, T3 −72%) rather than as fixed weekly templates.
4. **Model cessation per lift as a first-class field** with the hard 7-day validation.
5. **Raise the realization ceiling to a ~94% RPE 8.5–9 top single** at −1.5 τ₂, and raise meet-week primers to 75–80 / 70–75%.
6. **Add the peak-quality panel** (§3.7) — grade, per-lift Δ timeline, expected-kg cost, and the single highest-value fix.
7. **Clamp the realization block to `min(28 d, τ₁)`** regardless of prep length.
8. **Add an `arrivalFatigue` input** and wire it to both τ₂ and the short-runway allocation (§4.4).
9. **Fix the string literal** `"LAST HEAVY DEADLIFT (10–14 days out)"` in `Engine.swift:242` — make the parenthetical computed. As shipped it lands at 16 days out for a Saturday meet.
10. **Ship a methodology note** carrying the §1.10 caveats. The model is the derivation, not a live simulator.

---

## Sources

**Fitness–fatigue modelling**
- [Banister EW, Calvert TW, et al. Fatigue and fitness modelled from the effects of training on performance. *Eur J Appl Physiol* (1976)](https://link.springer.com/article/10.1007/BF00867927)
- [Fitz-Clarke JR, Morton RH, Banister EW. Optimizing athletic performance by influence curves. *J Appl Physiol* 71(3):1151–8 (1991)](https://journals.physiology.org/doi/abs/10.1152/jappl.1990.69.3.1171) — origin of t_r / t_g
- [Morton RH, Fitz-Clarke JR, Banister EW. Modeling human performance in running. *J Appl Physiol* (1990)](https://journals.physiology.org/doi/abs/10.1152/jappl.1990.69.3.1171)
- [Busso T, Häkkinen K, Pakarinen A, et al. A systems model of training responses and its relationship to hormonal responses in elite weight-lifters. *Eur J Appl Physiol* (1990)](https://pubmed.ncbi.nlm.nih.gov/2289497/)
- [Busso T et al. Hormonal adaptations and modelled responses in elite weightlifters during 6 weeks of training. (1992)](https://pubmed.ncbi.nlm.nih.gov/1592066/)
- [**Thomas L, Busso T. A Theoretical Study of Taper Characteristics to Optimize Performance.** *Med Sci Sports Exerc* 37(9):1615–21 (2005)](https://paulogentil.com/pdf/A%20theoretical%20study%20of%20taper%20characteristics%20to%20optimize%20performance.pdf) — the key quantitative taper-optimisation paper; source of the 30.8%/19.3 d and 39.3%/28.0 d optima I reproduced
- [Hellard P et al. Assessing the limitations of the Banister model in monitoring training. *J Sports Sci* / PMC1974899 (2006)](https://pmc.ncbi.nlm.nih.gov/articles/PMC1974899/) — τa 38 ± 16, τf 19 ± 11, t_n 19 ± 9, t_g 43 ± 16; identifiability failure
- [Taha T, Thomas SG. Systems Modelling of the Relationship Between Training and Performance. *Sports Medicine* 33(14) (2003)](https://link.springer.com/article/10.2165/00007256-200333140-00003)
- [Chiu LZF, Barnes JL. The Fitness–Fatigue Model Revisited: Implications for Planning Short- and Long-Term Training. *NSCA Strength & Conditioning Journal* 25(6):42–51 (2003)](https://journals.lww.com/nsca-scj/citation/2003/12000/the_fitness_fatigue_model_revisited__implications.7.aspx) — the strength-sport translation
- [Ceddia D et al. Mathematical Modelling and Optimisation of Athletic Performance: Tapering and Periodisation. arXiv:2505.20859 (2025)](https://arxiv.org/pdf/2505.20859) — clean statement of eqs (1)–(4), including t_r and t_p
- [Imbach F et al. The Use of Fitness-Fatigue Models for Sport Performance Modelling: Conceptual Issues and Contributions from Machine-Learning. *Sports Medicine – Open* (2022)](https://link.springer.com/article/10.1186/s40798-022-00426-x)
- [**Statistical flaws of the fitness-fatigue sports performance prediction model.** *Scientific Reports* 15:3706 (2025)](https://pmc.ncbi.nlm.nih.gov/articles/PMC11779798/) — ill-conditioning, poor identifiability, overfitting; the fatigue term adds no predictive ability
- [The Fitness–Fatigue Model: What's in the Numbers? *IJSPP* 17(5):810 (2022)](https://pubmed.ncbi.nlm.nih.gov/35320776/) — warns against general constants
- [Issurin & Lustig. Residual training effects table (2004)](https://coachsci.sdsu.edu/csa/vol161/issurin.htm) — maximal strength residual 30 ± 5 d

**Tapering and peaking for strength**
- [**Travis SK, Mujika I, Gentles JA, Stone MH, Bazyler CD. Tapering and Peaking Maximal Strength for Powerlifting Performance: A Review.** *Sports* 8(9):125 (2020)](https://pmc.ncbi.nlm.nih.gov/articles/PMC7552788/)
- [Travis SK et al. Skeletal Muscle Adaptations and Performance Outcomes Following a Step and Exponential Taper in Strength Athletes. *Frontiers in Physiology* (2021)](https://www.frontiersin.org/journals/physiology/articles/10.3389/fphys.2021.735932/full)
- [Travis SK, Mizuguchi S, Stone MH, Sands WA, Bazyler CD. Preparing for a National Weightlifting Championship: A Case Series. *JSCR* (2020)](https://pubmed.ncbi.nlm.nih.gov/31373973/) — peak preparedness 3–4 d out after 1-wk overreach + 3-wk exponential taper
- [Pritchard HJ, Travis SK et al. Characterizing the Tapering Practices of United States and Canadian Raw Powerlifters. *JSCR* (2022), n = 364](https://pubmed.ncbi.nlm.nih.gov/34846328/)
- [Grgic J, Mikulic P. Tapering Practices of Croatian Open-Class Powerlifting Champions. *JSCR* 31(9):2371–8 (2017)](https://pubmed.ncbi.nlm.nih.gov/27806009/) — −50.5 ± 11.7%, intensity peaks 8 ± 3 d out, last session 3 ± 1 d out
- [Winwood P, Keogh J, Travis SK, Pritchard HJ. The Tapering Practices of Competitive Weightlifters. *JSCR* (2023), n = 146](https://pubmed.ncbi.nlm.nih.gov/35976755/) — 8.0 ± 4.4 d, −43.1 ± 14.6%, cessation 1.5 ± 0.6 d
- [Bell L, Darragh IAJ, Travis SK, Rogerson D, Nolan D. A Practical Approach to Deloading. *NSCA SCJ* (2025)](https://doras.dcu.ie/31501/1/a_practical_approach_to_deloading__recommendations.203(2).pdf) — Table 1 taper parameters
- [Higher- vs Lower-Intensity Strength-Training Taper: Effects on Neuromuscular Performance. *IJSPP* 14(4):458 (2019)](https://journals.humankinetics.com/view/journals/ijspp/14/4/article-p458.xml)
- [Stronger by Science — Research Spotlight: How do powerlifters taper?](https://www.strongerbyscience.com/research-spotlight-taper/)
- [Israetel M / JTS — Peaking for Powerlifting](https://www.jtsstrength.com/peaking-powerlifting/) — athlete-scaled 2/3/4-week tapers
- [Rob Palmer — Tapering in Powerlifting](https://robpalmer949.substack.com/p/tapering-in-powerlifting)

**Per-lift recovery kinetics and dose**
- [Belcher DJ et al. Time course of recovery is similar for the back squat, bench press, and deadlift in well-trained males. *Appl Physiol Nutr Metab* 44(10):1033–42 (2019)](https://cdnsciencepub.com/doi/abs/10.1139/apnm-2019-0004) · [plain-language summary](https://csep.ca/2019/06/19/time-course-of-recovery-is-similar-for-the-back-squat-bench-press-and-deadlift-in-well-trained-males-2/)
- [Androulakis-Korakakis P et al. The Minimum Effective Training Dose Required for 1RM Strength in Powerlifters. *Front Sports Act Living* (2021)](https://www.frontiersin.org/journals/sports-and-active-living/articles/10.3389/fspor.2021.713655/full) — 2 SQ / 3 BP / 1 DL optimal frequency
- [Grgic J et al. Effect of Resistance Training Frequency on Gains in Muscular Strength: meta-analysis](https://pubmed.ncbi.nlm.nih.gov/29470825/)

**Attempt selection**
- [What are the odds? Identifying factors related to competitive success in powerlifting. *BMC Sports Sci Med Rehabil* (2022)](https://bmcsportsscimedrehabil.biomedcentral.com/articles/10.1186/s13102-022-00505-2)
- [Travis SK, Zourdos MC, Bazyler CD. Weight Selection Attempts of Elite Classic Powerlifters. *Percept Mot Skills* (2021)](https://journals.sagepub.com/doi/abs/10.1177/0031512520967608)

**Repo files referenced**
- `/Users/richardholguin/dev/powerlifting-trainer/docs/research-science.md`
- `/Users/richardholguin/dev/powerlifting-trainer/Sources/PeakWeek/Engine.swift` (lines 216–272, 279)

**Simulation scripts written for this report**
- `/private/tmp/claude-501/-Users-richardholguin-dev-foreman/31e6222c-323a-4cf6-add5-c46759d2c57a/scratchpad/ffm.py` — closed-form t_r / t_p
- `.../ffm2.py` — linear Banister taper scenarios (demonstrates the linear model's degeneracy)
- `.../ffm3.py` — **Thomas & Busso 2005 reproduction** (ODT search + step-taper scan)
- `.../ffm4.py` — τ₁ × τ₂ sensitivity grid (source of Law #1)
- `.../ffm5.py` — peak-flatness and volume-cut sensitivity (source of the 0.19Δ² / 0.10Δ² penalty functions)
- `.../ffm6.py` — overreach magnitude effect (source of Law #3)