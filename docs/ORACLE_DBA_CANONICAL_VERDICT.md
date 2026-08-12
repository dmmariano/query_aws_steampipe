# Oracle DBA / Data Architecture Canonical Verdict

Status: HOLD

This is the canonical Oracle DBA/Data Architecture position for the
Cloud Architect Discovery/Lift Oracle-first workstream. It is a sanitized
architecture and authorization contract placeholder. It is not a DBA physical
contract, not a deployment candidate, and not evidence of production data.

## Scope

Applies to:

- BE-ORA-WRITER / Discovery Oracle-first.
- Lift/Moinhos server-side consumer.
- Writer, journal, projection/API incremental, DTOs, run-control, grants,
  pool, healthcheck, and data governance.

Does not authorize:

- DDL, DML, grants, deploy, restart, collection, reprocessing, or data reads.
- Plaintext secrets, wallet content, full endpoints, sensitive OCIDs, customer
  content, or real object names not explicitly DBA-approved.
- Use of local Mac, local CSV, local SQLite, local query_aws, or local tests as
  production diagnosis.

## Verdict

| Item | Position |
|---|---|
| Overall status | HOLD |
| Physical DBA contract | MISSING |
| Existing Autonomous authorization for Discovery/Lift | NOT_CONFIRMED |
| Physical names | No DBA-approved schema/package/view/grant names |
| Backend allowed now | Fake-only artifacts, default OFF, sanitized logical contract |
| Runtime Oracle pool | BLOCKED |
| Real integration | BLOCKED |
| Data operations | BLOCKED |

## Server-Side Evidence Summary

Read-only server inspection on 2026-08-11 confirmed:

- Hosted runtime `oracle-ai` is reachable and healthy.
- `/srv/cloud-architect/app` is present with service user/group
  `cloudarchitect`.
- Runtime is `NO_GIT_REPO`.
- `oracledb` is present in the app venv.
- ADB wallet references and wallet files are present.
- OCI CLI/config are missing on the host.
- Discovery/Lift DSN, secret references, pool settings, Oracle healthcheck,
  writer, journal, projection/API, and DTO contract remain missing.

Detailed sanitized evidence is recorded in
`docs/ORACLE_SERVER_READONLY_EVIDENCE_2026-08-11.md`.

## Canonical Architecture Position

The existing Autonomous Database may be used for Discovery/Lift only if DBA/Infra
explicitly confirms it as authorized for this operational domain. If approved,
Discovery/Lift must be logically separated from the Knowledge/RAG domain.

Required separation:

- Use a separate Discovery/Lift owner/schema or DBA-approved equivalent.
- Do not use `ca_knowledge_*`, vector indexes, or RAG storage as operational
  source of truth for Discovery/Lift.
- Treat Knowledge/RAG as a consumer or adjacent domain only when an explicit
  contract says so.

## Required DBA Physical Contract

DBA/Infra must return a sanitized contract containing DBA-approved values or
aliases for:

- Discovery/Lift owner/schema.
- Writer package/procedure for batch metadata-only ingestion.
- Append-only journal/run events object or API.
- Projection/view/API incremental by `client_id + provider + project_id`.
- Resources projection.
- Dependency graph projection for account-account, app-app, and app-database.
- Value/cost projection.
- Files metadata-only projection.
- Runtime progress/events projection.
- Grants model with runtime least privilege.
- Isolation mechanism, such as VPD, application context, or DBA-approved
  equivalent.
- Secret reference, endpoint alias, wallet/TLS reference, pool settings, and
  read-only healthcheck method.

Until those values are explicitly DBA-approved, physical names remain
`DBA_APPROVED_*` placeholders and must not be inferred.

## Backend Boundary

Backend may implement only:

- Adapter and DTO code behind feature flag default OFF.
- Fake Oracle tests and fixtures with no real credentials or data.
- Sanitized JSON contracts.
- Fail-closed guards before pool/query/write.
- Idempotency and run-control simulation.
- Sentinels against CSV, pandas, SQLite, dual-read, local artifacts, and local
  query_aws as production path.

Backend must not implement:

- Real pool configuration.
- DDL/DML.
- Direct grants.
- Physical schema/object names.
- Real writer/journal/projection bindings.
- Runtime deploy.

## RM / Dispatcher Boundary

RM may proceed only after all are true:

- DBA/Infra provides the sanitized physical contract.
- Backend provides SHA/base/parent/ref, branch/worktree, claims, gates, and
  rollback.
- Runtime target has a traceable base or deployment package.
- Secret reference, wallet/TLS, endpoint alias, pool limits, and healthcheck
  method are authorized without exposing secret content.

Dispatcher must keep this workstream in HOLD until that condition is met.
