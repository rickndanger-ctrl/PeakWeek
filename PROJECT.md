# Peak Week

**Native coaching software for a solo powerlifting practice** — a macOS console for building and delivering meet-prep programs, paired with an iPhone app clients use to receive their week and log training data back.

## What it is

Peak Week replaces spreadsheets and one-off text messages with purpose-built software for running a powerlifting coaching business:

- Block-periodized program generation (accumulation → transmutation → realization → meet), built on published sports-science defaults (RPE tables, taper math, attempt-selection percentages) that stay locked and trusted, with full customization layered on top.
- Automated weekly delivery to each client, one week at a time — the coach reviews and adjusts before every send, never the whole prep at once.
- A native iPhone app so clients can see their week, log lifts, attach video, and send notes straight back into the coach's records.

## Status

- **In production** with real client load: the coach trains on it himself, and a paying client is live on the iPhone app logging real sessions.
- 188 automated tests, ~13,100 lines of Swift, zero failures on the current build.
- Public repo: https://github.com/rickndanger-ctrl/PeakWeek

## What's built

**Coach console (macOS)**
- Program generation: phase lengths, lifter-chosen day order, 4- or 5-day weeks, meet-date-driven scheduling
- Multiple progression schemes per phase (linear, wave, DUP, hypertrophy off-season) — composable per client, per block
- Per-client coaching options: attempt-risk profile, training-max %, per-lift intensity offsets, injury/equipment exclusions
- Deload insertion anywhere in the plan (trade a week or insert-and-shift), meet week protected
- Session logging + e1RM trend charts, block-over-block verdicts, RPE-drift detection with check-in prompts — surfaces signal, never auto-prescribes a fix
- Weekly delivery: text or PDF via iMessage/Mail, scheduled auto-send with a review queue, full send history
- Client inbox: submissions from the phone app land here with anomaly flags (e1RM spikes, load-vs-max, kg/lb mix-ups, duplicates) and macOS notifications

**Client app (iOS, TestFlight)**
- Pairs to a coach-issued code; shows exactly the week the coach sent — never more
- Log a lift (prefilled from the prescribed slot), attach or record video, send a note
- Offline-safe outbox with background video upload
- Local "new week" notification when the coach publishes

**Pipeline**
- Supabase-backed sync between the two: idempotent submissions, signed video uploads, coach-token auth
- Delivery is self-healing — a failed text still gets the correct week onto the client's phone, and failures notify the coach instead of silently retrying forever

## Architecture

- `Sources/PeakWeekCore` — shared engine (program generation, scheduling math, trends, anomaly detection); pure Swift, used by both apps
- `Sources/PeakWeek` — the macOS coach console (SwiftUI)
- `ios/PeakWeekClient` — the iPhone client (SwiftUI)
- `supabase/` — Edge Function + Postgres schema for the sync pipeline
- Local-first: all client data lives in a JSON file on the coach's Mac; the pipeline is a thin relay, not the system of record

## What's next

- Two minor hardening items from the last audit (an edge case in unknown-submission handling, a narrow crash-window on video acknowledgment)
- iPad companion (read-only) — on the roadmap, not started
- Conjugate/Westside programming scheme — on the roadmap, not started

---

Further reading in this repo: `README.md` (build/run instructions), `docs/product-spec.md` (full feature spec with science citations), `CLAUDE.md` (repo conventions).
