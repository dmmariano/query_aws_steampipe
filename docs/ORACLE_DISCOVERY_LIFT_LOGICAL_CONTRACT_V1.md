# Oracle Discovery/Lift Logical Contract v1

Status: PARTIAL_PHYSICAL_CONTRACT_READY

This document defines the logical contract expected by Backend, RM, and DBA for
the Discovery/Lift Oracle-first path. The first physical base for the Lift
multi-project Workplan contract now exists in the connected runtime schema of
the current Autonomous Database.

## Domains

| Domain | Logical contract | Physical status |
|---|---|---|
| Tenant scope | `client_id`, `project_id`, `provider`, `environment` | READY_CA_DISC_LIFT_V1 |
| Active projects | selectable project registry | READY_CA_DISC_LIFT_V1 |
| Run-control | run lifecycle and batch lifecycle | READY_CA_DISC_LIFT_V1 |
| Writer | metadata-only run/event/artifact package API | READY_CA_DISC_LIFT_V1 |
| Journal | append-only run/event log | READY_CA_DISC_LIFT_V1 |
| Projection | incremental read model by scope and cursor | PENDING_BACKEND_API |
| DTO | public sanitized Lift payload | PENDING_BACKEND_API |
| Resources | inventory resources read model | PENDING_DBA |
| Dependencies | account-account, app-app, app-database graph | PENDING_DBA |
| Value/cost | aggregated value and cost metrics | PENDING_DBA |
| Files | metadata-only file records, no content | PENDING_DBA |
| Progress/events | runtime progress and public state | PARTIAL_CA_DISC_LIFT_JOURNAL |

## Physical Contract V1

The following physical names are DBA-approved for v1 and were created in the
connected runtime schema. Schema is the connected database owner namespace;
tablespace was not changed.

| Physical name | Purpose |
|---|---|
| `CA_DISC_LIFT_PROJECTS` | active/eligible project registry by tenant scope |
| `CA_DISC_LIFT_RUNS` | run-control and idempotency |
| `CA_DISC_LIFT_JOURNAL` | append-only event journal |
| `CA_DISC_LIFT_ARTIFACTS` | opaque artifact references |
| `CA_DISC_LIFT_PROJECTS_SCOPE_IX` | project selection lookup |
| `CA_DISC_LIFT_RUNS_SCOPE_IX` | run polling lookup |
| `CA_DISC_LIFT_JOURNAL_CURSOR_IX` | incremental journal cursor lookup |
| `CA_DISC_LIFT_API` | approved package boundary for run/event/artifact writes |

Endpoint alias: `cloudarchdb_high`.

## Remaining Placeholder Contracts

The following aliases remain placeholders until Backend/RM/DBA provide the next
approved contract.

| Placeholder | Meaning |
|---|---|
| `DBA_APPROVED_PROJECTION_API` | public incremental projection surface |
| `DBA_APPROVED_RUNTIME_PROGRESS_API` | deployed runtime progress surface |
| `DBA_APPROVED_RESOURCE_PROJECTION` | resources projection |
| `DBA_APPROVED_DEPENDENCY_PROJECTION` | dependency graph projection |
| `DBA_APPROVED_VALUE_COST_PROJECTION` | value/cost projection |
| `DBA_APPROVED_FILES_METADATA_PROJECTION` | files metadata-only projection |
| `DBA_APPROVED_POOL_LIMITS` | pool min/max/increment/wait/statement cache |

## Run-Control And Idempotency

Required fields:

- `run_id`
- `batch_id`
- `event_id`
- `event_sequence`
- `client_id`
- `project_id`
- `provider`
- `environment`
- `idempotency_key`
- `source_fingerprint`
- `payload_digest`
- `projection_cursor`
- `observed_at`
- `committed_at`
- `rollback_run_marker`

Official states:

- `PENDING`
- `RUNNING`
- `BATCH_COMMITTED`
- `COMMITTED`
- `EMPTY`
- `FAILED_RETRYABLE`
- `FAILED_FINAL`
- `CANCELLED`
- `ROLLED_BACK`

Idempotency contract:

- Natural key must include tenant scope and source identity.
- `idempotency_key` must be deterministic for the same logical event.
- Duplicate events must not produce duplicate projection rows.
- Retry must be bounded and must preserve the original `run_id` and batch
  lineage.
- Commit boundary is batch-level unless DBA explicitly approves another unit.
- Rollback is logical by `run_id` or rollback marker; destructive delete is not
  permitted as the default rollback mechanism.

## Grants Model

Runtime should receive the minimum privileges required:

- Prefer `EXECUTE` on DBA-approved packages/procedures.
- Prefer `SELECT` on DBA-approved projections/views.
- Avoid direct DML from runtime users.
- No broad DDL privileges.
- No broad owner privileges.
- Separate writer and reader capabilities where possible.
- DBA/admin capability must stay outside application runtime.

## Fail-Closed Isolation

Every read and write must validate these dimensions before any pool query,
procedure call, projection read, export, or DTO rendering:

- `client_id`
- `project_id`
- `provider`
- `environment`

Acceptable mechanisms:

- DBA-approved VPD policy.
- DBA-approved application context.
- DBA-approved stored API parameter validation.
- Equivalent mechanism documented by DBA.

Failure mode:

- Invalid or missing scope returns public sanitized error.
- No partial query or write is allowed before scope validation.
- Internal reason, schema details, object names, and query diagnostics are not
  exposed to public DTOs.

## Operational Limits

DBA/Infra must approve concrete values. Until then these remain placeholders:

| Limit | Placeholder |
|---|---|
| Batch size | `DBA_APPROVED_BATCH_SIZE` |
| Page size | `DBA_APPROVED_PAGE_SIZE` |
| Statement timeout | `DBA_APPROVED_STATEMENT_TIMEOUT_MS` |
| Connect timeout | `DBA_APPROVED_CONNECT_TIMEOUT_MS` |
| Circuit breaker threshold | `DBA_APPROVED_CIRCUIT_BREAKER` |
| Pool min | `DBA_APPROVED_POOL_MIN` |
| Pool max | `DBA_APPROVED_POOL_MAX` |
| Pool increment | `DBA_APPROVED_POOL_INCREMENT` |
| Pool wait timeout | `DBA_APPROVED_POOL_WAIT_TIMEOUT_MS` |
| Statement cache size | `DBA_APPROVED_STATEMENT_CACHE_SIZE` |

Internal metrics:

- p95 latency by operation.
- query/procedure call count.
- retry count.
- timeout count.
- pool saturation.
- circuit breaker open/close events.
- rows accepted/rejected per batch, sanitized and tenant-scoped.

## Healthcheck

Allowed healthcheck levels:

| Level | Allowed test | Public output |
|---|---|---|
| Config-only | Required references are present and well-shaped | `oracle_config=READY/PARTIAL/MISSING` |
| Import-only | Oracle driver import and version check | `oracle_driver=READY/MISSING` |
| Wallet metadata | Wallet path exists and permissions are compatible | `oracle_wallet=READY/PARTIAL/MISSING` |
| Pool dry-run | Pool config parses without opening data query | `oracle_pool_config=READY/PARTIAL/MISSING` |

Blocked without DBA approval:

- Querying customer data.
- Exposing schema/object names.
- Exposing endpoint, OCID, wallet content, or secret plaintext.
- Running `SELECT` against application tables.
- Running DDL, DML, grants, or procedures that mutate state.

## Public Incremental API Shape

Expected logical request:

```text
GET /api/lift/oracle/progress?client_id=&provider=&project_id=&cursor=
```

Expected public response fields:

```text
status
projection
events
next_cursor
retry_after_ms
```

Allowed public statuses:

- `READY`
- `INGEST_PENDING`
- `EMPTY_FILTER`
- `ZERO_REAL`
- `ERROR`
- `UNAUTHORIZED`
- `FEATURE_DISABLED`
- `TIMEOUT`
- `CIRCUIT_OPEN`

Public response must be sanitized and must not expose schema internals, query
text, credentials, OCIDs, endpoint details, file content, or customer content.
