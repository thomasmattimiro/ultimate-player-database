-- Public catalog read policies and FK indexes.
-- Import internals and external identity crosswalks remain service-role only.
do $$
declare tbl text;
public_tables text[] := array[
 'players','teams','seasons','events','games','locations',
 'player_event_appearances','player_location_history','player_team_memberships','ratings',
 'data_sources','disciplines','rulesets','event_divisions','event_entries',
 'game_team_results','team_memberships','game_player_participation',
 'stat_definitions','player_game_stats','rating_models','rating_environments','team_rating_snapshots'
];
begin
 foreach tbl in array public_tables loop
  execute format('alter table public.%I enable row level security',tbl);
  execute format('grant select on public.%I to anon, authenticated',tbl);
  if not exists (select 1 from pg_policies p where p.schemaname='public' and p.tablename=tbl and p.policyname=tbl||'_public_read') then
   execute format('create policy %I on public.%I for select to anon, authenticated using (true)',tbl||'_public_read',tbl);
  end if;
 end loop;
end $$;
alter table public.import_batches enable row level security;
alter table public.external_identities enable row level security;
revoke all on public.import_batches,public.external_identities from anon,authenticated;
grant all on public.import_batches,public.external_identities to service_role;

create index if not exists idx_players_source_batch on public.players(data_source_id,import_batch_id);
create index if not exists idx_teams_source_batch on public.teams(data_source_id,import_batch_id);
create index if not exists idx_events_source_batch on public.events(data_source_id,import_batch_id);
create index if not exists idx_games_source_batch on public.games(data_source_id,import_batch_id);
create index if not exists idx_import_batches_source on public.import_batches(data_source_id);
create index if not exists idx_event_divisions_season on public.event_divisions(season_uuid);
create index if not exists idx_event_entries_team on public.event_entries(team_uuid);
create index if not exists idx_event_entries_source_batch on public.event_entries(data_source_id,import_batch_id);
create index if not exists idx_game_team_results_team on public.game_team_results(team_uuid);
create index if not exists idx_team_memberships_season on public.team_memberships(season_uuid);
create index if not exists idx_team_memberships_source_batch on public.team_memberships(data_source_id,import_batch_id);
create index if not exists idx_game_participation_team on public.game_player_participation(team_uuid);
create index if not exists idx_game_participation_source_batch on public.game_player_participation(data_source_id,import_batch_id);
create index if not exists idx_player_stats_definition on public.player_game_stats(stat_definition_id);
create index if not exists idx_player_stats_source_batch on public.player_game_stats(data_source_id,import_batch_id);
create index if not exists idx_rating_env_discipline on public.rating_environments(discipline_id);
create index if not exists idx_rating_env_ruleset on public.rating_environments(ruleset_id);
create index if not exists idx_rating_env_season on public.rating_environments(season_uuid);
create index if not exists idx_rating_snapshots_model on public.team_rating_snapshots(rating_model_id);
create index if not exists idx_rating_snapshots_environment on public.team_rating_snapshots(rating_environment_id);
create index if not exists idx_events_location on public.events(location_id);
create index if not exists idx_teams_location on public.teams(location_id);
create index if not exists idx_players_hometown on public.players(hometown_location_id);
create index if not exists idx_players_college on public.players(college_location_id);
create index if not exists idx_games_event on public.games(event);
create index if not exists idx_legacy_player_memberships_player on public.player_team_memberships(player_id);
create index if not exists idx_legacy_player_memberships_team on public.player_team_memberships(team_id);
create index if not exists idx_legacy_player_appearances_event on public.player_event_appearances(event_id);
create index if not exists idx_legacy_player_appearances_team on public.player_event_appearances(team_id);
create index if not exists idx_legacy_player_location_player on public.player_location_history(player_id);
create index if not exists idx_legacy_player_location_location on public.player_location_history(location_id);
create index if not exists idx_legacy_ratings_team on public.ratings(team_id);
create index if not exists idx_legacy_ratings_season on public.ratings(season_id);