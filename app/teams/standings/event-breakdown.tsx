"use client";

import { useMemo, useState } from "react";
import type { EventResultsBreakdown } from "./data";

const percent = new Intl.NumberFormat("en-US", {
  style: "percent",
  maximumFractionDigits: 1,
});
const number = new Intl.NumberFormat("en-US");

function formatDateRange(start: string | null, end: string | null) {
  if (!start && !end) return "Dates not set";
  const format = (value: string) =>
    new Date(`${value}T12:00:00`).toLocaleDateString("en-US", {
      month: "short",
      day: "numeric",
      year: "numeric",
    });
  if (start && end && start !== end) return `${format(start)} – ${format(end)}`;
  return format(start ?? end!);
}

export function EventBreakdown({
  events,
}: {
  events: EventResultsBreakdown[];
}) {
  const [expanded, setExpanded] = useState<string | null>(events[0]?.eventUuid ?? null);
  const [search, setSearch] = useState("");

  const visibleEvents = useMemo(() => {
    const query = search.trim().toLowerCase();
    return events.filter((event) =>
      !query ||
      event.eventName.toLowerCase().includes(query) ||
      event.teams.some((team) => team.teamName.toLowerCase().includes(query)),
    );
  }, [events, search]);

  if (events.length === 0) {
    return <p className="muted-copy">No events are linked to this season yet.</p>;
  }

  return (
    <section className="event-breakdown" aria-label="Event-by-event results">
      <div className="event-breakdown-toolbar">
        <label>
          <span className="sr-only">Filter events and teams</span>
          <input
            type="search"
            value={search}
            onChange={(event) => setSearch(event.target.value)}
            placeholder="Filter events or teams…"
          />
        </label>
        <span>{visibleEvents.length} of {events.length} events</span>
      </div>

      <div className="event-list">
        {visibleEvents.map((event) => {
          const isExpanded = expanded === event.eventUuid;
          const completeGames = event.gamesPlayed - event.gamesMissingResults;
          return (
            <article className="event-item" key={event.eventUuid}>
              <button
                aria-expanded={isExpanded}
                className="event-toggle"
                onClick={() => setExpanded(isExpanded ? null : event.eventUuid)}
                type="button"
              >
                <span className="event-toggle-main">
                  <strong>{event.eventName}</strong>
                  <span>{formatDateRange(event.startDate, event.endDate)}</span>
                </span>
                <span className="event-toggle-stats">
                  <span>{event.teams.length} teams</span>
                  <span>{completeGames}/{event.gamesPlayed} complete games</span>
                  <span aria-hidden="true">{isExpanded ? "−" : "+"}</span>
                </span>
              </button>

              {isExpanded ? (
                <div className="event-content">
                  {event.gamesMissingResults > 0 ? (
                    <p className="data-warning">
                      {event.gamesMissingResults} game(s) excluded because they do not have
                      exactly two team-result records.
                    </p>
                  ) : (
                    <p className="event-complete-note">
                      All {event.gamesPlayed} games have complete team results.
                    </p>
                  )}

                  <div className="table-scroll">
                    <table className="standings-table event-table">
                      <thead>
                        <tr>
                          <th scope="col">#</th>
                          <th scope="col">Team</th>
                          <th className="numeric-cell" scope="col">GP</th>
                          <th className="numeric-cell" scope="col">W</th>
                          <th className="numeric-cell" scope="col">L</th>
                          <th className="numeric-cell" scope="col">Win %</th>
                          <th className="numeric-cell" scope="col">PF</th>
                          <th className="numeric-cell" scope="col">PA</th>
                          <th className="numeric-cell" scope="col">+/-</th>
                        </tr>
                      </thead>
                      <tbody>
                        {event.teams.map((team, index) => (
                          <tr key={team.teamUuid}>
                            <td className="rank-column">{index + 1}</td>
                            <td><strong>{team.teamName}</strong></td>
                            <td className="numeric-cell tabular">{team.gamesPlayed}</td>
                            <td className="numeric-cell tabular">{team.wins}</td>
                            <td className="numeric-cell tabular">{team.losses}</td>
                            <td className="numeric-cell tabular">{percent.format(team.winPercentage)}</td>
                            <td className="numeric-cell tabular">{number.format(team.pointsFor)}</td>
                            <td className="numeric-cell tabular">{number.format(team.pointsAgainst)}</td>
                            <td className="numeric-cell tabular">
                              {team.pointDifferential > 0 ? "+" : ""}{number.format(team.pointDifferential)}
                            </td>
                          </tr>
                        ))}
                        {event.teams.length === 0 ? (
                          <tr><td className="empty-cell" colSpan={9}>No complete results recorded for this event.</td></tr>
                        ) : null}
                      </tbody>
                    </table>
                  </div>
                </div>
              ) : null}
            </article>
          );
        })}
        {visibleEvents.length === 0 ? (
          <p className="empty-cell">No events or teams match this filter.</p>
        ) : null}
      </div>
    </section>
  );
}
