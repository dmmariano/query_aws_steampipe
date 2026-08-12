# Oracle Lift Multi-Project Workplan Contract v1

Status: SANITIZED_LOGICAL_CONTRACT_ONLY / HOLD

Issue: `#203`

This addendum extends the Discovery/Lift Oracle logical contract for the
`Preparar Workplan` flow. It defines a server-only multi-project job contract.
It does not authorize physical Oracle objects, DDL, DML, grants, deploy,
collection, reprocessing, secret access, wallet access, or customer data reads.

## Goal

The Lift UI must show active projects for a client and let the user select one
or more projects. A single click must create one server-side job that produces:

- one Workload Builder artifact;
- one Workplan artifact;
- one public sanitized DTO/projection for the selected project set.

The renderer must not aggregate, sum, infer scope, read local artifacts, or
trigger reprocessing by itself. It sends a selection and displays the server DTO.

## Logical Endpoints

The endpoint names below are logical. They are not deployed routes.

| Endpoint | Purpose | Physical status |
|---|---|---|
| `GET /api/lift/workplan/active-projects?client_id=&provider=` | List active projects eligible for selection | PENDING_DBA_BE |
| `POST /api/lift/workplan/prepare` | Create or return one server-side run for the selected project set | PENDING_DBA_BE |
| `GET /api/lift/workplan/runs/{run_id}` | Return sanitized status/projection for polling | PENDING_DBA_BE |
| `GET /api/lift/workplan/runs/{run_id}/events?cursor=` | Return sanitized incremental journal events | PENDING_DBA_BE |

## Prepare Input

Required fields:

- `client_id`
- `provider`
- `project_ids`

Optional fields:

- `environment`
- `request_id`
- `idempotency_key`
- `approval_ref`

Rules:

- `project_ids` must be a non-empty array.
- Server must trim, deduplicate, sort, and canonicalize `project_ids`.
- Server must reject unknown, inactive, unauthorized, duplicate-after-normalize,
  or cross-client project ids before any query/write/job dispatch.
- Maximum project count is `DBA_BE_APPROVED_MAX_PROJECTS_PER_RUN`.
- Empty selection returns a sanitized validation error and creates no run.

## Canonical Selection

Canonical selection fields:

- `client_id`
- `provider`
- `environment`
- sorted `project_ids`
- contract version
- requested generation mode

The canonical selection is the input to idempotency and run-control. The UI
selection order must not change the resulting idempotency key.

## Idempotency

`idempotency_key` must be deterministic for the same canonical selection and
generation mode.

Recommended logical formula:

```text
idempotency_key = SHA256(
  contract_version,
  client_id,
  provider,
  environment,
  sorted(project_ids),
  generation_mode,
  source_snapshot_ref
)
```

`source_snapshot_ref` must be server-side and opaque. If no approved source
snapshot exists, the request must remain `INGEST_PENDING` or `BLOCKED`.

Duplicate behavior:

- Same canonical request returns the existing `run_id` and current projection.
- Same `request_id` with different canonical selection fails closed.
- Retry uses the same `run_id` unless DBA/BE policy explicitly creates a new
  run attempt.
- Reprocess requires explicit authorization and a new reason-coded request.

## Run-Control

One selected project set maps to one `run_id`.

Required run fields:

- `run_id`
- `idempotency_key`
- `client_id`
- `provider`
- `environment`
- `project_ids`
- `project_count`
- `request_id`
- `source_snapshot_ref`
- `status`
- `created_at`
- `updated_at`
- `approval`
- `rollback_run_marker`

Allowed run states:

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

Default policy:

- No partial public success: if one project is unauthorized or invalid, the run
  must not start.
- Per-project internal progress is allowed, but the public DTO must make clear
  whether the single run is ready, pending, failed, or blocked.
- Rollback is logical by `run_id`; destructive delete is not a default rollback.

## Journal

Journal must be append-only.

Required event fields:

- `run_id`
- `event_id`
- `event_sequence`
- `event_type`
- `event_status`
- `client_id`
- `provider`
- `environment`
- `project_ids_digest`
- `project_id_ref`
- `batch_id`
- `observed_at`
- `committed_at`
- `projection_cursor`
- `retry_after_ms`

Allowed public event types:

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

Public journal events must not expose schema names, object names, query text,
file paths, endpoint details, OCIDs, credentials, wallet content, or customer
content.

## Projection / DTO

The public DTO is the only renderer contract.

Required DTO fields:

- `run_id`
- `idempotency_key`
- `status`
- `client_id`
- `provider`
- `environment`
- `project_ids`
- `project_count`
- `counts`
- `artifact_refs`
- `approval`
- `journal_cursor`
- `next_poll_after_ms`
- `created_at`
- `updated_at`

Counts are server-computed. The renderer must not sum project-level values.

`counts` may include:

- `projects_selected`
- `projects_validated`
- `resources_total`
- `dependencies_total`
- `applications_total`
- `databases_total`
- `files_metadata_total`
- `value_items_total`
- `warnings_total`
- `errors_total`

`artifact_refs` are opaque references only:

- `workload_builder_ref`
- `workplan_ref`
- `manifest_ref`

Artifact refs must not expose local paths, bucket names, object keys, file
content, customer names, or storage credentials.

Approval fields:

- `approval_required`
- `approval_status`
- `approval_ref`
- `approval_reason_code`

Approval actor details must be omitted or represented by opaque references.

## Active Projects Projection

The active-projects projection must be server-side and fail-closed.

Required fields:

- `client_id`
- `provider`
- `project_id`
- `project_label`
- `environment`
- `active`
- `eligible_for_workplan`
- `blocked_reason_code`
- `last_projection_cursor`

Only active and eligible projects should be selectable by default. Inactive or
blocked projects may be returned only if the UI needs a disabled row with a
sanitized reason code.

## Distributed Job Contract

The job may distribute internal work per project, but the public contract stays
single-run:

- one request;
- one `run_id`;
- one idempotency key;
- one append-only journal stream;
- one status projection;
- one Workload Builder artifact ref;
- one Workplan artifact ref.

Internal project tasks must carry the parent `run_id` and a per-project
`project_task_id`. Public DTOs may expose per-project status only as sanitized
progress, never as independent artifact generation.

## Fail-Closed Isolation

Before any query, write, job enqueue, artifact publication, or DTO rendering,
the server must validate:

- client ownership;
- provider ownership;
- every requested project belongs to the client/provider;
- every requested project is active and eligible;
- environment is allowed for the client/provider/project set;
- requested project count is within limit;
- user/session/capability is authorized for the selected scope.

Recommended DBA mechanisms:

- VPD.
- Application context.
- Stored API validation.
- DBA-approved equivalent.

Until DBA approves a physical mechanism, this remains HOLD.

## Backend Fake-Only Pre-Edit Allowed

Backend may implement:

- fake active-projects projection;
- fake prepare-workplan job adapter;
- DTO model and JSON schema validation;
- in-memory journal for tests;
- deterministic idempotency for synthetic inputs;
- feature flag default OFF;
- fail-closed guards before fake write/job dispatch;
- tests for empty selection, duplicate ids, cross-client ids, inactive projects,
  unauthorized provider, replay, retry, rollback marker, and renderer no-sum.

Backend must not implement:

- real Oracle pool;
- real secret or wallet use;
- real writer/journal/projection binding;
- real artifact generation for Moinhos;
- reprocessing;
- DDL/DML/grants;
- deploy or restart.

## DBA / Infra Gaps

Required before real integration:

- Confirm whether existing Autonomous is approved for Discovery/Lift.
- Approve separate Discovery/Lift owner/schema or equivalent.
- Approve active-projects projection.
- Approve prepare-workplan writer API.
- Approve append-only journal.
- Approve run status/projection API.
- Approve artifact registry metadata-only surface.
- Approve VPD/application context or equivalent.
- Approve runtime grants.
- Approve secret reference, endpoint alias, wallet reference, and pool limits.
- Approve read-only Oracle healthcheck.

Without those approvals, the lane remains HOLD.
