#!/bin/bash

# ─────────────────────────────────────────────────────────────
# 📊 AWS CLI Script for Amazon Athena and Glue Usage Report
# ─────────────────────────────────────────────────────────────
#
# DESCRIPTION:
# This script uses AWS CLI directly to collect data from Amazon Athena executions
# and AWS Glue jobs, generating usage reports.
#
# FEATURES:
# - Collect Athena queries
# - Collect Glue jobs and executions
# - Generate consolidated report with unique queries and count
# - Support for multiple AWS accounts
#
# PREREQUISITES:
# - AWS CLI installed and configured
# - jq installed for JSON processing
# - Valid AWS credentials
# - Python 3 with pandas (optional for advanced report)
#
# USAGE:
# ./athena_report_awscli.sh
#
# OPERATION:
# - Automatically reads available profiles from ~/.steampipe/config/aws.spc file
# - Presents menu for AWS profile selection
# - Uses sa-east-1 region by default (compatible with Steampipe configuration)
#
# ─────────────────────────────────────────────────────────────

# Parameters (compatible with all_resource.sh standard)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CSV_DIR="${SCRIPT_DIR}/csv"
OUTPUT_XLSX="${SCRIPT_DIR}/aws_resources_consolidado.xlsx"
RESUMO_CSV="${CSV_DIR}/resumo_quantidade_linhas.csv"
LOG_FILE="${SCRIPT_DIR}/erro_execucao.log"

mkdir -p "$CSV_DIR"
> "$LOG_FILE"  # Clear previous log

# Select accounts (same as athena_report.sh)
echo "🔍 Select accounts for analysis:"
read -p "Run for all accounts? (y/n): " RUN_ALL

if [[ "$RUN_ALL" =~ ^[Yy]$ ]]; then
  echo "📊 Using all accounts (multi-account mode)"
  echo "⚠️  Note: In multi-account mode, valid credentials for each account will be required"
  # For multi-account mode, use default credentials or implement specific logic
  PROFILE=""
  PROFILE_PARAM=""
  # Read all connections and iterate over them
  SPC_FILE="${HOME}/.steampipe/config/aws.spc"
  if [ ! -f "$SPC_FILE" ]; then
    echo "❌ Steampipe configuration file not found: $SPC_FILE"
    exit 1
  fi
  # Extract all connections
  ALL_CONNECTIONS=()
  ALL_PROFILES=()
  while IFS= read -r conn_line; do
    connection=$(echo "$conn_line" | sed 's/connection "\(.*\)".*/\1/')
    profile_line=$(grep -A 10 "$conn_line" "$SPC_FILE" | grep 'profile.*=' | head -1)
    if [ ! -z "$profile_line" ]; then
      profile=$(echo "$profile_line" | sed 's/.*profile.*= "\(.*\)".*/\1/')
      ALL_CONNECTIONS+=("$connection")
      ALL_PROFILES+=("$profile")
    fi
  done < <(grep '^connection ' "$SPC_FILE")
  EXPANDED_REGIONS=("sa-east-1")  # Default region for multi-account mode
else
  # Read available profiles from aws.spc file for individual selection
  SPC_FILE="${HOME}/.steampipe/config/aws.spc"
  if [ ! -f "$SPC_FILE" ]; then
    echo "❌ Steampipe configuration file not found: $SPC_FILE"
    exit 1
  fi

  # Extract connection names using grep
  echo "🔍 Available connections in aws.spc:"
  CONNECTIONS=()
  PROFILES_MAP=()

  # Use grep to extract connections and profiles
  while IFS= read -r conn_line; do
    connection=$(echo "$conn_line" | sed 's/connection "\(.*\)".*/\1/')
    profile_line=$(grep -A 10 "$conn_line" "$SPC_FILE" | grep 'profile.*=' | head -1)
    if [ ! -z "$profile_line" ]; then
      profile=$(echo "$profile_line" | sed 's/.*profile.*= "\(.*\)".*/\1/')
      CONNECTIONS+=("$connection")
      PROFILES_MAP+=("$profile")
      echo "$(( ${#CONNECTIONS[@]} )): $connection"
    fi
  done < <(grep '^connection ' "$SPC_FILE")

  if [ ${#CONNECTIONS[@]} -eq 0 ]; then
    echo "❌ No connections found in aws.spc file"
    exit 1
  fi

  # Select connection
  read -p "Choose the connection number (1-${#CONNECTIONS[@]}): " profile_choice

  if ! [[ "$profile_choice" =~ ^[0-9]+$ ]] || [ "$profile_choice" -lt 1 ] || [ "$profile_choice" -gt ${#CONNECTIONS[@]} ]; then
    echo "❌ Invalid choice. Using the first connection."
    profile_choice=1
  fi

  CONNECTION_NAME="${CONNECTIONS[$((profile_choice-1))]}"
  PROFILE="${PROFILES_MAP[$((profile_choice-1))]}"
  PROFILE_PARAM="--profile $PROFILE"

  # Extract regions from selected connection
  conn_line=$(grep "^connection \"$CONNECTION_NAME\"" "$SPC_FILE")
  regions_line=$(grep -A 10 "$conn_line" "$SPC_FILE" | grep "regions.*=" | head -1)
  if [ ! -z "$regions_line" ]; then
    # Extract regions array
    regions_str=$(echo "$regions_line" | sed 's/.*regions.*= \[\(.*\)\].*/\1/')
    # Remove quotes and split by comma
    IFS=',' read -ra REGIONS_ARRAY <<< "$(echo "$regions_str" | sed 's/[" ]//g')"

    # Expand wildcards
    EXPANDED_REGIONS=()
    for region_pattern in "${REGIONS_ARRAY[@]}"; do
      if [[ "$region_pattern" == *"-*" ]]; then
        # Expand wildcard (e.g.: us-east-* -> us-east-1, us-east-2, etc.)
        base_region=$(echo "$region_pattern" | sed 's/\*$//')
        # Add common regions for each pattern
        case "$base_region" in
          "us-east-") EXPANDED_REGIONS+=("us-east-1" "us-east-2") ;;
          "us-west-") EXPANDED_REGIONS+=("us-west-1" "us-west-2") ;;
          "eu-west-") EXPANDED_REGIONS+=("eu-west-1" "eu-west-2" "eu-west-3") ;;
          "eu-central-") EXPANDED_REGIONS+=("eu-central-1") ;;
          "ap-southeast-") EXPANDED_REGIONS+=("ap-southeast-1" "ap-southeast-2") ;;
          "ap-northeast-") EXPANDED_REGIONS+=("ap-northeast-1" "ap-northeast-2" "ap-northeast-3") ;;
          "sa-east-") EXPANDED_REGIONS+=("sa-east-1") ;;
          *) EXPANDED_REGIONS+=("$region_pattern") ;;
        esac
      else
        EXPANDED_REGIONS+=("$region_pattern")
      fi
    done
  else
    # Fallback to default region
    EXPANDED_REGIONS=("sa-east-1")
  fi

  echo "🌍 Regions to query: ${EXPANDED_REGIONS[*]}"
fi

echo "📊 Collecting AWS data"
if [ ! -z "$PROFILE" ]; then
  echo "Using profile: $PROFILE"
else
  echo "Using default AWS CLI configuration"
fi

# Collect Athena data from multiple regions
echo "🚀 [1/2] Collecting Athena executions..."
ATHENA_CSV="${CSV_DIR}/aws_athena_query_execution.csv"
ATHENA_TMP="${CSV_DIR}/aws_athena_query_execution.tmp"

# Create CSV with header
echo "database,query,executions" > "$ATHENA_CSV"
> "$ATHENA_TMP"

# Collect from all configured regions
for region in "${EXPANDED_REGIONS[@]}"; do
  echo "  🌍 Querying region: $region"
  # Collect workgroups and IDs with pagination (using service max-results/next-token)
  > /tmp/query_ids_${region}.txt
  WORKGROUPS=()
  WG_NEXT_TOKEN=""
  while true; do
    if [ -z "$WG_NEXT_TOKEN" ]; then
      wg_resp=$(aws athena list-work-groups $PROFILE_PARAM --region "$region" --output json 2>>"$LOG_FILE")
    else
      wg_resp=$(aws athena list-work-groups $PROFILE_PARAM --region "$region" --next-token "$WG_NEXT_TOKEN" --output json 2>>"$LOG_FILE")
    fi

    if [ $? -ne 0 ] || [ -z "$wg_resp" ]; then
      break
    fi

    while IFS= read -r wg_name; do
      if [ ! -z "$wg_name" ]; then
        WORKGROUPS+=("$wg_name")
      fi
    done < <(echo "$wg_resp" | jq -r '.WorkGroups[].Name // empty')

    WG_NEXT_TOKEN=$(echo "$wg_resp" | jq -r '.NextToken // empty')
    if [ -z "$WG_NEXT_TOKEN" ]; then
      break
    fi
  done

  if [ ${#WORKGROUPS[@]} -eq 0 ]; then
    WORKGROUPS=("primary")
  fi

  for workgroup in "${WORKGROUPS[@]}"; do
    NEXT_TOKEN=""
    while true; do
      if [ -z "$NEXT_TOKEN" ]; then
        resp=$(aws athena list-query-executions $PROFILE_PARAM --region "$region" \
          --work-group "$workgroup" --max-results 50 --output json 2>>"$LOG_FILE")
      else
        resp=$(aws athena list-query-executions $PROFILE_PARAM --region "$region" \
          --work-group "$workgroup" --max-results 50 --next-token "$NEXT_TOKEN" --output json 2>>"$LOG_FILE")
      fi

      if [ $? -ne 0 ] || [ -z "$resp" ]; then
        break
      fi

      echo "$resp" | jq -r '.QueryExecutionIds[]? // empty' >> /tmp/query_ids_${region}.txt
      NEXT_TOKEN=$(echo "$resp" | jq -r '.NextToken // empty')
      if [ -z "$NEXT_TOKEN" ]; then
        break
      fi
    done
  done

  while read -r query_id; do
    if [ ! -z "$query_id" ] && [ "$query_id" != "None" ]; then
      query_info=$(aws athena get-query-execution --query-execution-id "$query_id" \
        $PROFILE_PARAM --region "$region" --output json 2>>"$LOG_FILE")

      if [ $? -eq 0 ]; then
        database=$(echo "$query_info" | jq -r '.QueryExecution.QueryExecutionContext.Database // empty')
        query=$(echo "$query_info" | jq -r '.QueryExecution.Query // empty' | tr '\r\n\t' '   ')
        if [ ! -z "$query" ]; then
          printf "%s\t%s\n" "$database" "$query" >> "$ATHENA_TMP"
        fi
      fi
    fi
  done < /tmp/query_ids_${region}.txt

  # Clean up temporary region file
  rm -f /tmp/query_ids_${region}.txt
done

# Consolidate unique queries with count
if [ -s "$ATHENA_TMP" ]; then
  awk -F'\t' '{
    key = $1 FS $2
    count[key]++
  }
  END {
    for (k in count) {
      split(k, parts, FS)
      db = parts[1]
      q = parts[2]
      gsub(/"/, "\"\"", db)
      gsub(/"/, "\"\"", q)
      printf "\"%s\",\"%s\",%d\n", db, q, count[k]
    }
  }' "$ATHENA_TMP" >> "$ATHENA_CSV"
fi

# Check if data was obtained
ATHENA_LINE_COUNT=$(wc -l < "$ATHENA_CSV")
if [ "$ATHENA_LINE_COUNT" -le 1 ]; then
  echo "🟡 [1/2] No data found for Athena executions"
  rm -f "$ATHENA_CSV"
else
  lines=$((ATHENA_LINE_COUNT - 1))
  echo "✅ [1/2] OK: aws_athena_query_execution (${lines} lines)"
fi

# Collect Glue data from multiple regions
echo "🚀 [2/2] Collecting Glue jobs..."
GLUE_CSV="${CSV_DIR}/aws_glue_job.csv"

# Create CSV with expanded header
echo "name,description,role,created_on,last_modified_on,glue_version,python_version,max_concurrent_runs,worker_type,number_of_workers,max_retries,timeout,job_mode,execution_class,bookmark_option,region" > "$GLUE_CSV"

# Collect from all configured regions
for region in "${EXPANDED_REGIONS[@]}"; do
  echo "  🌍 Querying region: $region"
  glue_jobs=$(aws glue get-jobs $PROFILE_PARAM --region "$region" --output json 2>>"$LOG_FILE")

  if [ $? -eq 0 ] && [ ! -z "$glue_jobs" ]; then
    echo "$glue_jobs" | jq -r --arg region "$region" '.Jobs[] | [
      .Name,
      .Description,
      .Role,
      .CreatedOn,
      .LastModifiedOn,
      .GlueVersion,
      .PythonVersion,
      .MaxConcurrentRuns,
      .WorkerType,
      .NumberOfWorkers,
      .MaxRetries,
      .Timeout,
      .JobMode,
      .ExecutionClass,
      .JobBookmarkOption,
      $region
    ] | @csv' >> "$GLUE_CSV" 2>/dev/null
  fi
done

if [ "$(wc -l < "$GLUE_CSV")" -le 1 ]; then
  echo "🟡 [2/2] No data found for Glue jobs"
  rm -f "$GLUE_CSV"
else
  lines=$(( $(wc -l < "$GLUE_CSV") - 1 ))
  echo "✅ [2/2] OK: aws_glue_job (${lines} lines)"
fi

echo
echo "📦 Consolidating CSVs into Excel..."

# Generate summary with CSV names and line counts
echo "🧮 Generating line summary..."
echo "file,lines" > "$RESUMO_CSV"

shopt -s nullglob
for csv_file in "$CSV_DIR"/*.csv; do
  if [ -f "$csv_file" ]; then
    total_lines=$(wc -l < "$csv_file")
    lines=$((total_lines > 0 ? total_lines - 1 : 0))
    filename=$(basename "$csv_file")
    echo "${filename},${lines}" >> "$RESUMO_CSV"
  fi
done
shopt -u nullglob

echo "📝 Summary saved to: $RESUMO_CSV"

# Excel consolidation (summary first)
python3 - <<EOF
import pandas as pd
import os

csv_dir = "$CSV_DIR"
xlsx_path = "$OUTPUT_XLSX"
resumo_path = "$RESUMO_CSV"

with pd.ExcelWriter(xlsx_path, engine="openpyxl") as writer:
    # Write summary as first sheet
    try:
        df_resumo = pd.read_csv(resumo_path)
        df_resumo.to_excel(writer, sheet_name="00_resumo", index=False)
    except Exception as e:
        print(f"❗ Error adding summary: {e}")

    # Write other CSVs
    for csv_file in os.listdir(csv_dir):
        if csv_file.endswith('.csv') and csv_file != 'resumo_quantidade_linhas.csv':
            csv_path = os.path.join(csv_dir, csv_file)
            try:
                df = pd.read_csv(csv_path)
                sheet_name = csv_file[:-4][:31]  # remove .csv and truncate to 31 chars
                df.to_excel(writer, sheet_name=sheet_name, index=False)
            except Exception as e:
                print(f"❗ Error processing {csv_file}: {e}")
EOF

echo "✅ Processing completed!"
echo "📊 Excel file: $OUTPUT_XLSX"
echo "📁 Individual CSVs: $CSV_DIR"
echo "🧾 Error log: $LOG_FILE"

# Clean up temporary files
rm -f /tmp/query_ids.txt "$ATHENA_TMP"
