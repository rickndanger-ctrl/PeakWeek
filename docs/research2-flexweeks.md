# Coaching-Ops Research: Flexible Training Weeks & Peak-Day Placement

Research for PeakWeek (macOS coaching app, `/Users/richardholguin/dev/powerlifting-trainer`). Grounded in `docs/product-spec.md`, `docs/research-practice.md` (both read in full), plus web research. The trusted engine (block allocation, 91/97/101.5 attempts, last-heavy-DL 10–14 d, openers 7–10 d) is treated as frozen; everything below is scheduling semantics layered around it.

---

## 1. Flexible training weeks (day-one anchoring)

### 1.1 What real coaches actually do

- **The training week is the athlete's week, not the calendar week.** The universal unit of coaching work is the microcycle reviewed weekly against the block and the meet date (`research-practice.md` §0). Coaches talk in "weeks out," never in ISO calendar weeks. A lifter who starts Wednesday simply trains a Wed→Tue week; nothing in coaching practice snaps to Monday.
- **Microcycles are not even required to be 7 days.** PowerliftingToWin notes a week is "an arbitrary measure of time chosen for social convenience" — adaptive cycles can be 5, 7, 9, or 14 days ([PowerliftingToWin](https://www.powerliftingtowin.com/powerlifting-training-organization/), [EliteFTS non-traditional microcycles](https://elitefts.com/blogs/motivation/non-traditional-microcycles-in-a-powerlifting-program)). PeakWeek's engine is 7-day-weekly, which is fine — but this is strong evidence that **day-one anchoring (not calendar snapping) is the correct primitive**, since coaches already treat the week boundary as arbitrary.
- **Incumbent software confirms it.** TrueCoach assigns a program to a client "at any time, starting them at any point," including choosing which *day of the program* they start on; clients can shift individual workouts to any date (coach-approved) ([TrueCoach Programs help](https://help.truecoach.co/en/articles/3047401-programs), [client schedule changes](https://help.truecoach.co/en/articles/9099548-client-changing-my-workout-schedule)). Delivery cadence follows the assignment date, not Monday.
- **Partial first weeks:** the common coach move when someone starts mid-cycle is either (a) start day 1 on the start date (full week, shifted anchor — the norm), or (b) run a short "week 0" of just the remaining sessions, then start week 1 on the next anchor. (b) is used when the coach wants everyone on a squad rhythm; a solo coach with per-client delivery (PeakWeek's model) has no reason to prefer it.
- **Check-in timing follows the athlete's week.** The canonical review loop is "Sunday night" only because most athletes' weeks end Sunday (`research-practice.md` §1.2). For a Wed-anchored athlete, review lands Tuesday night and next week's plan goes out before Wednesday. The rule coaches actually follow: **review at the end of the athlete's week; deliver before the athlete's next day-1.**

### 1.2 Recommended exact semantics for PeakWeek

**Adopt strict day-one anchoring. No partial weeks. No calendar snapping.**

1. **`programDayOne`** = any coach-chosen calendar date (default: today, or `meetDate − 7×totalWeeks + 1` when meet-anchored — see §2.3). Store as a pure calendar date (year-month-day, no time-of-day), interpreted in a stored named timezone (e.g. `America/Los_Angeles`), never as a raw epoch instant.
2. **Week N (1-based) = the half-open day interval `[dayOne + 7(N−1), dayOne + 7N)`** — i.e. days `7(N−1)` through `7N − 1` inclusive, counted in *calendar days*. Every date maps to exactly one week; week boundaries fall on the same weekday as `dayOne` forever. Properties to unit-test:
   - `weekIndex(d) = floor(daysBetween(dayOne, d) / 7) + 1` for `d ≥ dayOne` (calendar-day difference, not seconds/86400).
   - `weekStart(N) = dayOne + 7(N−1)` days; `weekEnd(N) = weekStart(N+1)` (exclusive).
   - Total program span = exactly `7 × totalWeeks` days; last program day = `dayOne + 7×totalWeeks − 1`.
3. **The athlete's "weekday slots"**: day template position `k` (0…6, or the 4/5 training days within it) maps to date `weekStart(N) + k`. A Wed-anchored 4-day athlete trains Wed/Thu/Sat/Sun (or wherever the template's rest days land) — the template is positional within the athlete week, never tied to Mon–Sun names. Display both: "Week 3 · Day 2" and the concrete date.
4. **Weekly send moment** (per client): `sendAt(N) = weekStart(N) − sendLeadDays` at `sendTimeOfDay`, where defaults are `sendLeadDays = 1`, `sendTimeOfDay = 18:00` local — i.e. the plan for the athlete's week arrives the evening before their day 1. Both knobs coach-configurable per client (some coaches send morning-of: `leadDays = 0`, `time = 06:00`). Check-in review reminder (if ever built) = `weekEnd(N) − 1` evening. This makes delivery *rotate with the anchor automatically* — the Wed-anchored client gets Tuesday-evening sends, the Monday client Sunday-evening sends, with zero special-casing.
5. **Mid-week program start** (coach signs a client today, wants them lifting today): set `dayOne = today`. Week 1 is a full 7-day week ending next Tuesday if today is Wednesday. Week 1's send fires immediately if `sendAt(1)` is already past (see catch-up rules, §3).
6. **Re-anchoring** (client wants to shift from Wed-weeks to Mon-weeks mid-program): model as `dayOne += δ` where δ ∈ (−6…+6), applied *forward only* — past weeks keep their historical dates in the delivery ledger; future `weekStart`s recompute. Warn the coach that one week becomes long or short in lived time (the athlete gets an extra rest day or loses one); coaches handle this by inserting rest days, never by cutting sessions, so prefer positive δ (push later) in the UI hint.

### 1.3 Pitfalls (all avoidable with calendar-day arithmetic)

| Pitfall | Failure mode | Rule |
|---|---|---|
| **DST spring-forward/fall-back** | `dayOne + N×7×86400` seconds drifts by ±1 h across a DST change; after fall-back a date computed at 00:30 can land on the *previous* day; a send scheduled 02:30 never fires on spring-forward night, or fires twice at 01:30 on fall-back ([Cronjob.live DST pitfalls](https://cronjob.live/docs/dst-pitfalls), [Red Hat](https://access.redhat.com/solutions/477963)) | All week math in `Calendar.date(byAdding: .day, value: 7, to:)` / `dateComponents([.day], from:to:)` — never seconds. Sends resolve "date + local time-of-day" via `Calendar` at fire time; default send times outside 01:00–03:00 (18:00 default is safe). If a send time is skipped by DST, fire at the next valid instant; if repeated, dedupe (§3). |
| **Month/year boundaries** | Hand-rolled "day of month + 7" wraps wrong on 28/29/30/31-day months and Dec→Jan | Never touch month components; day-interval arithmetic through `Calendar` handles months, leap days, and year ends for free. Unit-test weeks spanning Feb 28–Mar 1 (leap and non-leap) and Dec 29–Jan 4. |
| **Timezone of the date** | Storing `dayOne` as midnight-UTC epoch shows the wrong date for US timezones (classic off-by-one) | Persist `DateComponents`-style y/m/d (or ISO `yyyy-MM-dd` string) + named tz. Render and compute in that tz. If the coach travels, dates don't move. |
| **"Week N" vs ISO week numbers** | Any use of `Calendar.weekOfYear` breaks for non-Monday anchors and at year boundaries | Week N is *only* ever `floor(days/7)+1` from `dayOne`. Never use `weekOfYear`/`yearForWeekOfYear`. |
| **`weeksOut` inconsistency** | Two formulas ("weeks between today and meet" vs "totalWeeks − N") disagree for mid-week meets | Define once: `weeksOut(N) = totalWeeks − N` (label of the week), and `daysOut(d) = daysBetween(d, meetDate)` for event placement. Never mix. |

---

## 2. Peak-day placement (meet on any weekday)

### 2.1 What coaches do when the meet isn't Saturday

The unanimous rule: **spacing is measured in days-before-meet, not weekday names — slide the whole final sequence to preserve days-out.** Bonvec states it directly: if the meet isn't Saturday, "adjust your timeline accordingly so the spacing to competition day is the same" ([Bonvec Strength taper](https://bonvecstrength.com/2023/04/26/how-long-should-you-taper-before-your-powerlifting-meet/); same logic in [Stronger by Science taper](https://www.strongerbyscience.com/taper-for-powerlifting/), [All About Powerlifting](https://allaboutpowerlifting.com/how-to-properly-taper-for-a-powerlifting-competition/), [Catalyst Athletics](https://www.catalystathletics.com/article/2236/Tapering-for-Olympic-Weightlifting-Competition/)). Days-out targets consistent with the engine and `product-spec.md` §A3:

- Last heavy **DL 10–14 d** out (engine default, keep), **SQ 7–10 d**, **BP 4–7 d**.
- **Opener-confirmation singles** (90–92.5%) 7–10 d out — the engine's existing "openers" event.
- **Meet-week primer singles** (70–80% SQ/BP, 70–75% DL) 4–6 d out.
- **Training cessation**: last session ~2–4 d before the meet ([EliteFTS taper](https://elitefts.com/blogs/powerlifting/tapering-for-a-powerlifting-meet), cessation research in spec §A3: DL ~6 d / SQ ~4 d / BP ~4 d, warn > 7 d).
- Day before the meet: full rest (or travel/weigh-in per federation).

So a **Monday meet** vs a **Saturday meet** with the same 7–10 d opener rule: Saturday meet → openers previous Sat–Tue; Monday meet → openers previous Mon–Thu. The final training day moves from Wed/Thu (Sat meet) to Fri/Sat (Mon meet). Weekday-name templates ("openers on Tuesday") are always wrong; **days-out templates are always right.**

### 2.2 Practical implications for the engine

- **Meet week is defined backward from the meet: `meetWeek = [meetDate − 6, meetDate]`** — the 7 days *ending on* meet day, regardless of where the athlete's week anchor falls. All meet-week content (primers, rest day, travel/weigh-in day, meet day) is placed by days-out offsets from `meetDate`.
- The existing meet-week template (60/55% work) should be expressed as offsets: e.g. primers at `meetDate − 5…−4`, last light touch at `meetDate − 3`, rest `−2…−1`, meet at `0`. Then any weekday meet is automatically correct.
- Realization-week events (last heavy DL, openers) are *already* days-out ranges in the engine — keep resolving them against `meetDate`, and clamp them onto that athlete's actual training days (nearest training day within the range; prefer the later end for BP, earlier end for DL per spec helper text).

### 2.3 When the meet date isn't the end of week N (mid-week meet vs the athlete's anchor)

This is the real design decision. Given day-one anchoring, `meetDate` generally does **not** equal `dayOne + 7×totalWeeks − 1`. Three strategies exist in practice; recommend in this order:

**Strategy A — meet-anchored programs (recommended default when `meetDate` is set):**
Derive `dayOne = meetDate − 7×totalWeeks + 1`. Meet day is then *exactly* the last day of week `totalWeeks`, every week ends on the meet's weekday, and all days-out math is congruent with week numbers (`weeksOut = totalWeeks − N` is exact). A Wednesday meet yields Thu→Wed athlete weeks throughout the prep. This is what coaches mean by "plan backward from the meet" (`research-practice.md` §0, §3.5: "block templates snap backward from meet dates"). It's also the cleanest with the frozen engine: no week is irregular.

**Strategy B — start-anchored with a bridge segment (when the coach fixes `dayOne` first, or the client already has an anchor):**
Let `gap = daysBetween(dayOne + 7×(totalWeeks−1) − 1, meetDate)` … more simply: compute `totalDays = daysBetween(dayOne, meetDate) + 1`; `fullWeeks = floor(totalDays / 7)`; `rem = totalDays mod 7`.
- If `rem == 0`: pure Strategy A alignment, done.
- If `rem ∈ {1, 2, 3}`: **absorb into an extended meet week** of `7 + rem` days (8–10 days). The extra days go in *before* the taper events as light technique/rest — never after, and never compress the days-out targets. Structurally: weeks 1…`fullWeeks − 1` normal, final segment = last 7+rem days planned backward from `meetDate` by days-out.
- If `rem ∈ {4, 5, 6}`: **insert a short bridge week** (a partial week of `rem` days) at the *start* of the prep (before week 1), containing ramp-in/technique work — coaches lengthen the low-stakes end (accumulation) and never distort the taper. Weeks then renumber so the final week still ends on meet day.
- Either way, the invariant is: **the last `~14` days are always laid out backward from `meetDate` by days-out; any slack is pushed to the front of the program.**

**Strategy C — truncated final week (avoid; offer only as explicit coach override):** meet lands mid-week-N and week N is simply cut short after meet day. This silently deletes taper days and is how spreadsheet preps go wrong. If a coach forces it (e.g. late meet-date change with no room), warn when any last-heavy/opener event's days-out window can no longer be satisfied.

**Meet-date changes mid-prep:** recompute with the same strategy; diff old vs new event dates; mark already-sent weeks whose content changed as stale ("resend?"), never auto-resend (matches the spec's "Settings changed — Regenerate to apply" banner pattern, `product-spec.md` §D3).

**Two meets / qualifier en route (P2 in spec):** each meet anchors its own backward-planned segment; the bridge block between them is start-anchored off the day after meet 1 ([JTS periodization](https://www.jtsstrength.com/periodization-powerlifting-definitive-guide/), spec §3.5).

---

## 3. Scheduling-engine sanity checklist (ops)

Exactly-once delivery is not achievable; build **at-least-once firing + idempotent effects** ([JobRunr on idempotence](https://www.jobrunr.io/en/blog/idempotence-in-java-job-scheduling/), [distributed scheduler design](https://www.systemdesignhandbook.com/guides/design-a-distributed-job-scheduler/)). For a macOS app that sleeps, quits, and changes timezones, this matters more, not less.

**Idempotent sends**
- [ ] Every delivery has a **dedupe key**: `(clientID, programGenerationID, weekN)` — where `programGenerationID` is a UUID minted on every regenerate. A send only fires if no ledger entry exists for that key.
- [ ] **Delivery ledger** is written *before* invoking the share/send bridge (intent recorded), then marked `sent`/`failed` after — write-ahead pattern so a crash mid-send can't double-fire silently and can't lose the fact that a send was attempted ([idempotency via WAL + key](https://qasimalbaqali.medium.com/achieving-idempotency-in-the-aws-serverless-space-d0671a521479)).
- [ ] Firing logic is **"should week N be sent now?" evaluated against state**, not "a timer fired" — i.e. reconciliation, not event-driven. A tick asks: for each client, what is the highest N with `sendAt(N) ≤ now` and no ledger entry? Timers merely cause ticks.

**Catch-up policy (Mac was asleep / app not running)**
- [ ] On launch/wake, run the reconciliation pass. **If multiple weeks are overdue, send only the current week** (the one whose interval contains today) — never burst-send weeks 3, 4, 5 at once; mark skipped weeks `superseded` in the ledger. This mirrors scheduler "catch-up vs skip" policy decisions ([Educative scheduler design](https://www.educative.io/blog/distributed-job-scheduler-system-design)) and matches coaching reality: the athlete needs *this* week, and old plans arriving late erode trust.
- [ ] A send more than `X` hours late (default 24 h past `weekStart`) surfaces to the coach for confirmation instead of auto-firing — mid-prep silence usually means something changed.
- [ ] Ledger entries carry the *dates as delivered* (frozen snapshot of weekStart/weekEnd/daysOut text), so later re-anchoring can't retroactively falsify what was sent.

**Renumbering / regeneration safety**
- [ ] Regenerate → new `programGenerationID`; ledger rows from prior generations remain but are matched to new weeks **by week number** for "already sent?" display (consistent with spec §C2.6 log carry-forward by `num`).
- [ ] Deload insertion/removal or phase-length edits that shift week numbers must show a "weeks renumbered; weeks 4+ differ from what was sent" diff; never silently re-send, never let the dedupe key accidentally block a legitimately changed week (generation ID in the key handles this).
- [ ] `dayOne` or `meetDate` edits: recompute all `sendAt(N)`; already-`sent` weeks keep frozen dates; pending sends move.

**Time correctness**
- [ ] All week math is calendar-day based (see §1.3); assert `weekStart(N+1) − weekStart(N) == 7 days` across DST transitions in tests (US Mar/Nov dates).
- [ ] Send scheduling resolves date + local time at arm time *and re-validates at fire time* (system clock changes, tz changes while asleep). Skipped DST hour → fire at next valid instant; repeated hour → dedupe key absorbs the double-fire ([Cronjob.live](https://cronjob.live/docs/dst-pitfalls)).
- [ ] Manual clock set-backs can't re-fire sends (ledger check is by key, not by time).
- [ ] Client timezone stored per client if remote clients differ from coach; default = coach tz.

**General ops**
- [ ] Failure handling: a failed send (share bridge error) retries with backoff a bounded number of times then parks as `failed` needing coach attention — a dead-letter state, not an infinite retry loop ([scheduler pattern guide](https://developersvoice.com/blog/behavioral-design-patterns/design-pattern-scheduler/)).
- [ ] Everything visible: a per-client delivery history (week, generation, timestamp, status) — the audit log *is* the coach UI for "did Sarah get week 6?".
- [ ] Golden tests: (a) Wed `dayOne`, 12-week prep, Saturday meet via Strategy A → assert every event's days-out; (b) same but Monday meet; (c) `rem=2` and `rem=5` bridge cases; (d) sleep-over-two-send-times catch-up sends exactly one message.

---

## Bottom line

1. **Day-one anchoring, half-open 7-day intervals, calendar-day arithmetic, per-client send moment = `weekStart(N) − 1 day @ 18:00` local (configurable).** No partial first weeks; the athlete's week is whatever 7-day window starts on their day 1.
2. **When a meet date exists, anchor backward from it** so meet day is the final day of the final week; when `dayOne` is fixed and doesn't divide evenly, push slack to the *front* (bridge days) and always lay out the last ~14 days by days-out from the meet. Never truncate the taper.
3. **At-least-once + ledger-keyed idempotent sends, current-week-only catch-up, generation-ID-scoped dedupe, and frozen-snapshot ledger rows** cover the ops failure modes for a sleep-prone desktop app.

Sources: [Bonvec — taper length](https://bonvecstrength.com/2023/04/26/how-long-should-you-taper-before-your-powerlifting-meet/) · [Stronger by Science — taper](https://www.strongerbyscience.com/taper-for-powerlifting/) · [All About Powerlifting — taper](https://allaboutpowerlifting.com/how-to-properly-taper-for-a-powerlifting-competition/) · [Catalyst Athletics — competition taper](https://www.catalystathletics.com/article/2236/Tapering-for-Olympic-Weightlifting-Competition/) · [EliteFTS — tapering](https://elitefts.com/blogs/powerlifting/tapering-for-a-powerlifting-meet) · [EliteFTS — non-traditional microcycles](https://elitefts.com/blogs/motivation/non-traditional-microcycles-in-a-powerlifting-program) · [PowerliftingToWin — training organization](https://www.powerliftingtowin.com/powerlifting-training-organization/) · [TrueCoach — Programs](https://help.truecoach.co/en/articles/3047401-programs) · [TrueCoach — client schedule changes](https://help.truecoach.co/en/articles/9099548-client-changing-my-workout-schedule) · [JTS — periodization guide](https://www.jtsstrength.com/periodization-powerlifting-definitive-guide/) · [Cronjob.live — DST pitfalls](https://cronjob.live/docs/dst-pitfalls) · [Red Hat — cron and DST](https://access.redhat.com/solutions/477963) · [JobRunr — idempotence](https://www.jobrunr.io/en/blog/idempotence-in-java-job-scheduling/) · [System Design Handbook — distributed job scheduler](https://www.systemdesignhandbook.com/guides/design-a-distributed-job-scheduler/) · [Educative — scheduler design](https://www.educative.io/blog/distributed-job-scheduler-system-design) · [Qasim Albaqali — serverless idempotency](https://qasimalbaqali.medium.com/achieving-idempotency-in-the-aws-serverless-space-d0671a521479) · repo docs `/Users/richardholguin/dev/powerlifting-trainer/docs/product-spec.md`, `/Users/richardholguin/dev/powerlifting-trainer/docs/research-practice.md`.