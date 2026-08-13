# Lift Multi-Project Pre-Edit Handoff

Issue: `#203`

Status: BACKLOG / ORACLE_PHYSICAL_V1_READY / BACKEND_RM_PENDING

This handoff defines the safe pre-edit boundary for the `Preparar Workplan`
multi-project flow. It is intended for Backend and UX planning. The Oracle
physical v1 base now exists; this is still not a runtime implementation or RM
deploy approval.

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

Allowed default-OFF claims:

- DTO model for active projects.
- DTO model for prepare-workplan response.
- Proposed active-projects adapter shape from
  `docs/ORACLE_DBA_DELTA_V1_1_READ_API_PREEDIT_2026-08-12.md`.
- Prepare-workplan service scaffolding against existing `CA_DISC_LIFT_API`
  write signatures.
- Proposed journal polling DTO shape from the v1.1 read API delta.
- Fake/in-memory stores for tests.
- Deterministic idempotency for canonical `project_ids[]`.
- Fail-closed scope validation before job creation.
- Feature flag default OFF.
- Tests for project selection and renderer contract.

Blocked claims:

- Real read adapter until v1.1 read API/grants approval.
- Direct SQL against `CA_DISC_LIFT_*` tables for missing read operations.
- Grants.
- Additional DDL.
- Direct table DML outside `CA_DISC_LIFT_API`.
- Real artifact generation or storage writes.
- Moinhos reprocessing.
- Deploy/RM.

## UX Claims For Future Pre-Edit

Allowed default-OFF claims:

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

For future pre-edit code:

- Feature flag OFF.
- `git revert <candidate_sha>`.
- No data rollback because real data operations remain prohibited.

For deployed real integration:

- DBA-approved logical rollback by `run_id`.
- RM release restore.
- No destructive delete as default rollback.

## Remaining Exit Criteria

Data Architecture object-absence HOLD is removed for the v1 Oracle base.
Backend/RM still need:

- active projects route/API;
- prepare-workplan route/API;
- run status/projection API;
- DTO publication;
- pool limits;
- circuit breaker/timeouts;
- RM deploy gate;
- optional VPD/application context or split grants for the next hardening step.
