# AWS All Resources Discovery Script

This repository contains a comprehensive script for collecting and consolidating AWS resource data across multiple accounts and regions using Steampipe.

## Overview

The `all_resource.sh` script automates the collection of AWS resource data by querying Steampipe tables, saving results to individual CSV files, and consolidating everything into a single Excel spreadsheet. It supports incremental execution, error handling, and optional Athena/Glue reporting via AWS CLI.

## Features

- **Comprehensive Data Collection**: Queries all configured AWS tables from Steampipe
- **Multi-Account Support**: Supports multiple AWS accounts via Steampipe aggregators
- **Incremental Execution**: Resume interrupted runs from any table
- **Flexible Execution Modes**:
  - Interactive mode with progress tracking
  - Single table execution (`--table N`)
  - List all tables (`--list`)
  - Force mode to continue despite errors (`--force`)
- **Integrated Athena/Glue Reports**: AWS CLI collection for Athena queries and Glue jobs (can be run individually)
- **Progress Tracking**: Real-time progress with ETA calculations
- **Error Handling**: Detailed logging and graceful error recovery
- **Excel Consolidation**: Automatic consolidation of all CSV data into a single Excel file

## Prerequisites

- **Steampipe** installed and configured with AWS plugin
- **AWS CLI** installed (for optional Athena/Glue reports)
- **Python 3** with pandas for Excel generation
- **jq** for JSON processing (for Athena/Glue reports)
- AWS credentials configured in Steampipe (`~/.steampipe/config/aws.spc`)
- Table list file: `tables_query.txt` (contains list of Steampipe tables to query)

## Installation

1. Install Steampipe:
   ```bash
   sudo /bin/sh -c "$(curl -fsSL https://steampipe.io/install/steampipe.sh)"
   ```

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

## Usage

### Basic Execution
```bash
cd Steampipe/query_aws/Script_All_Resources
./all_resource.sh
```

The script will:
- Test Steampipe connection
- Display total number of tables
- Run queries for each table with progress tracking
- Optionally include Athena/Glue reports
- Generate consolidated Excel file

### Command Line Options

#### List All Tables
```bash
./all_resource.sh --list
```
Displays numbered list of all tables from `tables_query.txt`

#### Execute Single Table
```bash
./all_resource.sh --table N
```
Executes only the Nth table from the list

#### Force Mode
```bash
./all_resource.sh --force
```
Continues execution even when encountering errors

#### Resume Previous Run
When CSV files exist from a previous run, the script will prompt to resume from a specific table number.

## File Structure

```
Script_All_Resources/
├── all_resource.sh              # Main execution script
├── tables_query.txt             # List of Steampipe tables to query
├── csv/                         # Output directory for CSV files
│   ├── table1.csv
│   ├── table2.csv
│   └── resumo_quantidade_linhas.csv
├── all_resources_consolidado_aws.xlsx  # Consolidated Excel output
├── erro_execucao.log            # Error log file
└── .DS_Store                    # macOS system file
```

## Output Files

- **CSV Files**: Individual table data in `csv/` directory
- **Excel File**: `all_resources_consolidado_aws.xlsx` with:
  - `00_resumo` sheet: Summary of row counts per table
  - Individual sheets for each table's data
- **Summary CSV**: `resumo_quantidade_linhas.csv` with file names and row counts
- **Error Log**: `erro_execucao.log` with detailed error information

## Configuration

### tables_query.txt Format
```
aws_ec2_instance
aws_s3_bucket
aws_iam_user
aws_rds_db_instance
# Comments are ignored
aws_lambda_function
```

### AWS Connections
Configure multiple AWS accounts in `~/.steampipe/config/aws.spc`:
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
Create an aggregator connection:
```
connection "aws_all" {
  plugin = "aws"
  type = "aggregator"
  connections = ["aws_account1", "aws_account2"]
}
```

## Athena/Glue Integration

When prompted, the script can optionally collect:
- **Athena Query Executions**: Query history, databases, workgroups
- **Glue Jobs**: Job configurations, execution details, metadata

This requires:
- Valid AWS CLI credentials
- Appropriate IAM permissions for Athena and Glue services

## Troubleshooting

### Common Issues

1. **Steampipe Connection Failed**
   - Verify AWS credentials are configured
   - Check `~/.steampipe/config/aws.spc` configuration
   - Run `steampipe query "select 1"`

2. **Access Denied Errors**
   - Ensure IAM user/role has appropriate permissions
   - Some tables may require specific AWS service permissions

3. **Empty CSV Files**
   - Check if the AWS account has resources for that service
   - Verify correct regions are configured

### Logs
Check `erro_execucao.log` for detailed error information and debugging.

## Performance Notes

- Large datasets may take significant time to process
- Excel consolidation is memory-intensive for many/large tables
- Consider running single tables (`--table N`) for testing
- Use `--force` mode to skip problematic tables in production

## Contributing

1. Fork the repository
2. Create a feature branch
3. Test changes with sample data
4. Update documentation as needed
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.
