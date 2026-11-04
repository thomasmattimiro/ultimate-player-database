-- Remove leftover public SELECT policies from server-only ingestion metadata
-- and index the newly added legacy player UUID foreign key.
drop policy if exists import_batches_public_read on public.import_batches;
drop policy if exists external_identities_public_read on public.external_identities;
create index if not exists idx_player_event_appearances_player_uuid
  on public.player_event_appearances(player_id);