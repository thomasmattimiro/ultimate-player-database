"use client";

import { useMemo, useState } from "react";
import type { TeamSeasonStanding } from "./data";

type SortKey =
  | "teamName"
  | "gamesPlayed"
  | "wins"
  | "losses"
  | "winPercentage"
  | "pointsFor"
  | "pointsAgainst"
  | "pointDifferential"
  | "eventsPlayed";

type Column = {
  key: SortKey;
  label: string;
  align?: "left" | "right";
};

const columns: Column[] = [
  { key: "teamName", label: "Team" },
  { key: "gamesPlayed", label: "GP", align: "right" },
  { key: "wins", label: "W", align: "right" },
  { key: "losses", label: "L", align: "right" },
  { key: "winPercentage", label: "Win %", align: "right" },
  { key: "pointsFor", label: "PF", align: "right" },
  { key: "pointsAgainst", label: "PA", align: "right" },
  { key: "pointDifferential", label: "+/-", align: "right" },
  { key: "eventsPlayed", label: "Events", align: "right" },
];

const numberFormat = new Intl.NumberFormat("en-US");
const percentageFormat = new Intl.NumberFormat("en-US", {
  style: "percent",
  maximumFractionDigits: 1,
});

function cellValue(row: TeamSeasonStanding, key: SortKey) {
  if (key === "teamName") return row.teamName;
  if (key === "winPercentage") return percentageFormat.format(row.winPercentage);
  if (key === "pointDifferential") {
    return row.pointDifferential > 0 ? `+${row.pointDifferential}` : numberFormat.format(row.pointDifferential);
  }
  return numberFormat.format(row[key]);
}

function csvValue(value: string | number) {
  const safe = String(value).replace(/^[=+\-@]/, "'$&");
  return `"${safe.replaceAll('"', '""')}"`;
}

export function StandingsTable({
  standings,
  seasonUuid,
}: {
  standings: TeamSeasonStanding[];
  seasonUuid: string;
}) {
  const [search, setSearch] = useState("");
  const [sortKey, setSortKey] = useState<SortKey>("winPercentage");
  const [sortAscending, setSortAscending] = useState(false);
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(25);
  const [visibleColumns, setVisibleColumns] = useState<SortKey[]>(
    columns.map((column) => column.key),
  );

  const filtered = useMemo(() => {
    const query = search.trim().toLowerCase();
    return standings
      .filter((row) =>
        !query ||
        row.teamName.toLowerCase().includes(query) ||
        (row.division ?? "").toLowerCase().includes(query),
      )
      .sort((a, b) => {
        const left = a[sortKey];
        const right = b[sortKey];
        const comparison =
          typeof left === "string" && typeof right === "string"
            ? left.localeCompare(right)
            : Number(left) - Number(right);
        return sortAscending ? comparison : -comparison;
      });
  }, [search, sortAscending, sortKey, standings]);

  const pageCount = Math.max(1, Math.ceil(filtered.length / pageSize));
  const currentPage = Math.min(page, pageCount);
  const pageRows = filtered.slice((currentPage - 1) * pageSize, currentPage * pageSize);
  const visible = columns.filter((column) => visibleColumns.includes(column.key));

  function toggleSort(key: SortKey) {
    if (sortKey === key) setSortAscending((current) => !current);
    else {
      setSortKey(key);
      setSortAscending(key === "teamName");
    }
    setPage(1);
  }

  function exportCsv() {
    const header = visible.map((column) => csvValue(column.label)).join(",");
    const body = filtered.map((row) =>
      visible.map((column) => csvValue(cellValue(row, column.key))).join(","),
    );
    const csv = [header, ...body].join("\r\n");
    const url = URL.createObjectURL(new Blob([csv], { type: "text/csv;charset=utf-8;" }));
    const anchor = document.createElement("a");
    anchor.href = url;
    anchor.download = `team-standings-${seasonUuid}.csv`;
    anchor.click();
    URL.revokeObjectURL(url);
  }

  return (
    <section className="standings-panel" aria-label="Team season standings">
      <div className="standings-toolbar">
        <label className="standings-search">
          <span className="sr-only">Filter teams</span>
          <input
            value={search}
            onChange={(event) => {
              setSearch(event.target.value);
              setPage(1);
            }}
            placeholder="Filter teams…"
            type="search"
          />
        </label>
        <div className="standings-tools">
          <details className="column-picker">
            <summary>Columns</summary>
            <div className="column-picker-menu">
              {columns.map((column) => (
                <label key={column.key}>
                  <input
                    type="checkbox"
                    checked={visibleColumns.includes(column.key)}
                    onChange={(event) => {
                      setVisibleColumns((current) =>
                        event.target.checked
                          ? [...current, column.key]
                          : current.filter((key) => key !== column.key),
                      );
                    }}
                  />
                  {column.label}
                </label>
              ))}
            </div>
          </details>
          <button className="table-action" onClick={exportCsv} type="button">
            Export CSV
          </button>
        </div>
      </div>

      <div className="table-scroll">
        <table className="standings-table">
          <thead>
            <tr>
              <th className="rank-column" scope="col">#</th>
              {visible.map((column) => (
                <th
                  className={column.align === "right" ? "numeric-cell" : ""}
                  key={column.key}
                  scope="col"
                >
                  <button
                    className="sort-button"
                    onClick={() => toggleSort(column.key)}
                    type="button"
                  >
                    {column.label}
                    {sortKey === column.key ? (
                      <span aria-label={sortAscending ? "ascending" : "descending"}>
                        {sortAscending ? " ↑" : " ↓"}
                      </span>
                    ) : null}
                  </button>
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {pageRows.map((row, index) => (
              <tr key={row.teamUuid}>
                <td className="rank-column">{(currentPage - 1) * pageSize + index + 1}</td>
                {visible.map((column) => (
                  <td
                    className={column.align === "right" ? "numeric-cell tabular" : ""}
                    key={column.key}
                  >
                    {column.key === "teamName" ? (
                      <span className="team-name-link">{row.teamName}</span>
                    ) : (
                      cellValue(row, column.key)
                    )}
                  </td>
                ))}
              </tr>
            ))}
            {pageRows.length === 0 ? (
              <tr>
                <td className="empty-cell" colSpan={visible.length + 1}>
                  No teams match this filter.
                </td>
              </tr>
            ) : null}
          </tbody>
        </table>
      </div>

      <div className="table-footer">
        <span>
          Showing {filtered.length === 0 ? 0 : (currentPage - 1) * pageSize + 1}–
          {Math.min(currentPage * pageSize, filtered.length)} of {filtered.length} teams
        </span>
        <div className="pagination-controls">
          <label>
            Rows
            <select
              value={pageSize}
              onChange={(event) => {
                setPageSize(Number(event.target.value));
                setPage(1);
              }}
            >
              <option value={10}>10</option>
              <option value={25}>25</option>
              <option value={50}>50</option>
              <option value={100}>100</option>
            </select>
          </label>
          <button
            className="table-action"
            disabled={currentPage <= 1}
            onClick={() => setPage((current) => current - 1)}
            type="button"
          >
            Previous
          </button>
          <span>Page {currentPage} of {pageCount}</span>
          <button
            className="table-action"
            disabled={currentPage >= pageCount}
            onClick={() => setPage((current) => current + 1)}
            type="button"
          >
            Next
          </button>
        </div>
      </div>
    </section>
  );
}
