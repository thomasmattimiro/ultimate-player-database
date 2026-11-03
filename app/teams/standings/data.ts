import { createClient } from "@/lib/supabase/server";

export type TeamSeasonStanding = {
  teamUuid: string;
  teamName: string;
  division: string | null;
  competitionGender: string | null;
  verificationStatus: string;
  gamesPlayed: number;
  wins: number;
  losses: number;
  ties: number;
  winPercentage: number;
  pointsFor: number;
  pointsAgainst: number;
  pointDifferential: number;
  eventsPlayed: number;
};

export type TeamSeasonResults = {
  season: {
    uuid: string;
    year: number | null;
    division: string | null;
    startDate: string | null;
    endDate: string | null;
  };
  standings: TeamSeasonStanding[];
  gamesPlayed: number;
  gamesMissingResults: number;
};

type ResultRow = {
  game_uuid: string;
  team_uuid: string;
  score: number | null;
  outcome: string | null;
};

export async function getAvailableSeasons() {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("seasons")
    .select("uuid, year, division, start_date, end_date")
    .order("year", { ascending: false })
    .order("division", { ascending: true });

  if (error) throw new Error(`Unable to load seasons: ${error.message}`);
  return data ?? [];
}

export async function getTeamSeasonResults(
  seasonUuid: string,
): Promise<TeamSeasonResults | null> {
  const supabase = await createClient();

  const { data: season, error: seasonError } = await supabase
    .from("seasons")
    .select("uuid, year, division, start_date, end_date")
    .eq("uuid", seasonUuid)
    .maybeSingle();

  if (seasonError) throw new Error(`Unable to load season: ${seasonError.message}`);
  if (!season) return null;

  const { data: eventDivisions, error: divisionsError } = await supabase
    .from("event_divisions")
    .select("id, event_id")
    .eq("season_uuid", seasonUuid);

  if (divisionsError) {
    throw new Error(`Unable to load season divisions: ${divisionsError.message}`);
  }

  const divisionIds = (eventDivisions ?? []).map((division) => division.id);
  if (divisionIds.length === 0) {
    return {
      season: {
        uuid: season.uuid,
        year: season.year,
        division: season.division,
        startDate: season.start_date,
        endDate: season.end_date,
      },
      standings: [],
      gamesPlayed: 0,
      gamesMissingResults: 0,
    };
  }

  const { data: games, error: gamesError } = await supabase
    .from("games")
    .select("uuid, event, date")
    .in("event_division_id", divisionIds)
    .order("date", { ascending: true });

  if (gamesError) throw new Error(`Unable to load games: ${gamesError.message}`);

  const gameRows = games ?? [];
  const gameUuids = gameRows.map((game) => game.uuid);
  if (gameUuids.length === 0) {
    return {
      season: {
        uuid: season.uuid,
        year: season.year,
        division: season.division,
        startDate: season.start_date,
        endDate: season.end_date,
      },
      standings: [],
      gamesPlayed: 0,
      gamesMissingResults: 0,
    };
  }

  const { data: results, error: resultsError } = await supabase
    .from("game_team_results")
    .select("game_uuid, team_uuid, score, outcome")
    .in("game_uuid", gameUuids);

  if (resultsError) {
    throw new Error(`Unable to load game results: ${resultsError.message}`);
  }

  const resultRows = (results ?? []) as ResultRow[];
  const resultsByGame = new Map<string, ResultRow[]>();

  for (const result of completeResultRows) {
    const existing = resultsByGame.get(result.game_uuid) ?? [];
    existing.push(result);
    resultsByGame.set(result.game_uuid, existing);
  }

  const gamesMissingResults = gameRows.filter(
    (game) => (resultsByGame.get(game.uuid)?.length ?? 0) !== 2,
  ).length;
  const completeGameUuids = new Set(
    gameRows
      .filter((game) => (resultsByGame.get(game.uuid)?.length ?? 0) === 2)
      .map((game) => game.uuid),
  );
  const completeResultRows = resultRows.filter((result) =>
    completeGameUuids.has(result.game_uuid),
  );
  const teamUuids = [...new Set(completeResultRows.map((result) => result.team_uuid))];
  const { data: teams, error: teamsError } = teamUuids.length
    ? await supabase
        .from("teams")
        .select("uuid, name, division, competition_gender, verification_status")
        .in("uuid", teamUuids)
    : { data: [], error: null };

  if (teamsError) throw new Error(`Unable to load teams: ${teamsError.message}`);

  const teamByUuid = new Map((teams ?? []).map((team) => [team.uuid, team]));
  const gameByUuid = new Map(gameRows.map((game) => [game.uuid, game]));

  const aggregates = new Map<
    string,
    {
      games: Set<string>;
      events: Set<string>;
      wins: number;
      losses: number;
      ties: number;
      pointsFor: number;
      pointsAgainst: number;
    }
  >();

  for (const result of resultRows) {
    const team = teamByUuid.get(result.team_uuid);
    if (!team) continue;

    const aggregate = aggregates.get(result.team_uuid) ?? {
      games: new Set<string>(),
      events: new Set<string>(),
      wins: 0,
      losses: 0,
      ties: 0,
      pointsFor: 0,
      pointsAgainst: 0,
    };

    aggregate.games.add(result.game_uuid);
    if (result.outcome === "win") aggregate.wins += 1;
    if (result.outcome === "loss") aggregate.losses += 1;
    if (result.outcome === "tie") aggregate.ties += 1;
    if (result.score !== null) aggregate.pointsFor += result.score;

    const game = gameByUuid.get(result.game_uuid);
    if (game?.event) aggregate.events.add(game.event);

    const opponent = (resultsByGame.get(result.game_uuid) ?? []).find(
      (candidate) => candidate.team_uuid !== result.team_uuid,
    );
    if (opponent?.score !== null && opponent?.score !== undefined) {
      aggregate.pointsAgainst += opponent.score;
    }

    aggregates.set(result.team_uuid, aggregate);
  }

  const standings = [...aggregates.entries()]
    .flatMap(([teamUuid, aggregate]) => {
      const team = teamByUuid.get(teamUuid);
      if (!team) return [];

      const gamesPlayed = aggregate.games.size;
      const decisions = aggregate.wins + aggregate.losses + aggregate.ties;
      const pointDifferential = aggregate.pointsFor - aggregate.pointsAgainst;

      return [{
        teamUuid,
        teamName: team.name ?? "Unnamed team",
        division: team.division,
        competitionGender: team.competition_gender,
        verificationStatus: team.verification_status,
        gamesPlayed,
        wins: aggregate.wins,
        losses: aggregate.losses,
        ties: aggregate.ties,
        winPercentage: decisions > 0 ? (aggregate.wins + aggregate.ties * 0.5) / decisions : 0,
        pointsFor: aggregate.pointsFor,
        pointsAgainst: aggregate.pointsAgainst,
        pointDifferential,
        eventsPlayed: aggregate.events.size,
      }];
    })
    .sort((a, b) =>
      b.winPercentage - a.winPercentage ||
      b.wins - a.wins ||
      b.pointDifferential - a.pointDifferential ||
      b.pointsFor - a.pointsFor ||
      a.teamName.localeCompare(b.teamName),
    );

  return {
    season: {
      uuid: season.uuid,
      year: season.year,
      division: season.division,
      startDate: season.start_date,
      endDate: season.end_date,
    },
    standings,
    gamesPlayed: gameRows.length,
    gamesMissingResults,
  };
}

