-- Reconstructed from the live schema for migration-history reconciliation.
create table if not exists public.competitions (uuid uuid primary key default gen_random_uuid(), name text not null, competition_type text not null default 'league' check (competition_type in ('league','series','other')), organizer text, description text, website_url text, verification_status text not null default 'unverified' check (verification_status in ('unverified','pending','verified','disputed')), data_source_id uuid references public.data_sources(id) on delete set null, import_batch_id uuid references public.import_batches(id) on delete set null, created_at timestamptz not null default now(), updated_at timestamptz not null default now());
alter table public.events add column if not exists competition_uuid uuid;
do $$ begin if not exists (select 1 from pg_constraint where conrelid='public.events'::regclass and conname='events_competition_uuid_fkey') then alter table public.events add constraint events_competition_uuid_fkey foreign key (competition_uuid) references public.competitions(uuid) on delete set null; end if; end $$;
create index if not exists competitions_name_idx on public.competitions (lower(name));
create index if not exists competitions_type_idx on public.competitions (competition_type);
create index if not exists competitions_data_source_id_idx on public.competitions (data_source_id);
create index if not exists competitions_import_batch_id_idx on public.competitions (import_batch_id);
create index if not exists events_competition_uuid_idx on public.events (competition_uuid);
alter table public.competitions enable row level security;
grant select on public.competitions to anon, authenticated;
grant all on public.competitions to service_role;
drop policy if exists competitions_public_read on public.competitions;
create policy competitions_public_read on public.competitions for select to anon, authenticated using (true);
