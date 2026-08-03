# Practical Meet-Prep Powerlifting Coaching Workflows
### Research report for software supporting a solo coach with 5–30 clients

This report synthesizes how real powerlifting coaches — Mike Tuchscherer (Reactive Training Systems), Boris Sheiko, Chad Wesley Smith (Juggernaut/JuggernautAI), Bryce Lewis (The Strength Athlete), Calgary Barbell, and Greg Nuckols (Stronger by Science) — actually run meet prep with online clients, and translates each workflow into concrete software requirements.

---

## 0. The operating reality of a solo coach

Before the workflows, the constraints that shape everything:

- **Time budget per client is ~30–60 min/week**: writing/adjusting the next week (10–20 min), reviewing videos (10–20 min), check-in reply (10 min). At 30 clients that's a 15–30 hr/week job. Every software feature should be judged by minutes saved per client per week.
- **The unit of work is the training week (microcycle)**, reviewed against the block (mesocycle) and the meet date (macrocycle). All three horizons are live simultaneously.
- **The coach's real product is the adjustment, not the template.** TSA's team explicitly frames coaching as "weekly adjustments rather than templated approaches" — programs emerge from athlete response ([StrengthPortal interview with Bryce Lewis](http://strengthportal.com/blog/bryce-lewis-the-strength-athlete/)). Tuchscherer's "Emerging Strategies" formalizes this: programming is bottom-up from observed athlete response, reviewed block-by-block, not top-down periodization ([RTS Emerging Strategies interview](https://articles.reactivetrainingsystems.com/2023/06/21/powerlifting-emerging-strategies-an-interview-with-mike-tuchscherer/)). Example: Brett Gibbs responded poorly to high intensity, so RTS ran his pre-Worlds blocks at ~70–80% average intensity and he won a world title.
- **Everything anchors to a meet date.** The countdown ("6 weeks out") is the universal coordinate system; software should display weeks-out everywhere, not just calendar dates.

---

## 1. Client check-ins: what comes back and how adjustments get made

### 1.1 Data clients send back

The universal per-set training data (logged daily, reviewed weekly):

| Data item | Detail | Who emphasizes it |
|---|---|---|
| **Load actually lifted** | vs. prescribed; deviations are signal | Everyone |
| **Reps completed** | incl. AMRAP results | SBS (drives TM auto-adjustment) |
| **RPE per set** | logged to the half point (7.5, 8, 8.5…) | RTS invented the convention; TSA, Calgary Barbell use it |
| **Estimated 1RM (e1RM)** | computed from load × reps × RPE via chart, tracked as a trendline per lift | RTS core metric; the single best "is it working" signal |
| **Video** | top sets of comp lifts minimum; TSA has new clients film *every* movement, then tapers down "once we're both comfortable" | TSA, RTS, virtually all online coaches |
| **Set-level comments** | "felt pinchy in left hip," "grip almost slipped" | Everyone; often the most decision-relevant data |

Weekly wellness/lifestyle data (the check-in form proper):

- **Bodyweight** — daily or 2–3×/week, morning, post-void. Critical in meet prep for weight-class management (trend matters, not single readings).
- **Sleep** (hours + quality), **stress** (life/work), **soreness** by body part, **motivation/mood** — TrueCoach's standard check-in template covers "mindset & motivation, progress & lifestyle, nutrition consistency, weekly reflection (wins/challenges/goals)" ([TrueCoach check-in template](https://truecoach.co/learning-resources/client-check-in-template-for-personal-trainers/)).
- **Readiness score** — JuggernautAI operationalizes this as a daily 1–10 rating that modulates the day's loading pre-session, intra-session, and week-to-week ([JuggernautAI](https://www.juggernautai.app/)).
- **Nutrition adherence** — calories/protein vs. target, especially when cutting to a class.
- **Pain/injury flags** — anything above "normal soreness" gets its own field so it can't hide in free text.
- **Free-text reflection** — "biggest win, biggest struggle, questions for me."

### 1.2 The weekly adjustment loop (what the coach actually does)

The canonical Sunday-night workflow:

1. **Scan compliance** — did all sessions happen? Missed sessions change the plan more than bad sessions. (TrueCoach surfaces a compliance % per client and lets coaches sort by it — [TrueCoach features](https://truecoach.co/features/).)
2. **Scan e1RM trend per lift** — flat/rising/falling vs. block expectation.
3. **Compare prescribed vs. actual RPE** — if sets prescribed @8 keep coming in @9.5, loads are mis-calibrated or fatigue is accumulating; if @8 comes in @6.5, the lifter is sandbagging or peaking early. RTS treats the gap between called RPE and bar speed/actual as "information — closing it over time is what calibrating your RPE means" ([RTS/VBT](https://vbtcoach.com/appearances/using-velocity-to-calibrate-rpe/)).
4. **Watch flagged videos** (top sets, misses, anything commented) at 0.5× speed, leave timestamped feedback with 1–2 cues max.
5. **Cross-reference wellness** — a bad week of RPEs + 5 hrs sleep + work crisis = leave program alone, cut a backoff set; bad RPEs with good sleep = programming problem.
6. **Write/adjust next week** — usually the *next* week already exists as a draft from the block plan and gets edited, not written from scratch.
7. **Reply to check-in** — short, personal, references specifics. This is retention; clients quit coaches who send generic replies.

### 1.3 Adjustment mechanics coaches use (the levers)

- **RPE-based autoregulation (RTS)**: prescribe "5 reps @8" instead of a fixed weight; daily load self-adjusts to daily readiness ([PowerliftingToWin RTS review](https://www.powerliftingtowin.com/a-review-of-mike-tuchscherers-reactive-training-systems-rts/)).
- **Fatigue percents / load drops (RTS)**: after the top set @ target RPE, drop 3–7% and repeat sets until the reduced load reaches the same RPE — volume self-limits to a chosen fatigue dose. E.g. 500×5@9 → drop 5% → 475×5 repeats until 475 is @9.
- **AMRAP-driven training-max adjustment (SBS)**: beat the rep target → TM up ~0.5% per extra rep; miss by 2+ → TM down ~1% per missed rep ([SBS Program Bundle](https://www.strongerbyscience.com/program-bundle/), [Lift Vault summary](https://liftvault.com/programs/strength/stronger-by-science-sbs-program-bundle-by-greg-nuckols/)).
- **Percent-based with fixed waves (Sheiko)**: huge submax volume at 68–80%, adjustments made by editing the plan between cycles, not within it ([Sheiko structure](https://www.powerliftingtowin.com/sheiko/)).
- **Block-level review (RTS Emerging Strategies)**: don't chase weekly noise; judge each 3–6 week block against its hypothesis ("did high-frequency benching move his e1RM?") and adapt the next block.

**Software implications:** per-set logging of load/reps/RPE with computed e1RM trendlines per lift; prescribed-vs-actual RPE deltas surfaced automatically; a check-in form builder with numeric + free-text fields; a per-client review queue (unwatched videos, unanswered check-ins, red flags like pain mentions or 3-day logging gaps); compliance %; and a block-level report view (avg intensity, tonnage, e1RM delta per block) to support Emerging-Strategies-style review.

---

## 2. Program delivery: spreadsheets, daily cards, and what a prescribed set carries

### 2.1 The classic coaching spreadsheet layout

The de facto standard (visible across Calgary Barbell, TSA, SBS, RTS templates on [Lift Vault](https://liftvault.com/programs/powerlifting/)):

- **One tab per week** (or one giant tab with week bands); rows grouped by **Day 1–4**, columns roughly:

  `Exercise | Sets | Reps | %1RM or RPE target | Prescribed load (auto-calc) | Actual load | Actual reps | Actual RPE | e1RM (auto) | Lifter comment | Coach comment`

- An **input block** (training maxes per lift, kg/lb toggle) feeds percentage auto-calculation; loads round to 2.5 kg / 5 lb.
- **Color conventions**: input cells one color, auto-calculated cells locked, lifter-fill cells another; green/red conditional formatting on target-vs-actual.
- **A tracking/dashboard tab**: e1RM chart per lift, weekly tonnage, PR table by rep range (1,2,3,5,8…), bodyweight graph.
- The lifter-comment column is sacred — it's the async conversation channel. Coaches reply inline in a different color.
- SBS sheets show the ceiling of automation: log a heavy single or AMRAP anywhere and the sheet recalibrates the TM for all downstream weeks.
- Calgary Barbell's 16-week sheet shows the meet-prep archetype: 4 phases (volume → 76–82% intensity work → 78–81% comp specificity → taper with RPE-based top singles, triples→singles, shrinking backoffs) with both % and RPE prescriptions coexisting ([Calgary Barbell 16-week](https://liftvault.com/programs/powerlifting/calgary-barbell-16-week-8-week-program-spreadsheets/), [structure review](https://fitnessvolt.com/powerlifting/programs/calgary-barbell-16wk/)).

### 2.2 TrueCoach-style daily cards

The alternative delivery model: the client opens today and sees only today.

- Free-form workout builder; drag-and-drop; templates copied across clients then individualized ([TrueCoach workout builder](https://truecoach.co/features/workout-builder/)).
- Typing an exercise name **auto-attaches the demo video** from a 3000+ video library; coaches can override with their own video ([video library](https://truecoach.co/features/video-exercise-library/)).
- Client logs results + uploads video directly on the card; coach comments inline; per-client compliance and messaging in one place.
- Weakness vs. spreadsheets: week-at-a-glance and long-horizon periodization visibility is worse — which is why many powerlifting coaches stay on Sheets.

### 2.3 What a single prescribed set/line must be able to carry

A powerlifting prescription line is surprisingly rich. Full field list observed across systems:

1. **Exercise** (with variation taxonomy: comp squat vs. 2ct pause squat vs. SSB squat)
2. **Sets × reps** (incl. AMRAP, rep ranges, "myo-reps," singles clusters)
3. **Intensity prescription — one or more of:** %1RM (of *training* max or comp max), RPE target ("@8"), absolute load, or RPE-capped percent ("80% not to exceed @8")
4. **Load-drop/fatigue-percent instruction** ("−5% repeats @9 cap")
5. **Tempo** (e.g., 3-1-0; pause counts: "2ct pause")
6. **Rest interval**
7. **Equipment/setup notes** (bar type, stance, grip width in cm/fingers-on-ring, box height, board count, sling shot, belt/no belt, wraps vs. sleeves)
8. **Coach note/cue for the day** ("focus: knees out on descent; only cue this")
9. **Video demo link**
10. **"Film this set" flag**
11. Expected back-calculated load (so the athlete knows ~what @8 should be)

**Software implications:** the prescription model must support %, RPE, absolute load, and hybrid caps *on the same line*; per-set (not just per-exercise) prescriptions; exercise library with variation lineage (so a swap keeps history comparable); both a week/block grid view (coach) and a daily card view (client); template blocks that copy across clients and then diverge; kg/lb per client with plate-sensible rounding.

---

## 3. Customization coaches constantly need

### 3.1 Per-lift, per-client progression rates
Lifts progress at different speeds (bench ~half the rate of squat/deadlift for most; women and lighter classes take smaller absolute jumps — 2.5 kg on bench can be 3% of the lift). SBS's per-lift TM auto-adjustment is the template: every lift has its own training max, its own increment, and its own response curve. RTS goes further: per-lift *and* per-block intensity preferences discovered from data (the Brett Gibbs example). Software needs per-lift TMs, per-lift increment settings, and per-lift e1RM histories — never a single "strength number."

### 3.2 Exercise swaps for injury
The standard clinical-adjacent workflow (see [Bonvec Strength low-back guide](https://bonvecstrength.com/2022/10/06/the-powerlifters-guide-to-working-around-lower-back-pain/), [Muscle & Strength](https://www.muscleandstrength.com/articles/lifting-with-back-injuries)):
- **Traffic-light pain rule**: 0–3/10 train normally; 4–6 modify (reduce ROM, load, or swap variation); 7+ swap the pattern entirely.
- **Swap ladders coaches keep in their heads** (software should encode them): low-back tweak → high-bar/SSB → belt squat/leg press; comp deadlift → block pull or trap bar → hinge machine work. Touch-and-go → dead-stop to cut eccentric stress.
- **Graded return protocol**: reintroduce at ~50% for 3×8–10 controlled, assess 48 hr, step up ~10–15% per exposure if no flare-up.
- Meet-prep-specific tension: how late can a swap run before comp-specificity suffers? (Rule of thumb: must be back on the comp lift by ~3–4 weeks out.)
Software: a substitution table per movement pattern, an injury log attached to the client, and one-click "swap exercise forward for N weeks" that preserves the slot's sets/reps/intent.

### 3.3 Equipment constraints
- **Raw vs. equipped** changes everything: equipped work needs suit/shirt-specific sessions (straps up/down, board work to learn shirt touch), wider bench grips, monolift-style no-walkout squats, and different overload ranges because gear assists the bottom ([JTS raw+equipped bench](https://www.jtsstrength.com/training-for-both-raw-and-equipped-bench-pressing/), [raw vs equipped overview](https://ironbullstrength.com/blogs/powerlifting/raw-vs-equipped-powerlifting)).
- **Gym equipment inventory**: no monolift → program walkout practice; no calibrated plates → attempt planning must anticipate kilo jumps feeling different; home-gym clients lack specialty bars, boards, blocks, chains. JuggernautAI's onboarding asks equipment availability explicitly and filters exercise selection through it ([JuggernautAI review](https://ai-fitness-engineer.com/juggernautai)).
- **Federation rules matter for prep**: deadlift bar vs. stiff bar, squat depth judging norms, walkout vs. monolift fed, allowed gear (sleeves/wraps), 2-hr vs. 24-hr weigh-in.
Software: per-client equipment profile that constrains the exercise picker; per-client federation profile that drives meet-week logic.

### 3.4 Weight-class and bodyweight management
Coach decision rules from the literature ([PowerliftingToWin weight cutting](https://www.powerliftingtowin.com/cutting-weight-for-powerlifting/), [PowerliftingTechnique water cut guide](https://powerliftingtechnique.com/water-cut-for-powerlifting/), [JTS cutting guide](https://www.jtsstrength.com/complete-guide-to-cutting-weight-without-sacrificing-strength-2/)):
- Within **3–5% of the class limit** → water cut manageable; **>5% over** → move up a class or diet earlier in the season. 24-hr weigh-ins tolerate bigger cuts (5–10% BW) than 2-hr weigh-ins (IPF-style, keep cuts small).
- Water-cut timeline: commit 2 weeks out; ~1 week of high water (≥1 gal/day), sodium manipulation, then water restriction ~12 hr pre-weigh-in; weigh AM and PM daily through the process.
- Rehydration protocol post-weigh-in: immediately ~32 oz of 50/50 water/electrolyte drink, then eat/drink aggressively with sodium-potassium-magnesium; performance recovery depends on it.
Software: bodyweight trendline vs. class limit with "%-over-class" and weeks-out overlay; a meet-week checklist generator keyed to federation weigh-in type; alert when trend projects a miss.

### 3.5 Multi-meet season planning
Standard model ([JTS periodization guide](https://www.jtsstrength.com/periodization-powerlifting-definitive-guide/), block periodization reviews): **hypertrophy/accumulation → strength/intensification → peak/taper → meet → 1–2 week pivot/recovery → repeat**, supporting ~2–3 meets/year; a 16-week prep is the archetype (Calgary Barbell), 8–9 weeks the compressed version. Sheiko's classic #29→#30→#31→#32 is the same arc in percent-based form (prep ~68% avg → accumulation ~70% → transmutation 80–85% → peak 85–90% + taper) ([Sheiko guide](https://www.typeatraining.com/blog/sheiko-programs/)). Coaches plan backward from the meet date and often juggle a local meet as a "qualifier" en route to nationals — meaning two peaks with a bridge block between. Software: a season timeline where you drop meet dates and block templates snap backward from them; moving a meet date reflows blocks; per-block intent labels and post-block review notes (Emerging Strategies workflow).

---

## 4. Cue libraries and weak-point accessory logic

### 4.1 Cue library structure
Research and TSA practice strongly favor **external cues** (attention on environment/outcome) over internal ones, delivered **one at a time** ([TSA on external cues](https://www.thestrengthathlete.com/blog/external-cues), [Legion cue list](https://legionathletics.com/weightlifting-cues/)). A coach's working library, organized by lift × phase:

- **Squat**: "spread the floor," "big air, brace" ([EliteFTS Big Air](https://www.elitefts.com/education/big-squat-big-bench-big-deadlift-big-air/)), "sit between your heels," "push the floor away," "chest through" on the ascent, "knees out" (borderline internal but universal).
- **Bench**: "break the bar in half," "press yourself away from the bar / press the bench away," "meet the bar with your chest" (touch point), "drive your feet through the floor" (leg drive — [Ironside on leg drive](https://www.ironsidetraining.com/blog/optimizing-your-leg-drive-for-a-bigger-bench)), "flare and finish over the shoulder."
- **Deadlift**: "push the floor away / leg-press the floor" (stops hips shooting up), "pull the slack out of the bar," "bend the bar around your shins," "hips through at the top," "long arms, proud chest" at setup ([deadlift cues](https://deadliftworkout.com/blog/deadlift-cues)).

Workflow reality: the cue lives attached to (a) the video review comment, (b) the next week's exercise note ("only think about X this week"), and (c) the meet-day handler card (the 1–2 words the coach will shout from the chalk box — though TSA notes mid-attempt shouting of body-part cues is low-value). Software: a per-coach cue library, taggable per lifter ("cues that work for Sarah"), insertable into video comments and set notes.

### 4.2 Weak-point → accessory mapping (the diagnostic core of meet prep)
Juggernaut's Addressing Weak Points series is the canonical taxonomy ([off the chest](https://www.jtsstrength.com/addressing-weak-points-off-the-chest-in-the-bench-press/), [bench lockout](https://www.jtsstrength.com/addressing-weak-points-lockout-in-the-bench-press/), [in the hole](https://www.jtsstrength.com/addressing-weak-points-in-the-hole-in-the-squat/), [deadlift lockout](https://www.jtsstrength.com/improving-deadlift-lockout/)). JuggernautAI encodes exactly this: report a lockout weakness and it prescribes close-grip/boards/triceps work rather than generic bench volume.

| Lift | Failure point (from video/misses) | Primary variation fixes | Muscle-builder accessories |
|---|---|---|---|
| **Bench** | Off the chest | Long-pause comp bench (2–3ct), Spoto press (mid-range: pause 2–3 cm off chest), wide-grip, dips | Chest hypertrophy: flyes, incline DB press |
| **Bench** | Mid-range (10–15 cm up, common raw sticking point) | Spoto press, tempo bench, pin press at sticking height | Shoulders/upper chest: incline, OHP |
| **Bench** | Lockout | Close-grip bench, board press (1–2 boards), floor press, pin press | Triceps: skullcrushers, JM press, pushdowns |
| **Squat** | Out of the hole | Pause squat, tempo squat, dead/pin squat from bottom (kills stretch reflex) | Quads: front squat, hack squat, leg press; glutes: hip thrust |
| **Squat** | Mid-thigh / "good-morning squat" | Pin squat at sticking point, SSB squat, tempo descent to fix position | Back/trunk: good mornings, back ext |
| **Deadlift** | Off the floor | Deficit pulls (2–3"), paused deadlift below knee, halting DL | Quads + lats: leg press, rows |
| **Deadlift** | Lockout/knee-up | Block pulls (knee height, supra-max), heavy holds, RDL, hip hinges | Glutes/hams/upper back: hip thrust, RDL, shrugs, rows |

Important caveat coaches apply (JTS's own warning in [Partial Movements for Raw Lifters](https://www.jtsstrength.com/partial-movements-for-raw-lifters/)): the visible failure point often reflects a positional break *earlier* in the lift — so the diagnosis step is video-driven ("hips shot up at the floor, so the 'lockout miss' is actually an off-the-floor position problem"), not just where the bar stopped. Timing convention: weak-point variation work lives in accumulation/strength blocks and is progressively replaced by comp-lift specificity in the last 3–6 weeks.

**Software implications:** a weak-point tag per lift per client; a variation/accessory recommendation table behind the exercise picker; e1RM tracking on *variations* (pause squat e1RM vs. comp squat e1RM ratios are diagnostic); block-phase awareness (warn if high-specificity weeks still carry heavy variation work).

---

## 5. Warm-up protocols

### 5.1 Gym warm-ups computed from the working weight
Standard convention ([warm-up calculators](https://coachway.io/tools/warm-up-set-calculator/), [Ironside](https://www.ironsidetraining.com/blog/how-to-warm-up-for-your-working-sets)):
- Default ramp: **bar × 5–10 → 40%×5 → 60%×5 → 80%×3 → (90%×1) → work set**, percentages of the *day's top set*, each rounded to a loadable 2.5 kg / 5 lb.
- Rep rule: reps fall as load rises — triples 60–80%, singles above ~80–90%.
- With RPE prescriptions the target load is unknown until the ramp happens — the ramp doubles as the readiness probe: the coach's chart says "your 80% single should feel @6; if it's @7.5, today's @8 will be lighter." This is a real software feature: back-calculate an *expected* top load from current e1RM, generate the ramp from it, and let the logged ramp singles revise the day's estimate live.

### 5.2 Meet-day back-room warm-ups (the handler's craft)
From [PRS warm-up room strategy](https://prsontheplatform.com/2018/09/03/powerlifting-warm-up-room-strategy/), [EliteFTS](https://www.elitefts.com/education/how-to-survive-in-the-warm-up-area/), [PowerliftingTechnique meet timing](https://powerliftingtechnique.com/how-long-are-powerlifting-meets/):

- **Set counts**: squat 5–8 warm-up sets, bench 4–6, deadlift ~5–7 (timing less critical since it's last). No more than ~30 min of bar work needed unless squatting 600+.
- **Load spacing**: progress from bar to a last warm-up ~**90% of the opener** — classically ~50 lb (~25 kg) under the opener for squat/deadlift and ~25 lb (~10–15 kg) under for bench. Example from Girls Gone Strong for a 200 lb opener: 75×5, 95×5, 120×3, 140×1, 160×1, 180×1.
- **Timing is counted in attempts, not minutes.** With ~1 min per attempt and flights of ~12–14 lifters, a flight runs ~45–60 min per lift. The rules of thumb: start warming up **when the flight before you begins that lift**; take your 4th-to-last warm-up when they start second attempts, 3rd-to-last halfway through seconds, 2nd-to-last at the start of thirds, and your **last warm-up halfway through the prior flight's third attempts (~5–8 min before you lift)**. Flight A squats: start general prep ~45 min before start, bar work ~30 min before, last warm-up ~5 min before the flight, spacing sets ~5 min apart. Between own warm-ups: 5–7 min.
- Shared-rack etiquette/logistics (3–5 lifters per rack, working in) is why handlers precompute every plate loading.
- **The attempt sheet / handler card** is the standard artifact (see [EliteFTS meet manual](https://www.elitefts.com/education/powerlifting-meet-manual-with-formula-for-selecting-attempts/)): per lift — full warm-up list with loads *and plate breakdowns in kilos*, opener, planned 2nd and 3rd in three variants (conservative / plan / aggressive) with the decision rule attached ("if 2nd moved <RPE 9 → take plan; if grindy → conservative"), plus rack heights, gear notes, and the 1-min-deadline reminder to submit next attempts.
- **Attempt selection doctrine** (consensus across [PowerliftingTechnique](https://powerliftingtechnique.com/how-to-pick-attempts-for-powerlifting/), [StrengthLog calculator](https://www.strengthlog.com/powerlifting-competition-attempt-calculator/), [EliteFTS](https://www.elitefts.com/education/powerlifting-meet-manual-with-formula-for-selecting-attempts/)): opener ~88–93% of true max ("a weight you could triple on a bad day," ~single @7.5–8 RPE); second ~93–97% to calibrate the third within 2.5–5 kg; third 100–103% chosen from how the second moved. Jumps ~5–7.5% for squat/deadlift, 3–5% for bench. Going 9/9 beats bigger 6/9 totals.

**Software implications:** a warm-up generator parameterized per client (ramp % steps, rep scheme, rounding, bar type) for both gym days and meet day; a meet-day mode that takes opener + flight position and emits the timed warm-up card (attempt-count-based triggers, not clock-based); kilo plate-math everywhere; an attempt-planning tool storing conservative/plan/aggressive trees per lift with RPE-based decision rules; printable/offline handler card.

---

## 6. Consolidated software feature map (what the workflows demand)

**Program authoring:** week/block grid editor + client daily-card view; hybrid %/RPE/absolute prescriptions with caps and load-drop syntax; per-lift training maxes with auto-recalc and plate rounding; block templates that snap backward from a meet date; exercise library with variation lineage, equipment filters, demo videos, and swap ladders.

**Logging & review:** per-set load/reps/RPE/comment/video; e1RM trendlines per lift and per variation; prescribed-vs-actual RPE deltas; AMRAP-driven TM auto-adjust option; compliance %; coach review queue (videos, check-ins, pain flags, gaps); timestamped video comments with cue-library insertion.

**Check-ins:** configurable weekly form (sleep, stress, soreness, motivation, bodyweight, nutrition adherence, wins/struggles); daily readiness score option; bodyweight-vs-class-limit projection with weigh-in-type-aware meet-week checklist.

**Meet prep:** season timeline with multiple meets and bridge blocks; weeks-out displayed globally; taper templates (triples→singles, shrinking backoffs); attempt planner (88–93/93–97/100–103% trees, decision rules); meet-day warm-up card generator with flight-based timing and kilo plate math; federation/equipment profiles per client.

**Analytics for block review (Emerging Strategies):** per-block average intensity, tonnage, frequency, e1RM delta, and a coach hypothesis/outcome note — the artifact that turns 30 clients' histories into individualized programming knowledge.

---

## Sources

- [PowerliftingToWin — RTS review (RPE, fatigue percents, load drops)](https://www.powerliftingtowin.com/a-review-of-mike-tuchscherers-reactive-training-systems-rts/)
- [RTS — Emerging Strategies interview](https://articles.reactivetrainingsystems.com/2023/06/21/powerlifting-emerging-strategies-an-interview-with-mike-tuchscherer/)
- [VBTcoach — RTS on velocity-calibrated RPE](https://vbtcoach.com/appearances/using-velocity-to-calibrate-rpe/)
- [StrengthPortal — Bryce Lewis / TSA coaching operations interview](http://strengthportal.com/blog/bryce-lewis-the-strength-athlete/)
- [TSA — external cues](https://www.thestrengthathlete.com/blog/external-cues)
- [TrueCoach — client check-in template](https://truecoach.co/learning-resources/client-check-in-template-for-personal-trainers/), [workout builder](https://truecoach.co/features/workout-builder/), [video exercise library](https://truecoach.co/features/video-exercise-library/), [features overview](https://truecoach.co/features/)
- [Lift Vault — Calgary Barbell 16/8-week spreadsheets](https://liftvault.com/programs/powerlifting/calgary-barbell-16-week-8-week-program-spreadsheets/), [FitnessVolt — Calgary Barbell 16-week structure](https://fitnessvolt.com/powerlifting/programs/calgary-barbell-16wk/)
- [Stronger by Science — Program Bundle](https://www.strongerbyscience.com/program-bundle/), [Lift Vault — SBS bundle TM auto-adjustment](https://liftvault.com/programs/strength/stronger-by-science-sbs-program-bundle-by-greg-nuckols/)
- [PowerliftingToWin — Sheiko #29–32 review](https://www.powerliftingtowin.com/sheiko/), [Type A Training — Sheiko guide](https://www.typeatraining.com/blog/sheiko-programs/)
- [JTS — periodization definitive guide](https://www.jtsstrength.com/periodization-powerlifting-definitive-guide/), [weak points: off the chest](https://www.jtsstrength.com/addressing-weak-points-off-the-chest-in-the-bench-press/), [bench lockout](https://www.jtsstrength.com/addressing-weak-points-lockout-in-the-bench-press/), [squat hole](https://www.jtsstrength.com/addressing-weak-points-in-the-hole-in-the-squat/), [deadlift lockout](https://www.jtsstrength.com/improving-deadlift-lockout/), [partial movements caveat](https://www.jtsstrength.com/partial-movements-for-raw-lifters/), [raw+equipped bench](https://www.jtsstrength.com/training-for-both-raw-and-equipped-bench-pressing/), [weight cutting guide](https://www.jtsstrength.com/complete-guide-to-cutting-weight-without-sacrificing-strength-2/)
- [JuggernautAI](https://www.juggernautai.app/), [JuggernautAI review (onboarding, readiness, weak points)](https://ai-fitness-engineer.com/juggernautai)
- [PRS — warm-up room strategy](https://prsontheplatform.com/2018/09/03/powerlifting-warm-up-room-strategy/), [EliteFTS — surviving the warm-up area](https://www.elitefts.com/education/how-to-survive-in-the-warm-up-area/), [PowerliftingTechnique — meet timing](https://powerliftingtechnique.com/how-long-are-powerlifting-meets/)
- [EliteFTS — meet manual with attempt formula](https://www.elitefts.com/education/powerlifting-meet-manual-with-formula-for-selecting-attempts/), [PowerliftingTechnique — attempt selection](https://powerliftingtechnique.com/how-to-pick-attempts-for-powerlifting/), [StrengthLog — attempt calculator](https://www.strengthlog.com/powerlifting-competition-attempt-calculator/)
- [Girls Gone Strong — first meet warm-up example](https://www.girlsgonestrong.com/blog/articles/preparing-for-your-first-powerlifting-meet-part-2/)
- [Coachway — warm-up set calculator conventions](https://coachway.io/tools/warm-up-set-calculator/), [Ironside — warm-up sets](https://www.ironsidetraining.com/blog/how-to-warm-up-for-your-working-sets/)
- [PowerliftingToWin — weight cutting (2-hr vs 24-hr weigh-ins)](https://www.powerliftingtowin.com/cutting-weight-for-powerlifting/), [PowerliftingTechnique — water cut mistakes](https://powerliftingtechnique.com/water-cut-for-powerlifting/)
- [Bonvec Strength — working around low back pain](https://bonvecstrength.com/2022/10/06/the-powerlifters-guide-to-working-around-lower-back-pain/), [Muscle & Strength — training with back injuries](https://www.muscleandstrength.com/articles/lifting-with-back-injuries)
- [EliteFTS — Big Air bracing cue](https://www.elitefts.com/education/big-squat-big-bench-big-deadlift-big-air/), [Legion — weightlifting cue list](https://legionathletics.com/weightlifting-cues/), [Deadlift cues](https://deadliftworkout.com/blog/deadlift-cues), [Ironside — bench leg drive](https://www.ironsidetraining.com/blog/optimizing-your-leg-drive-for-a-bigger-bench)
- [Iron Bull — raw vs equipped](https://ironbullstrength.com/blogs/powerlifting/raw-vs-equipped-powerlifting), [RitFit — monolift mechanism](https://www.ritfitsports.com/blogs/article/monolift)