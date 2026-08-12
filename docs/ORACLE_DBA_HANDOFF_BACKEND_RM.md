# Oracle DBA Handoff For Backend, RM, And Dispatcher

Status: DBA_PHYSICAL_V1_EXECUTED / BACKEND_RM_PENDING

This handoff records what is ready as sanitized architecture and what remains
blocked outside the DBA physical v1 object-creation scope.

## What Was Created

- Canonical DBA/Data Architecture verdict.
- Logical Discovery/Lift Oracle contract v1.
- Logical Lift multi-project Workplan addendum v1 for `#203`.
- JSON schema for validating sanitized contract payloads.
- Server-side read-only evidence record for hosted Oracle readiness.
- Physical DDL and rollback scripts for DBA/RM approval.
- Approved Oracle `CA_DISC_LIFT_*` physical base executed in the current
  Autonomous Database via the runtime connection alias `cloudarchdb_high`.
- Backend physical handoff for the next implementation slice:
  `docs/ORACLE_DBA_PHYSICAL_HANDOFF_BACKEND_2026-08-12.md`.

No application code path was deployed or connected to the new objects. No
grants, deploy, restart, collection, Moinhos reprocessing, endpoint exposure, or
real customer data access was performed.

Server evidence confirms wallet material, driver presence, ADB connectivity, and
successful creation of the approved `CA_DISC_LIFT_*` objects. Backend route/API,
runtime pool configuration, DTO publication, and RM deploy remain pending.

## Backend Next Step

Backend may build the implementation using the approved physical contract:

- Adapter interface.
- DTO model.
- Multi-project active-projects and prepare-workplan services.
- Feature flag default OFF.
- Fake Oracle tests plus integration code behind the default-OFF flag.
- Idempotency/run-control mapping to `CA_DISC_LIFT_RUNS`,
  `CA_DISC_LIFT_JOURNAL`, and `CA_DISC_LIFT_API`.
- Public sanitization.
- Fail-closed scope validation.
- Sentinels against CSV, pandas, SQLite, dual-read, local query_aws, and local
  files as production path.

Backend must stop before:

- Deploy/restart.
- Additional DDL or grants.
- Direct table DML from web handlers outside the approved package boundary.
- Real Workload Builder or Workplan generation for Moinhos without workflow
  authorization.
- Customer-content reads or local artifact fallback.

## RM Next Step

RM must keep deploy blocked until Backend returns a candidate with:

- SHA/base/parent/ref.
- Branch/worktree.
- File claims and blobs.
- Gates.
- Rollback.
- Contract proving use of the executed `CA_DISC_LIFT_*` physical base.
- Pool limits and healthcheck method without plaintext.
- Feature flag default OFF and rollback.

Physical DDL scripts are available under `db/oracle/`. The v1 create script was
executed once under explicit approval. The rollback script remains approved only
for removing the same `CA_DISC_LIFT_*` objects if that rollback is requested.

## Dispatcher Next Step

Dispatcher should move BE-ORA-WRITER/Lift out of DBA object-absence HOLD and
assign:

- Backend owner for adapter/API implementation.
- RM owner for later preflight after Backend candidate.
- DBA owner for any additional hardening DDL, VPD/application context, grants,
  or projection expansion.

## DBA/Infra Required Response

DBA/Infra v1 has provided and executed:

- Existing Autonomous Database authorization for this v1 Discovery/Lift scope.
- Logical separation by `CA_DISC_LIFT_*` prefix plus `client_id`, `provider`,
  `environment`, and `project_id`.
- Connected runtime schema; no separate schema or tablespace change.
- Write package alias: `CA_DISC_LIFT_API`.
- Journal object: `CA_DISC_LIFT_JOURNAL`.
- Run-control object: `CA_DISC_LIFT_RUNS`.
- Active-project object: `CA_DISC_LIFT_PROJECTS`.
- Artifact object: `CA_DISC_LIFT_ARTIFACTS`.
- Endpoint alias: `cloudarchdb_high`.
- Read-only healthcheck method: mTLS wallet/TNS connection plus `dual`.

Remaining DBA/RM/BE gaps must be named specifically, not collapsed back into a
generic DBA HOLD.
