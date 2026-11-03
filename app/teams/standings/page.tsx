import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { getAvailableSeasons, getTeamSeasonResults } from "./data";
import { EventBreakdown } from "./event-breakdown";
import { StandingsTable } from "./standings-table";

export const metadata: Metadata = {
  title: "Team Season Results",
  description:
    "Historical team standings, wins, losses, and point differentials by season and event.",
};

type PageProps = {
  searchParams: Promise<{ season?: string }>;
};

function formatDate(date: string | null) {
  if (!date) return "Dates not set";
  return new Date(`${date}T12:00:00`).toLocaleDateString("en-US", {
    month: "short",
    day: "numeric",
    year: "numeric",
  });
}

export default async function TeamSeasonStandingsPage({ searchParams }: PageProps) {
  const params = await searchParams;
  const seasons = await getAvailableSeasons();
  const selectedSeasonUuid = params.season ?? seasons[0]?.uuid;

  if (!selectedSeasonUuid) {
    return (
      <main className="site-shell">
        <header className="topbar">
          <Link className="brand" href="/">UPD<span>.</span></Link>
          <nav aria-label="Main navigation">
            <Link href="/players">Players</Link>
            <Link href="/teams/standings" aria-current="page">Teams</Link>
            <Link href="/events">Events</Link>
            <Link href="/rankings">Rankings</Link>
          </nav>
        </header>
        <section className="standings-page">
          <p className="eyebrow">TEAM DATABASE</p>
          <h1>Team season results</h1>
          <p className="muted-copy">No seasons have been added to the database yet.</p>
        </section>
      </main>
    );
  }

  const results = await getTeamSeasonResults(selectedSeasonUuid);
  if (!results) notFound();

  const { season, standings, eventBreakdown, gamesPlayed, gamesMissingResults } = results;
  const title = [season.year, season.division].filter(Boolean).join(" ") || "Season";

  return (
    <main className="site-shell">
      <header className="topbar">
        <Link className="brand" href="/">UPD<span>.</span></Link>
        <nav aria-label="Main navigation">
          <Link href="/players">Players</Link>
          <Link href="/teams/standings" aria-current="page">Teams</Link>
          <Link href="/events">Events</Link>
          <Link href="/rankings">Rankings</Link>
          <Link href="/statistics">Statistics</Link>
          <Link href="/maps">Maps</Link>
        </nav>
        <span className="status-label">Historical results</span>
      </header>

      <section className="standings-page">
        <div className="breadcrumbs">
          <Link href="/">Home</Link>
          <span>/</span>
          <span>Teams</span>
          <span>/</span>
          <span>Season results</span>
        </div>

        <div className="standings-heading">
          <div>
            <p className="eyebrow">TEAM DATABASE / STANDINGS</p>
            <h1>Team season results</h1>
            <p className="muted-copy">
              Competitive records built from verified team identities and canonical game results.
            </p>
          </div>
          <form action="/teams/standings" className="season-selector" method="get">
            <label htmlFor="season">Season</label>
            <select defaultValue={season.uuid} id="season" name="season">
              {seasons.map((option) => (
                <option key={option.uuid} value={option.uuid}>
                  {[option.year, option.division].filter(Boolean).join(" ")}
                </option>
              ))}
            </select>
            <button className="button button-primary" type="submit">View season</button>
          </form>
        </div>

        <div className="season-context">
          <span>{title}</span>
          <span>{formatDate(season.startDate)} – {formatDate(season.endDate)}</span>
        </div>

        <div className="standings-metrics">
          <article className="metric">
            <span>Teams</span>
            <strong>{standings.length}</strong>
          </article>
          <article className="metric">
            <span>Games</span>
            <strong>{gamesPlayed}</strong>
          </article>
          <article className="metric">
            <span>Team results</span>
            <strong>{standings.reduce((total, row) => total + row.gamesPlayed, 0)}</strong>
          </article>
          <article className="metric">
            <span>Events</span>
            <strong>{eventBreakdown.length}</strong>
          </article>
        </div>

        {gamesMissingResults > 0 ? (
          <p className="data-warning" role="status">
            {gamesMissingResults} game{gamesMissingResults === 1 ? "" : "s"} do not yet have
            exactly two team-result records and are excluded from complete team records.
          </p>
        ) : (
          <p className="data-complete" role="status">
            All {gamesPlayed} games have two team-result records.
          </p>
        )}

        <div className="standings-section-heading">
          <div>
            <h2>{season.year} {season.division} standings</h2>
            <p>Sorted by win percentage, wins, then point differential. This is not a power rating.</p>
          </div>
        </div>

        <StandingsTable standings={standings} seasonUuid={season.uuid} />

        <div className="standings-section-heading event-section-heading">
          <div>
            <h2>Results by event</h2>
            <p>Expand an event to see each participating team’s record and scoring totals at that event.</p>
          </div>
        </div>
        <EventBreakdown events={eventBreakdown} />
      </section>

      <footer className="footer">
        <span>Ultimate Player Database</span>
        <span>Results are distinct from model-based team ratings.</span>
      </footer>
    </main>
  );
}
