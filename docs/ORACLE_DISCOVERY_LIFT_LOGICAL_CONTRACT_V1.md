# Oracle Discovery/Lift Logical Contract v1

Status: SANITIZED_LOGICAL_CONTRACT_ONLY

This document defines the logical contract expected by Backend, RM, and DBA for
the Discovery/Lift Oracle-first path. It deliberately uses placeholders instead
of physical object names.

## Domains

| Domain | Logical contract | Physical status |
|---|---|---|
| Tenant scope | `client_id`, `project_id`, `provider`, `environment` | PENDING_DBA |
| Run-control | run lifecycle and batch lifecycle | PENDING_DBA |
| Writer | metadata-only batch publish API | PENDING_DBA |
| Journal | append-only run/event log | PENDING_DBA |
| Projection | incremental read model by scope and cursor | PENDING_DBA |
| DTO | public sanitized Lift payload | PENDING_DBA |
| Resources | inventory resources read model | PENDING_DBA |
| Dependencies | account-account, app-app, app-database graph | PENDING_DBA |
| Value/cost | aggregated value and cost metrics | PENDING_DBA |
| Files | metadata-only file records, no content | PENDING_DBA |
| Progress/events | runtime progress and public state | PENDING_DBA |

## Placeholder Objects

The following aliases are placeholders. They are not object names.

| Placeholder | Meaning |
|---|---|
| `DBA_APPROVED_DISCOVERY_LIFT_OWNER` | DBA-approved logical owner/schema |
| `DBA_APPROVED_WRITER_API` | DBA-approved package/procedure for writes |
| `DBA_APPROVED_JOURNAL_OBJECT` | DBA-approved append-only journal surface |
| `DBA_APPROVED_PROJECTION_API` | DBA-approved incremental projection surface |
| `DBA_APPROVED_RUNTIME_PROGRESS_API` | DBA-approved runtime progress surface |
| `DBA_APPROVED_RESOURCE_PROJECTION` | DBA-approved resources projection |
| `DBA_APPROVED_DEPENDENCY_PROJECTION` | DBA-approved dependency graph projection |
| `DBA_APPROVED_VALUE_COST_PROJECTION` | DBA-approved value/cost projection |
| `DBA_APPROVED_FILES_METADATA_PROJECTION` | DBA-approved files metadata-only projection |
| `DBA_APPROVED_SECRET_REFERENCE` | Secret manager reference, no plaintext |
| `DBA_APPROVED_ENDPOINT_ALIAS` | Sanitized endpoint/TNS alias |
| `DBA_APPROVED_WALLET_REFERENCE` | Wallet/TLS reference, no content |

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
