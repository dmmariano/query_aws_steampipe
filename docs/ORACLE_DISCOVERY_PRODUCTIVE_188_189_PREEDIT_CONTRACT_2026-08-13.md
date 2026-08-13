# Oracle Discovery Productive #188/#189 Pre-Edit Contract

Date: 2026-08-13

Status: DOCUMENTAL_PRE_EDIT_ONLY / EXTERNAL_APPROVAL_REQUIRED

Provenance: Git canonical references plus sanitized read-only Autonomous
metadata gathered from `oracle-ai`. Local runtime, local DB, local CSV, local
SQLite, local tests, and Mac paths are not production evidence.

This document is a DBA/Data Architecture pre-edit for productive Discovery
items:

- `#188` BE-ORA-01 - Oracle Resources API
- `#189` BE-GRAPH-02 - Oracle Property Graph

It does not authorize DDL, DML, grants, deploy, restart, customer data reads,
collection, reprocessing, Graph Studio mutation, or direct table coupling by
Backend.

## Canonical References

| Ref | Status |
|---|---|
| Cloud Architect `#188` | OPEN / Backlog as of GitHub read-only check on 2026-08-13 |
| Cloud Architect `#189` | OPEN / Bloqueado as of GitHub read-only check on 2026-08-13 |
| `#188` registration | `origin/main` `19a71201a22d21c065b90d095d4898063c37fcd5` |
| `#188` limited backend | `origin/main` `0526d129a1520396641a3c4d0572318ced5609a5` |
| `#188` documental record | `origin/main` `906ece8e0d6a34ce0da293b7674c629db56208b8` |
| Frontend separation ref | `6076a88296a02691ad56860951846a89edca3629`; no Oracle promotion |
| External DBA PR | `dmmariano/query_aws_steampipe#3` |
| External DBA PR head before this delta | `ae1be599c04a74a8a95f738c6754514c894ab106` |
| External DBA PR base | `319b8992d345c933bd325a0829be71754abef2de` |
| Lift physical DDL evidence | `0519aa4198a1a15fbacf53f01b2c5588329ebfd2` |

## Read-Only Autonomous Findings

Sanitized metadata evidence from `oracle-ai` confirms only these relevant
surfaces:

| Surface | Finding | Contract impact |
|---|---|---|
| `CA_DISC_LIFT_*` | Tables/indexes and `CA_DISC_LIFT_API` exist and are valid | Lift v1 operational lane only |
| `CA_DISC_LIFT_API` | Mutation package only; no read/projection procedures | Not sufficient for #188/#189 productive read APIs |
| Grants on `CA_DISC_LIFT_*` | `0` observed | Runtime grant contract missing |
| `CA_KNOWLEDGE_*` | Knowledge tables/indexes/audit exist and are valid | Knowledge domain only, not Resources/Graph operational truth |
| Resources API physical contract | Not observed in sanitized metadata audit | MISSING |
| DependencySnapshot physical contract | Not observed in sanitized metadata audit | MISSING |
| Property Graph production contract | Not observed in sanitized metadata audit | MISSING |
| Atomic inventory publication contract | Not observed in sanitized metadata audit | MISSING |
| Discovery single-flight contract | Not observed in sanitized metadata audit | MISSING |
| Discovery productive audit journal | Not observed in sanitized metadata audit | MISSING |

Do not infer physical object names from this table. Names below are contract
placeholders until DBA approves an object list.

## Contract Matrix

| Capability | Current state | Required approved contract |
|---|---|---|
| Execution/run-control | PARTIAL for Lift only; MISSING for productive Discovery | `DBA_APPROVED_DISCOVERY_EXECUTION_API` |
| Provisional resources | MISSING | `DBA_APPROVED_DISCOVERY_RESOURCE_STAGE_CONTRACT` |
| Resources read projection | MISSING | `DBA_APPROVED_DISCOVERY_RESOURCE_PROJECTION_API` |
| DependencySnapshot | MISSING | `DBA_APPROVED_DEPENDENCY_SNAPSHOT_CONTRACT` |
| Property graph model/query | MISSING | `DBA_APPROVED_DISCOVERY_PROPERTY_GRAPH_CONTRACT` |
| Atomic inventory publication | MISSING | `DBA_APPROVED_ATOMIC_INVENTORY_PUBLICATION_API` |
| Idempotency | PARTIAL for Lift only; MISSING for #188/#189 | `DBA_APPROVED_DISCOVERY_IDEMPOTENCY_CONTRACT` |
| Single-flight | MISSING | `DBA_APPROVED_DISCOVERY_SINGLE_FLIGHT_API` |
| Audit/journal | Knowledge audit exists; Discovery productive audit MISSING | `DBA_APPROVED_DISCOVERY_AUDIT_JOURNAL` |
| Runtime grants | `0` grants observed for Lift lane; #188/#189 MISSING | `DBA_APPROVED_RUNTIME_EXECUTE_GRANTS` |
| VPD/app context | MISSING | `DBA_APPROVED_VPD_APP_CONTEXT_POLICY` |
| Pool/timeout/circuit breaker | MISSING for productive Discovery | `DBA_APPROVED_DISCOVERY_POOL_LIMITS` |

## Scope And Isolation

Every productive Discovery operation must fail closed before query or write
unless these scoped inputs are present and authorized:

- `client_id`
- `provider`
- `environment`
- `project_id`
- `actor_id` or equivalent runtime actor claim
- `request_id`
- `contract_version`

Optional, when the operation is execution-bound:

- `run_id`
- `batch_id`
- `source_snapshot_ref`
- `idempotency_key`

Public DTOs must not expose schema owner, SQL text, table names, wallet paths,
bucket paths, object keys, customer content, raw provider payloads, full
endpoint descriptors, or sensitive OCIDs.

## Proposed Package Boundaries

The exact physical package names are pending DBA approval. Backend must consume
only approved package/view/API contracts, not direct table SQL.

### Execution API

`DBA_APPROVED_DISCOVERY_EXECUTION_API`

Minimum operations:

- `begin_execution`: claim a scoped run idempotently.
- `append_execution_event`: append sanitized progress/audit events.
- `set_execution_status`: transition run state.
- `discard_execution`: logical rollback/discard without destructive delete.
- `get_execution_status`: read sanitized run status.

Required run states:

- `REQUESTED`
- `QUEUED`
- `RUNNING`
- `STAGED`
- `PUBLISHED`
- `FAILED`
- `CANCELLED`
- `DISCARDED`

State transitions must be monotonic except explicit logical discard/rollback.

### Resources API

`DBA_APPROVED_DISCOVERY_RESOURCE_STAGE_CONTRACT`

Minimum write-side contract:

- stage metadata-only resource rows by `run_id + batch_id`;
- validate scope before accepting a row;
- reject unknown provider/project/environment scope;
- commit by bounded batch only;
- return sanitized counts and status codes only.

`DBA_APPROVED_DISCOVERY_RESOURCE_PROJECTION_API`

Minimum read-side contract:

- list resources by `client_id + provider + environment + project_id`;
- return opaque refs and approved metadata fields only;
- page with an opaque cursor;
- never ask UI/renderer to sum or reconcile backend totals.

### DependencySnapshot / Graph

`DBA_APPROVED_DEPENDENCY_SNAPSHOT_CONTRACT`

Minimum contract:

- record a versioned dependency snapshot for account-account, app-app, and
  app-database relationships;
- bind every vertex and edge to `client_id`, `provider`, `environment`,
  `project_id`, source ref, source hash, and ingestion/run ref;
- publish one immutable snapshot ref for a consumer DTO.

`DBA_APPROVED_DISCOVERY_PROPERTY_GRAPH_CONTRACT`

Minimum contract:

- define whether the approved graph is SQL Property Graph, PGQL Property Graph,
  RDF graph, or a read API over relational edge tables;
- expose read-only traversal/query procedures or views;
- forbid Graph Studio playground queries as production runtime;
- return graph DTOs with opaque ids, labels, relationship types, direction,
  confidence/source refs, and pagination.

Oracle Graph Studio is an administrative and exploratory surface. Production
runtime still needs an approved Backend-facing query contract and grants.

### Atomic Inventory Publication

`DBA_APPROVED_ATOMIC_INVENTORY_PUBLICATION_API`

Minimum contract:

- stage resources and dependency snapshot under one `run_id`;
- validate staged counts, scope, required refs, and privacy classification;
- publish a single inventory manifest pointer in one transaction boundary;
- preserve prior published manifest until the new manifest is committed;
- rollback by leaving the prior manifest active and marking the failed run;
- never destructively delete the prior published inventory as rollback.

### Idempotency And Single-Flight

`DBA_APPROVED_DISCOVERY_IDEMPOTENCY_CONTRACT`

Required idempotency key inputs:

- `contract_version`
- `client_id`
- `provider`
- `environment`
- `project_id`
- operation type
- source snapshot ref or digest
- canonical request body digest

`DBA_APPROVED_DISCOVERY_SINGLE_FLIGHT_API`

Minimum contract:

- acquire scoped execution lock by `client_id + provider + environment +
  project_id + operation`;
- reject or replay concurrent equivalent request with a sanitized conflict or
  existing run status;
- include lease/heartbeat/expiry and stale-lock reclaim rules;
- log every acquire/release/failure in the audit journal.

### Audit Journal

`DBA_APPROVED_DISCOVERY_AUDIT_JOURNAL`

Minimum append-only fields:

- `event_id`
- `run_id`
- `batch_id`
- `event_sequence`
- `client_id`
- `provider`
- `environment`
- `project_id`
- `actor_id`
- `event_type`
- `event_status`
- `source_ref`
- `projection_cursor`
- `created_at`

Payloads must be sanitized by allowlist. Raw provider records and customer
content are not public audit DTOs.

## Grants

Current grants are not sufficient for productive BE:

- observed Lift grants: `0`;
- #188/#189 grants: MISSING.

Required pattern:

- writer runtime principal: `EXECUTE` on approved write packages only;
- reader runtime principal: `EXECUTE` on approved read packages only, or
  `SELECT` on DBA-approved projections only;
- graph runtime principal: read/query grants only on approved graph surface;
- no broad DDL grant for application runtime;
- no direct DML on physical tables outside approved package boundaries.

## Operational Limits

No production value is approved yet. Backend/RM must not invent runtime limits
from local tests.

Required DBA/RM-approved limit contracts:

- `DBA_APPROVED_DISCOVERY_BATCH_SIZE`
- `DBA_APPROVED_DISCOVERY_COMMIT_BOUNDARY`
- `DBA_APPROVED_DISCOVERY_PAGE_SIZE`
- `DBA_APPROVED_DISCOVERY_PROJECT_IDS_MAX`
- `DBA_APPROVED_DISCOVERY_STATEMENT_TIMEOUT`
- `DBA_APPROVED_DISCOVERY_RETRY_POLICY`
- `DBA_APPROVED_DISCOVERY_CIRCUIT_BREAKER`
- `DBA_APPROVED_DISCOVERY_POOL_MIN_MAX_INCREMENT_WAIT`
- `DBA_APPROVED_DISCOVERY_STATEMENT_CACHE`
- `DBA_APPROVED_DISCOVERY_METRICS_ALLOWLIST`

Minimum required metrics shape:

- query count;
- batch count;
- retry count;
- timeout count;
- p95 latency bucket;
- pool saturation bucket;
- failed-closed count.

Metrics must not include SQL text, bind values, customer content, secret values,
wallet paths, or physical endpoint descriptors.

## Healthcheck

Required read-only healthcheck contract:

- connectivity to approved alias: `READY/PARTIAL/MISSING`;
- approved package availability: `READY/PARTIAL/MISSING`;
- grants availability: `READY/PARTIAL/MISSING`;
- VPD/app-context policy availability: `READY/PARTIAL/MISSING`;
- resource projection availability: `READY/PARTIAL/MISSING`;
- graph projection availability: `READY/PARTIAL/MISSING`;
- audit journal availability: `READY/PARTIAL/MISSING`.

Healthcheck must not reveal schema owner, object counts by tenant, table names
unless explicitly approved, SQL text, ORA stack, endpoint descriptor, wallet
content, or customer content.

## External Approval Gates

The productive Discovery lane remains blocked until all gates are met:

| Gate | Owner | Exit condition |
|---|---|---|
| Physical object contract | DBA/Data Architecture | Approved object/package/view/graph list for #188/#189 |
| Security/privacy | Security/Privacy | Metadata allowlist, classification, masking, and retention approved |
| Grants | DBA/Infra | Runtime grants applied and verified by sanitized dictionary metadata |
| VPD/app context | DBA/Infra | Context setter and policies approved or accepted compensating control |
| Backend adapter | Backend | Default-OFF code consumes approved APIs only; no direct table SQL |
| RM config | RM | Hosted DEV config uses approved alias/flags without exposing secrets |
| DEV evidence | RM/DBA | Hosted `oracle-ai` validation only; no local runtime/DB evidence |
| Rollback | DBA/RM | Logical rollback and deployment rollback documented |

## Official Oracle Design Anchors

These references inform the pre-edit contract and do not authorize any action:

- Application contexts support secure session attributes and are commonly used
  with fine-grained access control:
  <https://docs.oracle.com/en/database/oracle/oracle-database/19/dbseg/application-contexts.html>
- `DBMS_SESSION.SET_CONTEXT` must be invoked through the trusted application
  context path:
  <https://docs.oracle.com/en/database/oracle/oracle-database/21/arpls/DBMS_SESSION.html>
- VPD policies are attached with `DBMS_RLS` to tables, views, or synonyms and
  can enforce statement-specific row-level controls:
  <https://docs.oracle.com/en/database/oracle/oracle-database/19/dbseg/configuration-oracle-virtual-private-database-policies.html>
- Autonomous Graph Studio supports property/RDF graph work, but exploratory
  tools do not replace production runtime contracts:
  <https://docs.oracle.com/en/cloud/paas/autonomous-database/csgru/graph-studio-interactive-self-service-user-interface.html>
- Oracle Property Graph supports SQL/PGQL graph models depending on database
  version and graph type:
  <https://docs.oracle.com/en/database/oracle/property-graph/>

## Verdict

`#188` and `#189` are not ready for productive BE Oracle integration.

Existing `CA_DISC_LIFT_*` and `CA_KNOWLEDGE_*` objects prove useful foundations
inside the same Autonomous Database, but they do not constitute an approved
physical contract for Resources API, DependencySnapshot, atomic publication,
single-flight, or productive Discovery audit.

Next allowed step is review/approval of this pre-edit contract by DBA/Infra,
Security/Privacy, Backend, Dispatcher, and RM. Only after that should a separate
DDL/grants request be assembled with an explicit object list and rollback.
