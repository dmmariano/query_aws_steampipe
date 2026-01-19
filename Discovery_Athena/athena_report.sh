#!/bin/bash

# ─────────────────────────────────────────────────────────────
# 📊 Script for Amazon Athena Usage Report
# ─────────────────────────────────────────────────────────────
#
# DESCRIPTION:
# This script collects and analyzes Amazon Athena query execution data
# through Steampipe, providing detailed insights about service usage.
# Can be executed for all configured AWS accounts or for a specific account.
#
# FEATURES:
# - Custom selection of report period (in days)
# - Comprehensive report with:
#   - Call origins (workgroups)
#   - Accessed databases
#   - Executed queries and frequency
#   - Execution distribution by day
#   - Statistics by workgroup and database
#
# PREREQUISITES:
# - Steampipe installed and configured
# - AWS connections configured in .steampipe/config/aws.spc file
# - "aws_all" aggregator configured for multiple accounts
# - Python 3 with pandas installed
#
# USAGE:
# 1. Run the script: ./athena_report.sh
# 2. Choose whether to run for all accounts or a specific one
# 3. If choosing a specific account, enter the connection name (ex: aws_datalake)
# 4. The script will validate the Steampipe connection
# 5. Enter the desired number of days for the report
# 6. It will collect data and generate the report
#
# OUTPUTS:
# - athena_executions.csv: Raw data in CSV format
# - athena_report.txt: Formatted report with analyses
#
# ─────────────────────────────────────────────────────────────

export SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export OUTPUT_DIR="${SCRIPT_DIR}/athena_reports"
export CSV_FILE="${OUTPUT_DIR}/athena_executions.csv"
export REPORT_FILE="${OUTPUT_DIR}/athena_report.txt"

mkdir -p "$OUTPUT_DIR"

# Select accounts
echo "🔍 Select accounts for analysis:"
read -p "Run for all accounts? (y/n): " RUN_ALL

if [[ "$RUN_ALL" =~ ^[Yy]$ ]]; then
  SEARCH_PATH="aws_all"
  TABLE_NAME="aws_all.aws_athena_query_execution"
  echo "📊 Using all accounts (aws_all)."
else
  read -p "Enter the account name (ex: aws_datalake): " ACCOUNT_NAME
  SEARCH_PATH="$ACCOUNT_NAME"
  TABLE_NAME="${ACCOUNT_NAME}.aws_athena_query_execution"
  echo "📊 Using specific account: $SEARCH_PATH."
fi

echo "🧪 Testing Steampipe connection..."
if ! steampipe query "select 1" --search-path "$SEARCH_PATH" > /dev/null 2>&1; then
  echo "❌ Steampipe connection failed."
  exit 1
fi
echo "✅ Connection OK"

# Request number of days for the report
read -p "🔢 Enter the number of days for the report (ex: 30): " DAYS_REPORT

if ! [[ "$DAYS_REPORT" =~ ^[0-9]+$ ]] || [ "$DAYS_REPORT" -le 0 ]; then
  echo "❌ Invalid number of days. Using default of 30 days."
  DAYS_REPORT=30
fi

echo "📊 Collecting Athena execution data (last $DAYS_REPORT days)..."

# Collect data with a single limited query for performance
steampipe query --output csv --search-path "$SEARCH_PATH" > "$CSV_FILE" << EOF
select
  id,
  workgroup,
  database,
  statement_type,
  submission_date_time,
  query
from
  $TABLE_NAME
where
  submission_date_time >= now() - interval '$DAYS_REPORT days'
order by
  submission_date_time desc
limit 10000;
EOF

if [ $? -ne 0 ]; then
  echo "❌ Error collecting Athena data."
  exit 1
fi

echo "✅ Data collection completed."

echo "📈 Generating analysis report..."

python3 - <<EOF > "$REPORT_FILE"
import pandas as pd
from collections import Counter
import re

# Load data
df = pd.read_csv('$CSV_FILE')

# Check if there is data
if df.empty or len(df) == 0:
    print("📊 AMAZON ATHENA USAGE REPORT")
    print("=" * 50)
    print("❌ No data found for the specified period.")
    print()
    print("✅ Report saved to: $REPORT_FILE")
    print("📊 Raw data saved to: $CSV_FILE")
    exit(0)

# Clean empty data
df = df.dropna(subset=['database', 'query', 'workgroup'])

# Check again after cleaning
if df.empty:
    print("📊 AMAZON ATHENA USAGE REPORT")
    print("=" * 50)
    print("❌ No valid data found after cleaning.")
    print()
    print("✅ Report saved to: $REPORT_FILE")
    print("📊 Raw data saved to: $CSV_FILE")
    exit(0)

# Convert date
df['submission_date_time'] = pd.to_datetime(df['submission_date_time'])

print("📊 AMAZON ATHENA USAGE REPORT")
print("=" * 50)
print(f"Period: {df['submission_date_time'].min()} to {df['submission_date_time'].max()}")
print(f"Total executions: {len(df)}")
print()

# 1. Workgroups (call origins)
print("🏢 CALL ORIGINS (Workgroups):")
wg_counts = df['workgroup'].value_counts()
for wg, count in wg_counts.items():
    print(f"  {wg}: {count} executions")
print()

# 2. Accessed databases
print("💾 ACCESSED DATABASES:")
db_counts = df['database'].value_counts()
for db, count in db_counts.items():
    print(f"  {db}: {count} queries")
print()

# 3. Statement types
print("📝 STATEMENT TYPES:")
stmt_counts = df['statement_type'].value_counts()
for stmt, count in stmt_counts.items():
    print(f"  {stmt}: {count}")
print()

# 4. Top 10 most executed queries
print("🔝 TOP 10 MOST EXECUTED QUERIES:")
# Normalize queries (remove extra spaces, lowercase)
df['query_norm'] = df['query'].str.strip().str.lower()

# Remove comments and normalize
def normalize_query(q):
    # Remove comments /* */ and --
    q = re.sub(r'/\*.*?\*/', '', q, flags=re.DOTALL)
    q = re.sub(r'--.*', '', q)
    # Remove extra spaces
    q = ' '.join(q.split())
    return q

df['query_norm'] = df['query_norm'].apply(normalize_query)

query_counts = df['query_norm'].value_counts().head(10)
for i, (query, count) in enumerate(query_counts.items(), 1):
    # Show only first 100 chars of query
    short_query = query[:100] + "..." if len(query) > 100 else query
    print(f"  {i}. ({count}x) {short_query}")
print()

# 5. Distribution by day
print("📅 EXECUTION DISTRIBUTION BY DAY:")
df['date'] = df['submission_date_time'].dt.date
daily_counts = df.groupby('date').size()
for date, count in daily_counts.sort_index(ascending=False).items():
    print(f"  {date}: {count} executions")
print()

# 6. Queries by workgroup and database
print("🔗 EXECUTIONS BY WORKGROUP AND DATABASE:")
wg_db = df.groupby(['workgroup', 'database']).size().sort_values(ascending=False)
for (wg, db), count in wg_db.items():
    print(f"  {wg} -> {db}: {count}")
print()

print("✅ Report saved to: $REPORT_FILE")
print("📊 Raw data saved to: $CSV_FILE")
EOF

echo "✅ Report generated successfully!"
echo "📊 Report file: $REPORT_FILE"
echo "📁 Raw data: $CSV_FILE"
