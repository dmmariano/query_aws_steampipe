# Oracle DBA Handoff For Backend, RM, And Dispatcher

Status: HOLD

This handoff records what is ready as sanitized architecture and what remains
blocked by DBA/Infra.

## What Was Created

- Canonical DBA/Data Architecture verdict.
- Logical Discovery/Lift Oracle contract v1.
- JSON schema for validating sanitized contract payloads.
- Server-side read-only evidence record for hosted Oracle readiness.

No code path was connected to Oracle. No DDL, DML, grants, deploy, restart,
collection, reprocessing, secret read, wallet read, endpoint exposure, or real
data access was performed.

Server evidence confirms wallet material and driver presence, but it does not
confirm Discovery/Lift authorization or readiness. Discovery/Lift secret
reference, endpoint/DSN, pool configuration, Oracle healthcheck,
writer/journal/projection/API, and DTO contract remain missing.

## Backend Next Step

Backend may build a fake-only/default OFF implementation using the logical
contract:

- Adapter interface.
- DTO model.
- Feature flag default OFF.
- Fake Oracle tests.
- Idempotency/run-control simulation.
- Public sanitization.
- Fail-closed scope validation.
- Sentinels against CSV, pandas, SQLite, dual-read, local query_aws, and local
  files as production path.

Backend must stop before:

- Real pool.
- Real writer call.
- Real journal/projection.
- Secret, wallet, endpoint, schema, grant, DDL, DML, or deploy.

## RM Next Step

RM must keep deploy blocked until Backend returns a candidate with:

- SHA/base/parent/ref.
- Branch/worktree.
- File claims and blobs.
- Gates.
- Rollback.
- Contract proving DBA/Infra physical approval.
- Secret reference, wallet/TLS, endpoint alias, pool limits, and healthcheck
  method without plaintext.

## Dispatcher Next Step

Dispatcher should keep BE-ORA-WRITER/Lift as external HOLD and assign:

- DBA/Infra owner for physical contract.
- Backend owner for fake-only/default OFF adapter.
- RM owner for later preflight after DBA contract and Backend candidate.

## DBA/Infra Required Response

DBA/Infra must provide sanitized approval or rejection for:

- Whether the existing Autonomous Database is authorized for Discovery/Lift.
- Logical separation from Knowledge/RAG.
- DBA-approved owner/schema aliases.
- DBA-approved write package/procedure aliases.
- DBA-approved journal/projection/API aliases.
- Grants model.
- Isolation mechanism.
- Pool limits and timeouts.
- Secret reference.
- Endpoint alias.
- Wallet/TLS reference.
- Read-only healthcheck method.

If any item is not approved, the answer must remain HOLD with the missing item
named as `*_MISSING` or `PENDING_DBA`.
