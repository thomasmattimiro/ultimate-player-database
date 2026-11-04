-- Reference catalogs and controlled ingestion staging.
-- Raw source payloads and identity-review metadata remain service-role only.

insert into public.disciplines (code, name, description)
values ('ultimate','Ultimate','Flying-disc team sport played with an end zone scoring objective.')
on conflict (code) do nothing;

insert into public.data_sources (name, source_type, description, is_active)
values
  ('Manual curation', 'manual', 'Records entered or corrected by an authorized curator.', true),
  ('Legacy database', 'other', 'Pre-canonical records retained from the original Ultimate Player Database schema.', true)
on conflict (name) do nothing;

insert into public.stat_definitions
  (code, name, description, entity_scope, unit, aggregation_method, is_counting_stat, metadata)
values
  ('goals','Goals','Goals credited to a player in a game.','player','count','sum',true,'{"definition_status":"provisional","semantic_version":1}'::jsonb),
  ('assists','Assists','Assists credited to a player in a game.','player','count','sum',true,'{"definition_status":"provisional","semantic_version":1}'::jsonb),
  ('blocks','Blocks','Defensive blocks credited to a player in a game.','player','count','sum',true,'{"definition_status":"provisional","semantic_version":1}'::jsonb),
  ('throwaways','Throwaways','Throwaways charged to a player in a game.','player','count','sum',true,'{"definition_status":"provisional","semantic_version":1}'::jsonb),
  ('completions','Completions','Completed throws credited to a player in a game.','player','count','sum',true,'{"definition_status":"provisional","semantic_version":1}'::jsonb),
  ('drops','Drops','Drops charged to a player in a game.','player','count','sum',true,'{"definition_status":"provisional","semantic_version":1}'::jsonb),
  ('callahans','Callahans','Goals scored directly from a defensive interception/block.','player','count','sum',true,'{"definition_status":"provisional","semantic_version":1}'::jsonb)
on conflict (code) do nothing;

alter table public.external_identities
  drop constraint if exists external_identities_entity_type_check;
alter table public.external_identities
  add constraint external_identities_entity_type_check
  check (entity_type in ('player','team','event','event_division','game','season','location'));

create table if not exists public.source_stat_mappings (
  id uuid primary key default gen_random_uuid(),
  data_source_id uuid not null references public.data_sources(id),
  external_stat_code text not null,
  external_stat_name text,
  stat_definition_id uuid not null references public.stat_definitions(id),
  transformation_config jsonb not null default '{}'::jsonb,
  mapping_status text not null default 'needs_review'
    check (mapping_status in ('needs_review','active','disabled')),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (data_source_id, external_stat_code)
);

create table if not exists public.ingestion_records (
  id uuid primary key default gen_random_uuid(),
  import_batch_id uuid not null references public.import_batches(id),
  data_source_id uuid not null references public.data_sources(id),
  entity_type text not null
    check (entity_type in ('player','team','event','event_division','game','season','location','stat')),
  record_key text not null,
  external_id text,
  source_record_url text,
  payload_hash text not null check (payload_hash ~ '^[a-f0-9]{64}$'),
  raw_payload jsonb not null,
  normalized_payload jsonb,
  processing_status text not null default 'received'
    check (processing_status in ('received','normalized','needs_review','ready_to_commit','committed','rejected','duplicate','failed')),
  canonical_entity_type text
    check (canonical_entity_type is null or canonical_entity_type in ('player','team','event','event_division','game','season','location')),
  canonical_entity_uuid uuid,
  error_details jsonb not null default '[]'::jsonb,
  received_at timestamptz not null default now(),
  processed_at timestamptz,
  unique (import_batch_id, record_key)
);

create table if not exists public.ingestion_record_matches (
  id uuid primary key default gen_random_uuid(),
  ingestion_record_id uuid not null references public.ingestion_records(id) on delete cascade,
  entity_type text not null
    check (entity_type in ('player','team','event','event_division','game','season','location')),
  entity_uuid uuid not null,
  confidence numeric(5,4) not null check (confidence >= 0 and confidence <= 1),
  match_method text not null,
  rationale text,
  decision_status text not null default 'pending'
    check (decision_status in ('pending','accepted','rejected')),
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  unique (ingestion_record_id, entity_type, entity_uuid)
);

create index if not exists idx_ingestion_records_batch_status
  on public.ingestion_records(import_batch_id, processing_status);
create index if not exists idx_ingestion_records_source_external
  on public.ingestion_records(data_source_id, entity_type, external_id);
create index if not exists idx_ingestion_records_source_hash
  on public.ingestion_records(data_source_id, entity_type, payload_hash);
create index if not exists idx_ingestion_matches_review
  on public.ingestion_record_matches(decision_status, confidence desc);
create index if not exists idx_source_stat_mappings_definition
  on public.source_stat_mappings(stat_definition_id);

do $$
declare tbl text;
begin
  foreach tbl in array array['source_stat_mappings','ingestion_records','ingestion_record_matches'] loop
    execute format('alter table public.%I enable row level security', tbl);
    execute format('revoke all on public.%I from anon, authenticated', tbl);
    execute format('grant all on public.%I to service_role', tbl);
  end loop;
end $$;
