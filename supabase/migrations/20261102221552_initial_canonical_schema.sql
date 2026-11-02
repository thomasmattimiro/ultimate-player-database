-- Ultimate Player Database: additive canonical foundation.
-- Existing public tables are retained. Their current numeric identifiers remain valid;
-- UUIDs are the canonical identifiers for new application relationships.
-- This migration intentionally does not modify spatial_ref_sys RLS.

create extension if not exists pgcrypto;

create table if not exists public.data_sources (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  source_type text not null check (source_type in ('website','api','file','manual','other')),
  base_url text,
  terms_url text,
  description text,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
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

-- Preserve legacy numeric IDs and existing relationships. Add UUID identity for
-- players, teams, seasons, and games; events already use UUID primary keys.
alter table public.players alter column usau_id drop not null;
alter table public.players add constraint players_uuid_pkey primary key (uuid);
alter table public.players
  add column if not exists verification_status text not null default 'unverified'
    check (verification_status in ('unverified','pending','verified','disputed')),
  add column if not exists data_source_id uuid references public.data_sources(id),
  add column if not exists import_batch_id uuid references public.import_batches(id),
  add column if not exists nationality_code text,
  add column if not exists competition_gender text,
  add column if not exists updated_at timestamptz not null default now();

alter table public.teams
  add column if not exists uuid uuid not null default gen_random_uuid(),
  add column if not exists team_type text,
  add column if not exists competition_gender text,
  add column if not exists verification_status text not null default 'unverified'
    check (verification_status in ('unverified','pending','verified','disputed')),
  add column if not exists data_source_id uuid references public.data_sources(id),
  add column if not exists import_batch_id uuid references public.import_batches(id),
  add column if not exists updated_at timestamptz not null default now();
create unique index if not exists teams_uuid_uidx on public.teams(uuid);

alter table public.seasons
  add column if not exists uuid uuid not null default gen_random_uuid(),
  add column if not exists name text,
  add column if not exists discipline_id uuid;
create unique index if not exists seasons_uuid_uidx on public.seasons(uuid);

alter table public.events
  add column if not exists timezone text,
  add column if not exists venue_name text,
  add column if not exists verification_status text not null default 'unverified'
    check (verification_status in ('unverified','pending','verified','disputed')),
  add column if not exists data_source_id uuid references public.data_sources(id),
  add column if not exists import_batch_id uuid references public.import_batches(id),
  add column if not exists updated_at timestamptz not null default now();

alter table public.games
  add column if not exists uuid uuid not null default gen_random_uuid(),
  add column if not exists event_division_id uuid,
  add column if not exists round_name text,
  add column if not exists pool_name text,
  add column if not exists scheduled_at timestamptz,
  add column if not exists completed_at timestamptz,
  add column if not exists status text not null default 'completed'
    check (status in ('scheduled','in_progress','completed','forfeit','cancelled')),
  add column if not exists data_source_id uuid references public.data_sources(id),
  add column if not exists import_batch_id uuid references public.import_batches(id);
create unique index if not exists games_uuid_uidx on public.games(uuid);

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
  version text not null default '1',
  effective_from date,
  effective_to date,
  metadata jsonb not null default '{}'::jsonb,
  unique (discipline_id, code, version)
);

alter table public.seasons
  add constraint seasons_discipline_id_fkey
  foreign key (discipline_id) references public.disciplines(id);

create table if not exists public.event_divisions (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  discipline_id uuid references public.disciplines(id),
  ruleset_id uuid references public.rulesets(id),
  season_uuid uuid references public.seasons(uuid),
  name text not null,
  competition_gender text,
  division_level text,
  unique (event_id, name)
);

alter table public.games
  add constraint games_event_division_id_fkey
  foreign key (event_division_id) references public.event_divisions(id);

create table if not exists public.event_entries (
  id uuid primary key default gen_random_uuid(),
  event_division_id uuid not null references public.event_divisions(id) on delete cascade,
  team_uuid uuid not null references public.teams(uuid),
  seed numeric(8,2),
  final_placement integer check (final_placement is null or final_placement > 0),
  status text not null default 'registered'
    check (status in ('registered','accepted','withdrawn','completed')),
  data_source_id uuid references public.data_sources(id),
  import_batch_id uuid references public.import_batches(id),
  unique (event_division_id, team_uuid)
);

create table if not exists public.game_team_results (
  id uuid primary key default gen_random_uuid(),
  game_uuid uuid not null references public.games(uuid) on delete cascade,
  team_uuid uuid not null references public.teams(uuid),
  score integer check (score is null or score >= 0),
  outcome text check (outcome is null or outcome in ('win','loss','tie','forfeit')),
  unique (game_uuid, team_uuid)
);

create table if not exists public.team_memberships (
  id uuid primary key default gen_random_uuid(),
  player_uuid uuid not null references public.players(uuid),
  team_uuid uuid not null references public.teams(uuid),
  season_uuid uuid references public.seasons(uuid),
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
  game_uuid uuid not null references public.games(uuid) on delete cascade,
  player_uuid uuid not null references public.players(uuid),
  team_uuid uuid not null references public.teams(uuid),
  started boolean,
  minutes_played numeric(6,2) check (minutes_played is null or minutes_played >= 0),
  data_source_id uuid references public.data_sources(id),
  import_batch_id uuid references public.import_batches(id),
  verification_status text not null default 'unverified'
    check (verification_status in ('unverified','pending','verified','disputed')),
  unique (game_uuid, player_uuid)
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
  game_uuid uuid not null references public.games(uuid) on delete cascade,
  player_uuid uuid not null references public.players(uuid),
  stat_definition_id uuid not null references public.stat_definitions(id),
  value numeric(14,4) not null,
  data_source_id uuid references public.data_sources(id),
  import_batch_id uuid references public.import_batches(id),
  verification_status text not null default 'unverified'
    check (verification_status in ('unverified','pending','verified','disputed')),
  recorded_at timestamptz not null default now()
);
create unique index if not exists player_game_stats_source_uidx
  on public.player_game_stats(game_uuid, player_uuid, stat_definition_id, coalesce(data_source_id, '00000000-0000-0000-0000-000000000000'::uuid));

create table if not exists public.external_identities (
  id uuid primary key default gen_random_uuid(),
  data_source_id uuid not null references public.data_sources(id),
  entity_type text not null check (entity_type in ('player','team','event','game','season')),
  entity_uuid uuid not null,
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
  season_uuid uuid references public.seasons(uuid),
  configuration jsonb not null default '{}'::jsonb
);

create table if not exists public.team_rating_snapshots (
  id uuid primary key default gen_random_uuid(),
  team_uuid uuid not null references public.teams(uuid),
  rating_model_id uuid not null references public.rating_models(id),
  rating_environment_id uuid not null references public.rating_environments(id),
  rating_value numeric(12,4) not null,
  rating_deviation numeric(12,4),
  volatility numeric(12,6),
  games_played integer not null default 0 check (games_played >= 0),
  effective_at timestamptz not null,
  data_cutoff_at timestamptz not null,
  created_at timestamptz not null default now(),
  unique (team_uuid, rating_model_id, rating_environment_id, effective_at)
);

create index if not exists idx_players_full_name on public.players(full_name);
create index if not exists idx_teams_name on public.teams(name);
create index if not exists idx_events_dates on public.events(start_date, end_date);
create index if not exists idx_event_divisions_event on public.event_divisions(event_id);
create index if not exists idx_games_division_status on public.games(event_division_id, status);
create index if not exists idx_team_memberships_player_dates on public.team_memberships(player_uuid, start_date, end_date);
create index if not exists idx_team_memberships_team_season on public.team_memberships(team_uuid, season_uuid);
create index if not exists idx_participation_player_game on public.game_player_participation(player_uuid, game_uuid);
create index if not exists idx_player_stats_player_game on public.player_game_stats(player_uuid, game_uuid);
create index if not exists idx_external_identity_lookup on public.external_identities(data_source_id, entity_type, external_id);
create index if not exists idx_team_rating_lookup on public.team_rating_snapshots(team_uuid, rating_environment_id, effective_at desc);

-- Catalog tables are publicly readable. Mutations are reserved for trusted server
-- workflows (service role) until curator permissions are designed explicitly.
do $$
declare
  table_name text;
  tables text[] := array[
    'data_sources','import_batches','disciplines','rulesets','event_divisions',
    'event_entries','game_team_results','team_memberships','game_player_participation',
    'stat_definitions','player_game_stats','external_identities','rating_models',
    'rating_environments','team_rating_snapshots'
  ];
begin
  foreach table_name in array tables loop
    execute format('alter table public.%I enable row level security', table_name);
    execute format('grant select on public.%I to anon, authenticated', table_name);
    execute format('grant all on public.%I to service_role', table_name);
    if not exists (
      select 1 from pg_policies
      where schemaname = 'public' and tablename = table_name
        and policyname = table_name || '_public_read'
    ) then
      execute format(
        'create policy %I on public.%I for select to anon, authenticated using (true)',
        table_name || '_public_read', table_name
      );
    end if;
  end loop;
end $$;

grant select on public.players, public.teams, public.seasons, public.events, public.games to anon, authenticated;
grant all on public.players, public.teams, public.seasons, public.events, public.games to service_role;
