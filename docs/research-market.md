# Powerlifting / Strength Coaching Software — Market Survey

Research date: August 2026. Scope: TrueCoach, TrainHeroic, RTS (E-Coach lineage / Generalized Intermediate Program / TRAC / RTS Lab), JuggernautAI, TeamBuildr, CoachRx, Everfit, and spreadsheet-based coaching (Calgary Barbell 16/8-week, TSA 9-week, general Google Sheets workflows). All findings from public web sources; source links at the end of each section and in the synthesis.

---

## Part 1 — Product-by-Product Survey

### 1. TrueCoach (by Xplor)

**Positioning:** The default "online personal trainer" platform; general fitness first, strength coaching second. Very large installed base (4.8/5 on Software Advice from 837 reviews).

**Core features**
- Program builder with a large stock exercise-video library plus custom video upload
- Client mobile app (free for clients), in-platform messaging, client video upload for form review
- Habit tracking, progress metrics, compliance dashboard
- Wearable/recovery data (heart rate, sleep, activity) on Standard/Pro tiers; MyFitnessPal integration with custom calorie/macro targets
- Stripe-based automated client billing

**How coaches build programs:** Day-by-day workout documents assembled from the exercise library; reusable templates; drag/copy workouts across a client calendar. Programming is fundamentally free-text-plus-exercise-rows — not a periodization engine.

**How clients receive/log:** Client opens the mobile app, sees today's workout, checks off sets, types results into result fields, can attach video; coach sees compliance and results in a dashboard and comments back.

**Pricing:** Per-coach, tiered by active client count: ~$30/mo (Starter, 5 clients), ~$70/mo (Standard, 20), ~$165/mo (Pro, 50); annual discounts; 14-day trial; 90-day money-back on annual. Free for clients.

**Praise:** Time saved on program creation; polished client app; communication loop (messaging + video feedback) is its strongest feature; video library.

**Complaints (highly relevant to powerlifting):**
- **No e1RM tracking** — repeatedly called out as disqualifying for barbell coaching; you cannot see fatigue/performance trends over time (Progressive Rehab & Strength explicitly names TrueCoach as failing this)
- Percentage/RPE prescriptions are second-class: results are semi-structured text, so aggregate analysis is weak
- Viewing metrics across clients requires drilling into each client's dashboard one at a time — time-consuming
- Unreliable saving while programming, clunky mobile editing, confusing exercise search, awkward copy/paste/move of workouts
- Payment-processing friction, video-upload failures, occasional app crashes

Sources: [GetApp](https://www.getapp.com/recreation-wellness-software/a/truecoach/), [Coachway review](https://coachway.io/articles/truecoach-review/), [QuickCoach pricing breakdown](https://www.quickcoach.fit/truecoach-pricing-2026.html), [PTPioneer review](https://ptpioneer.com/truecoach-review), [Software Advice](https://www.softwareadvice.com/fitness/truecoach-profile/), [Capterra reviews](https://www.capterra.com/p/155784/Fitbot/reviews/), [PR&S on e1RM tracking](https://www.progressiverehabandstrength.com/articles/calculating-and-tracking-rpe-e1rm-for-barbell-strength-training), [TrueCoach metrics blog](https://truecoach.co/blog/how-to-track-client-progress-online-with-truecoach-metrics/)

---

### 2. TrainHeroic

**Positioning:** The most strength-sport-native of the big SaaS platforms — "built by coaches who coach strength sports." Speaks percentages, RPE, competition cycles, meet prep.

**Core features**
- Program/session builder with circuits, supersets, EMOMs, percentage-based and RPE-based prescriptions, custom metrics
- Tracks training volume, RPE, and relative intensity across blocks; leaderboards for team culture
- Excellent stock exercise video library; clean athlete mobile app
- **Marketplace**: coaches sell templated programs/subscriptions ($15–40/mo per athlete, set by coach) — a genuine revenue stream
- Team dashboards: compliance, readiness, programming status

**How coaches build programs:** Structured session builder (blocks → exercises → sets×reps at %1RM or RPE); programs saved to a library, assignable to teams or individuals; marketplace programs are templated (not individualized).

**How clients receive/log:** Athlete app shows the day's session with prescribed loads auto-calculated from stored maxes; athletes log weights/reps/RPE; leaderboards and team feeds add gamification.

**Pricing:** Coach base $9.99/mo + $1 per attached athlete (coach bills clients directly), or bundled "Plus" tiers (~$30/5, $99/20, $199/50, $275+/100 athletes); marketplace takes $1/athlete + 2.9%.

**Praise:** Best-in-class strength programming vocabulary; percentage automation off stored maxes; team features; marketplace monetization; video library.

**Complaints:**
- Personal (non-marketplace) clients historically can't comment back-and-forth on workouts or send video for review in some configurations — communication is weaker than TrueCoach
- Pricing tier jumps ("by the 50s") punish mid-size rosters
- No nutrition, no branded app, no wearables, no before/after photos, thin client-record storage
- Endurance/hybrid support is poor (less relevant for pure powerlifting)

Sources: [TrainHeroic coach page](https://www.trainheroic.com/coach/), [FitBudd pricing analysis](https://www.fitbudd.com/post/how-much-does-trainheroic-costs), [Coachbox review](https://coachbox.app/en/compare/trainheroic-review/), [Coachbox TrueCoach-vs-TrainHeroic](https://coachbox.app/en/compare/truecoach-vs-trainheroic), [GetApp](https://www.getapp.com/recreation-wellness-software/a/trainheroic/), [Software Advice](https://www.softwareadvice.com/fitness/trainheroic-profile/), [Cora review](https://www.corahealth.app/compare/trainheroic)

---

### 3. RTS — Reactive Training Systems (E-Coach lineage, Generalized Intermediate Program, TRAC / RTS Lab)

**Positioning:** Not a SaaS competitor so much as the intellectual wellspring of modern autoregulated powerlifting (RPE, fatigue percents, Emerging Strategies). Mike Tuchscherer pioneered online powerlifting coaching; the old "E-Coach" style asynchronous coaching offering has evolved into RTS's current coaching + education + tools stack.

**Current ecosystem (per RTS store, 2026):**
- **All Access Coaching** — 1-on-1 human coaching, includes monthly tactics lessons and staff office hours
- **RTS Training Lab** — "Design. Deliver. Execute." — a suite for coaching yourself and other lifters (the descendant of TRAC, RTS's training log that computed e1RM and stress/fatigue analytics from logged RPE data)
- **Free training log** via the training dashboard
- **Emerging Strategies Classroom** — video course teaching the individualization framework (~$1,000; historically bundled 6 months of RTS Lab and a TRAC coaching feature)
- **Generalized Intermediate Program** — free 9-week spreadsheet: 4 days/wk tapering to 3, every slot prescribed as reps @ target RPE (no fixed percentages), load-drop/fatigue-percent volume regulation, peaks to heavy singles in week 9. PowerliftingToWin called RTS "the single best programmatic system in powerlifting" and praised that it "conforms to YOUR volume needs and not the other way around."

**How coaches build programs:** RTS is methodology-first — the tooling exists to serve RPE logging, e1RM trend analysis, and block-review ("Emerging Strategies" = run a block, measure the adaptation, adjust the next block). Program construction itself historically happened in spreadsheets/TRAC.

**How clients receive/log:** Via RTS dashboard/Lab or plain spreadsheets; the essential loop is: lifter logs load/reps/RPE → system computes e1RM per lift → coach reads the trend and adjusts.

**Pricing:** Coaching is premium human-coaching pricing; Classroom ~$1,000; GIP spreadsheet free; Lab subscription modest (bundled in education products).

**Praise:** Unmatched methodological credibility (100% expert endorsement per PowerliftingToWin); the autoregulation model that every serious tool now copies.

**Complaints:** Tooling is niche, dated, and small-team; e1RM-from-RPE analysis requires buy-in to the RPE system; steep learning curve; not a polished consumer product.

**Lesson for a new tool:** RTS defines the *data model* serious powerlifting software must support: per-set RPE, e1RM computed per lift per session, fatigue/stress trends, block-over-block adaptation review.

Sources: [RTS store](https://store.reactivetrainingsystems.com/), [RTS GIP article](https://store.reactivetrainingsystems.com/blogs/program-articles/the-rts-generalized-intermediate-program-by-mike-tuchscherer), [Lift Vault GIP page](https://liftvault.com/programs/powerlifting/rts-general-intermediate-program-spreadsheet/), [PowerliftingToWin GIP review](https://www.powerliftingtowin.com/rts-generalized-intermediate-program/), [PowerliftingToWin RTS review](https://www.powerliftingtowin.com/a-review-of-mike-tuchscherers-reactive-training-systems-rts/), [All Access Coaching](https://store.reactivetrainingsystems.com/products/all-access-coaching), [ES Classroom review](https://counsellingharbour.com/emerging-strategies-review/), [RTS ES podcast](https://reactivetrainingsystems.libsyn.com/how-to-start-programming-with-emerging-strategies)

---

### 4. JuggernautAI

**Positioning:** Not a coach's tool — a **coach replacement** for self-coached lifters. Chad Wesley Smith's methodology encoded as an algorithmic app. Important as the competitive benchmark for "what individualization without a human looks like."

**Core features / how it works**
- Onboarding builds a lifter profile; **individualized volume landmarks (MEV/MRV)** per muscle group
- **Daily readiness questionnaire** (soreness by muscle group, sleep, nutrition, stress) that modulates the day's session; low readiness → app recommends extra rest
- Per-set RPE/RIR feedback loop: every logged set adjusts subsequent sessions and future cycles
- Phasic periodization (hypertrophy → strength → peak) with meet-day targeting; user picks training days/week and the app optimizes SBD frequency
- Mid-program volume-profile recalculation without losing progress

**Client experience:** The lifter *is* the client; everything happens in the mobile app — prescriptions, logging, adjustment.

**Pricing:** $34.99/mo or ~$350/yr (discount codes common).

**Praise:** "Most sophisticated periodized powerlifting app available"; personalization and accountability at a fraction of human-coach cost; genuinely hard to replicate the programming quality elsewhere.

**Complaints:** Volume can swing "too little to way too much" with no human oversight to catch it; steep price for casual lifters; best only for intermediate/advanced 4+ day-per-week lifters; it's a black box — the lifter can't interrogate why.

**Lesson for a coach tool:** The readiness-check + per-set-RPE adjustment loop is the individualization bar; but the complaint pattern ("no human caught the bad volume call") is exactly the gap a solo coach with better tooling fills.

Sources: [How JuggernautAI works (JTS)](https://www.jtsstrength.com/how-juggernautai-works/), [Pricing](https://www.juggernautai.app/pricing), [PowerliftingTechnique review](https://powerliftingtechnique.com/juggernaut-ai-review/), [Dr. Muscle independent review](https://dr-muscle.com/juggernaut-workout-app-review/), [JustUseApp user reviews](https://justuseapp.com/en/app/1515756471/juggernautai/reviews), [AIToolsBakery review](https://aitoolsbakery.com/blog/juggernautai-review/)

---

### 5. TeamBuildr

**Positioning:** Team/institutional S&C — high schools, colleges, pro teams, tactical (military/first-responder). 5,500+ organizations. The wrong shape for a solo coach, but instructive on reporting and weight-room UX.

**Core features**
- Programming: percentage-based, **velocity-based (VBT)**, and custom periodized programs for individuals/teams/facilities
- 1,000+ exercise library with video, custom exercises, reusable templates
- **Weight Room View**: tablet-optimized shared-rack interface (racks of athletes log on one iPad)
- 16+ exportable reports: progress, wellness questionnaires, completion %, group comparisons; evaluations module; optional AMS (athlete-management) add-on ($50/mo)
- Free iOS/Android app for all athletes, no per-athlete fee; 24/7 human support

**How coaches build:** Calendar/block-based team programming with percentage auto-calculation from testing maxes; mass-assign to squads, individualize by exception.

**How athletes log:** Mobile app or shared tablet; coaches watch live boards and completion dashboards.

**Pricing:** $90/mo (up to 50 athletes) → $280/mo (up to 1,000); OS gym-management $200/mo.

**Praise:** Outstanding customer support (minutes-fast responses); saves coaches from Excel-transfer drudgery; athletes find the app easy.

**Complaints:** App instability (lost lifts, failed saves, frequent crashes in some reviews); overwhelming setup for new users; confusing superset navigation (click back-and-forth instead of scroll); "programming is very general"; interface not user-friendly.

Sources: [TeamBuildr features](https://www.teambuildr.com/features), [Pricing](https://www.teambuildr.com/pricing), [Strength platform page](https://www.teambuildr.com/platform-strength), [Science for Sport overview](https://www.scienceforsport.com/teambuildr-everything-you-need-to-know/), [JustUseApp reviews](https://justuseapp.com/en/app/1148960445/teambuildr/reviews), [Trustpilot](https://www.trustpilot.com/review/teambuildr.com), [PrepareLikeAPro coach's perspective](https://preparelikeapro.com/is-teambuildr-programming-software-good-a-coaches-perspective/)

---

### 6. CoachRx (OPEX)

**Positioning:** "Professional coaching operating system" built on OPEX methodology — program design + behavior/lifestyle coaching + business suite. Coach-centric; the closest of the SaaS crowd to a *program-design-first* tool.

**Core features**
- Program design: training splits, exercise video library, conditioning library, templates, drag-and-drop client calendar, copy/paste across weeks
- Assessments: intake forms, movement screens, body-composition tracking
- Principle-based programming suggestions drawn from 25 years of OPEX education; **RxBot** AI program-drafting assistant
- Business suite: storefronts, payments (2% processing), contracts, waivers, sales pages, payroll
- Programs feature for selling templated programs at scale

**How clients receive/log:** Client mobile app with daily calendar; logs results, videos, lifestyle/habit data; coach dashboard for review loops.

**Pricing:** By active clients, all features at every tier: $29/mo (1–5), $79/mo (6–50), $149/mo (51–150); 14-day full trial.

**Praise:** 4.9/5; clean, coach-first UX; "built by people who actually work with athletes"; assessment→program flow; fast support; constant feature updates.

**Complaints:** Data disappearing / saves failing / broken video links; no scheduling option; limited exercise options; can't swap or copy workout *segments*; no Apple Health sync; some coaches uneasy about the AI (RxBot) writing programs.

Sources: [CoachRx](https://www.coachrx.app/), [Pricing & plan comparison](https://intercom.help/coachrx/en/articles/14310925-coachrx-pricing-plans-feature-comparison), [Fees](https://intercom.help/coachrx/en/articles/6045483-fees), [OPEX blog](https://www.opexfit.com/blog/best-programming-platform-coachrx), [GetApp](https://www.getapp.com/recreation-wellness-software/a/coachrx/), [Capterra reviews](https://www.capterra.com/p/253158/CoachRx/reviews/), [G2 pros/cons](https://www.g2.com/products/coachrx/reviews?qs=pros-and-cons), [App Store reviews](https://apps.apple.com/us/app/coachrx-by-opex-fitness/id1544150077)

---

### 7. Everfit

**Positioning:** Modern general-fitness coaching platform; workout + habit + nutrition + automation; generous free tier; add-on-driven pricing.

**Core features**
- AI Workout Builder; exercise library; habit coaching; in-app messaging
- Meal plans/recipes (paid add-on), Autoflow automation (paid add-on), payments (add-on), custom branding / white-label
- Client management: onboarding, progress tracking, communication

**How coaches build:** Visual workout builder + AI assist; automation sequences (drip programs, auto check-ins) are the standout.

**How clients receive/log:** Polished client mobile app; logs workouts, habits, photos, food; wearable data.

**Pricing:** Free forever up to 5 clients; Pro scales by client count (~$77/mo at 50 clients); real all-in cost with add-ons ≈ $134/mo (Pro + meal plans $33 + Autoflow $24). Reviewers flag the add-on stack as a hidden-cost trap.

**Praise:** User-friendly; flexible; robust automation; responsive support; best free tier in the category.

**Complaints:** Free tier outgrown in weeks; premium pricing once add-ons stack; occasional bugs and sluggish mobile; meal-plan add-on too shallow for nutrition-led coaches. Nothing powerlifting-specific: no meet-prep, attempt-selection, or e1RM trend tooling.

Sources: [GetApp](https://www.getapp.com/recreation-wellness-software/a/everfit/), [Coachway review](https://coachway.io/articles/everfit-review/), [QuickCoach alternatives analysis](https://www.quickcoach.fit/everfit-alternatives-2026.html), [Software Advice](https://www.softwareadvice.com/club-management/everfit-profile/), [Capterra](https://capterra.com/p/202837/Everfit/), [Hidden-fees analysis](https://assistantcoach.fit/blog/hidden-fees-fitness-coaching-software/)

---

### 8. Spreadsheet-Based Coaching (Calgary Barbell 16/8-week, TSA 9-week, Google Sheets workflows)

**Why it persists:** Spreadsheets remain the *lingua franca* of powerlifting programming. Google Sheets is customizable, collaborative, near-free, and coach/athlete discussion happens inline in cells. Famous free templates keep the format alive:

- **Calgary Barbell 16-Week / 8-Week** (Bryce Krawczyk): 4 days/wk meet-prep progression; phases from volume (~weeks 1–4) through intensity (76–82% top sets), comp prep, and an RPE-based taper to openers. The "Revised" sheet lets the athlete **customize the %-at-RPE mapping per rep range** — user-tunable load tables inside a spreadsheet. ([Lift Vault](https://liftvault.com/programs/powerlifting/calgary-barbell-16-week-8-week-program-spreadsheets/), [FitnessVolt review](https://fitnessvolt.com/powerlifting/programs/calgary-barbell-16wk/), [FitFrek](https://fitfrek.com/calgary-barbell-program/))
- **TSA 9-Week Intermediate** (Bryce Lewis / Hani Jazayrli): 4 days/wk, volume→intensity→peak into a mock meet; mixed reviews note real PRs but thin accessory coverage and heavy mid-cycle fatigue. ([Lift Vault](https://liftvault.com/programs/powerlifting/tsa-9-week-intermediate-program/), [Boostcamp reviews](https://www.boostcamp.app/bryce-lewis/tsa-9-week-intermediate-approach/reviews))
- Note the migration path: **Boostcamp** now ships free app versions of these exact spreadsheets with auto-calculated loads — evidence that "spreadsheet programs, app delivery" is a proven demand.

**The real solo-coach workflow (the competitor to beat):** Excel/Sheets distributed via Drive for programming; WhatsApp/Instagram DM for communication; video review of SBD lifts via shared links; Google Forms for intake; MyFitnessPal for food; Stripe/invoices for money. A weekly check-in is "the heartbeat of online coaching." This stitched stack **stops scaling somewhere between 10 and 25 clients**, when copying numbers between five tools and chasing check-ins across three inboxes becomes the job. ([Coachway check-in guide](https://coachway.io/articles/check-in-software-for-online-coaches/), [Coachway software survey](https://coachway.io/articles/what-software-do-online-fitness-coaches-use/), [AssistantCoach on the 20-client wall](https://assistantcoach.fit/blog/whatsapp-google-sheets-fitness-coaching/), [Volition Fitness example workflow](https://volitionfit.com/online-personal-training-coaching), [HubFit check-in guide](https://hubfit.com/blog/the-ultimate-guide-to-online-coaching-check-ins))

**Strengths of sheets:** total programming freedom (any set scheme, any formula, e1RM columns, tonnage charts); zero cost; the coach owns the data; every powerlifter already understands them.
**Weaknesses:** no mobile logging UX (typing into cells in a gym is miserable); no notifications/compliance visibility; formulas break when clients edit; no video-review loop; no cross-client dashboard; versioning chaos; manual copy-forward every block.

---

## Part 2 — Synthesis

### (1) Table-stakes features a professional tool MUST have

Anything missing from this list gets a tool dismissed as amateur by working coaches:

1. **Program builder with reusable structure** — exercises → sets×reps×load prescription; templates; copy/paste weeks and blocks; drag-and-drop calendar. (Every platform has this; TrueCoach/CoachRx complaints show even incumbents get copy/paste wrong.)
2. **Both %1RM and RPE prescription, natively** — auto-calculated target loads from stored maxes, RPE targets with rep ranges, ability to mix both in one session (TrainHeroic's core advantage; the Calgary Barbell sheet's %-at-RPE table is the folk version).
3. **Set-by-set result logging** — weight × reps × RPE per set, not a free-text results box. This is the data-model divide between general-fitness tools and strength tools.
4. **e1RM computation and trending per lift** — the single most-cited disqualifier for TrueCoach in powerlifting circles; RTS made it the backbone of the methodology.
5. **Exercise library with video** — stock demos plus custom-video upload (every incumbent has one; coaches expect it).
6. **Client video upload + coach feedback loop** — technique review on squat/bench/deadlift is non-negotiable in powerlifting coaching; TrainHeroic's weakness here is its loudest complaint.
7. **Coach↔client messaging tied to workouts** — comments on the session/set, not a separate inbox.
8. **Compliance visibility** — who trained, who didn't, who's behind, at a glance across the roster.
9. **History that never loses data** — "data disappears / saves fail / app crashes" is the #1 complaint category across TrueCoach, TeamBuildr, and CoachRx. Reliability is itself a feature gap in this market.
10. **Templates → individualization** — start from a template (16-week peak, 9-week prep), then customize per lifter without breaking the template.

### (2) Differentiators observed in the market

- **Strength-native periodization vocabulary** (TrainHeroic): blocks, meet timelines, relative-intensity tracking.
- **Autoregulation analytics** (RTS): fatigue percents, RPE-driven load drops, block-over-block adaptation review (Emerging Strategies).
- **Algorithmic individualization** (JuggernautAI): readiness questionnaires modulating the day's work; MEV/MRV volume landmarks; per-set RPE feedback rewriting future weeks.
- **Marketplace / program sales** (TrainHeroic, CoachRx Programs): templated-program revenue.
- **Team/facility UX** (TeamBuildr): tablet weight-room view, group reports, VBT.
- **Business-in-a-box** (CoachRx, Everfit, TrueCoach): payments, contracts, storefronts, automation, white-label branding.
- **AI program drafting** (CoachRx RxBot, Everfit AI Builder) — noting real coach skepticism about AI-written programs.
- **Assessment-driven onboarding** (CoachRx): intake → movement screen → program logic.
- **Meet-prep specificity** (spreadsheet culture, JuggernautAI): tapers, openers/attempt selection, mock meets — *almost entirely absent from the SaaS platforms*, which is striking.

### (3) What a native Mac desktop app for a SOLO powerlifting coach could do better

The incumbents are web/mobile SaaS optimized for either general fitness (TrueCoach, Everfit, CoachRx) or teams (TeamBuildr, TrainHeroic). A native Mac app can win on:

1. **Programming as a power-user activity.** Coaches *write* programs at a desk, in bulk, for hours — the exact workflow where web builders are slowest (TrueCoach's "unreliable saving, clunky editing"; TeamBuildr's "overwhelming" setup). A native app can offer spreadsheet-grade editing — keyboard-first grid entry, multi-select, fill-down, copy structures across weeks/lifters, undo that always works — with a real periodization data model underneath. Beat Google Sheets at its own game instead of replacing it with forms.
2. **Local-first reliability and ownership.** The #1 complaint class across incumbents is lost data and failed saves. Local storage (SQLite/Core Data) with instant saves, full offline operation, Time Machine backups, and export-anytime directly answers it — and the coach owns their client data instead of renting access at $70–165/mo forever.
3. **Powerlifting-native math as a first-class citizen.** e1RM per lift per session, RPE→% tables (coach-tunable, like the Calgary Barbell revised sheet), tonnage/relative-intensity/stress trends, block-over-block comparison, fatigue detection — the RTS analytical layer that no polished commercial product ships. This is the single clearest open lane.
4. **Meet-prep tooling nobody has.** Meet-date-anchored program timelines, taper templates, attempt-selection calculators (opener/second/third from recent e1RMs), weight-class/gameday planning, meet-day cards. Spreadsheets do this by hand; SaaS does it not at all.
5. **Cross-client command center.** TrueCoach makes coaches click into each client one at a time. A desktop app has screen real estate for a true multi-client dashboard: who logged, whose e1RM is trending down, who's 3 weeks from a meet, whose check-in is overdue — one glance.
6. **Fast local video review.** Native AVFoundation playback: frame-step, slow-motion, side-by-side comparison (this week's squat vs. last month's), drawing/annotation, no upload-transcode-buffer cycle. Web video review is universally mediocre.
7. **One-time or modest pricing.** Solo coaches pay $360–2,000/yr for SaaS whose per-client tiering punishes growth (TrainHeroic's "jumps by the 50s"; Everfit's add-on stack). A paid-once Mac app (or cheap subscription) with unlimited clients is a genuinely disruptive price story for a 10–30-client solo coach.
8. **Flexible delivery, not a captive client app.** The client side can stay simple: export beautiful weekly PDFs, shared sheets, or a lightweight companion/web view — meeting clients in the WhatsApp-and-Sheets workflow they already have rather than forcing a proprietary app adoption hurdle (the stitched stack is the real incumbent).
9. **macOS platform leverage.** Spotlight-style quick-open of any lifter, Shortcuts automation, drag-and-drop video ingestion from AirDrop/Photos, menu-bar check-in reminders, local notifications, widgets showing today's roster.
10. **Privacy as a selling point.** Client health data stays on the coach's machine — no cloud vendor, no breach surface, no terms-of-service changes.

### (4) Features IRRELEVANT for a solo-coach desktop tool (explicitly out of scope)

- **Payments/billing infrastructure** (Stripe rails, invoicing, payroll, disputes, processing fees) — a solo coach with 10–30 clients uses Stripe/PayPal/e-transfer directly; CoachRx's 2% cut and TrueCoach's billing complaints show this is a liability, not a draw.
- **Program marketplaces** (TrainHeroic's store, CoachRx storefronts) — templated-program retail is a different business than 1:1 coaching.
- **Team/facility features** — weight-room tablet view, squad leaderboards, group assignment, org hierarchies, AMS modules (TeamBuildr's whole value prop).
- **White-label/branded client apps** (Everfit) — solo coaches sell *themselves*, not an app brand.
- **Marketing automation / funnels / sales pages / lead capture** — CRM-adjacent bloat.
- **Contracts, waivers, e-signature** — DocuSign/PDF handles the once-per-client event.
- **Nutrition/meal-plan builders** — powerlifting coaches at most set macro targets; full meal planning (Everfit's shallow $33/mo add-on) is a separate profession's tool.
- **Wearable/recovery integrations** (WHOOP, sleep, HR) — nice-to-have at best; powerlifting readiness is captured better by bar speed, RPE, and a 4-question check-in than by wrist telemetry.
- **AI program generation** — the JuggernautAI complaint pattern (unchecked volume swings) and CoachRx RxBot skepticism both say coaches want *decision support* (trends, flags, suggestions), not ghost-written programs.
- **Habit/lifestyle coaching modules, before/after photo galleries, class scheduling, gym-management OS** — general-fitness and facility concerns, not barbell coaching.

### Bottom line

The market splits into general-fitness client-management SaaS (TrueCoach, Everfit, CoachRx), team platforms (TeamBuildr, TrainHeroic), a self-coaching algorithm (JuggernautAI), and a methodology ecosystem with weak tooling (RTS) — while the actual solo powerlifting coach still lives in Google Sheets + WhatsApp because nothing else matches spreadsheet programming freedom. The open position is precisely: **spreadsheet-grade programming speed + RTS-grade RPE/e1RM analytics + meet-prep tooling + local-first reliability, on the desktop where coaches actually write programs** — skipping billing, marketplaces, teams, and nutrition entirely.

## Sources (consolidated)

- TrueCoach: [GetApp](https://www.getapp.com/recreation-wellness-software/a/truecoach/) · [Coachway](https://coachway.io/articles/truecoach-review/) · [QuickCoach pricing](https://www.quickcoach.fit/truecoach-pricing-2026.html) · [PTPioneer](https://ptpioneer.com/truecoach-review) · [Software Advice](https://www.softwareadvice.com/fitness/truecoach-profile/) · [Capterra](https://www.capterra.com/p/155784/Fitbot/reviews/) · [TrueCoach metrics](https://truecoach.co/blog/how-to-track-client-progress-online-with-truecoach-metrics/)
- TrainHeroic: [Coach page](https://www.trainheroic.com/coach/) · [FitBudd pricing](https://www.fitbudd.com/post/how-much-does-trainheroic-costs) · [Coachbox review](https://coachbox.app/en/compare/trainheroic-review/) · [Coachbox comparison](https://coachbox.app/en/compare/truecoach-vs-trainheroic) · [GetApp](https://www.getapp.com/recreation-wellness-software/a/trainheroic/) · [Cora](https://www.corahealth.app/compare/trainheroic)
- RTS: [Store](https://store.reactivetrainingsystems.com/) · [GIP article](https://store.reactivetrainingsystems.com/blogs/program-articles/the-rts-generalized-intermediate-program-by-mike-tuchscherer) · [Lift Vault](https://liftvault.com/programs/powerlifting/rts-general-intermediate-program-spreadsheet/) · [PowerliftingToWin GIP](https://www.powerliftingtowin.com/rts-generalized-intermediate-program/) · [PowerliftingToWin RTS](https://www.powerliftingtowin.com/a-review-of-mike-tuchscherers-reactive-training-systems-rts/) · [All Access Coaching](https://store.reactivetrainingsystems.com/products/all-access-coaching)
- JuggernautAI: [How it works](https://www.jtsstrength.com/how-juggernautai-works/) · [Pricing](https://www.juggernautai.app/pricing) · [PowerliftingTechnique](https://powerliftingtechnique.com/juggernaut-ai-review/) · [Dr. Muscle](https://dr-muscle.com/juggernaut-workout-app-review/) · [JustUseApp](https://justuseapp.com/en/app/1515756471/juggernautai/reviews)
- TeamBuildr: [Features](https://www.teambuildr.com/features) · [Pricing](https://www.teambuildr.com/pricing) · [Science for Sport](https://www.scienceforsport.com/teambuildr-everything-you-need-to-know/) · [Trustpilot](https://www.trustpilot.com/review/teambuildr.com) · [JustUseApp](https://justuseapp.com/en/app/1148960445/teambuildr/reviews) · [PrepareLikeAPro](https://preparelikeapro.com/is-teambuildr-programming-software-good-a-coaches-perspective/)
- CoachRx: [Site](https://www.coachrx.app/) · [Pricing help doc](https://intercom.help/coachrx/en/articles/14310925-coachrx-pricing-plans-feature-comparison) · [Fees](https://intercom.help/coachrx/en/articles/6045483-fees) · [Capterra](https://www.capterra.com/p/253158/CoachRx/reviews/) · [G2](https://www.g2.com/products/coachrx/reviews?qs=pros-and-cons) · [App Store](https://apps.apple.com/us/app/coachrx-by-opex-fitness/id1544150077)
- Everfit: [GetApp](https://www.getapp.com/recreation-wellness-software/a/everfit/) · [Coachway](https://coachway.io/articles/everfit-review/) · [QuickCoach](https://www.quickcoach.fit/everfit-alternatives-2026.html) · [Hidden fees](https://assistantcoach.fit/blog/hidden-fees-fitness-coaching-software/)
- Spreadsheets & workflows: [Calgary Barbell — Lift Vault](https://liftvault.com/programs/powerlifting/calgary-barbell-16-week-8-week-program-spreadsheets/) · [FitnessVolt](https://fitnessvolt.com/powerlifting/programs/calgary-barbell-16wk/) · [FitFrek](https://fitfrek.com/calgary-barbell-program/) · [TSA — Lift Vault](https://liftvault.com/programs/powerlifting/tsa-9-week-intermediate-program/) · [Boostcamp TSA reviews](https://www.boostcamp.app/bryce-lewis/tsa-9-week-intermediate-approach/reviews) · [e1RM tracking — PR&S](https://www.progressiverehabandstrength.com/articles/calculating-and-tracking-rpe-e1rm-for-barbell-strength-training) · [Check-in software guide](https://coachway.io/articles/check-in-software-for-online-coaches/) · [The 20-client wall](https://assistantcoach.fit/blog/whatsapp-google-sheets-fitness-coaching/) · [Volition workflow](https://volitionfit.com/online-personal-training-coaching) · [HubFit check-ins](https://hubfit.com/blog/the-ultimate-guide-to-online-coaching-check-ins)