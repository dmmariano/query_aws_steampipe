# Oracle Server Read-Only Evidence

Date: 2026-08-11

Scope: sanitized read-only inspection on the hosted `oracle-ai` runtime. No
secret value, wallet content, endpoint hostname, OCID value, schema name,
customer content, DDL, DML, grants, deploy, restart, collection, or query
against application data was executed.

## Runtime

| Item | Evidence |
|---|---|
| Host | `instance-20260504-2033` |
| Runtime path | `/srv/cloud-architect/app` |
| Runtime path status | PRESENT when checked with authorized server permissions |
| Runtime Git status | `NO_GIT_REPO` |
| Web service | `cloud-architect.service` active |
| Processing service | `cloud-architect-processing.service` active |
| Service user/group | `cloudarchitect` / `cloudarchitect` |
| Service workdir | `/srv/cloud-architect/app` |
| Service env file | `/etc/cloud-architect/runtime.env` |
| App health | `/health=200` |
| App readiness | `/healthz/ready=200` |

## OCI / Secret / Vault

| Item | Evidence | Verdict |
|---|---|---|
| OCI CLI | `MISSING` | Cannot query Vault metadata from host |
| User OCI config | `MISSING` | No user OCI config available |
| Root OCI config | `MISSING` | No root OCI config available |
| `OCI_COMPARTMENT_ID` marker | SET, value not printed | PARTIAL |
| `OCI_REGION` marker | SET, value not printed | PARTIAL |
| Secret/Vault reference for Discovery/Lift | No `SECRET_`, `VAULT_`, `DISCOVERY_ORACLE_*`, or Discovery/Lift secret reference found | MISSING |

## Wallet / TLS

| Item | Evidence | Verdict |
|---|---|---|
| `CLOUD_ARCHITECT_ADB_WALLET` | SET, value not printed | PRESENT |
| `CLOUD_ARCHITECT_ADB_WALLET_PASSWORD_FILE` | SET, value not printed | PRESENT |
| Wallet directory | PRESENT, path not printed beyond known runtime context | PRESENT |
| `tnsnames.ora` | PRESENT, content not read | PRESENT |
| `sqlnet.ora` | PRESENT, content not read | PRESENT |
| `cwallet.sso` | PRESENT, content not read | PRESENT |
| `ewallet.p12` | PRESENT, content not read | PRESENT |
| TNS alias count | 5 aliases detected, names not printed | PARTIAL |
| Wallet password file | PRESENT, owner `root`, group `cloudarchitect`, mode `640` | PRESENT |

Interpretation: wallet/TLS material exists for the hosted application, but this
does not prove Discovery/Lift authorization, endpoint selection, pool readiness,
or writer/journal/projection availability.

## Driver / Pool / Endpoint

| Item | Evidence | Verdict |
|---|---|---|
| Python Oracle driver | `oracledb` PRESENT in app venv |
| Driver version | `4.0.2` |
| `DISCOVERY_ORACLE_DSN` | MISSING |
| `DISCOVERY_ORACLE_USER_SECRET` | MISSING |
| `DISCOVERY_ORACLE_PASSWORD_SECRET` | MISSING |
| `DISCOVERY_ORACLE_POOL_MIN` | MISSING |
| `DISCOVERY_ORACLE_POOL_MAX` | MISSING |
| `DISCOVERY_ORACLE_POOL_INCREMENT` | MISSING |
| `DISCOVERY_ORACLE_POOL_WAIT_TIMEOUT_MS` | MISSING |
| `DISCOVERY_ORACLE_STATEMENT_TIMEOUT_MS` | MISSING |
| `ORACLE_DSN` | MISSING |
| `TNS_ADMIN` | MISSING |
| Code marker `create_pool` | 0 files |
| Code marker `SessionPool` | 0 files |
| Code marker `oracledb.create_pool` | 0 files |
| Code marker `oracledb.connect` | 2 files, both Knowledge/Autonomous adjacent |
| Discovery/Lift Oracle marker | 0 files |

Interpretation: driver and wallet references exist, but Discovery/Lift does not
have a runtime DSN/secret reference, pool configuration, or pool implementation.
Observed Oracle connection markers are Knowledge/Autonomous adjacent, not a
Discovery/Lift writer contract.

## Healthcheck / API / Contract Surfaces

| Surface | Evidence | Verdict |
|---|---|---|
| Oracle-specific health marker | 0 files | MISSING |
| ADB health marker | 0 files | MISSING |
| `lift/oracle` marker | 0 files | MISSING |
| `oracle/progress` marker | 0 files | MISSING |
| `discovery_oracle_runtime` marker | 0 files | MISSING |
| `discovery_oracle_resources.py` | MISSING |
| `discovery_oracle_runtime_progress.py` | MISSING |
| `lift_publication_contract.py` | MISSING |
| `discovery_oracle_p0_v1.schema.json` | MISSING |
| `discovery_oracle_runtime_progress_v1.schema.json` | MISSING |

## Canonical Conclusion

Server-side evidence improves the status from "wallet unknown" to "wallet
material present", but the overall DBA/Architecture verdict remains HOLD:

- Autonomous use for Discovery/Lift is not confirmed by DBA/Infra.
- Discovery/Lift secret reference is missing.
- Discovery/Lift endpoint/DSN is missing.
- Discovery/Lift pool configuration is missing.
- Discovery/Lift Oracle healthcheck is missing.
- Discovery/Lift writer is missing.
- Discovery/Lift journal is missing.
- Discovery/Lift projection/API incremental is missing.
- Discovery/Lift public DTO contract is missing.
- Runtime is a materialized deployment, not a Git checkout.

No real integration should proceed until DBA/Infra provides a sanitized physical
contract and Git/RM provides a traceable deployment base.
