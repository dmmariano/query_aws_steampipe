# Oracle DBA / Data Architecture Canonical Verdict

Status: PARTIAL / BE_REAL_BLOCKED_PENDING_V1_1

Provenance for this document: Git candidate documentation. Runtime/DB evidence
must be revalidated on `oracle-ai` before this is treated as an operational
handoff.

This is the canonical Oracle DBA/Data Architecture position for the
Cloud Architect Discovery/Lift Oracle-first workstream. It records the
sanitized logical contract and the approved Oracle physical base created for
the first Lift multi-project contract. It is not a deployment candidate and not
evidence of production data.

## Scope

Applies to:

- BE-ORA-WRITER / Discovery Oracle-first.
- Lift/Moinhos server-side consumer.
- Lift multi-project Workplan preparation, tracked as `#203`.
- Writer, journal, projection/API incremental, DTOs, run-control, grants,
  pool, healthcheck, and data governance.

Still does not authorize:

- Additional DDL, DML outside the approved package, grants, deploy, restart,
  collection, reprocessing, or customer data reads.
- Plaintext secrets, wallet content, full endpoints, sensitive OCIDs, customer
  content, or real object names not explicitly DBA-approved.
- Use of local Mac, local CSV, local SQLite, local query_aws, or local tests as
  production diagnosis.

## Verdict

| Item | Position |
|---|---|
| Overall status | PARTIAL |
| Physical DBA contract | EXECUTED_FOR_CA_DISC_LIFT_V1 |
| Existing Autonomous authorization for Discovery/Lift | CONFIRMED_FOR_THIS_SCOPE |
| Physical schema | Connected runtime schema in the current Autonomous Database |
| Tablespace | Not changed, not required for this approval |
| Physical names | `CA_DISC_LIFT_PROJECTS`, `CA_DISC_LIFT_RUNS`, `CA_DISC_LIFT_JOURNAL`, `CA_DISC_LIFT_ARTIFACTS`, `CA_DISC_LIFT_API`, approved indexes |
| Backend allowed now | Pre-edit/default-OFF adapter preparation only |
| Runtime Oracle pool | PENDING_BACKEND_RM |
| Real integration | BLOCKED_PENDING_V1_1_READ_API_AND_GRANTS |
| Data operations | No customer-content read or Moinhos reprocessing without separate workflow authorization |

## Server-Side Evidence Summary

Server inspection and DBA execution on 2026-08-11 confirmed:

- Hosted runtime `oracle-ai` is reachable and healthy.
- `/srv/cloud-architect/app` is present with service user/group
  `cloudarchitect`.
- Runtime is `NO_GIT_REPO`.
- `oracledb` is present in the app venv.
- ADB wallet references and wallet files are present.
- ADB connection using `cloudarchdb_high` succeeded.
- Approved `CA_DISC_LIFT_*` tables, indexes, package, and package body were
  created and validated.
- Created tables were empty immediately after DDL execution.
- OCI CLI/config are not required for this database DDL path.
- Backend route/API, runtime pool wiring, DTO publication, and RM deploy remain
  pending.

Detailed sanitized evidence is recorded in
`docs/ORACLE_SERVER_READONLY_EVIDENCE_2026-08-11.md` and
`docs/ORACLE_DISCOVERY_LIFT_DDL_EXECUTION_EVIDENCE_2026-08-11.md`.

## Lift Multi-Project Addendum

The `Preparar Workplan` multi-project flow is a logical extension only. It
requires `client_id`, `provider`, and `project_ids[]` as server input and must
return a server-computed DTO with `run_id`, `idempotency_key`, status, counts,
opaque artifact refs, approval, and journal cursor.

The UI/renderer must not sum project data, infer project eligibility, read local
artifacts, or reprocess Moinhos. It may only submit selected project ids and
display the server projection.

Detailed contract is recorded in
`docs/ORACLE_LIFT_MULTI_PROJECT_WORKPLAN_CONTRACT_V1.md`.

## Canonical Architecture Position

The current Autonomous Database is approved for this Discovery/Lift v1 scope.
The first physical contract uses the connected runtime schema in the same
Autonomous Database. Schema is a logical namespace/owner; tablespace is storage
allocation. No tablespace change was requested or performed.

Required separation:

- Use `CA_DISC_LIFT_*` object prefixes plus mandatory logical scope columns:
  `client_id`, `provider`, `environment`, and `project_id`.
- Do not use `ca_knowledge_*`, vector indexes, or RAG storage as operational
  source of truth for Discovery/Lift.
- Treat Knowledge/RAG as a consumer or adjacent domain only when an explicit
  contract says so.

## Required DBA Physical Contract

The approved v1 physical contract contains:

- Connected runtime schema in current Autonomous Database.
- Endpoint alias `cloudarchdb_high`.
- Tables: `CA_DISC_LIFT_PROJECTS`, `CA_DISC_LIFT_RUNS`,
  `CA_DISC_LIFT_JOURNAL`, `CA_DISC_LIFT_ARTIFACTS`.
- Indexes: `CA_DISC_LIFT_PROJECTS_SCOPE_IX`, `CA_DISC_LIFT_RUNS_SCOPE_IX`,
  `CA_DISC_LIFT_JOURNAL_CURSOR_IX`.
- Package: `CA_DISC_LIFT_API`.
- Rollback script restricted to the same `CA_DISC_LIFT_*` objects.

Remaining DBA/Architecture gaps:

- VPD/application-context policy is not created.
- Grants are not created because runtime currently uses the connected schema.
- Public projection/read procedures are missing from `CA_DISC_LIFT_API`.
- v1.1 read package/grants delta is required before BE real integration.
- Resources, dependency graph, value/cost, files metadata, and runtime progress
  domain producers are not populated.
- Operational pool limits must be implemented by Backend/RM.
- Any hardening DDL beyond this v1 object list requires a new explicit gate.

## Backend Boundary

Backend may now implement:

- Pre-edit adapter and DTO code against documented v1/v1.1 contracts, behind
  feature flag default OFF.
- Fake Oracle tests and fixtures with no real credentials or customer data.
- Sanitized JSON contracts.
- Fail-closed guards before pool/query/write.
- Idempotency and run-control mapping to the approved objects.
- Sentinels against CSV, pandas, SQLite, dual-read, local artifacts, and local
  query_aws as production path.

Backend must not implement:

- Additional DDL/DML.
- Direct grants.
- Runtime deploy without RM.
- Customer-content reads or Moinhos reprocessing without explicit workflow
  authorization.
- Real read adapter until v1.1 read API and grants are approved.

## RM / Dispatcher Boundary

RM may proceed to a deploy review only after all are true:

- Backend provides SHA/base/parent/ref, branch/worktree, claims, gates, and
  rollback.
- Runtime target has a traceable base or deployment package.
- Pool limits, healthcheck method, rollback, and default-OFF feature gate are
  present without exposing secret content.

Dispatcher should keep BE real integration blocked until v1.1 read API/grants
approval and separate oracle-ai validation are available.
