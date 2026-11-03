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

export type EventTeamStanding = Omit<TeamSeasonStanding, "eventsPlayed">;

export type EventResultsBreakdown = {
  eventUuid: string;
  eventName: string;
  startDate: string | null;
  endDate: string | null;
  gamesPlayed: number;
  gamesMissingResults: number;
  teams: EventTeamStanding[];
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
  eventBreakdown: EventResultsBreakdown[];
  gamesPlayed: number;
  gamesMissingResults: number;
};

type ResultRow = {
  game_uuid: string;
  team_uuid: string;
  score: number | null;
  outcome: string | null;
};

type Aggregate = {
  games: Set<string>;
  wins: number;
  losses: number;
  ties: number;
  pointsFor: number;
  pointsAgainst: number;
};

function createAggregate(): Aggregate {
  return {
    games: new Set<string>(),
    wins: 0,
    losses: 0,
    ties: 0,
    pointsFor: 0,
    pointsAgainst: 0,
  };
}

function toStanding(
  teamUuid: string,
  aggregate: Aggregate,
  team: {
    name: string | null;
    division: string | null;
    competition_gender: string | null;
    verification_status: string;
  },
): EventTeamStanding {
  const gamesPlayed = aggregate.games.size;
  const decisions = aggregate.wins + aggregate.losses + aggregate.ties;
  const pointDifferential = aggregate.pointsFor - aggregate.pointsAgainst;

  return {
    teamUuid,
    teamName: team.name ?? "Unnamed team",
    division: team.division,
    competitionGender: team.competition_gender,
    verificationStatus: team.verification_status,
    gamesPlayed,
    wins: aggregate.wins,
    losses: aggregate.losses,
    ties: aggregate.ties,
    winPercentage:
      decisions > 0 ? (aggregate.wins + aggregate.ties * 0.5) / decisions : 0,
    pointsFor: aggregate.pointsFor,
    pointsAgainst: aggregate.pointsAgainst,
    pointDifferential,
  };
}

function compareStandings(
  a: EventTeamStanding,
  b: EventTeamStanding,
) {
  return (
    b.winPercentage - a.winPercentage ||
    b.wins - a.wins ||
    b.pointDifferential - a.pointDifferential ||
    b.pointsFor - a.pointsFor ||
    a.teamName.localeCompare(b.teamName)
  );
}

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

  const divisionRows = eventDivisions ?? [];
  const divisionIds = divisionRows.map((division) => division.id);
  const eventUuids = [...new Set(divisionRows.map((division) => division.event_id))];
  const emptySeason = {
    uuid: season.uuid,
    year: season.year,
    division: season.division,
    startDate: season.start_date,
    endDate: season.end_date,
  };

  if (divisionIds.length === 0) {
    return {
      season: emptySeason,
      standings: [],
      eventBreakdown: [],
      gamesPlayed: 0,
      gamesMissingResults: 0,
    };
  }

  const [{ data: games, error: gamesError }, { data: events, error: eventsError }] =
    await Promise.all([
      supabase
        .from("games")
        .select("uuid, event, date")
        .in("event_division_id", divisionIds)
        .order("date", { ascending: true }),
      supabase
        .from("events")
        .select("id, event_name, start_date, end_date")
        .in("id", eventUuids),
    ]);

  if (gamesError) throw new Error(`Unable to load games: ${gamesError.message}`);
  if (eventsError) throw new Error(`Unable to load events: ${eventsError.message}`);

  const gameRows = games ?? [];
  const eventRows = events ?? [];
  const eventByUuid = new Map(eventRows.map((event) => [event.id, event]));
  const gameUuids = gameRows.map((game) => game.uuid);

  if (gameUuids.length === 0) {
    return {
      season: emptySeason,
      standings: [],
      eventBreakdown: eventRows
        .map((event) => ({
          eventUuid: event.id,
          eventName: event.event_name ?? "Unnamed event",
          startDate: event.start_date,
          endDate: event.end_date,
          gamesPlayed: 0,
          gamesMissingResults: 0,
          teams: [],
        }))
        .sort((a, b) => (a.startDate ?? "").localeCompare(b.startDate ?? "")),
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

  for (const result of resultRows) {
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
  const seasonAggregates = new Map<string, Aggregate>();
  const eventAggregates = new Map<string, Map<string, Aggregate>>();
  const eventGameIds = new Map<string, Set<string>>();
  const eventMissingGames = new Map<string, number>();

  for (const game of gameRows) {
    if (!game.event) continue;
    const eventGames = eventGameIds.get(game.event) ?? new Set<string>();
    eventGames.add(game.uuid);
    eventGameIds.set(game.event, eventGames);
    if (!completeGameUuids.has(game.uuid)) {
      eventMissingGames.set(game.event, (eventMissingGames.get(game.event) ?? 0) + 1);
    }
  }

  for (const result of completeResultRows) {
    if (!teamByUuid.has(result.team_uuid)) continue;

    const seasonAggregate = seasonAggregates.get(result.team_uuid) ?? createAggregate();
    const eventUuid = gameByUuid.get(result.game_uuid)?.event;
    if (!eventUuid) continue;

    const byTeam = eventAggregates.get(eventUuid) ?? new Map<string, Aggregate>();
    const eventAggregate = byTeam.get(result.team_uuid) ?? createAggregate();

    for (const aggregate of [seasonAggregate, eventAggregate]) {
      aggregate.games.add(result.game_uuid);
      if (result.outcome === "win") aggregate.wins += 1;
      if (result.outcome === "loss") aggregate.losses += 1;
      if (result.outcome === "tie") aggregate.ties += 1;
      if (result.score !== null) aggregate.pointsFor += result.score;

      const opponent = (resultsByGame.get(result.game_uuid) ?? []).find(
        (candidate) => candidate.team_uuid !== result.team_uuid,
      );
      if (opponent?.score !== null && opponent?.score !== undefined) {
        aggregate.pointsAgainst += opponent.score;
      }
    }

    seasonAggregates.set(result.team_uuid, seasonAggregate);
    byTeam.set(result.team_uuid, eventAggregate);
    eventAggregates.set(eventUuid, byTeam);
  }

  const standings = [...seasonAggregates.entries()]
    .flatMap(([teamUuid, aggregate]) => {
      const team = teamByUuid.get(teamUuid);
      return team ? [{
        ...toStanding(teamUuid, aggregate, team),
        eventsPlayed: new Set(
          completeResultRows
            .filter((result) => result.team_uuid === teamUuid)
            .map((result) => gameByUuid.get(result.game_uuid)?.event)
            .filter(Boolean),
        ).size,
      }] : [];
    })
    .sort(compareStandings);

  const eventBreakdown = eventRows
    .map((event) => {
      const teamAggregates = eventAggregates.get(event.id) ?? new Map();
      const eventTeams = [...teamAggregates.entries()]
        .flatMap(([teamUuid, aggregate]) => {
          const team = teamByUuid.get(teamUuid);
          return team ? [toStanding(teamUuid, aggregate, team)] : [];
        })
        .sort(compareStandings);

      return {
        eventUuid: event.id,
        eventName: event.event_name ?? "Unnamed event",
        startDate: event.start_date,
        endDate: event.end_date,
        gamesPlayed: eventGameIds.get(event.id)?.size ?? 0,
        gamesMissingResults: eventMissingGames.get(event.id) ?? 0,
        teams: eventTeams,
      };
    })
    .sort((a, b) =>
      (a.startDate ?? "").localeCompare(b.startDate ?? "") ||
      a.eventName.localeCompare(b.eventName),
    );

  return {
    season: emptySeason,
    standings,
    eventBreakdown,
    gamesPlayed: gameRows.length,
    gamesMissingResults,
  };
}
