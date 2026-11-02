# Canonical data model

## Identity and provenance

- `players`, `teams`, `events`, and `games` use internal UUID primary keys.
- `external_identities` maps a canonical entity type and UUID to a source-specific external identifier. A source may use different IDs for the same entity over time; aliases are retained.
- `data_sources` describes upstream websites, APIs, files, and human curation.
- `import_batches` records each ingestion attempt, status, timing, and source. Imported rows retain source and batch references.
- Verification is represented explicitly; imported data is not silently treated as verified.

## Competition structure

- `disciplines` and `rulesets` make format and rules explicit.
- `seasons` represent a named competition period.
- `events` represent tournaments or other organized competitions; `event_divisions` describe their competition categories.
- `event_entries` connect teams to event divisions.
- `games` are independent records within an event/division and can be linked to external game identities.
- `game_team_results` store each side's score and outcome. This avoids assuming a fixed two-team schema in the event record.

## Historical participation

- `team_memberships` represent player-team relationships with optional start/end dates, season, and role. Corrections should close or supersede a period rather than erase history.
- `game_player_participation` represents actual participation in a game and is independent of a season roster.
- `player_game_stats` stores normalized player/game/stat/value observations. It supports imported and native statistics without locking the schema to a fixed set of columns.

## Analytics

- `rating_models` versions algorithm definitions and configuration.
- `rating_environments` define independent rating populations (for example, division/format/season scope).
- `team_rating_snapshots` store rating, uncertainty, model/environment, effective time, and data cutoff.
- Rating outputs are derived data and must be rebuildable from source games and a pinned model version.

## Core invariants

1. Never use an external provider ID as the canonical primary key.
2. Do not delete historical membership merely because a player changes teams.
3. Do not infer game participation from roster membership.
4. Keep source attribution and verification visible.
5. Preserve source payloads in a controlled staging/raw layer when licensing and retention terms permit.
6. Keep raw imported values separate from normalized values when transformation or interpretation may change.
7. Do not compare ratings across environments or model versions without an explicit normalization step.
8. Store UTC timestamps; preserve source-local event dates/time zones where relevant.
