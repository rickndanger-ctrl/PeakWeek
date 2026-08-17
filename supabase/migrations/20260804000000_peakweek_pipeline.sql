-- PeakWeek pipeline schema — faithful to the live lemon-tree deployment
-- (project zfelhehlwglvakpaelrj, went live 2026-08-04). Everything is
-- service-role only: RLS is ENABLED with ZERO policies on every table. The
-- anon key merely satisfies the edge-function gateway; real credentials are
-- SHA-256-hashed device/coach tokens verified inside peakweek-api.

create table pw_clients_mirror (
  id uuid primary key,                -- the Client.id from the Mac's data.json
  name text not null,
  unit text not null check (unit in ('lb','kg')),
  created_at timestamptz not null default now()
);

create table pw_coach_tokens (
  id uuid primary key default gen_random_uuid(),
  token_hash text not null unique,
  label text,
  created_at timestamptz not null default now()
);

create table pw_devices (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references pw_clients_mirror(id) on delete cascade,
  token_hash text not null unique,
  name text,
  created_at timestamptz not null default now(),
  last_seen_at timestamptz
);

create table pw_pairing_codes (
  code text primary key,              -- 8 chars, alphabet 23456789ABCDEFGHJKMNPQRSTUVWXYZ
  client_id uuid not null references pw_clients_mirror(id) on delete cascade,
  expires_at timestamptz not null,    -- minted with +24h
  used_at timestamptz                 -- one-use: set on pair, never cleared
);

-- PK on client_id = at most ONE published week per client, ever — the
-- week-by-week delivery doctrine enforced by schema.
create table pw_published_weeks (
  client_id uuid primary key references pw_clients_mirror(id) on delete cascade,
  week_num integer not null,
  program_stamp timestamptz not null,
  payload jsonb not null,             -- PublishedWeek, ISO-8601 dates
  published_at timestamptz not null default now()
);

create table pw_submissions (
  id uuid primary key,                -- client-generated: the end-to-end idempotency key
  client_id uuid not null references pw_clients_mirror(id) on delete cascade,
  performed_at timestamptz not null,
  lift text not null check (lift in ('squat','bench','deadlift')),
  exercise_name text,
  load numeric not null,
  unit text not null check (unit in ('lb','kg')),
  reps integer not null,
  rpe numeric,
  prescribed_pct numeric,
  prescribed_rpe numeric,
  week_num integer,
  program_stamp timestamptz,
  note text,
  video_path text,                    -- <client_id>/<submission_id>.mp4 in peakweek-videos
  video_status text not null default 'none' check (video_status in ('none','pending','uploaded')),
  status text not null default 'new' check (status in ('new','ingested')),
  created_at timestamptz not null default now(),
  ingested_at timestamptz
);

create index pw_submissions_new_idx on pw_submissions (created_at) where status = 'new';

alter table pw_clients_mirror  enable row level security;
alter table pw_coach_tokens    enable row level security;
alter table pw_devices         enable row level security;
alter table pw_pairing_codes   enable row level security;
alter table pw_published_weeks enable row level security;
alter table pw_submissions     enable row level security;

-- Private bucket for set videos: uploaded from the phone via signed URLs
-- minted by the edge function, downloaded by the Mac BEFORE ack, deleted on
-- ack (or by the 14-day orphan sweep in admin/inbox).
insert into storage.buckets (id, name, public)
values ('peakweek-videos', 'peakweek-videos', false)
on conflict (id) do nothing;
