-- Ultimate Player Database: canonical foundation
-- Apply only after the Supabase database is reachable and this migration has been reviewed.

create extension if not exists pgcrypto;

create table if not exists public.data_sources (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  source_type text not null check (source_type in ('website','api','file','manual','other')),
  base_url text,
  terms_url text,
  description text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (name)
);

create table if not exists public.import_batches (
  id uuid primary key default gen_random_uuid(),
  data_source_id uuid not null references public.data_sources(id),
  status text not null default 'pending' check (status in ('pending','running','completed','failed','partial')),
  started_at timestamptz,
  completed_at timestamptz,
  records_seen integer not null default 0 check (records_seen >= 0),
  records_created integer not null default 0 check (records_created >= 0),
  records_updated integer not null default 0 check (records_updated >= 0),
  records_rejected integer not null default 0 check (records_rejected >= 0),
  error_summary text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.players (
  id uuid primary key default gen_random_uuid(),
  display_name text not null,
  given_name text,
  family_name text,
  birth_date date,
  gender_identity text,
  competition_gender text,
  nationality_code text,
  hometown text,
  home_region text,
  home_country_code text,
  latitude double precision,
  longitude double precision,
  biography text,
  profile_image_url text,
  verification_status text not null default 'unverified'
    check (verification_status in ('unverified','pending','verified','disputed')),
  data_source_id uuid references public.data_sources(id),
  import_batch_id uuid references public.import_batches(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((latitude is null and longitude is null) or
         (latitude between -90 and 90 and longitude between -180 and 180))
);

create table if not exists public.teams (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  short_name text,
  team_type text,
  competition_gender text,
  home_city text,
  home_region text,
  home_country_code text,
  latitude double precision,
  longitude double precision,
  website_url text,
  verification_status text not null default 'unverified'
    check (verification_status in ('unverified','pending','verified','disputed')),
  data_source_id uuid references public.data_sources(id),
  import_batch_id uuid references public.import_batches(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((latitude is null and longitude is null) or
         (latitude between -90 and 90 and longitude between -180 and 180))
);

create table if not exists public.disciplines (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  description text
);

create table if not exists public.rulesets (
  id uuid primary key default gen_random_uuid(),
  discipline_id uuid not null references public.disciplines(id),
  code text not null,
  name text not null,
  version text,
  effective_from date,
  effective_to date,
  metadata jsonb not null default '{}'::jsonb,
  unique (discipline_id, code, version)
);

create table if not exists public.seasons (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  start_date date,
  end_date date,
  discipline_id uuid references public.disciplines(id),
  created_at timestamptz not null default now(),
  check (end_date is null or start_date is null or end_date >= start_date)
);

create table if not exists public.events (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  event_type text not null default 'tournament'
    check (event_type in ('tournament','league','series','showcase','other')),
  start_date date,
  end_date date,
  timezone text,
  venue_name text,
  city text,
  region text,
  country_code text,
  latitude double precision,
  longitude double precision,
  website_url text,
  verification_status text not null default 'unverified'
    check (verification_status in ('unverified','pending','verified','disputed')),
  data_source_id uuid references public.data_sources(id),
  import_batch_id uuid references public.import_batches(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (end_date is null or start_date is null or end_date >= start_date),
  check ((latitude is null and longitude is null) or
         (latitude between -90 and 90 and longitude between -180 and 180))
);

create table if not exists public.event_divisions (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  discipline_id uuid references public.disciplines(id),
  ruleset_id uuid references public.rulesets(id),
  season_id uuid references public.seasons(id),
  name text not null,
  competition_gender text,
  division_level text,
  unique (event_id, name)
);

create table if not exists public.event_entries (
  id uuid primary key default gen_random_uuid(),
  event_division_id uuid not null references public.event_divisions(id) on delete cascade,
  team_id uuid not null references public.teams(id),
  seed numeric(8,2),
  final_placement integer check (final_placement is null or final_placement > 0),
  status text not null default 'registered'
    check (status in ('registered','accepted','withdrawn','completed')),
  data_source_id uuid references public.data_sources(id),
  import_batch_id uuid references public.import_batches(id),
  unique (event_division_id, team_id)
);

create table if not exists public.games (
  id uuid primary key default gen_random_uuid(),
  event_division_id uuid not null references public.event_divisions(id),
  round_name text,
  pool_name text,
  scheduled_at timestamptz,
  completed_at timestamptz,
  status text not null default 'scheduled'
    check (status in ('scheduled','in_progress','completed','forfeit','cancelled')),
  field_name text,
  data_source_id uuid references public.data_sources(id),
  import_batch_id uuid references public.import_batches(id),
  external_game_key text,
  created_at timestamptz not null default now()
);

create table if not exists public.game_team_results (
  id uuid primary key default gen_random_uuid(),
  game_id uuid not null references public.games(id) on delete cascade,
  team_id uuid not null references public.teams(id),
  score integer check (score is null or score >= 0),
  outcome text check (outcome is null or outcome in ('win','loss','tie','forfeit')),
  unique (game_id, team_id)
);

create table if not exists public.team_memberships (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null references public.players(id),
  team_id uuid not null references public.teams(id),
  season_id uuid references public.seasons(id),
  role text,
  start_date date,
  end_date date,
  membership_status text not null default 'historical'
    check (membership_status in ('active','historical','prospective','unknown')),
  data_source_id uuid references public.data_sources(id),
  import_batch_id uuid references public.import_batches(id),
  verification_status text not null default 'unverified'
    check (verification_status in ('unverified','pending','verified','disputed')),
  created_at timestamptz not null default now(),
  check (end_date is null or start_date is null or end_date >= start_date)
);

create table if not exists public.game_player_participation (
  id uuid primary key default gen_random_uuid(),
  game_id uuid not null references public.games(id) on delete cascade,
  player_id uuid not null references public.players(id),
  team_id uuid not null references public.teams(id),
  started boolean,
  minutes_played numeric(6,2) check (minutes_played is null or minutes_played >= 0),
  data_source_id uuid references public.data_sources(id),
  import_batch_id uuid references public.import_batches(id),
  verification_status text not null default 'unverified'
    check (verification_status in ('unverified','pending','verified','disputed')),
  unique (game_id, player_id)
);

create table if not exists public.stat_definitions (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  description text,
  entity_scope text not null check (entity_scope in ('player','team','game')),
  unit text,
  aggregation_method text not null default 'sum'
    check (aggregation_method in ('sum','average','rate','max','min','count','custom')),
  is_counting_stat boolean not null default true,
  metadata jsonb not null default '{}'::jsonb
);

create table if not exists public.player_game_stats (
  id uuid primary key default gen_random_uuid(),
  game_id uuid not null references public.games(id) on delete cascade,
  player_id uuid not null references public.players(id),
  stat_definition_id uuid not null references public.stat_definitions(id),
  value numeric(14,4) not null,
  data_source_id uuid references public.data_sources(id),
  import_batch_id uuid references public.import_batches(id),
  verification_status text not null default 'unverified'
    check (verification_status in ('unverified','pending','verified','disputed')),
  recorded_at timestamptz not null default now(),
  unique (game_id, player_id, stat_definition_id, data_source_id)
);

create table if not exists public.external_identities (
  id uuid primary key default gen_random_uuid(),
  data_source_id uuid not null references public.data_sources(id),
  entity_type text not null check (entity_type in ('player','team','event','game')),
  entity_id uuid not null,
  external_id text not null,
  external_url text,
  first_seen_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb,
  unique (data_source_id, entity_type, external_id)
);

create table if not exists public.rating_models (
  id uuid primary key default gen_random_uuid(),
  code text not null,
  version text not null,
  description text,
  algorithm text not null,
  configuration jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (code, version)
);

create table if not exists public.rating_environments (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  description text,
  discipline_id uuid references public.disciplines(id),
  ruleset_id uuid references public.rulesets(id),
  competition_gender text,
  season_id uuid references public.seasons(id),
  configuration jsonb not null default '{}'::jsonb
);

create table if not exists public.team_rating_snapshots (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.teams(id),
  rating_model_id uuid not null references public.rating_models(id),
  rating_environment_id uuid not null references public.rating_environments(id),
  rating_value numeric(12,4) not null,
  rating_deviation numeric(12,4),
  volatility numeric(12,6),
  games_played integer not null default 0 check (games_played >= 0),
  effective_at timestamptz not null,
  data_cutoff_at timestamptz not null,
  created_at timestamptz not null default now(),
  unique (team_id, rating_model_id, rating_environment_id, effective_at)
);

create index if not exists idx_players_display_name on public.players (display_name);
create index if not exists idx_teams_name on public.teams (name);
create index if not exists idx_events_dates on public.events (start_date, end_date);
create index if not exists idx_event_divisions_event on public.event_divisions (event_id);
create index if not exists idx_games_division_status on public.games (event_division_id, status);
create index if not exists idx_game_results_team on public.game_team_results (team_id);
create index if not exists idx_memberships_player_dates on public.team_memberships (player_id, start_date, end_date);
create index if not exists idx_memberships_team_season on public.team_memberships (team_id, season_id);
create index if not exists idx_participation_player on public.game_player_participation (player_id, game_id);
create index if not exists idx_player_stats_player_game on public.player_game_stats (player_id, game_id);
create index if not exists idx_external_identity_lookup on public.external_identities (data_source_id, entity_type, external_id);
create index if not exists idx_team_rating_lookup on public.team_rating_snapshots (team_id, rating_environment_id, effective_at desc);

-- All catalog records are public-readable. Writes are reserved for trusted server-side
-- workflows using the service role until explicit curator roles and policies are designed.
do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'data_sources','import_batches','players','teams','disciplines','rulesets','seasons',
    'events','event_divisions','event_entries','games','game_team_results',
    'team_memberships','game_player_participation','stat_definitions','player_game_stats',
    'external_identities','rating_models','rating_environments','team_rating_snapshots'
  ]
  loop
    execute format('alter table public.%I enable row level security', table_name);
    execute format('create policy %I on public.%I for select to anon, authenticated using (true)',
      table_name || '_public_read', table_name);
  end loop;
end $$;
