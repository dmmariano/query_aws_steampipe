#!/bin/bash

# ─────────────────────────────────────────────────────────────
# 📋 Script to collect AWS data via Steampipe
# ─────────────────────────────────────────────────────────────
#
# This script runs queries on AWS tables using Steampipe,
# saves the results to CSVs, and consolidates everything into an Excel file.
#
# 📁 Required files:
#   - tables_query.txt: list of tables to process
#
# 🚀 Run options:
#   --list          : List all tables with their numbers
#   --table N       : Run only table number N
#   --force         : Keep running even when errors occur
#   (no options)    : Interactive mode, allows resuming previous runs
#
# 📊 Outputs:
#   - csv/*.csv     : Per-table CSV files
#   - *.xlsx        : Consolidated Excel file
#   - erro_execucao.log : Error log
#
# ─────────────────────────────────────────────────────────────

export TABLE_PREFIX="aws_all"
export SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export CSV_DIR="${SCRIPT_DIR}/csv"
export OUTPUT_XLSX="${SCRIPT_DIR}/all_resources_consolidado_aws.xlsx"
export LOG_FILE="${SCRIPT_DIR}/erro_execucao.log"
export RESUMO_CSV="${CSV_DIR}/resumo_quantidade_linhas.csv"

TABLE_LIST="${SCRIPT_DIR}/tables_query.txt"
[ ! -f "$TABLE_LIST" ] && { echo "Table list file not found: $TABLE_LIST"; exit 1; }

setup_aws_config() {
  local RUN_ALL PROFILE PROFILE_PARAM SPC_FILE
  local -a EXPANDED_REGIONS ALL_CONNECTIONS ALL_PROFILES CONNECTIONS PROFILES_MAP REGIONS_ARRAY

  # Select accounts (same as athena_report_awscli.sh)
  echo "🔍 Select accounts for analysis:"
  read -p "Run for all accounts? (y/n): " RUN_ALL

  if [[ "$RUN_ALL" =~ ^[Yy]$ ]]; then
    echo "📊 Using all accounts (multi-account mode)"
    echo "⚠️  Note: In multi-account mode, valid credentials for each account are required"
    PROFILE=""
    PROFILE_PARAM=""
    SPC_FILE="${HOME}/.steampipe/config/aws.spc"
    if [ ! -f "$SPC_FILE" ]; then
      echo "❌ Steampipe configuration file not found: $SPC_FILE"
      return 1
    fi
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
    EXPANDED_REGIONS=("sa-east-1")
  else
    SPC_FILE="${HOME}/.steampipe/config/aws.spc"
    if [ ! -f "$SPC_FILE" ]; then
      echo "❌ Steampipe configuration file not found: $SPC_FILE"
      return 1
    fi

    echo "🔍 Available connections in aws.spc:"
    CONNECTIONS=()
    PROFILES_MAP=()

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
      return 1
    fi

    read -p "Choose the connection number (1-${#CONNECTIONS[@]}): " profile_choice

    if ! [[ "$profile_choice" =~ ^[0-9]+$ ]] || [ "$profile_choice" -lt 1 ] || [ "$profile_choice" -gt ${#CONNECTIONS[@]} ]; then
      echo "❌ Invalid choice. Using the first connection."
      profile_choice=1
    fi

    CONNECTION_NAME="${CONNECTIONS[$((profile_choice-1))]}"
    PROFILE="${PROFILES_MAP[$((profile_choice-1))]}"
    PROFILE_PARAM="--profile $PROFILE"

    conn_line=$(grep "^connection \"$CONNECTION_NAME\"" "$SPC_FILE")
    regions_line=$(grep -A 10 "$conn_line" "$SPC_FILE" | grep "regions.*=" | head -1)
    if [ ! -z "$regions_line" ]; then
      regions_str=$(echo "$regions_line" | sed 's/.*regions.*= \[\(.*\)\].*/\1/')
      IFS=',' read -ra REGIONS_ARRAY <<< "$(echo "$regions_str" | sed 's/[" ]//g')"

      EXPANDED_REGIONS=()
      for region_pattern in "${REGIONS_ARRAY[@]}"; do
        if [[ "$region_pattern" == *"-*" ]]; then
          base_region=$(echo "$region_pattern" | sed 's/\*$//')
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

  # Export variables for use in other functions
  AWS_PROFILE="$PROFILE"
  AWS_PROFILE_PARAM="$PROFILE_PARAM"
  AWS_EXPANDED_REGIONS=("${EXPANDED_REGIONS[@]}")
}

run_athena_report() {
  echo "🚀 Collecting Athena executions..."
  local ATHENA_CSV="${CSV_DIR}/aws_athena_query_execution.csv"
  local ATHENA_TMP="${CSV_DIR}/aws_athena_query_execution.tmp"

  echo "database,query,executions" > "$ATHENA_CSV"
  > "$ATHENA_TMP"

  for region in "${AWS_EXPANDED_REGIONS[@]}"; do
    echo "  🌍 Querying region: $region"
    > /tmp/query_ids_${region}.txt
    local WORKGROUPS=()
    local WG_NEXT_TOKEN=""
    while true; do
      if [ -z "$WG_NEXT_TOKEN" ]; then
        wg_resp=$(aws athena list-work-groups $AWS_PROFILE_PARAM --region "$region" --output json 2>>"$LOG_FILE")
      else
        wg_resp=$(aws athena list-work-groups $AWS_PROFILE_PARAM --region "$region" --next-token "$WG_NEXT_TOKEN" --output json 2>>"$LOG_FILE")
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
          resp=$(aws athena list-query-executions $AWS_PROFILE_PARAM --region "$region" \
            --work-group "$workgroup" --max-results 50 --output json 2>>"$LOG_FILE")
        else
          resp=$(aws athena list-query-executions $AWS_PROFILE_PARAM --region "$region" \
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
          $AWS_PROFILE_PARAM --region "$region" --output json 2>>"$LOG_FILE")

        if [ $? -eq 0 ]; then
          database=$(echo "$query_info" | jq -r '.QueryExecution.QueryExecutionContext.Database // empty')
          query=$(echo "$query_info" | jq -r '.QueryExecution.Query // empty' | tr '\r\n\t' '   ')
          if [ ! -z "$query" ]; then
            printf "%s\t%s\n" "$database" "$query" >> "$ATHENA_TMP"
          fi
        fi
      fi
    done < /tmp/query_ids_${region}.txt

    rm -f /tmp/query_ids_${region}.txt
  done

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

  ATHENA_LINE_COUNT=$(wc -l < "$ATHENA_CSV")
  if [ "$ATHENA_LINE_COUNT" -le 1 ]; then
    echo "🟡 No data found for Athena executions"
    rm -f "$ATHENA_CSV"
  else
    linhas=$((ATHENA_LINE_COUNT - 1))
    echo "✅ OK: aws_athena_query_execution (${linhas} lines)"
  fi

  rm -f "$ATHENA_TMP"
}

run_glue_report() {
  echo "🚀 Collecting Glue jobs..."
  local GLUE_CSV="${CSV_DIR}/aws_glue_job.csv"

  echo "name,description,role,created_on,last_modified_on,glue_version,python_version,max_concurrent_runs,worker_type,number_of_workers,max_retries,timeout,job_mode,execution_class,bookmark_option,region" > "$GLUE_CSV"

  for region in "${AWS_EXPANDED_REGIONS[@]}"; do
    echo "  🌍 Querying region: $region"
    glue_jobs=$(aws glue get-jobs $AWS_PROFILE_PARAM --region "$region" --output json 2>>"$LOG_FILE")

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
    echo "🟡 No data found for Glue jobs"
    rm -f "$GLUE_CSV"
  else
    linhas=$(( $(wc -l < "$GLUE_CSV") - 1 ))
    echo "✅ OK: aws_glue_job (${linhas} lines)"
  fi
}

run_athena_glue_report() {
  setup_aws_config || return 1
  run_athena_report
  run_glue_report
}

# Check options
force=false
single_table=false
table_num=0

if [[ "$1" == "--force" ]]; then
  force=true
  echo "⚡ Force mode enabled: ignoring errors and continuing."
elif [[ "$1" == "--table" ]]; then
  if [[ "$2" =~ ^[0-9]+$ ]]; then
    table_num=$2
    single_table=true
    echo "🎯 Running only table $table_num"
  else
    echo "❌ Usage: --table <number>"
    exit 1
  fi
elif [[ "$1" == "--list" ]]; then
  echo "📋 Table list:"
  idx=1
  while IFS= read -r line; do
    echo "$idx: $line"
    ((idx++))
  done < <(grep -vE '^\s*$|^\s*#' "$TABLE_LIST")
  exit 0
fi

# Build clean list (remove blanks and comments) to get total
TABLES=()
while IFS= read -r line; do
    TABLES+=("$line")
done < <(grep -vE '^\s*$|^\s*#' "$TABLE_LIST")

TOTAL=${#TABLES[@]}
[ "$TOTAL" -eq 0 ] && { echo "No valid tables in: $TABLE_LIST"; exit 1; }

if $single_table; then
  if [ $table_num -gt $TOTAL ]; then
    echo "❌ Table $table_num does not exist. Total: $TOTAL"
    exit 1
  fi
  start_idx=$((table_num - 1))
  end_idx=$((start_idx + 1))
else
  end_idx=$TOTAL
  # Check for previous run
  if [ -d "$CSV_DIR" ] && [ "$(ls -A "$CSV_DIR" 2>/dev/null)" ]; then
    echo "📁 Found CSV files from a previous run in $CSV_DIR"
    read -p "🔄 Resume where you left off? (y/n): " choice
    if [[ "$choice" =~ ^[Yy]$ ]]; then
      # Do not clean
      echo "📋 Total tables: $TOTAL"
      while true; do
        read -p "▶️ Enter the table number to resume (1-$TOTAL): " table_num
        if [[ "$table_num" =~ ^[0-9]+$ ]] && [ "$table_num" -ge 1 ] && [ "$table_num" -le "$TOTAL" ]; then
          start_idx=$((table_num - 1))
          echo "⏭️ Resuming from table $table_num: ${TABLES[$start_idx]}"
          break
        else
          echo "❌ Invalid number. Enter a number between 1 and $TOTAL."
        fi
      done
    else
      echo "🗑️ Starting from scratch..."
      rm -rf "$CSV_DIR"
      rm -f "$OUTPUT_XLSX"
      rm -f "$LOG_FILE"
      start_idx=0
    fi
  else
    start_idx=0
  fi
fi

mkdir -p "$CSV_DIR"
if [ $start_idx -eq 0 ]; then
  > "$LOG_FILE"
fi

start_all=$(date +%s)

echo "📌 Total tables: $TOTAL"
echo "📂 CSV_DIR: $CSV_DIR"
echo "🧾 LOG_FILE: $LOG_FILE"
echo

echo "🧪 Testing Steampipe connection..."
if ! steampipe query "select 1" > /dev/null 2>>"$LOG_FILE"; then
  echo "❌ Steampipe connection failed. Check $LOG_FILE"
  exit 1
fi
echo "✅ Connection OK"
echo

for ((idx=start_idx; idx<end_idx; idx++)); do
  table="${TABLES[$idx]}"
  idx_display=$((idx + 1))

  table_start=$(date +%s)

  # Progress header
  echo "🚀 [$idx_display/$TOTAL] Starting: $table"

  # Check for special AWS CLI tables
  if [[ "$table" == "aws_athena_query_execution" ]]; then
    if ! setup_aws_config; then
      if $force; then
        echo "⚠️ [$idx_display/$TOTAL] AWS config failed for: $table (continuing)"
        continue
      else
        echo "❌ [$idx_display/$TOTAL] AWS config failed for: $table"
        exit 1
      fi
    fi
    run_athena_report
  elif [[ "$table" == "aws_glue_job" ]]; then
    if ! setup_aws_config; then
      if $force; then
        echo "⚠️ [$idx_display/$TOTAL] AWS config failed for: $table (continuing)"
        continue
      else
        echo "❌ [$idx_display/$TOTAL] AWS config failed for: $table"
        exit 1
      fi
    fi
    run_glue_report
  else
    # Normal Steampipe table query
    csv_file="${CSV_DIR}/${table}.csv"

    # Execution (capture errors in LOG_FILE)
    error_output=$(steampipe query --output csv "select * from ${TABLE_PREFIX}.${table};" 2>&1 > "$csv_file")
    exit_code=$?
    if [ $exit_code -ne 0 ]; then
      echo "$error_output" >> "$LOG_FILE"
      if echo "$error_output" | grep -q "AccessDeniedException"; then
        echo "⚠️ [$idx_display/$TOTAL] Access denied on table: $table (skipping)"
        rm -f "$csv_file"
      else
        if $force; then
          echo "⚠️ [$idx_display/$TOTAL] Error ignored on table: $table (continuing)"
          rm -f "$csv_file"
        else
          echo "❌ [$idx_display/$TOTAL] Error on table: $table (see $LOG_FILE)"
          rm -f "$csv_file"
          exit 1
        fi
      fi
    else
      # Remove empty CSVs (header only)
      if [ "$(wc -l < "$csv_file")" -le 1 ]; then
        echo "🟡 [$idx_display/$TOTAL] No data (removed): $table"
        rm -f "$csv_file"
      else
        linhas_total=$(wc -l < "$csv_file")
        linhas=$((linhas_total > 0 ? linhas_total - 1 : 0))
        echo "✅ [$idx_display/$TOTAL] OK: $table (${linhas} lines)"
      fi
    fi
  fi

  table_end=$(date +%s)
  dur=$((table_end - table_start))

  elapsed=$((table_end - start_all))
  if [ $idx -eq 0 ]; then
    avg=$elapsed
  else
    avg=$((elapsed / idx))
  fi
  remaining=$((TOTAL - idx))
  eta=$((avg * remaining))

  # Progress/ETA line
  printf "⏱️  Time: %ss | Avg: %ss | ETA approx.: %ss\n\n" "$dur" "$avg" "$eta"
done

echo
read -p "📊 Include Athena/Glue report via AWS CLI? (y/n): " include_athena
if [[ "$include_athena" =~ ^[Yy]$ ]]; then
  run_athena_glue_report
fi

# Generate summary with CSV names and line counts (without header)
echo "🧮 Generating line summary..."
echo "file,lines" > "$RESUMO_CSV"

shopt -s nullglob
for csv_file in "$CSV_DIR"/*.csv; do
  if [ -f "$csv_file" ]; then
    linhas_total=$(wc -l < "$csv_file")
    linhas=$((linhas_total > 0 ? linhas_total - 1 : 0))
    nome_arquivo=$(basename "$csv_file")
    echo "${nome_arquivo},${linhas}" >> "$RESUMO_CSV"
  fi
done
shopt -u nullglob

echo "📝 Summary saved to: $RESUMO_CSV"

# Excel consolidation (summary first)
echo "📦 Consolidating CSVs into Excel... (this may take a while depending on volume)"

python3 - <<EOF
import pandas as pd
import os

csv_dir = "$CSV_DIR"
xlsx_path = "$OUTPUT_XLSX"
resumo_path = "$RESUMO_CSV"

with pd.ExcelWriter(xlsx_path, engine="openpyxl") as writer:
    # Write the summary as the first sheet
    try:
        df_resumo = pd.read_csv(resumo_path)
        df_resumo.to_excel(writer, sheet_name="00_summary", index=False)
    except Exception as e:
        print(f"❗ Error adding summary: {e}")

    # Write remaining CSVs, excluding the summary
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
