# Oracle DBA Physical Handoff For Backend

Date: 2026-08-12

Status: DBA_PHYSICAL_V1_READY / BE_REAL_BLOCKED_PENDING_V1_1

Document package ref: `0519aa4198a1a15fbacf53f01b2c5588329ebfd2`

Scope: Discovery/Lift multi-cloud Workplan pre-edit and server-side integration.

Superseding pre-edit delta for real BE integration:
`docs/ORACLE_DBA_DELTA_V1_1_READ_API_PREEDIT_2026-08-12.md`.

Important: physical v1 does not unblock BE real integration by itself. Grants
are absent and the package does not expose active-projects read, run
projection/DTO, journal cursor, or artifact read operations.

This handoff is sanitized. It does not expose user, password, wallet content,
full DSN descriptor, schema owner, customer data, OCIDs, object-storage paths, or
client content.

## Evidence

Read-only metadata introspection on `oracle-ai` using `cloudarchdb_high`:

- ADB connection: `OK`
- `CA_DISC_LIFT_API`: `PACKAGE` and `PACKAGE BODY` are `VALID`
- Tables: all `VALID`
- Indexes: all `VALID`
- Constraints: `ENABLED` and `VALIDATED`
- Grants made by owner for these objects: `0`
- DDL/DML executed during this handoff: `NONE`
- Customer data read during this handoff: `NONE`

## Authorized Connection Contract

Runtime connection alias:

- `cloudarchdb_high`

Runtime may use only configured secret/wallet references. Do not place secret
plaintext in code, logs, DTOs, docs, issues, PRs, or chat.

Approved env/reference names:

- `CLOUD_ARCHITECT_ADB_USER`
- `CLOUD_ARCHITECT_ADB_PASSWORD_FILE`
- `CLOUD_ARCHITECT_ADB_WALLET`
- `CLOUD_ARCHITECT_ADB_WALLET_PASSWORD_FILE`
- `CLOUD_ARCHITECT_ADB_DSN`, only if it resolves to the approved alias or is
  overridden by explicit runtime config to `cloudarchdb_high`

## Physical Objects

| Object | Type | Runtime contract |
|---|---|---|
| `CA_DISC_LIFT_API` | Package | Public runtime mutation API for v1 |
| `CA_DISC_LIFT_PROJECTS` | Table | Physical active-project persistence; no package read API exists in v1 |
| `CA_DISC_LIFT_RUNS` | Table | Physical run-control persistence; write via package only |
| `CA_DISC_LIFT_JOURNAL` | Table | Physical append-only journal persistence; append via package only |
| `CA_DISC_LIFT_ARTIFACTS` | Table | Physical artifact-ref persistence; write via package only |
| `CA_DISC_LIFT_PROJECTS_SCOPE_IX` | Index | Internal lookup support |
| `CA_DISC_LIFT_RUNS_SCOPE_IX` | Index | Internal lookup support |
| `CA_DISC_LIFT_JOURNAL_CURSOR_IX` | Index | Internal lookup support |

Views created in v1: `NONE`.

Sequences/triggers/jobs created in v1: `NONE`.

## Package API

Approved package: `CA_DISC_LIFT_API`.

All package procedures are mutation procedures. None returns a result set or
DTO. There are no functions and no OUT parameters in v1.

### `REGISTER_RUN`

Purpose: create a run-control row. Duplicate idempotency/run key is swallowed by
the package and must be treated by Backend as idempotent replay requiring a
follow-up projection read. The package does not return the existing row.

```sql
procedure register_run(
  p_run_id in varchar2,
  p_idempotency_key in varchar2,
  p_client_id in varchar2,
  p_provider in varchar2,
  p_environment in varchar2,
  p_project_ids_json in clob,
  p_project_count in number,
  p_source_snapshot_ref in varchar2 default null,
  p_approval_required in char default 'N',
  p_approval_ref in varchar2 default null
);
```

DB behavior:

- inserts status `QUEUED`;
- sets `approval_status` to `PENDING` when `approval_required='Y'`;
- otherwise sets `approval_status` to `NOT_REQUIRED`;
- rejects null `client_id`, null `provider`, or `project_count < 1`;
- does not commit.

### `APPEND_EVENT`

Purpose: append one journal event for an existing run.

```sql
procedure append_event(
  p_run_id in varchar2,
  p_event_id in varchar2,
  p_event_sequence in number,
  p_event_type in varchar2,
  p_event_status in varchar2,
  p_client_id in varchar2,
  p_provider in varchar2,
  p_environment in varchar2,
  p_project_ids_digest in varchar2,
  p_projection_cursor in varchar2,
  p_project_id_ref in varchar2 default null,
  p_batch_id in varchar2 default null,
  p_retry_after_ms in number default null,
  p_event_payload_json in clob default null
);
```

DB behavior:

- writes `committed_at=systimestamp`;
- enforces `run_id` foreign key;
- enforces unique `event_id`;
- enforces primary key `(run_id, event_sequence)`;
- does not commit.

### `PUBLISH_ARTIFACT`

Purpose: upsert one opaque artifact reference by run and artifact type.

```sql
procedure publish_artifact(
  p_run_id in varchar2,
  p_artifact_type in varchar2,
  p_artifact_ref in varchar2,
  p_metadata_json in clob default null
);
```

DB behavior:

- `merge` by `(run_id, artifact_type)`;
- approved artifact types are `WORKLOAD_BUILDER`, `WORKPLAN`, `MANIFEST`;
- artifact refs are opaque and must not expose local paths, bucket names, object
  keys, credentials, or customer content;
- does not commit.

### `SET_RUN_STATUS`

Purpose: update run status and optional logical rollback marker.

```sql
procedure set_run_status(
  p_run_id in varchar2,
  p_status in varchar2,
  p_rollback_run_marker in varchar2 default null
);
```

DB behavior:

- updates `status`, `updated_at`, and optional `rollback_run_marker`;
- raises `RUN_NOT_FOUND` when no run matches;
- allowed statuses are constrained by `CA_DISC_LIFT_RUNS_STATUS_CK`;
- does not commit.

## Missing Package Operations

Do not ask Backend to infer direct SQL for these. They require a later approved
BE/DBA contract or a new package/view/API surface.

| Operation | v1 status |
|---|---|
| List active projects | `MISSING_IN_CA_DISC_LIFT_API` |
| Read run projection/DTO by `run_id` | `MISSING_IN_CA_DISC_LIFT_API` |
| Read journal events by cursor | `MISSING_IN_CA_DISC_LIFT_API` |
| Read artifact refs by `run_id` | `MISSING_IN_CA_DISC_LIFT_API` |
| Multi-cloud resources projection | `MISSING` |
| Dependency graph projection | `MISSING` |
| Value/cost projection | `MISSING` |
| Files metadata projection | `MISSING` |
| Runtime progress public projection | `MISSING` |

## Keys And Idempotency

| Surface | Key contract |
|---|---|
| `CA_DISC_LIFT_PROJECTS` | PK `(client_id, provider, environment, project_id)` |
| `CA_DISC_LIFT_RUNS` | PK `(run_id)` |
| `CA_DISC_LIFT_RUNS` | unique `(idempotency_key)` |
| `CA_DISC_LIFT_JOURNAL` | PK `(run_id, event_sequence)` |
| `CA_DISC_LIFT_JOURNAL` | unique `(event_id)` |
| `CA_DISC_LIFT_ARTIFACTS` | PK `(run_id, artifact_type)` |

Backend idempotency key must be deterministic for:

- contract version;
- `client_id`;
- `provider`;
- `environment`;
- canonical sorted `project_ids[]`;
- generation mode;
- server-side `source_snapshot_ref` when present.

`project_ids_json` must be canonical JSON. Renderer order must not change the
idempotency key.

## Run-Control

Run statuses allowed by DB:

- `VALIDATING`
- `REJECTED`
- `QUEUED`
- `RUNNING`
- `PARTIAL_RETRYABLE`
- `READY`
- `EMPTY`
- `FAILED_RETRYABLE`
- `FAILED_FINAL`
- `CANCELLED`
- `ROLLED_BACK`

Journal event types allowed by DB:

- `REQUEST_ACCEPTED`
- `PROJECT_SET_VALIDATED`
- `RUN_QUEUED`
- `RUN_STARTED`
- `PROJECT_PROGRESS`
- `ARTIFACTS_PUBLISHED`
- `APPROVAL_REQUIRED`
- `APPROVAL_RECORDED`
- `RUN_READY`
- `RUN_FAILED`
- `RUN_CANCELLED`
- `RUN_ROLLED_BACK`

Journal event statuses allowed by DB:

- `INFO`
- `READY`
- `PENDING`
- `WARNING`
- `ERROR`

Approval statuses allowed by DB:

- `NOT_REQUIRED`
- `PENDING`
- `APPROVED`
- `REJECTED`

## Batch, Commit, Retry, Timeout, Page Limits

DB-enforced:

- `project_count >= 1`
- `event_sequence >= 0`
- `retry_after_ms` column exists for retry hints
- `batch_id` column exists for batch lineage
- package procedures do not commit

Transaction boundary:

- Backend/RM must treat each package call as part of an explicit application
  transaction.
- Recommended default: commit `register_run` plus the initial journal event in
  one transaction; commit later event/status/artifact updates per run stage.
- On exception before commit, rollback the current transaction and append a
  failure event only in a new explicit transaction when appropriate.

Not DB-enforced in v1:

- max `project_ids[]`;
- batch size;
- page size;
- statement timeout;
- connect timeout;
- retry count;
- pool min/max/increment/wait;
- statement cache size;
- circuit breaker threshold.

Backend/RM must define these in runtime configuration before deploy. Until then
they are `PENDING_BACKEND_RM_CONFIG`, not DBA object blockers.

## Multi-Cloud Isolation

Mandatory scope columns:

- `client_id`
- `provider`
- `environment`
- `project_id` for project-level rows

Multi-project runs store:

- `project_ids_json`
- `project_count`
- `project_ids_digest` on journal events

Fail-closed rules:

- no pool call, package call, projection read, DTO rendering, artifact publish,
  or job enqueue before validating `client_id`, `provider`, `environment`, and
  every selected `project_id`;
- unknown provider/environment/project returns sanitized rejection;
- inactive or ineligible project returns sanitized rejection;
- mixed-client or mixed-provider project sets are rejected;
- renderer must not aggregate totals, infer project eligibility, read local
  files, or trigger reprocessing.

VPD/application context:

- not created in v1;
- required for future split-user or broad direct-table access;
- current v1 isolation is scoped columns plus stored API parameter validation.

## Grants

Observed grants made on `CA_DISC_LIFT_*`: `0`.

No grant DDL was executed. Current physical contract assumes the connected
runtime schema owns the objects. If Backend/RM introduces a separate runtime
database user, grants are `MISSING` and require a new explicit DBA gate.

Minimum future grant model, if split-user is introduced:

- runtime writer: `EXECUTE` on `CA_DISC_LIFT_API`;
- runtime reader: `SELECT` only on DBA-approved projection surfaces;
- no broad DDL;
- no direct table DML from web handlers;
- admin/owner capability outside application runtime.

## Rollback

Approved rollback artifact:

- `db/oracle/discovery_lift_multi_project_v1_rollback.sql`

Rollback scope:

- drops `CA_DISC_LIFT_API`;
- drops `CA_DISC_LIFT_ARTIFACTS`;
- drops `CA_DISC_LIFT_JOURNAL`;
- drops `CA_DISC_LIFT_RUNS`;
- drops `CA_DISC_LIFT_PROJECTS`;
- removes only the `CA_DISC_LIFT_*` v1 physical base.

Rollback has not been executed.

Do not run rollback after real integration starts without a data-retention and
release rollback decision. Default runtime rollback is logical by `run_id` and
`rollback_run_marker`, not destructive delete.

## Backend Next Slice

Allowed:

- prepare a server-side adapter to `CA_DISC_LIFT_API` only for existing package
  procedures, default OFF;
- keep feature flag default `OFF`;
- implement DTO models and fake tests;
- implement fail-closed request validation;
- implement idempotency calculation and run-control mapping;
- implement no-local-artifact/no-CSV/no-SQLite sentinels.

Blocked:

- BE real integration until v1.1 read API/grants are approved;
- new DDL/DML;
- grants;
- deploy/restart;
- customer data reads;
- reprocessing Moinhos;
- direct SQL inference for operations marked `MISSING_IN_CA_DISC_LIFT_API`;
- exposing secrets or physical owner/schema.
