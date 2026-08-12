# Oracle DBA Delta v1.1 Read API Pre-Edit

Date: 2026-08-12

Status: DOCUMENTAL_PRE_EDIT_ONLY / EXTERNAL_APPROVAL_REQUIRED

Base package ref: `704bdcf6bc54e63b15ebf4263bffc533e718d444`

Prior execution ref: `0519aa4198a1a15fbacf53f01b2c5588329ebfd2`

Scope: proposed minimal Oracle v1.1 delta to unblock Backend server-side
integration without direct SQL inference.

This document does not authorize DDL, DML, grants, deploy, restart, data reads,
or Moinhos reprocessing. It is a review package for DBA/Infra/RM approval.

## Current v1 Blocker

The physical v1 base exists, but it is not sufficient for BE real integration:

- grants observed on `CA_DISC_LIFT_*`: `0`;
- `CA_DISC_LIFT_API` exposes mutation procedures only;
- active-projects read API: `MISSING_IN_V1`;
- run projection/DTO read API: `MISSING_IN_V1`;
- journal cursor read API: `MISSING_IN_V1`;
- artifact read API: `MISSING_IN_V1`;
- VPD/application context: `MISSING_IN_V1`;
- public DTO/projection surface: `MISSING_IN_V1`.

Backend must not infer direct table SQL for missing operations.

## Proposed v1.1 Physical Delta

Preferred new read-only package:

- `CA_DISC_LIFT_READ_API`

Rationale: keep write and read grants segregated. `CA_DISC_LIFT_API` remains the
mutation package. `CA_DISC_LIFT_READ_API` becomes the approved projection/read
boundary.

Views proposed for v1.1 minimal: `NONE`.

Tables proposed for v1.1 minimal: `NONE`.

Indexes proposed for v1.1 minimal: `NONE`, unless DBA query plan review proves
one is required.

## Mandatory Scope Filters

Every read signature must require these filters:

- `p_client_id`
- `p_provider`
- `p_environment`

Project filter:

- `p_project_id` is required for project-list filtering when reading a single
  project.
- For multi-project run projection, `p_project_id` is optional. If supplied, the
  run must contain that project. If omitted, the run must still match
  `client_id + provider + environment`.

Fail-closed behavior:

- missing scope returns sanitized `INVALID_SCOPE`;
- unknown scope returns sanitized `NOT_FOUND`;
- unauthorized scope returns sanitized `UNAUTHORIZED`;
- invalid cursor returns sanitized `INVALID_CURSOR`;
- no internal schema, SQL text, ORA message, owner, wallet, endpoint, or data
  content may be returned.

## Proposed Read Signatures

All signatures below are proposed only. They are `MISSING` until DBA approves
and executes a v1.1 DDL package change.

### `LIST_ACTIVE_PROJECTS`

Purpose: return selectable projects for the modal.

```sql
procedure list_active_projects(
  p_client_id in varchar2,
  p_provider in varchar2,
  p_environment in varchar2,
  p_project_id in varchar2 default null,
  p_page_size in number default 100,
  p_page_cursor in varchar2 default null,
  p_next_cursor out varchar2,
  p_result out sys_refcursor
);
```

Required output columns:

- `client_id`
- `provider`
- `environment`
- `project_id`
- `project_label`
- `active`
- `eligible_for_workplan`
- `blocked_reason_code`
- `last_projection_cursor`

Rules:

- default filter returns only rows with `active='Y'` and
  `eligible_for_workplan='Y'`;
- disabled-row mode may be added later, but must return sanitized reason codes
  only;
- page cursor is opaque to Backend/UI.

### `GET_RUN_PROJECTION`

Purpose: return one sanitized run-level DTO projection.

```sql
procedure get_run_projection(
  p_run_id in varchar2,
  p_client_id in varchar2,
  p_provider in varchar2,
  p_environment in varchar2,
  p_project_id in varchar2 default null,
  p_result out sys_refcursor
);
```

Required output columns:

- `run_id`
- `idempotency_key`
- `status`
- `client_id`
- `provider`
- `environment`
- `project_ids_json`
- `project_count`
- `source_snapshot_ref`
- `approval_required`
- `approval_status`
- `approval_ref`
- `approval_reason_code`
- `rollback_run_marker`
- `journal_cursor`
- `created_at`
- `updated_at`

Artifact refs may be returned as nullable columns if DBA approves the join:

- `workload_builder_ref`
- `workplan_ref`
- `manifest_ref`

Counts not physically available in v1 must be returned as `NULL` or omitted;
Backend must not synthesize totals from renderer-side project cards.

### `LIST_RUN_EVENTS`

Purpose: return sanitized journal events by cursor/page.

```sql
procedure list_run_events(
  p_run_id in varchar2,
  p_client_id in varchar2,
  p_provider in varchar2,
  p_environment in varchar2,
  p_project_id in varchar2 default null,
  p_after_cursor in varchar2 default null,
  p_page_size in number default 100,
  p_next_cursor out varchar2,
  p_result out sys_refcursor
);
```

Required output columns:

- `run_id`
- `event_id`
- `event_sequence`
- `event_type`
- `event_status`
- `client_id`
- `provider`
- `environment`
- `project_id_ref`
- `batch_id`
- `observed_at`
- `committed_at`
- `projection_cursor`
- `retry_after_ms`

Rules:

- order by `event_sequence`;
- cursor must be server-generated and opaque;
- `event_payload_json` must not be returned unless DBA/Backend explicitly
  approves a sanitized public payload shape.

### `LIST_RUN_ARTIFACTS`

Purpose: return opaque artifact references for one scoped run.

```sql
procedure list_run_artifacts(
  p_run_id in varchar2,
  p_client_id in varchar2,
  p_provider in varchar2,
  p_environment in varchar2,
  p_project_id in varchar2 default null,
  p_result out sys_refcursor
);
```

Required output columns:

- `run_id`
- `artifact_type`
- `artifact_ref`
- `artifact_status`
- `created_at`

`metadata_json` is `MISSING_FROM_PUBLIC_CONTRACT` until sanitized keys are
approved. Artifact references must remain opaque.

### `HEALTHCHECK_READONLY`

Purpose: runtime healthcheck without exposing internals or reading customer
data.

```sql
procedure healthcheck_readonly(
  p_result out sys_refcursor
);
```

Allowed output:

- `oracle_contract_version`
- `database_connectivity_status`
- `package_status`
- `read_api_status`

Blocked output:

- schema owner;
- object counts that expose tenant data;
- endpoint descriptor;
- wallet path/content;
- secret reference value;
- SQL text;
- ORA stack.

## Proposed Pagination And Limits

These values are proposed for v1.1 approval. They are not approved limits until
DBA/RM accepts them.

| Limit | Proposed value | Rule |
|---|---:|---|
| Default page size | 100 | used when caller omits `p_page_size` |
| Max page size | 500 | values above max fail closed |
| Max `project_ids[]` per prepare request | 50 | enforced by Backend before write |
| Statement timeout | `PENDING_RM_CONFIG` | must be set outside the package |
| Connect timeout | `PENDING_RM_CONFIG` | must be set outside the package |
| Retry attempts | 3 | proposed Backend policy for transient failures |
| Retry backoff | 250ms, 1000ms, 2000ms | proposed Backend policy |
| Circuit breaker | `PENDING_RM_CONFIG` | required before deploy |

Read procedures are read-only and must not commit.

Existing v1 write procedures still do not commit. Backend must own transaction
boundaries explicitly.

## Idempotency And Run-Control

No v1.1 change to v1 keys:

- `CA_DISC_LIFT_RUNS.run_id` remains primary run identity;
- `CA_DISC_LIFT_RUNS.idempotency_key` remains unique;
- `CA_DISC_LIFT_JOURNAL(event_id)` remains unique;
- `CA_DISC_LIFT_JOURNAL(run_id, event_sequence)` remains ordered journal key.

Backend rule:

- deterministic idempotency key must include contract version, `client_id`,
  `provider`, `environment`, canonical sorted `project_ids[]`, generation mode,
  and server-side source snapshot reference when present.

Projection rule:

- duplicate prepare must return existing run projection only after v1.1 read API
  exists;
- until then, duplicate prepare in BE real mode is `BLOCKED_READ_API_MISSING`.

## Sanitized Status Contract

Approved public status values for missing/fail-closed cases:

- `FEATURE_DISABLED`
- `INVALID_SCOPE`
- `UNAUTHORIZED`
- `NOT_FOUND`
- `EMPTY`
- `PENDING`
- `READY`
- `FAILED_RETRYABLE`
- `FAILED_FINAL`
- `TIMEOUT`
- `CIRCUIT_OPEN`
- `READ_API_MISSING`
- `GRANTS_MISSING`
- `PROJECTION_MISSING`

Backend must map internal database errors to these values and log only
sanitized diagnostics.

## Grants Delta

No grants are created by this document.

Proposed segregated model for approval:

| Principal | Proposed privilege | Object | Notes |
|---|---|---|---|
| Runtime writer | `EXECUTE` | `CA_DISC_LIFT_API` | write package only |
| Runtime reader | `EXECUTE` | `CA_DISC_LIFT_READ_API` | read package only |
| Runtime web handler | no direct table DML | `CA_DISC_LIFT_*` tables | package boundary required |
| Runtime web handler | no broad DDL | schema | never grant |
| DBA/owner | owner capability | `CA_DISC_LIFT_*` | outside app runtime |

Preferred implementation: definer-rights read package with no direct table
`SELECT` grants to web/runtime users.

If a separate runtime DB user is introduced, grants remain `MISSING` until DBA
executes an approved grant script.

## VPD / Application Context Roadmap

No VPD or application context is created by this document.

Roadmap for approval:

- create application context for tenant scope;
- trusted setter package accepts `client_id`, `provider`, `environment`, and
  optional `project_id`;
- read/write APIs set and validate context before any table access;
- VPD policy applies fail-closed predicates to `CA_DISC_LIFT_PROJECTS`,
  `CA_DISC_LIFT_RUNS`, `CA_DISC_LIFT_JOURNAL`, and `CA_DISC_LIFT_ARTIFACTS`;
- direct table access remains blocked for runtime users even after VPD unless
  DBA explicitly grants it.

Proposed context attributes:

- `client_id`
- `provider`
- `environment`
- `project_id`
- `run_id`

Until this is approved and executed, v1.1 must rely on mandatory procedure
parameters plus package-side validation.

## Backend Boundary Until v1.1 Approval

Allowed:

- pre-edit interface work;
- fake/default-OFF adapter tests;
- DTO shape matching this proposed read API;
- validation sentinels for scope, cursor, renderer no-sum, no local files,
  no CSV/SQLite/query_aws production path.

Blocked:

- real read adapter;
- real pool usage for missing read operations;
- direct SQL against `CA_DISC_LIFT_*` tables from Backend;
- grants;
- deploy/restart;
- customer data reads;
- Moinhos reprocessing.

## Approval Checklist

External approval must explicitly decide:

- package name: `CA_DISC_LIFT_READ_API` or extension of `CA_DISC_LIFT_API`;
- exact read signatures;
- whether any views are required;
- max page size and project count;
- timeout/circuit-breaker runtime values;
- grant recipients as sanitized aliases;
- VPD/application context timing;
- rollback for v1.1 package/grant changes.
