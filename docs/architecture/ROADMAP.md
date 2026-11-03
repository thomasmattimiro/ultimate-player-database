# Ultimate Player Database — implementation roadmap

## Product decisions

- **Audience:** players, teams, fans, coaches, organizers, analysts, and researchers.
- **Historical scope:** all eras for which reliable records can be assembled.
- **Statistics:** integrate existing third-party records and support native stat collection.
- **Ambition:** an ecosystem, not only a player directory.

## Architecture principles

1. A modular Next.js monolith backed by PostgreSQL is the right starting point. Split services only when a measured scaling or ownership need justifies it.
2. PostgreSQL is the canonical record. Next.js owns presentation, application workflows, and server-side orchestration.
3. Internal UUIDs identify canonical players, teams, events, and games. External IDs are source-specific aliases, never primary keys.
4. Historical relationships are effective-dated and append-preserving. A roster change must not rewrite a past season.
5. Every imported or manually curated fact should be traceable to its source and import batch, with verification state.
6. Rulesets and formats are explicit so historical and emerging forms of the sport can coexist.
7. Analytics are reproducible: each rating run belongs to a named, versioned model and environment.
8. Build team competitive ratings before individual ratings. Validate team ratings against held-out games before publishing them.
9. Public data is readable without authentication; privileged ingestion and curation writes happen server-side.
10. Preserve raw and normalized source values separately, subject to source terms and retention requirements.

## Phases and gates

### Phase 0 — recover and baseline
- Inspect the repository, Supabase project, and Vercel project.
- Confirm the real source-of-truth branch and record deployment failure causes.
- Keep infrastructure changes isolated from production data.

**Exit:** a working repository baseline and a known database state.

### Phase 1 — application foundation
- Establish Next.js App Router, strict TypeScript, linting, environment variable conventions, and Supabase SSR/browser clients.
- Establish reusable layout, navigation, typography, and route conventions.
- Verify a production build before adding feature complexity.

**Exit:** local install, typecheck, lint, and production build succeed.

### Phase 2 — canonical data model
- Create source registry, import batches, canonical player/team/event/game entities, and external identity mapping.
- Model seasons, disciplines, formats/rulesets, event entries, rosters, and game participation independently.
- Preserve historical membership with effective dates.
- Attach provenance and verification state to ingested facts.

**Exit:** migrations apply cleanly; key relationships and historical queries are tested.

### Phase 3 — reference data and ingestion foundation
- Seed the Ultimate discipline, an initial provisional player-stat dictionary, and internal manual/legacy data sources.
- Keep rulesets empty until exact governing-body editions and effective dates are documented.
- Add secure raw-record staging, payload hashes, normalized payloads, validation states, candidate identity matches, and source-stat mappings.
- Keep staging, external identity crosswalks, and batch diagnostics inaccessible to browser roles.

**Exit:** schema and generated types are current; reference seeds are idempotent; staging tables pass RLS/privilege checks.

### Phase 4 — ingestion adapters and legacy reconciliation
- Build a source-adapter contract, normalizers, validators, identity resolver, and server-only canonical commit service.
- First reconcile existing legacy game results and text-based team names without deleting or rewriting source facts.
- Add a review workflow for ambiguous player/team matches and source conflicts.
- Add one external source only after access, terms, licensing, and stable identifiers are understood.

**Exit:** a source can be re-imported without duplicate staged records or canonical entities, and ambiguous identities require review.

### Phase 5 — searchable public directories
- Team season standings with sortable, filterable, paginated results and CSV export. **First slice complete.**
- Event-by-event team results nested within season standings. **First slice complete.**
- Player, team, event, season, and tournament directory pages.
- Profile pages with historical rosters, participation, and source citations.
- Server-side filtering, sorting, pagination, and global search.

**Exit:** users can navigate reliable records from a player to teams, events, and games.

### Phase 6 — team ratings and competitive analytics
- Define independent rating environments (division, gender/competition class, format, season scope).
- Implement versioned team TrueSkill-style ratings, with game score differential as a carefully calibrated performance signal.
- Persist rating snapshots and game-level rating updates.
- Backtest predictive accuracy, calibration, cold starts, inactivity, and schedule strength.

**Exit:** published ratings include model version, data cutoff, uncertainty, and validation metrics.

### Phase 7 — player statistics and comparisons
- Finalize canonical stat semantics and source mappings.
- Build season/career aggregates, per-game rates, percentiles, and comparison views.
- Keep player impact ratings separate from raw box-score totals.

**Exit:** player comparisons are explainable and can be traced to underlying games/stat lines.

### Phase 8 — native statistics and ecosystem integrations
- Add live/native scorekeeping and player-level event capture.
- Support tournament organizer, team, and player workflows.
- Expand import adapters and API access.

**Exit:** native and external data coexist under the same canonical model and provenance rules.

### Phase 9 — advanced ecosystem
- Maps, movement timelines, recruiting/college pipelines, team builder, scouting, similarity, projections, and machine learning.
- Add predictive models only after sufficient high-quality longitudinal data exists.
- Keep future products as modules on the same canonical data foundation.

## Immediate implementation order

1. Restore a non-empty application scaffold and reproducible package setup. **Complete.**
2. Apply and test the canonical schema migration. **Complete.**
3. Add generated database types and typed data-access modules. **Types generated; typed data access remains next.**
4. Seed reference catalogs. **Initial seed complete; stat semantics remain provisional.**
5. Add secure ingestion staging and identity candidate review schema. **Schema complete; application pipeline remains next.**
6. Build the first legacy-data adapter and reconcile game/team identities.
7. Build read-only directory pages backed by verified Supabase records. **Team-season standings and event breakdown are the first implemented directory slice.**

## Explicitly deferred

- Player ratings before reliable participation and stat data.
- Machine learning before adequate sample size and validation.
- Microservices, event streaming, and complex distributed infrastructure.
- Hardcoded demo statistics presented as real records.
- Automatic identity merges based only on names or similarity scores.
