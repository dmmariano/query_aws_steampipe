# Oracle Autonomous Multimodal Application Knowledge Base Contract

Date: 2026-08-12

Status: DOCUMENTAL_CONTRACT_CANDIDATE / EXTERNAL_APPROVAL_REQUIRED

Provenance: Git candidate documentation only. Runtime/DB validation remains a
separate oracle-ai activity.

## Position

The current Oracle Autonomous Database is the intended application-wide
multimodal knowledge and data intelligence foundation for Cloud Architect.

It is not only a Vector DB and it is not only a relational store. Vector search
is one capability inside the Autonomous Database knowledge plane. The knowledge
base may also include transactions, relational facts, JSON/document metadata,
graph relationships, spatial/location data, provenance, lineage, governed
projections, embeddings, and semantic retrieval surfaces.

The architecture principle is: use the best native Autonomous Database model for
each moment of the application, while keeping one governed database platform,
one security boundary, and explicit contracts between domains.

## Oracle Capabilities In Scope

The application knowledge base may use these Autonomous Database capabilities
when each capability has an approved owner, contract, grants, and runtime path:

| Capability | Application role |
|---|---|
| Relational SQL / PL/SQL | transactions, canonical structured facts, operational metadata, projections |
| JSON / SODA | flexible document metadata and knowledge documents |
| AI Vector Search | embeddings, semantic retrieval, RAG context |
| Property Graph / RDF Graph | dependency graphs, relationships, ontology/semantic graph |
| Spatial | geospatial/location intelligence and map-ready analyses |
| Select AI / RAG | governed natural-language and retrieval workflows |
| ORDS / Database Actions | admin/developer tooling, not implicit runtime API |

Official Oracle references:

- Autonomous Database JSON/SODA:
  <https://docs.oracle.com/en/cloud/paas/autonomous-database/serverless/adbsb/document-database-json.html>
- Oracle AI Vector Search:
  <https://docs.oracle.com/en/database/oracle/oracle-database/26/vecse/overview-ai-vector-search.html>
- Graph Studio on Autonomous Database:
  <https://docs.oracle.com/en/cloud/paas/autonomous-database/csgru/graph-studio-interactive-self-service-user-interface.html>
- Using Oracle Graph with Autonomous Database:
  <https://docs.oracle.com/en/cloud/paas/autonomous-database/serverless/adbsb/graph-autonomous-database.html>
- Select AI:
  <https://docs.public.oneportal.content.oci.oraclecloud.com/en-us/iaas/autonomous-database-shared/doc/select-ai-about.html>
- Oracle Database transactions:
  <https://docs.oracle.com/html/E10713_02/transact.htm>
- Spatial Studio on Autonomous Database:
  <https://docs.oracle.com/en/cloud/paas/autonomous-database/serverless/adstu/oracle-spatial-studio.html>

## Use-The-Best-Model Matrix

| Application moment | Preferred Autonomous capability | Reason |
|---|---|---|
| User/session authorization | relational + VPD/application context | deterministic fail-closed access control |
| Workflow/run-control | relational tables + PL/SQL packages | ACID transaction boundary and explicit commit/rollback |
| Idempotency and journal | relational constraints + append-only event tables | uniqueness, ordering, retry lineage |
| Project/resource facts | relational projections | stable filtering, joins, pagination, DTO construction |
| Document ingestion metadata | JSON/SODA + relational provenance columns | flexible document shape with governed metadata |
| Semantic search/Q&A | AI Vector Search + approved RAG API | similarity search over approved knowledge corpus |
| Dependency/impact analysis | Property Graph or RDF Graph | graph traversal, relationship discovery, ontology-style queries |
| Location-aware architecture | Spatial | region/site/network/geographic analysis |
| Cost/value analytics | SQL analytic projections | auditable aggregation and explainable numbers |
| Natural-language assistance | Select AI/RAG when approved | governed NL interface over approved data surfaces |
| Public UI DTO | approved package/view/API projection | sanitized contract, no direct table coupling |

## Domain Model

Autonomous Database is the shared foundation. Each domain must still expose a
contracted interface and must not read another domain's internal tables by
accident.

| Domain | Purpose | Contract status |
|---|---|---|
| Application Knowledge | shared knowledge corpus, retrieval, summaries, semantic context | PENDING_SERVER_VALIDATION |
| Vector / Embeddings | semantic search over approved knowledge material | PENDING_SERVER_VALIDATION |
| Document Metadata | file/document metadata, content refs, provenance, hashes | PENDING_CONTRACT |
| Graph Knowledge | dependency graph, relationships, ontology/RDF/property graph | PENDING_CONTRACT |
| Spatial Knowledge | region/site/location and geospatial context | PENDING_CONTRACT |
| Discovery/Lift Operational | run-control, journal, artifacts, workplan projection | PARTIAL_CA_DISC_LIFT_V1 / V1_1_READ_API_PENDING |
| Value/Cost | value and cost facts/projections | PENDING_CONTRACT |
| Runtime Observability | progress/events/health/pipeline status | PENDING_CONTRACT |
| Governance | grants, VPD/application context, lineage, retention | PENDING_CONTRACT |

## Core Rule

Autonomous is the multimodal application knowledge base, but not every
Autonomous object is automatically part of every domain's source of truth.

Required distinction:

- Knowledge truth: facts, documents, embeddings, semantic retrieval, graph
  relationships, and explanations with provenance.
- Operational truth: run-control, idempotency, journal, approvals, artifacts,
  status transitions, and commit boundaries.
- Relationship truth: approved graph vertices/edges and their source
  provenance.
- Spatial truth: approved location entities and geometry/geography derivations.

Lift may consume application knowledge through an approved cross-domain
interface. Lift must not replace its operational run-control or projection API
with ad hoc reads from vector/RAG/knowledge tables.

## Required Shared Knowledge Contract

Before Backend treats Autonomous as the application-wide knowledge base in real
runtime, DBA/Infra must validate or approve sanitized aliases for:

- `DBA_APPROVED_APP_KNOWLEDGE_OWNER_OR_NAMESPACE`
- `DBA_APPROVED_KNOWLEDGE_INGEST_API`
- `DBA_APPROVED_KNOWLEDGE_SEARCH_API`
- `DBA_APPROVED_KNOWLEDGE_DOCUMENT_METADATA_SURFACE`
- `DBA_APPROVED_VECTOR_EMBEDDING_SURFACE`
- `DBA_APPROVED_VECTOR_INDEX_POLICY`
- `DBA_APPROVED_GRAPH_MODEL_OR_SURFACE`
- `DBA_APPROVED_SPATIAL_MODEL_OR_SURFACE`
- `DBA_APPROVED_RAG_CONTEXT_DTO`
- `DBA_APPROVED_KNOWLEDGE_PROVENANCE_FIELDS`
- `DBA_APPROVED_KNOWLEDGE_RETENTION_POLICY`
- `DBA_APPROVED_KNOWLEDGE_GRANTS`
- `DBA_APPROVED_KNOWLEDGE_HEALTHCHECK`

Do not infer these names from local files or from naming conventions.

## Mandatory Scope And Provenance

Every app-wide knowledge item must carry enough scope and provenance for
fail-closed use:

- `client_id`
- `provider`, when provider-specific
- `environment`, when environment-specific
- `project_id`, when project-specific
- `source_system`
- `source_ref`, opaque
- `source_hash` or digest
- `ingestion_run_id`
- `contract_version`
- `classification`
- `created_at`
- `updated_at`
- `last_verified_at`
- `embedding_model_ref`, when vectorized
- `graph_model_ref`, when graph-derived
- `spatial_model_ref`, when spatial-derived

Customer content must not be exposed in public DTOs. Public APIs return
sanitized summaries, opaque refs, counts, statuses, and approved snippets only.

## Access Model

Preferred runtime access:

- Backend calls approved packages/APIs.
- Runtime users receive `EXECUTE` on approved packages.
- Runtime users do not receive broad DDL.
- Runtime web handlers do not write directly to domain tables.
- Direct `SELECT` is limited to DBA-approved projections/views, if used.
- Admin/owner capability stays outside application runtime.

VPD/application context roadmap:

- application context stores `client_id`, `provider`, `environment`,
  `project_id`, and optional `run_id`;
- package setter validates the context;
- VPD policies enforce tenant/project boundaries across knowledge,
  graph/vector, and operational domains where direct table access exists;
- package-level validation remains mandatory even with VPD.

## Healthcheck Contract

Allowed healthcheck outputs:

- `autonomous_connectivity=READY/PARTIAL/MISSING`
- `knowledge_contract=READY/PARTIAL/MISSING`
- `vector_search=READY/PARTIAL/MISSING`
- `graph_capability=READY/PARTIAL/MISSING`
- `spatial_capability=READY/PARTIAL/MISSING`
- `json_document_capability=READY/PARTIAL/MISSING`
- `runtime_grants=READY/PARTIAL/MISSING`

Blocked healthcheck outputs:

- username;
- password;
- wallet content or path;
- full endpoint descriptor;
- schema owner;
- object counts that reveal tenant data;
- customer content;
- SQL text or ORA stack.

## Relationship To Discovery/Lift

The existing `CA_DISC_LIFT_*` v1 lane is an operational domain inside the same
Autonomous platform. It is not the whole knowledge base.

Current Lift status:

- v1 operational tables/package exist as candidate documented facts;
- v1 read/projection API is missing;
- v1 grants are absent;
- v1.1 read API/grants delta is pending external approval.

Knowledge status:

- Autonomous should be the app-wide knowledge foundation;
- existing Knowledge/RAG/vector physical objects must be validated server-side
  before they are declared current;
- Knowledge/RAG may continue independently of the Lift v1.1 blocker;
- any Lift consumption of Knowledge/RAG needs a cross-domain contract.

## Make-It-Real Gates

To make this architecture real, complete these gates in order:

1. Server-side read-only inventory on `oracle-ai` of current Autonomous
   Knowledge/RAG/vector/graph/spatial/document/transactional capabilities and
   objects.
2. Git handoff from DBA with sanitized object/API/grant aliases.
3. DBA approval for shared Knowledge contract and domain boundaries.
4. Backend default-OFF adapters for approved APIs only.
5. RM validation of runtime config, pool limits, circuit breaker, and
   healthcheck.
6. Dispatcher approval to move each domain from candidate to runtime.

No DDL/DML/grants/deploy/reprocessing is authorized by this document.
