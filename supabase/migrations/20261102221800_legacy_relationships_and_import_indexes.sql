-- Tighten legacy relationships and complete import-batch FK indexing.
-- Existing rows are currently empty; validate before adding the missing player FK.
alter table public.games alter column event drop default;
alter table public.player_event_appearances
  add constraint player_event_appearances_player_uuid_fkey
  foreign key (player_id) references public.players(uuid);
create index if not exists idx_event_divisions_discipline on public.event_divisions(discipline_id);
create index if not exists idx_event_divisions_ruleset on public.event_divisions(ruleset_id);
create index if not exists idx_event_entries_import_batch on public.event_entries(import_batch_id);
create index if not exists idx_events_import_batch on public.events(import_batch_id);
create index if not exists idx_game_participation_import_batch on public.game_player_participation(import_batch_id);
create index if not exists idx_games_import_batch on public.games(import_batch_id);
create index if not exists idx_player_stats_import_batch on public.player_game_stats(import_batch_id);
create index if not exists idx_players_import_batch on public.players(import_batch_id);
create index if not exists idx_seasons_discipline on public.seasons(discipline_id);
create index if not exists idx_team_memberships_import_batch on public.team_memberships(import_batch_id);
create index if not exists idx_teams_import_batch on public.teams(import_batch_id);
