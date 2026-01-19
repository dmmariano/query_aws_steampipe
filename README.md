# AWS Query Scripts (Steampipe + AWS CLI)

This repository contains scripts for AWS inventory, cost, and usage reporting using Steampipe and AWS CLI.

## Requirements

- Steampipe with the AWS plugin
- AWS CLI (required for Athena/Glue and S3 size scripts)
- Python 3 with pandas and openpyxl
- jq (for Athena/Glue reporting via AWS CLI)
- bc (for `query_aws_s3_bash.sh`)
- AWS connections configured in `~/.steampipe/config/aws.spc`

## Installation

1. Install Steampipe:
   ```bash
   sudo /bin/sh -c "$(curl -fsSL https://steampipe.io/install/steampipe.sh)"
   ```
   Reference: https://steampipe.io

2. Install AWS plugin for Steampipe:
   ```bash
   steampipe plugin install aws
   ```

3. Configure AWS connections in `~/.steampipe/config/aws.spc`

4. Install required dependencies:
   - AWS CLI
   - Python 3 with pandas (`pip install pandas openpyxl`)
   - jq

5. Create `tables_query.txt` with the list of AWS tables to query (one per line)

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
- Summary: orchestrates a curated discovery run, enriches EC2/RDS/ElastiCache outputs with vCPU and memory using reference CSVs, and consolidates everything into Excel with resume/skip support.
- Outputs:
  - `discovery_basico/csv/*.csv`
  - `discovery_basico/consolidado_aws.xlsx`
  - `discovery_basico/last_completed.txt`

### discovery_basico/scripts

All scripts in this folder write CSVs to `CSV_DIR` and expect `TABLE_PREFIX` and `CSV_DIR` to be set (usually by `discovery_all.sh`). To run one manually:

```bash
TABLE_PREFIX=aws_all CSV_DIR=./csv bash discovery_basico/scripts/<script>.sh
```

Summary of coverage:
- Cost reporting: `query_aws_cost_by_region_monthly.sh`, `query_aws_cost_by_service_usage_type_monthly.sh`.
- Load balancers: `query_aws_ec2_application_load_balancer.sh`, `query_aws_ec2_classic_load_balancer.sh`, `query_aws_ec2_network_load_balancer.sh`.
- Compute and storage: `query_aws_ec2_instance.sh`, `query_aws_ec2_block.sh`, `query_aws_efs_file_system.sh`, `query_aws_eks_node_group.sh`, `query_aws_elasticache_cluster.sh`.
- Databases: `query_aws_rds_db_cluster.sh`, `query_aws_rds_db_instance.sh`.
- S3: `query_aws_s3.sh` (Steampipe), `query_aws_s3_bash.sh` (AWS CLI size metrics).

Outputs are written to `CSV_DIR` and follow each script's CSV filename (for example, `aws_ec2_instance.csv`).

### Docs_Start_Install.sh

Quick install snippet for Steampipe (reference only).

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
