# AWS Query Scripts (Steampipe + AWS CLI)

This repository contains scripts for AWS inventory, cost, and usage reporting using Steampipe and AWS CLI.

## Requirements

- Steampipe with the AWS plugin
- AWS CLI (required for Athena/Glue and S3 size scripts)
- Python 3 with pandas and openpyxl
- jq (for Athena/Glue reporting via AWS CLI)
- bc (for `query_aws_s3_bash.sh`)
- AWS connections configured in `~/.steampipe/config/aws.spc`

## Repository Layout

- `Script_All_Resources/`: full inventory across Steampipe tables + optional Athena/Glue via AWS CLI
- `Discovery_Athena/`: Athena usage reports (Steampipe or AWS CLI)
- `discovery_basico/`: curated discovery workflow + enrichment + Excel consolidation
- `discovery_basico/scripts/`: individual Steampipe/AWS CLI queries
- `discovery_basico/scripts/info_aws_*.csv`: reference files used for enrichment

## Script Catalog

### Script_All_Resources

`Script_All_Resources/all_resource.sh`
- What it does: runs Steampipe queries for all tables listed in `tables_query.txt`, writes per-table CSVs, optionally runs Athena/Glue collection via AWS CLI, then generates a summary CSV and Excel workbook.
- How it works:
  - Uses `TABLE_PREFIX=aws_all` and `steampipe query` for each table.
  - Supports `--list`, `--table N`, `--force`, and resume prompts.
  - When enabled, runs Athena/Glue collection using AWS CLI and appends results to the same CSV folder.
  - Generates `resumo_quantidade_linhas.csv` and Excel output.
- Outputs:
  - `Script_All_Resources/csv/*.csv`
  - `Script_All_Resources/all_resources_consolidado_aws.xlsx`
  - `Script_All_Resources/erro_execucao.log`

`Script_All_Resources/tables_query.txt`
- List of Steampipe tables to query (one per line). Comments and blank lines are ignored.

### Discovery_Athena

`Discovery_Athena/athena_report.sh`
- What it does: builds an Athena usage report using Steampipe.
- How it works:
  - Prompts for all accounts or a single connection.
  - Queries `aws_athena_query_execution` for the last N days (limit 10,000 rows).
  - Generates a text report with workgroups, databases, statement types, top queries, and daily distribution.
- Outputs:
  - `Discovery_Athena/athena_reports/athena_executions.csv`
  - `Discovery_Athena/athena_reports/athena_report.txt`

`Discovery_Athena/athena_report_awscli.sh`
- What it does: collects Athena query executions and Glue jobs directly via AWS CLI.
- How it works:
  - Reads profiles and regions from `~/.steampipe/config/aws.spc`.
  - Lists workgroups, collects query executions, and aggregates unique queries with counts.
  - Collects Glue jobs per region.
  - Writes CSVs, summary CSV, and Excel workbook.
- Outputs:
  - `Discovery_Athena/csv/aws_athena_query_execution.csv`
  - `Discovery_Athena/csv/aws_glue_job.csv`
  - `Discovery_Athena/csv/resumo_quantidade_linhas.csv`
  - `Discovery_Athena/aws_resources_consolidado.xlsx`
  - `Discovery_Athena/erro_execucao.log`

### discovery_basico

`discovery_basico/discovery_all.sh`
- What it does: runs a curated set of discovery scripts, enriches outputs with vCPU/memory, and consolidates to Excel.
- How it works:
  - Sets `TABLE_PREFIX=aws_all`, `CSV_DIR`, and reference file paths.
  - Runs scripts in `discovery_basico/scripts/` sequentially with resume/skip support.
  - Enriches EC2, RDS, and ElastiCache CSVs using `info_aws_*.csv` reference files and adds totals.
  - Consolidates CSVs and logs into `consolidado_aws.xlsx`.
- Outputs:
  - `discovery_basico/csv/*.csv`
  - `discovery_basico/consolidado_aws.xlsx`
  - `discovery_basico/last_completed.txt`

### discovery_basico/scripts

All scripts in this folder write CSVs to `CSV_DIR` and expect `TABLE_PREFIX` and `CSV_DIR` to be set (usually by `discovery_all.sh`). To run one manually:

```bash
TABLE_PREFIX=aws_all CSV_DIR=./csv bash discovery_basico/scripts/<script>.sh
```

`query_aws_cost_by_region_monthly.sh`
- Steampipe table: `aws_cost_by_region_monthly`
- Output: `aws_cost_by_region_monthly.csv`
- Captures monthly cost and usage metrics by region.

`query_aws_cost_by_service_usage_type_monthly.sh`
- Steampipe table: `aws_cost_by_service_usage_type_monthly`
- Output: `aws_cost_by_service_usage_type_monthly.csv`
- Captures monthly cost and usage metrics by service and usage type.

`query_aws_ec2_application_load_balancer.sh`
- Steampipe table: `aws_ec2_application_load_balancer`
- Output: `aws_ec2_application_load_balancer.csv`
- Captures ALB identifiers, scheme, type, and account metadata.

`query_aws_ec2_classic_load_balancer.sh`
- Steampipe table: `aws_ec2_classic_load_balancer`
- Output: `aws_ec2_classic_load_balancer.csv`
- Captures classic ELB identifiers and account metadata.

`query_aws_ec2_network_load_balancer.sh`
- Steampipe table: `aws_ec2_network_load_balancer`
- Output: `aws_ec2_network_load_balancer.csv`
- Captures NLB identifiers, scheme, type, and account metadata.

`query_aws_ec2_instance.sh`
- Steampipe table: `aws_ec2_instance`
- Output: `aws_ec2_instance.csv`
- Captures instance metadata, instance type, state, and tags.

`query_aws_ec2_block.sh`
- Steampipe tables: `aws_ec2_instance` + `aws_ebs_volume`
- Output: `aws_ec2_instance_block.csv`
- Joins instances with attached EBS volumes to compute total volume size per instance.

`query_aws_efs_file_system.sh`
- Steampipe table: `aws_efs_file_system`
- Output: `aws-efs-elastic_file_system.csv`
- Captures EFS size and throughput fields.

`query_aws_eks_node_group.sh`
- Steampipe table: `aws_eks_node_group`
- Output: `aws_eks_node_group.csv`
- Captures node group status, scaling config, and instance types.

`query_aws_elasticache_cluster.sh`
- Steampipe table: `aws_elasticache_cluster`
- Output: `aws_elasticache_cluster.csv`
- Captures ElastiCache cluster size, engine, and node types.

`query_aws_rds_db_cluster.sh`
- Steampipe table: `aws_rds_db_cluster`
- Output: `aws_rds_db_cluster.csv`
- Captures cluster engine, status, and node count.

`query_aws_rds_db_instance.sh`
- Steampipe table: `aws_rds_db_instance`
- Output: `aws_rds_db_instance.csv`
- Captures instance class, storage, engine, and backup retention.

`query_aws_s3.sh`
- Steampipe table: `aws_s3_bucket`
- Output: `aws_s3_bucket.csv`
- Captures bucket name, region, and account metadata.

`query_aws_s3_bash.sh`
- AWS CLI + CloudWatch metrics
- Output: `aws_s3_bucket_size.csv`
- Lists buckets per AWS CLI profile, fetches BucketSizeBytes averages for the last 3 days, and includes a TOTAL row.

## Configuration Notes

### AWS Connections
Example `~/.steampipe/config/aws.spc`:
```
connection "aws_account1" {
  plugin = "aws"
  profile = "account1-profile"
  regions = ["us-east-1", "us-west-2"]
}

connection "aws_account2" {
  plugin = "aws"
  profile = "account2-profile"
  regions = ["eu-west-1"]
}
```

### Multi-Account Aggregation
```
connection "aws_all" {
  plugin = "aws"
  type = "aggregator"
  connections = ["aws_account1", "aws_account2"]
}
```

## Common Issues

- **Steampipe connection failed**: confirm AWS credentials and test `steampipe query "select 1"`.
- **Access denied**: required IAM permissions vary by table.
- **Empty CSVs**: may mean the account/region has no resources for that service.
