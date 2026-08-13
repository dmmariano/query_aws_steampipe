# Oracle Discovery/Lift DDL Execution Evidence

Date: 2026-08-11

Status: EXECUTED

Scope: approved Oracle physical base for Lift multi-project Workplan v1.

## Authorization Boundary

User-approved execution target:

- Server: `oracle-ai`
- Runtime app base: `/srv/cloud-architect/app`
- Database connection alias: `cloudarchdb_high`
- Autonomous Database: current database reached by the runtime wallet/TNS
- Schema: connected runtime schema
- Tablespace: unchanged

Approved object allowlist:

- `CA_DISC_LIFT_PROJECTS`
- `CA_DISC_LIFT_RUNS`
- `CA_DISC_LIFT_JOURNAL`
- `CA_DISC_LIFT_ARTIFACTS`
- `CA_DISC_LIFT_PROJECTS_SCOPE_IX`
- `CA_DISC_LIFT_RUNS_SCOPE_IX`
- `CA_DISC_LIFT_JOURNAL_CURSOR_IX`
- `CA_DISC_LIFT_API`

Explicitly excluded from this execution:

- user/schema creation;
- tablespace changes;
- grants;
- deploy or restart;
- Moinhos reprocessing;
- customer-content reads;
- DML outside DDL side effects;
- objects outside the `CA_DISC_LIFT_*` allowlist.

## Script Evidence

Approved DDL script hash:

```text
f895dc3cf1e3d8ec6552a81d8becb414667e5800ec8a27d8ff82205abac89763  db/oracle/discovery_lift_multi_project_v1.sql
```

Approved rollback script hash:

```text
70af791f7fc3b645b7a990a0c16def5d10116a607e4280b24eedd5cc633f4ab4  db/oracle/discovery_lift_multi_project_v1_rollback.sql
```

Server-side copied script hashes matched the local hashes before execution.

## Preflight

Sanitized preflight result:

```json
{
  "ADB_CONNECT": "OK",
  "DUAL_READONLY": "OK",
  "TARGET_EXISTING": [],
  "TARGET_EXISTING_COUNT": 0
}
```

## Execution Result

Sanitized DDL execution result:

```json
{
  "DDL_APPLY": "OK",
  "STATEMENTS_EXECUTED": 9,
  "CREATED_TARGETS": [
    "CA_DISC_LIFT_API",
    "CA_DISC_LIFT_ARTIFACTS",
    "CA_DISC_LIFT_JOURNAL",
    "CA_DISC_LIFT_JOURNAL_CURSOR_IX",
    "CA_DISC_LIFT_PROJECTS",
    "CA_DISC_LIFT_PROJECTS_SCOPE_IX",
    "CA_DISC_LIFT_RUNS",
    "CA_DISC_LIFT_RUNS_SCOPE_IX"
  ]
}
```

Oracle reports `CA_DISC_LIFT_API` as both `PACKAGE` and `PACKAGE BODY`, so the
post-execution object count is nine `USER_OBJECTS` rows for eight approved
object names.

## Postcheck

Sanitized postcheck result:

- `CA_DISC_LIFT_API` package: `VALID`
- `CA_DISC_LIFT_API` package body: `VALID`
- Four approved tables: `VALID`
- Three approved indexes: `VALID`
- Constraints observed: 58, all `ENABLED` and `VALIDATED`
- Row counts immediately after DDL:
  - `CA_DISC_LIFT_PROJECTS`: 0
  - `CA_DISC_LIFT_RUNS`: 0
  - `CA_DISC_LIFT_JOURNAL`: 0
  - `CA_DISC_LIFT_ARTIFACTS`: 0

No secret plaintext, wallet content, full endpoint descriptor, customer data,
OCID, grants, deploy, restart, or reprocessing action is recorded in this
evidence.

## Current State

The Oracle physical object-absence blocker for this v1 scope is removed.

Remaining blockers are not Oracle object-creation blockers:

- Backend must bind the server-only adapter/API to the approved package and
  object contract.
- RM must approve any deploy/restart candidate separately.
- Public DTO/projection route is not yet deployed.
- VPD/application context and split grants are not created in this v1 execution.
- Domain producers for resources, dependencies, value/cost, files metadata, and
  runtime progress are not populated by this DDL.
