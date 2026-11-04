# Ingestion architecture

## Design goal

Accept data from multiple providers and native collection workflows without allowing an external record to silently overwrite a canonical player, team, event, game, or statistic.

The first implementation is a controlled pipeline inside the existing Next.js + Supabase architecture. Do not introduce microservices or a message broker until measured volume requires them.

## Pipeline

1. **Source registration** — data_sources records the provider or curation channel, its type, terms URL, and active status.
2. **Batch creation** — create an import_batches row for each scheduled, manual, or native submission run.
3. **Raw staging** — store each source record in ingestion_records with its source key, external ID, source URL, SHA-256 payload hash, and unchanged JSON payload.
4. **Normalization** — adapters map source-specific fields into a versioned normalized payload. Raw payloads are never rewritten.
5. **Validation** — validate required fields, types, dates, scores, references, and source-specific constraints. Invalid rows are rejected with structured error_details.
6. **Identity resolution** — first look up external_identities; then generate candidate matches in ingestion_record_matches. Exact source IDs can be deterministic. Name/date/location similarity is only a candidate, never an automatic merge.
7. **Review** — ambiguous matches and conflicting facts remain in needs_review. A curator accepts or rejects a candidate.
8. **Canonical commit** — only validated, resolved records in ready_to_commit are written to canonical tables. Writes are idempotent and retain data_source_id, import_batch_id, and verification state.
9. **Batch closeout** — update batch counts and status (completed, partial, or failed) and retain diagnostics.

## Storage responsibilities

- import_batches: one execution and aggregate counters.
- ingestion_records: one raw source record per batch, plus normalized form, hash, state, and errors.
- ingestion_record_matches: proposed canonical matches and human review decisions.
- external_identities: durable source-to-canonical crosswalk after a match is accepted.
- source_stat_mappings: explicit mapping from provider-specific stat keys to canonical stat definitions. New mappings start as needs_review.
- Canonical tables: trusted, queryable product data. Raw source payloads do not belong in canonical entity columns.

## Security and retention

- Raw payloads, batch diagnostics, identity crosswalks, and mapping decisions are server-only. RLS is enabled and browser roles have no table privileges.
- Public directories read only the approved canonical catalog tables.
- Never expose the Supabase service-role key to browser code.
- Respect each provider's terms, licensing, privacy requirements, and retention rules before storing raw payloads. Store a payload only when permitted; otherwise retain the minimum permitted source reference and normalized evidence.
- The adapter computes SHA-256 before insert. The database enforces a 64-character lowercase hexadecimal hash and per-batch record-key uniqueness.

## Application boundaries

- **Source adapter:** fetches or receives provider data and emits a common raw-record envelope.
- **Normalizer:** deterministic, source-specific transformation with a version identifier.
- **Validator:** schema and business-rule checks; no writes to canonical tables.
- **Identity resolver:** deterministic external-ID lookup plus candidate generation.
- **Commit service:** server-only transaction that upserts canonical rows and external identity mappings.
- **Review interface:** displays source evidence, candidate entities, confidence, and decision history.

Keep these modules separated in the Next.js codebase (for example, app/lib/ingestion/adapters, normalizers, validation, identity, and commit). Route handlers should authenticate/authorize the operator and orchestrate the services; they should not contain source-specific parsing logic.

## First implementation target

Use the existing legacy game results as a controlled migration/import exercise before connecting an external provider. The current legacy games store winner/loser names as text, so team identity resolution must happen before writing game_team_results. Do not infer that a matching team name is sufficient when multiple historical teams may share it.

## Operational invariants

- Re-running the same batch cannot create duplicate staged records.
- Re-running a committed source record cannot create duplicate canonical entities or external identity mappings.
- No uncertain identity match is automatically merged.
- Every canonical fact remains attributable to a source and batch.
- A source correction creates an auditable update; it does not erase historical facts.
- Raw data and normalized data remain separately inspectable.
