# PeakWeek pipeline backend

Lives in the existing Supabase project `lemon-tree` (zfelhehlwglvakpaelrj),
fully namespaced: `pw_*` tables, `peakweek-videos` bucket, `peakweek-api`
edge function. RLS enabled with ZERO policies — service-role only; the anon
key merely satisfies the function gateway. Real credentials travel in
X-PW-Token (device tokens for phones, coach token for the Mac; SHA-256
hashes server-side).

Coach token: ~/Library/Application Support/PeakWeek/sync-token (0600).
Rotate: generate a new token, insert its sha256 into pw_coach_tokens,
replace the file, delete the old row.

Source of truth lives here:
- `migrations/20260804000000_peakweek_pipeline.sql` — the full pw_* schema,
  RLS enables, and the private video bucket, exactly as deployed live.
- `functions/peakweek-api/index.ts` — the deployed edge function, verbatim.
Edit here first, then redeploy (`supabase functions deploy peakweek-api`);
never let the dashboard drift from the repo.

Moving to a dedicated project later ($10/mo in this org): apply
migrations/, redeploy functions/, re-mint the coach token, update
SyncService.baseURL/anonKey. Nothing else changes.
