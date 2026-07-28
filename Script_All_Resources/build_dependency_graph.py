#!/usr/bin/env python3
import argparse
import csv
import json
import os
import re
import sys
from collections import Counter, defaultdict
from datetime import datetime, timezone


SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
RESOURCE_CATALOG_PATH = os.path.join(SCRIPT_DIR, "resource_catalog.json")
ACCOUNT_BU_MAP_PATH = os.path.join(SCRIPT_DIR, "account_bu_map.csv")
EXTRA_TARGET_METADATA = {
    "aws_vpc": {
        "label": "VPCs",
        "group": "network_delivery",
        "group_label": "Network & Delivery",
    },
    "aws_kms_alias": {
        "label": "KMS Aliases",
        "group": "security_identity",
        "group_label": "Security & Identity",
    },
}
EXCLUDED_CSVS = {
    "resumo_quantidade_linhas.csv",
    "dependency_relationships.csv",
    "dependency_account_edges.csv",
}
ARN_RE = re.compile(r"arn:aws[a-zA-Z-]*:[A-Za-z0-9_.-]+:[A-Za-z0-9-]*:\d{0,12}:[^\s\"'\],)}]+")
ECR_RE = re.compile(r"\b(\d{12})\.dkr\.ecr\.([a-z0-9-]+)\.amazonaws\.com(?:\.br)?/([A-Za-z0-9._/-]+)")
S3_URI_RE = re.compile(r"\bs3://([A-Za-z0-9.\-_]{3,63})(?:/[^\s\"']*)?")
S3_DOMAIN_RE = re.compile(r"\b([A-Za-z0-9.\-_]{3,63})\.s3(?:[.-][a-z0-9-]+)?\.amazonaws\.com(?:\.br)?")
SQS_URL_RE = re.compile(r"https://sqs\.([a-z0-9-]+)\.amazonaws\.com(?:\.br)?/(\d{12})/([A-Za-z0-9_-]+)")
ID_RES = [
    re.compile(pattern)
    for pattern in [
        r"\bvpc-[0-9a-f]{8,17}\b",
        r"\bsubnet-[0-9a-f]{8,17}\b",
        r"\bsg-[0-9a-f]{8,17}\b",
        r"\bfs-[0-9a-f]{8,17}\b",
        r"\bfsap-[0-9a-f]{8,17}\b",
        r"\bvol-[0-9a-f]{8,17}\b",
        r"\bi-[0-9a-f]{8,17}\b",
        r"\bami-[0-9a-f]{8,17}\b",
        r"\bni-[0-9a-f]{8,17}\b",
        r"\bvpce-[0-9a-f]{8,17}\b",
        r"\bnat-[0-9a-f]{8,17}\b",
        r"\btgw-[0-9a-f]{8,17}\b",
        r"\bd-[0-9a-f]{8,17}\b",
        r"\b[a-z]{2,4}-[A-Za-z0-9]{8,}\b",
    ]
]
NOISE_VALUES = {
    "",
    "-",
    "null",
    "none",
    "nan",
    "aws",
    "true",
    "false",
    "enabled",
    "disabled",
    "active",
    "available",
    "region",
    "global",
}
IGNORED_COLUMNS = {
    "account_id",
    "account_name",
    "sp_connection_name",
    "sp_ctx",
    "_ctx",
    "partition",
    "tags",
    "tags_src",
    "title",
    "akas",
    "created_at",
    "created_date",
    "create_time",
    "last_modified",
    "last_modified_time",
}
RELATION_HINTS = (
    "arn",
    "role",
    "kms",
    "vpc",
    "subnet",
    "security_group",
    "load_balancer",
    "target_group",
    "cluster",
    "task_definition",
    "topic",
    "queue",
    "bucket",
    "file_system",
    "network_interface",
    "endpoint",
    "policy",
    "source",
    "destination",
    "stream",
    "layer",
    "function",
    "authorizer",
    "integration",
    "certificate",
    "web_acl",
    "secret",
    "db_cluster",
    "db_instance",
    "repository",
    "image",
    "api",
    "origin",
    "volume",
    "key",
    "event_bus",
    "dead_letter",
    "environment",
    "configuration",
)
PRIMARY_ID_CANDIDATES = [
    "arn",
    "id",
    "name",
    "title",
    "instance_id",
    "cluster_arn",
    "cluster_name",
    "service_arn",
    "service_name",
    "task_definition_arn",
    "function_name",
    "file_system_id",
    "bucket_name",
    "db_instance_identifier",
    "db_cluster_identifier",
    "queue_url",
    "topic_arn",
    "api_id",
    "domain_name",
    "repository_name",
    "key_id",
    "alias_name",
]


def set_csv_field_limit():
    limit = sys.maxsize
    while True:
        try:
            csv.field_size_limit(limit)
            return
        except OverflowError:
            limit = int(limit / 10)


def clean(value):
    if value is None:
        return ""
    text = str(value).strip()
    return "" if text.lower() in NOISE_VALUES else text


def now_iso():
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def load_catalog():
    try:
        with open(RESOURCE_CATALOG_PATH, "r", encoding="utf-8") as handle:
            catalog = json.load(handle)
    except FileNotFoundError:
        return {"groups": {}, "resources": {}}

    groups = {
        str(group.get("id", "")).strip(): str(group.get("label") or group.get("id") or "").strip()
        for group in catalog.get("groups", [])
        if str(group.get("id", "")).strip()
    }
    resources = {}
    for table, metadata in catalog.get("resources", {}).items():
        if metadata.get("dashboard", True) is False:
            continue
        group = str(metadata.get("group") or "other").strip()
        resources[table] = {
            "label": str(metadata.get("label") or table).strip(),
            "group": group,
            "group_label": groups.get(group, group or "Other"),
        }
    return {"groups": groups, "resources": resources}


def load_bu_map():
    mapping = {}
    if not os.path.isfile(ACCOUNT_BU_MAP_PATH):
        return mapping
    with open(ACCOUNT_BU_MAP_PATH, newline="", encoding="utf-8", errors="replace") as handle:
        reader = csv.DictReader(handle)
        for row in reader:
            account_id = clean(row.get("account_id") or row.get("Account ID"))
            account = clean(row.get("Nome da Conta") or row.get("account_name") or row.get("Account Name"))
            bu = clean(row.get("BU") or row.get("business_unit") or row.get("bu") or row.get("Business Unit"))
            if account_id and bu:
                mapping[account_id] = bu
            if account and bu:
                mapping[account.lower()] = bu
    return mapping


def account_maps(csv_dir):
    account_names = {}
    connection_accounts = {}
    spc_path = os.path.expanduser("~/.steampipe/config/aws.spc")
    if os.path.isfile(spc_path):
        with open(spc_path, "r", encoding="utf-8", errors="replace") as handle:
            text = handle.read()
        for match in re.finditer(r'connection\s+"([^"]+)"\s*\{([\s\S]*?)\n\}', text):
            connection_name = match.group(1)
            body = match.group(2)
            account_id_match = re.search(r'#\s*account_id\s*=\s*"([^"]+)"', body)
            account_id = clean(account_id_match.group(1) if account_id_match else connection_name.replace("aws_", ""))
            account_name_match = re.search(r'#\s*account_name\s*=\s*"([^"]+)"', body)
            account_name = clean(account_name_match.group(1) if account_name_match else "")
            if re.fullmatch(r"\d{12}", account_id):
                connection_accounts[connection_name] = account_id
                if account_name:
                    account_names[account_id] = account_name
    path = os.path.join(csv_dir, "aws_account.csv")
    if os.path.isfile(path):
        with open(path, newline="", encoding="utf-8", errors="replace") as handle:
            reader = csv.DictReader(handle)
            for row in reader:
                account_id = clean(row.get("account_id"))
                if not re.fullmatch(r"\d{12}", account_id):
                    continue
                account_name = clean(row.get("title")) or account_id
                account_names.setdefault(account_id, account_name)
                connection = clean(row.get("sp_connection_name"))
                if connection:
                    connection_accounts[connection] = account_id
    return account_names, connection_accounts


def account_bu(account_id, account_names, bu_map):
    name = account_names.get(account_id, "")
    return bu_map.get(account_id, "") or bu_map.get(name.lower(), "")


def read_csv(path):
    with open(path, newline="", encoding="utf-8", errors="replace") as handle:
        yield from csv.DictReader(handle)


def csv_names(csv_dir):
    return sorted(
        name for name in os.listdir(csv_dir)
        if name.endswith(".csv") and name not in EXCLUDED_CSVS and not name.startswith("discovery_summary_")
    )


def metadata_for(table, catalog):
    if table in EXTRA_TARGET_METADATA:
        return EXTRA_TARGET_METADATA[table]
    return catalog["resources"].get(table, {
        "label": table,
        "group": "other",
        "group_label": "Other",
    })


def dependency_tables(catalog):
    return set(catalog["resources"]) | set(EXTRA_TARGET_METADATA)


def parse_jsonish(value):
    text = clean(value)
    if not text or text[0] not in "[{":
        return None
    try:
        return json.loads(text)
    except Exception:
        return None


def flatten_strings(value):
    if value is None:
        return []
    if isinstance(value, str):
        return [value]
    if isinstance(value, (int, float, bool)):
        return [str(value)]
    if isinstance(value, list):
        output = []
        for item in value:
            output.extend(flatten_strings(item))
        return output
    if isinstance(value, dict):
        output = []
        for key, item in value.items():
            output.append(str(key))
            output.extend(flatten_strings(item))
        return output
    return []


def display_name(row):
    for key in PRIMARY_ID_CANDIDATES:
        value = clean(row.get(key))
        if value:
            return value[:180]
    for key, value in row.items():
        if key.endswith("_name") or key.endswith("_id"):
            value = clean(value)
            if value:
                return value[:180]
    return "Recurso sem nome"


def resource_uid(table, row, fallback_index):
    for key in ["arn", "task_definition_arn", "service_arn", "cluster_arn", "topic_arn", "queue_arn"]:
        value = clean(row.get(key))
        if value.startswith("arn:"):
            return value
    account_id = clean(row.get("account_id")) or "sem-conta"
    region = clean(row.get("region")) or "global"
    return f"{table}|{account_id}|{region}|{display_name(row)}|{fallback_index}"


def identity_values(table, row):
    values = set()
    for key in ["arn", "task_definition_arn", "service_arn", "cluster_arn", "topic_arn", "queue_arn"]:
        value = clean(row.get(key))
        if value:
            values.add(value)
    for key in ["akas"]:
        parsed = parse_jsonish(row.get(key))
        if parsed:
            for item in flatten_strings(parsed):
                if item.startswith("arn:"):
                    values.add(item)
    for key in PRIMARY_ID_CANDIDATES:
        value = clean(row.get(key))
        if value and len(value) >= 3:
            values.add(value)
    for key, value in row.items():
        if key in IGNORED_COLUMNS:
            continue
        if key.endswith("_id") or key.endswith("_name"):
            value = clean(value)
            if value and 3 <= len(value) <= 220:
                values.add(value)
    return values


def build_resource_index(csv_dir, catalog, account_names, bu_map):
    resources = []
    arn_index = {}
    value_index = defaultdict(list)
    bucket_index = defaultdict(list)
    allowed_tables = dependency_tables(catalog)

    for filename in csv_names(csv_dir):
        table = filename[:-4]
        if table not in allowed_tables:
            continue
        path = os.path.join(csv_dir, filename)
        meta = metadata_for(table, catalog)
        for index, row in enumerate(read_csv(path), start=1):
            account_id = clean(row.get("account_id"))
            region = clean(row.get("region")) or "global"
            uid = resource_uid(table, row, index)
            resource = {
                "uid": uid,
                "table": table,
                "resource_label": meta["label"],
                "resource_group": meta["group"],
                "resource_group_label": meta["group_label"],
                "name": display_name(row),
                "account_id": account_id,
                "account_name": account_names.get(account_id, account_id or "Sem conta"),
                "business_unit": account_bu(account_id, account_names, bu_map),
                "region": region,
                "arn": clean(row.get("arn")),
                "dependency_source": table in catalog["resources"],
            }
            resources.append((resource, row))
            for value in identity_values(table, row):
                normalized = value.strip()
                if normalized.startswith("arn:"):
                    arn_index[normalized] = resource
                if len(normalized) >= 3:
                    value_index[(account_id, region, normalized)].append(resource)
                    value_index[(account_id, "global", normalized)].append(resource)
                    value_index[("", "", normalized)].append(resource)
            if table == "aws_s3_bucket":
                bucket = clean(row.get("name")) or clean(row.get("title"))
                if bucket:
                    bucket_index[bucket].append(resource)

    return resources, arn_index, value_index, bucket_index


def parse_arn(arn):
    parts = arn.split(":", 5)
    if len(parts) < 6 or not arn.startswith("arn:"):
        return {}
    return {
        "partition": parts[1],
        "service": parts[2],
        "region": parts[3] or "global",
        "account_id": parts[4],
        "resource": parts[5],
    }


def relation_category(field, reference):
    text = f"{field} {reference}".lower()
    if "kms" in text or ":kms:" in text:
        return "Encryption"
    if "role" in text or ":iam:" in text or "policy" in text:
        return "Identity & Access"
    if any(item in text for item in ["vpc", "subnet", "security_group", "sg-", "load_balancer", "targetgroup", "endpoint", "cloudfront"]):
        return "Network"
    if any(item in text for item in ["bucket", "s3", "efs", "fsx", "file_system", "volume"]):
        return "Storage"
    if any(item in text for item in ["queue", "topic", "event", "sqs", "sns", "eventbridge", "sfn"]):
        return "Integration"
    if any(item in text for item in ["lambda", "ecs", "eks", "task_definition", "cluster", "function", "ecr"]):
        return "Compute"
    if any(item in text for item in ["db_", "rds", "dynamodb", "elasticache", "opensearch", "docdb", "neptune"]):
        return "Data"
    return "Reference"


def source_candidate_column(column):
    if column in IGNORED_COLUMNS:
        return False
    lowered = column.lower()
    return any(hint in lowered for hint in RELATION_HINTS)


def resolve_by_value(value, source, value_index):
    candidates = []
    for key in [
        (source["account_id"], source["region"], value),
        (source["account_id"], "global", value),
        ("", "", value),
    ]:
        candidates.extend(value_index.get(key, []))
    unique = {item["uid"]: item for item in candidates}
    if len(unique) == 1:
        return next(iter(unique.values()))
    return None


def relationship_key(source, target, reference, field):
    target_key = target["uid"] if target else reference
    return (source["uid"], target_key, field, reference)


def make_relationship(source, target, field, reference, match_type, confidence):
    if target and target["uid"] == source["uid"]:
        return None
    parsed = parse_arn(reference) if reference.startswith("arn:") else {}
    target_account_id = target["account_id"] if target else parsed.get("account_id", "")
    relation_scope = "cross_account" if target_account_id and source["account_id"] and target_account_id != source["account_id"] else "same_account"
    if not target:
        relation_scope = "external_reference" if target_account_id else "unresolved_reference"
    if relation_scope == "unresolved_reference":
        return None

    return {
        "source_account_id": source["account_id"],
        "source_account_name": source["account_name"],
        "source_business_unit": source["business_unit"],
        "source_region": source["region"],
        "source_resource_type": source["table"],
        "source_resource_label": source["resource_label"],
        "source_resource": source["name"],
        "target_account_id": target_account_id,
        "target_account_name": target["account_name"] if target else (target_account_id or "Externo/nao identificado"),
        "target_business_unit": target["business_unit"] if target else "",
        "target_region": target["region"] if target else (parsed.get("region") or ""),
        "target_resource_type": target["table"] if target else (parsed.get("service") or "external"),
        "target_resource_label": target["resource_label"] if target else f"External {parsed.get('service', 'reference')}",
        "target_resource": target["name"] if target else reference[:220],
        "relationship_scope": relation_scope,
        "relationship_category": relation_category(field, reference),
        "field": field,
        "reference": reference[:500],
        "match_type": match_type,
        "confidence": confidence,
    }


def references_from_value(value):
    text = clean(value)
    if not text:
        return []
    refs = set()
    for item in ARN_RE.findall(text):
        refs.add(item)
    for match in ECR_RE.finditer(text):
        refs.add(f"ecr://{match.group(1)}:{match.group(2)}/{match.group(3)}")
    for match in SQS_URL_RE.finditer(text):
        refs.add(f"sqs://{match.group(2)}:{match.group(1)}/{match.group(3)}")
    for match in S3_URI_RE.finditer(text):
        refs.add(f"s3://{match.group(1)}")
    for match in S3_DOMAIN_RE.finditer(text):
        refs.add(f"s3://{match.group(1)}")
    for regex in ID_RES:
        for item in regex.findall(text):
            refs.add(item)
    return sorted(refs)


def target_for_reference(reference, source, arn_index, value_index, bucket_index):
    if reference.startswith("arn:"):
        return arn_index.get(reference), "arn"
    if reference.startswith("s3://"):
        bucket = reference.removeprefix("s3://").split("/", 1)[0]
        matches = bucket_index.get(bucket, [])
        return (matches[0] if len(matches) == 1 else None), "s3"
    if reference.startswith("ecr://"):
        account = reference.removeprefix("ecr://").split(":", 1)[0]
        return None, "ecr"
    if reference.startswith("sqs://"):
        return None, "sqs"
    return resolve_by_value(reference, source, value_index), "id"


def external_from_special(reference, source, account_names, bu_map):
    if reference.startswith("ecr://"):
        account_id = reference.removeprefix("ecr://").split(":", 1)[0]
        return {
            "uid": reference,
            "table": "aws_ecr_repository",
            "resource_label": "ECR Repository",
            "resource_group": "compute",
            "resource_group_label": "Compute",
            "name": reference,
            "account_id": account_id,
            "account_name": account_names.get(account_id, account_id),
            "business_unit": account_bu(account_id, account_names, bu_map),
            "region": reference.split(":", 2)[1].split("/", 1)[0] if ":" in reference else "",
            "arn": "",
        }
    if reference.startswith("sqs://"):
        account_id = reference.removeprefix("sqs://").split(":", 1)[0]
        return {
            "uid": reference,
            "table": "aws_sqs_queue",
            "resource_label": "SQS Queue",
            "resource_group": "integration",
            "resource_group_label": "Integration",
            "name": reference,
            "account_id": account_id,
            "account_name": account_names.get(account_id, account_id),
            "business_unit": account_bu(account_id, account_names, bu_map),
            "region": reference.split(":", 2)[1].split("/", 1)[0] if ":" in reference else "",
            "arn": "",
        }
    return None


def build_relationships(resources, arn_index, value_index, bucket_index, account_names, bu_map):
    relationships = []
    seen = set()
    for source, row in resources:
        if not source.get("dependency_source"):
            continue
        for field, raw_value in row.items():
            if not source_candidate_column(field):
                continue
            value = clean(raw_value)
            if not value or value == source.get("arn") or value == source.get("name"):
                continue
            for reference in references_from_value(value):
                target, match_type = target_for_reference(reference, source, arn_index, value_index, bucket_index)
                if not target:
                    target = external_from_special(reference, source, account_names, bu_map)
                relation = make_relationship(
                    source,
                    target,
                    field,
                    reference,
                    match_type,
                    "high" if match_type in {"arn", "s3"} else "medium",
                )
                if not relation:
                    continue
                key = relationship_key(source, target, reference, field)
                if key in seen:
                    continue
                seen.add(key)
                relationships.append(relation)
    return relationships


def percent(part, total):
    return round((part / total) * 100, 2) if total else 0


def summarize(relationships, account_names):
    account_edges = {}
    by_category = Counter()
    by_source_type = Counter()
    by_target_type = Counter()
    by_scope = Counter()

    for item in relationships:
        by_category[item["relationship_category"]] += 1
        by_source_type[(item["source_resource_type"], item["source_resource_label"])] += 1
        by_target_type[(item["target_resource_type"], item["target_resource_label"])] += 1
        by_scope[item["relationship_scope"]] += 1
        key = (item["source_account_id"], item["target_account_id"])
        if key not in account_edges:
            account_edges[key] = {
                "source_account_id": item["source_account_id"],
                "source_account_name": item["source_account_name"],
                "source_business_unit": item["source_business_unit"],
                "target_account_id": item["target_account_id"],
                "target_account_name": item["target_account_name"],
                "target_business_unit": item["target_business_unit"],
                "relationship_scope": item["relationship_scope"],
                "count": 0,
                "categories": Counter(),
                "source_types": Counter(),
                "target_types": Counter(),
            }
        edge = account_edges[key]
        edge["count"] += 1
        edge["categories"][item["relationship_category"]] += 1
        edge["source_types"][item["source_resource_label"]] += 1
        edge["target_types"][item["target_resource_label"]] += 1

    edge_rows = []
    for edge in account_edges.values():
        edge_rows.append({
            "source_account_id": edge["source_account_id"],
            "source_account_name": edge["source_account_name"],
            "source_business_unit": edge["source_business_unit"],
            "target_account_id": edge["target_account_id"],
            "target_account_name": edge["target_account_name"],
            "target_business_unit": edge["target_business_unit"],
            "relationship_scope": edge["relationship_scope"],
            "count": edge["count"],
            "top_categories": ", ".join(name for name, _ in edge["categories"].most_common(4)),
            "top_source_types": ", ".join(name for name, _ in edge["source_types"].most_common(4)),
            "top_target_types": ", ".join(name for name, _ in edge["target_types"].most_common(4)),
        })

    total = len(relationships)
    cross = by_scope.get("cross_account", 0)
    external = by_scope.get("external_reference", 0)
    accounts = {
        item["source_account_id"]
        for item in relationships
        if item["source_account_id"]
    } | {
        item["target_account_id"]
        for item in relationships
        if item["target_account_id"]
    }

    return {
        "totals": {
            "relationships": total,
            "crossAccount": cross,
            "sameAccount": by_scope.get("same_account", 0),
            "externalReferences": external,
            "accountsInvolved": len(accounts),
            "crossAccountPercent": percent(cross, total),
        },
        "byScope": [{"scope": key, "count": count, "percent_total": percent(count, total)} for key, count in by_scope.most_common()],
        "byCategory": [{"category": key, "count": count, "percent_total": percent(count, total)} for key, count in by_category.most_common()],
        "bySourceType": [
            {"resource_type": key[0], "resource_label": key[1], "count": count, "percent_total": percent(count, total)}
            for key, count in by_source_type.most_common()
        ],
        "byTargetType": [
            {"resource_type": key[0], "resource_label": key[1], "count": count, "percent_total": percent(count, total)}
            for key, count in by_target_type.most_common()
        ],
        "accountEdges": sorted(edge_rows, key=lambda item: (-item["count"], item["source_account_name"], item["target_account_name"])),
    }


def write_csv(path, rows, columns):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=columns)
        writer.writeheader()
        for row in rows:
            writer.writerow({column: row.get(column, "") for column in columns})


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv-dir", required=True)
    parser.add_argument("--output-json", required=True)
    parser.add_argument("--output-dir", required=True)
    args = parser.parse_args()

    set_csv_field_limit()
    catalog = load_catalog()
    bu_map = load_bu_map()
    account_names, _ = account_maps(args.csv_dir)
    resources, arn_index, value_index, bucket_index = build_resource_index(args.csv_dir, catalog, account_names, bu_map)
    relationships = build_relationships(resources, arn_index, value_index, bucket_index, account_names, bu_map)
    summary = summarize(relationships, account_names)

    payload = {
        "generatedAt": now_iso(),
        "method": "Automatic dependency discovery from collected CSVs using ARN, AWS ID, S3, SQS and ECR references.",
        **summary,
        "relationships": relationships,
    }

    os.makedirs(os.path.dirname(args.output_json), exist_ok=True)
    with open(args.output_json, "w", encoding="utf-8") as handle:
        json.dump(payload, handle, ensure_ascii=True, indent=2)

    write_csv(
        os.path.join(args.output_dir, "dependency_relationships.csv"),
        relationships,
        [
            "relationship_scope",
            "relationship_category",
            "source_account_id",
            "source_account_name",
            "source_business_unit",
            "source_region",
            "source_resource_type",
            "source_resource_label",
            "source_resource",
            "target_account_id",
            "target_account_name",
            "target_business_unit",
            "target_region",
            "target_resource_type",
            "target_resource_label",
            "target_resource",
            "field",
            "reference",
            "match_type",
            "confidence",
        ],
    )
    write_csv(
        os.path.join(args.output_dir, "dependency_account_edges.csv"),
        summary["accountEdges"],
        [
            "relationship_scope",
            "source_account_id",
            "source_account_name",
            "source_business_unit",
            "target_account_id",
            "target_account_name",
            "target_business_unit",
            "count",
            "top_categories",
            "top_source_types",
            "top_target_types",
        ],
    )
    print(f"Dependency graph saved to: {args.output_json}")
    print(f"Relationships: {len(relationships)}")


if __name__ == "__main__":
    main()
