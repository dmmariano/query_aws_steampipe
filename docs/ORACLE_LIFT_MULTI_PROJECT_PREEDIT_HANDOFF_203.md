# Lift Multi-Project Pre-Edit Handoff

Issue: `#203`

Status: BACKLOG / HOLD_EXTERNAL_DATA_ARCHITECTURE

This handoff defines the safe pre-edit boundary for the `Preparar Workplan`
multi-project flow. It is intended for Backend and UX planning. It is not a
runtime implementation and not a DBA physical contract.

## Objective

Allow the Lift page to show active projects for a client and submit one or more
selected projects to a server-only job that creates one Workload Builder and one
Workplan.

## User-Facing Flow

1. User opens `Preparar Workplan`.
2. UI loads active projects from server projection.
3. User selects one or more projects.
4. UI submits `client_id`, `provider`, and `project_ids[]`.
5. Server validates the whole selection fail-closed.
6. Server returns a DTO with `run_id`, `idempotency_key`, `status`, counts,
   opaque artifact refs, approval, and poll cursor.
7. UI displays DTO state and polls server projection.

The UI must not compute totals by summing project cards and must not read local
files or trigger reprocessing.

## Backend Claims For Future Pre-Edit

Allowed fake-only/default OFF claims:

- DTO model for active projects.
- DTO model for prepare-workplan response.
- Fake active-projects store.
- Fake prepare-workplan service.
- In-memory append-only journal for tests.
- Deterministic idempotency for canonical `project_ids[]`.
- Fail-closed scope validation before fake job creation.
- Feature flag default OFF.
- Tests for project selection and renderer contract.

Blocked claims:

- Oracle physical pool.
- DBA object names.
- Grants.
- DDL/DML.
- Real writer/journal/projection.
- Real artifact generation or storage writes.
- Moinhos reprocessing.
- Deploy/RM.

## UX Claims For Future Pre-Edit

Allowed fake-only/default OFF claims:

- Modal or selection control backed by server DTO.
- Disabled state for blocked/ineligible projects using reason codes.
- Submit disabled until at least one eligible project is selected.
- Poll status by `run_id`.
- Display counts and artifact refs exactly as returned by server.

Blocked UX behavior:

- Renderer-side aggregation.
- Local CSV/SQLite/artifact reads.
- Reprocess button without server authorization.
- Exposing artifact paths, object keys, or internal errors.

## Gates For Backend Pre-Edit

Minimum gates:

- JSON schema validation for request and response.
- Tests for empty `project_ids[]`.
- Tests for duplicate project ids after normalization.
- Tests for cross-client and unauthorized provider.
- Tests for inactive/ineligible projects.
- Tests for idempotent replay returning existing `run_id`.
- Tests for changed selection with same `request_id` failing closed.
- Tests for append-only journal ordering.
- Tests for rollback marker without destructive delete.
- Sentinels against CSV, pandas, SQLite, local query_aws, and local artifacts.

## Rollback

For future fake-only code:

- Feature flag OFF.
- `git revert <candidate_sha>`.
- No data rollback because real data operations remain prohibited.

For future real integration:

- DBA-approved logical rollback by `run_id`.
- RM release restore.
- No destructive delete as default rollback.

## Exit Criteria From HOLD

This lane can leave Data Architecture HOLD only when DBA/Infra provides a
sanitized physical contract for:

- active projects projection;
- prepare-workplan writer API;
- append-only journal;
- run status/projection API;
- artifact registry metadata-only references;
- isolation mechanism;
- grants;
- secret reference;
- endpoint alias;
- pool limits;
- read-only healthcheck.
