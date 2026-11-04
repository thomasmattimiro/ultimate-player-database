create or replace view public.league_standings with (security_invoker = true) as
 WITH game_sides AS (
         SELECT e_1.competition_uuid,
            e_1.id AS event_id,
            ed.id AS event_division_id,
            ed.name AS division_name,
            g.uuid AS game_uuid,
            g.date AS game_date,
            g.status AS game_status,
            own.team_uuid,
            own.score AS points_for,
            opponent.score AS points_against,
            own.outcome
           FROM events e_1
             JOIN competitions c_1 ON c_1.uuid = e_1.competition_uuid AND c_1.competition_type = 'league'::text
             JOIN event_divisions ed ON ed.event_id = e_1.id
             JOIN games g ON g.event = e_1.id AND g.event_division_id = ed.id
             JOIN game_team_results own ON own.game_uuid = g.uuid
             JOIN game_team_results opponent ON opponent.game_uuid = g.uuid AND opponent.team_uuid <> own.team_uuid
          WHERE g.status = ANY (ARRAY['completed'::text, 'forfeit'::text])
        )
 SELECT gs.competition_uuid,
    c.name AS competition_name,
    gs.event_id,
    e.event_name AS season_name,
    e.start_date AS season_start_date,
    e.end_date AS season_end_date,
    gs.event_division_id,
    gs.division_name,
    gs.team_uuid,
    t.name AS team_name,
    count(*) AS games_played,
    count(*) FILTER (WHERE gs.outcome = 'win'::text) AS wins,
    count(*) FILTER (WHERE gs.outcome = 'loss'::text) AS losses,
    count(*) FILTER (WHERE gs.outcome = 'tie'::text) AS ties,
    COALESCE(sum(gs.points_for), 0::bigint) AS points_for,
    COALESCE(sum(gs.points_against), 0::bigint) AS points_against,
    COALESCE(sum(gs.points_for), 0::bigint) - COALESCE(sum(gs.points_against), 0::bigint) AS point_differential,
    max(gs.game_date) AS latest_game_date
   FROM game_sides gs
     JOIN competitions c ON c.uuid = gs.competition_uuid
     JOIN events e ON e.id = gs.event_id
     JOIN teams t ON t.uuid = gs.team_uuid
  GROUP BY gs.competition_uuid, c.name, gs.event_id, e.event_name, e.start_date, e.end_date, gs.event_division_id, gs.division_name, gs.team_uuid, t.name;;
revoke all on public.league_standings from public, anon, authenticated;
grant select on public.league_standings to service_role;
