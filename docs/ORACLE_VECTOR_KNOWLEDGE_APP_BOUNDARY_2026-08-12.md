# Oracle Vector Knowledge Application Boundary

Date: 2026-08-12

Status: DOCUMENTAL_CLARIFICATION

Provenance: Git candidate documentation only. Runtime/DB validation remains a
separate oracle-ai activity.

## Position

The Vector DB / Knowledge / RAG domain is the shared knowledge base for the
Cloud Architect application. It is not exclusive to Lift and must not be blocked
as a platform capability just because the Lift operational contract is missing
read APIs or grants.

## Boundary

Allowed as application knowledge capability:

- semantic retrieval;
- documentation and architecture knowledge;
- knowledge-grounded assistance;
- cross-application context;
- derived explanations and recommendations;
- consumer-facing knowledge views when authorized by the Knowledge/RAG contract.

Not allowed as Lift operational source of truth without an explicit interface
contract:

- run-control;
- idempotency;
- active-project eligibility;
- Workplan generation state;
- journal cursor;
- artifact registry;
- financial/value/cost projection;
- dependency graph projection;
- renderer DTO totals.

## Correct Relationship With Lift

Lift may consume Knowledge/RAG only through an approved contract that defines:

- input scope: `client_id`, `provider`, `environment`, and optional
  `project_id`;
- output DTO fields;
- sanitization;
- freshness and provenance;
- authorization checks;
- fail-closed behavior;
- whether results are advisory knowledge or operational state.

Until that contract exists, Knowledge/RAG can continue as an application-wide
knowledge base, but Backend must not substitute it for `CA_DISC_LIFT_*`
operational projection/read APIs.

## Non-Blocking Statement

The DBA/Lift v1.1 blocker is:

- `CA_DISC_LIFT_API` has no read/projection procedures;
- grants are absent for segregated runtime access;
- VPD/application context is not yet approved.

That blocker does not imply that Vector DB/Knowledge/RAG is stopped globally.
Any Vector DB activity should be routed under the Knowledge/RAG owner and its
own contract, not under the Lift operational persistence lane.
