# Oracle DBA Modeling Best Practices

Date: 2026-08-11

Status: APPLIED_TO_V1_WITH_HARDENING_BACKLOG

This note records the Oracle modeling practices used for the Discovery/Lift v1
physical base and the next hardening items that require a separate gate.

## Official References

- Autonomous Database Python mTLS: Oracle documents using wallet configuration,
  `config_dir`, `dsn`, user, and password for Python applications with
  `python-oracledb`.
  <https://docs.oracle.com/en-us/iaas/autonomous-database-serverless/doc/connecting-python-mtls.html>
- Autonomous Database service names: Oracle documents service aliases such as
  `*_high`, `*_medium`, `*_low`, and their workload/concurrency implications.
  <https://docs.oracle.com/iaas/autonomous-database-shared/doc/connect-predefined-generic.html>
- JSON check constraints: Oracle documents `IS JSON` in check constraints and
  strict JSON validation with `IS JSON (STRICT)`.
  <https://docs.oracle.com/en/database/oracle/oracle-database/19/adjsn/conditions-is-json-and-is-not-json.html>
- VPD policies: Oracle documents `DBMS_RLS.ADD_POLICY` for applying fine-grained
  access control policies to tables, views, or synonyms.
  <https://docs.oracle.com/en/database/oracle/oracle-database/19/dbseg/configuration-oracle-virtual-private-database-policies.html>
- Application context: Oracle documents `SYS_CONTEXT` and
  `DBMS_SESSION.SET_CONTEXT` for session-scoped application attributes used by
  policies and server-side authorization.
  <https://docs.oracle.com/en/database/oracle/oracle-database/26/dbseg/using-application-contexts-to-retrieve-user-information.html>
- Index management: Oracle documents indexing join/filter columns and notes that
  primary/unique keys create indexes automatically, while foreign keys can still
  need supporting indexes.
  <https://docs.oracle.com/en/database/oracle/oracle-database/18/admin/managing-indexes.html>

## Applied In V1

- Used the Autonomous wallet/TNS path from the hosted runtime and the
  `cloudarchdb_high` service alias; no local Mac, local SQLite, CSV, or local
  diagnostic artifact was used as production evidence.
- Created only the approved `CA_DISC_LIFT_*` objects in the connected runtime
  schema. No user/schema creation and no tablespace change were performed.
- Modeled tenant/project scope explicitly with `client_id`, `provider`,
  `environment`, and `project_id`.
- Used primary keys for identity and composite tenant/project scope.
- Used foreign keys from journal/artifacts to runs.
- Used unique constraints for idempotency and event identity.
- Used check constraints for state machines, flags, counts, artifact types,
  event types, event statuses, and JSON well-formedness.
- Added targeted indexes for active-project lookup, run polling, and journal
  cursor access.
- Exposed mutation through `CA_DISC_LIFT_API` instead of requiring Backend to
  write arbitrary SQL from web handlers.
- Preserved append-only journal semantics at the contract level.
- Kept artifact references opaque and metadata-only.

## Hardening Backlog

These items are not silently authorized by the v1 execution:

- Add named strict JSON constraints using `IS JSON (STRICT)` for JSON CLOB
  columns. The v1 script has JSON checks, but they are not strict.
- Add explicit projection/read procedures or views for public DTO polling once
  Backend finalizes the DTO fields.
- Add VPD/application context if access will be split across multiple database
  users or if direct table access is ever granted beyond the package boundary.
- Split owner/runtime grants if the architecture moves away from the connected
  runtime schema.
- Add concrete pool limits, page sizes, statement timeouts, circuit breaker
  thresholds, and statement-cache sizing in Backend/RM configuration.
- Add domain producers for resources, dependency graph, value/cost, files
  metadata, and runtime progress.
- Consider immutable/blockchain-table patterns only after retention, rollback,
  and purge policy are approved. They are not appropriate as a default before
  data-retention decisions.

## Position On Schema And Tablespace

Schema and tablespace are different concerns.

- Schema: logical object owner/namespace. The v1 objects were created in the
  connected runtime schema.
- Tablespace: physical/logical storage allocation. The v1 execution did not
  create, alter, or select a tablespace.

The current approved separation is logical: `CA_DISC_LIFT_*` object names plus
mandatory tenant/project scope columns. A separate schema remains a possible
future hardening choice, not a requirement for the v1 Autonomous execution.
