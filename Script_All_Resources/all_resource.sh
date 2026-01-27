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

AWS_RUN_MODE="all"
AWS_CONFIG_DONE=false
AWS_CONFIG_MODE=""
AWS_MULTI_ACCOUNT=false
AWS_CONNECTION_NAME=""
AWS_PROFILE=""
AWS_EXPANDED_REGIONS=()
AWS_ALL_CONNECTIONS=()
AWS_ALL_PROFILES=()
AWS_ALL_REGIONS=()
ATHENA_RAN=false
GLUE_RAN=false

TABLE_LIST="${SCRIPT_DIR}/tables_query.txt"
[ ! -f "$TABLE_LIST" ] && { echo "Table list file not found: $TABLE_LIST"; exit 1; }

expand_regions_from_str() {
  local regions_str="$1"
  local -a regions_array=()
  if [ -n "$regions_str" ]; then
    IFS=',' read -ra regions_array <<< "$(echo "$regions_str" | sed 's/[" ]//g')"
  fi
  if [ ${#regions_array[@]} -eq 0 ]; then
    regions_array=("sa-east-1")
  fi

  EXPANDED_REGIONS=()
  for region_pattern in "${regions_array[@]}"; do
    if [[ "$region_pattern" == *"-*" ]]; then
      base_region="${region_pattern%\*}"
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
}

load_steampipe_connections() {
  local spc_file="${HOME}/.steampipe/config/aws.spc"
  if [ ! -f "$spc_file" ]; then
    echo "❌ Steampipe configuration file not found: $spc_file"
    return 1
  fi

  CONNECTIONS=()
  PROFILES_MAP=()
  REGIONS_MAP=()

  while IFS= read -r conn_line; do
    connection=$(echo "$conn_line" | sed 's/connection "\(.*\)".*/\1/')
    profile_line=$(grep -A 20 -F "$conn_line" "$spc_file" | grep 'profile.*=' | head -1)
    if [ -z "$profile_line" ]; then
      continue
    fi
    profile=$(echo "$profile_line" | sed 's/.*profile.*= "\(.*\)".*/\1/')
    regions_line=$(grep -A 20 -F "$conn_line" "$spc_file" | grep "regions.*=" | head -1)
    if [ -n "$regions_line" ]; then
      regions_str=$(echo "$regions_line" | sed 's/.*regions.*= \[\(.*\)\].*/\1/')
    else
      regions_str=""
    fi

    CONNECTIONS+=("$connection")
    PROFILES_MAP+=("$profile")
    REGIONS_MAP+=("$regions_str")
  done < <(grep '^connection ' "$spc_file")

  if [ ${#CONNECTIONS[@]} -eq 0 ]; then
    echo "❌ No connections with profile found in aws.spc file"
    return 1
  fi
}

setup_aws_config() {
  local mode="$1"
  local -a CONNECTIONS PROFILES_MAP REGIONS_MAP

  load_steampipe_connections || return 1

  if [ "$mode" == "all" ]; then
    echo "📊 Using all accounts (multi-account mode)"
    echo "⚠️  Note: In multi-account mode, valid credentials for each account are required"
    AWS_MULTI_ACCOUNT=true
    AWS_ALL_CONNECTIONS=("${CONNECTIONS[@]}")
    AWS_ALL_PROFILES=("${PROFILES_MAP[@]}")
    AWS_ALL_REGIONS=()
    for i in "${!CONNECTIONS[@]}"; do
      expand_regions_from_str "${REGIONS_MAP[$i]}"
      AWS_ALL_REGIONS+=("${EXPANDED_REGIONS[*]}")
    done
    return 0
  fi

  AWS_MULTI_ACCOUNT=false
  echo "🔍 Available connections in aws.spc:"
  for i in "${!CONNECTIONS[@]}"; do
    echo "$(( i + 1 )): ${CONNECTIONS[$i]}"
  done

  read -p "Choose the connection number (1-${#CONNECTIONS[@]}): " profile_choice
  if ! [[ "$profile_choice" =~ ^[0-9]+$ ]] || [ "$profile_choice" -lt 1 ] || [ "$profile_choice" -gt ${#CONNECTIONS[@]} ]; then
    echo "❌ Invalid choice. Using the first connection."
    profile_choice=1
  fi

  AWS_CONNECTION_NAME="${CONNECTIONS[$((profile_choice-1))]}"
  AWS_PROFILE="${PROFILES_MAP[$((profile_choice-1))]}"

  expand_regions_from_str "${REGIONS_MAP[$((profile_choice-1))]}"
  AWS_EXPANDED_REGIONS=("${EXPANDED_REGIONS[@]}")

  echo "📊 Collecting AWS data"
  if [ -n "$AWS_PROFILE" ]; then
    echo "Using profile: $AWS_PROFILE"
  else
    echo "Using default AWS CLI configuration"
  fi
  echo "🌍 Regions to query: ${AWS_EXPANDED_REGIONS[*]}"
}

ensure_aws_config() {
  local mode="$1"
  if [ "$AWS_CONFIG_DONE" = true ] && [ "$AWS_CONFIG_MODE" == "$mode" ]; then
    return 0
  fi
  setup_aws_config "$mode" || return 1
  AWS_CONFIG_DONE=true
  AWS_CONFIG_MODE="$mode"
}

exit_on_expired_token() {
  local output="$1"
  if echo "$output" | grep -q "ExpiredTokenException"; then
    echo "❌ ExpiredTokenException: token expirado. Revalide o token e execute novamente."
    exit 1
  fi
}

run_athena_report() {
  echo "🚀 Collecting Athena executions..."
  local ATHENA_CSV="${CSV_DIR}/aws_athena_query_execution.csv"
  local ATHENA_TMP="${CSV_DIR}/aws_athena_query_execution.tmp"

  echo "database,query,executions" > "$ATHENA_CSV"
  > "$ATHENA_TMP"

  if [ "$AWS_MULTI_ACCOUNT" = true ]; then
    for i in "${!AWS_ALL_PROFILES[@]}"; do
      local profile="${AWS_ALL_PROFILES[$i]}"
      local connection="${AWS_ALL_CONNECTIONS[$i]}"
      local regions_str="${AWS_ALL_REGIONS[$i]}"
      local -a regions=()
      IFS=' ' read -r -a regions <<< "$regions_str"
      if [ ${#regions[@]} -eq 0 ]; then
        regions=("sa-east-1")
      fi
      echo "🔑 Account: ${connection} (profile: ${profile})"
      local -a profile_param=()
      if [ -n "$profile" ]; then
        profile_param=(--profile "$profile")
      fi

      for region in "${regions[@]}"; do
        echo "  🌍 Querying region: $region"
        > /tmp/query_ids_${region}.txt
        local WORKGROUPS=()
        local WG_NEXT_TOKEN=""
        while true; do
          if [ -z "$WG_NEXT_TOKEN" ]; then
            wg_resp=$(aws athena list-work-groups "${profile_param[@]}" --region "$region" --output json 2>&1)
          else
            wg_resp=$(aws athena list-work-groups "${profile_param[@]}" --region "$region" --next-token "$WG_NEXT_TOKEN" --output json 2>&1)
          fi
          if [ $? -ne 0 ]; then
            echo "$wg_resp" >> "$LOG_FILE"
            exit_on_expired_token "$wg_resp"
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
              resp=$(aws athena list-query-executions "${profile_param[@]}" --region "$region" \
                --work-group "$workgroup" --max-results 50 --output json 2>&1)
            else
              resp=$(aws athena list-query-executions "${profile_param[@]}" --region "$region" \
                --work-group "$workgroup" --max-results 50 --next-token "$NEXT_TOKEN" --output json 2>&1)
            fi

            if [ $? -ne 0 ]; then
              echo "$resp" >> "$LOG_FILE"
              exit_on_expired_token "$resp"
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
              "${profile_param[@]}" --region "$region" --output json 2>&1)

            if [ $? -eq 0 ]; then
              database=$(echo "$query_info" | jq -r '.QueryExecution.QueryExecutionContext.Database // empty')
              query=$(echo "$query_info" | jq -r '.QueryExecution.Query // empty' | tr '\r\n\t' '   ')
              if [ ! -z "$query" ]; then
                printf "%s\t%s\n" "$database" "$query" >> "$ATHENA_TMP"
              fi
            else
              echo "$query_info" >> "$LOG_FILE"
              exit_on_expired_token "$query_info"
            fi
          fi
        done < /tmp/query_ids_${region}.txt

        rm -f /tmp/query_ids_${region}.txt
      done
    done
  else
    local -a profile_param=()
    if [ -n "$AWS_PROFILE" ]; then
      profile_param=(--profile "$AWS_PROFILE")
    fi
    for region in "${AWS_EXPANDED_REGIONS[@]}"; do
      echo "  🌍 Querying region: $region"
      > /tmp/query_ids_${region}.txt
      local WORKGROUPS=()
      local WG_NEXT_TOKEN=""
      while true; do
        if [ -z "$WG_NEXT_TOKEN" ]; then
          wg_resp=$(aws athena list-work-groups "${profile_param[@]}" --region "$region" --output json 2>&1)
        else
          wg_resp=$(aws athena list-work-groups "${profile_param[@]}" --region "$region" --next-token "$WG_NEXT_TOKEN" --output json 2>&1)
        fi

        if [ $? -ne 0 ]; then
          echo "$wg_resp" >> "$LOG_FILE"
          exit_on_expired_token "$wg_resp"
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
            resp=$(aws athena list-query-executions "${profile_param[@]}" --region "$region" \
              --work-group "$workgroup" --max-results 50 --output json 2>&1)
          else
            resp=$(aws athena list-query-executions "${profile_param[@]}" --region "$region" \
              --work-group "$workgroup" --max-results 50 --next-token "$NEXT_TOKEN" --output json 2>&1)
          fi

          if [ $? -ne 0 ]; then
            echo "$resp" >> "$LOG_FILE"
            exit_on_expired_token "$resp"
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
            "${profile_param[@]}" --region "$region" --output json 2>&1)

          if [ $? -eq 0 ]; then
            database=$(echo "$query_info" | jq -r '.QueryExecution.QueryExecutionContext.Database // empty')
            query=$(echo "$query_info" | jq -r '.QueryExecution.Query // empty' | tr '\r\n\t' '   ')
            if [ ! -z "$query" ]; then
              printf "%s\t%s\n" "$database" "$query" >> "$ATHENA_TMP"
            fi
          else
            echo "$query_info" >> "$LOG_FILE"
            exit_on_expired_token "$query_info"
          fi
        fi
      done < /tmp/query_ids_${region}.txt

      rm -f /tmp/query_ids_${region}.txt
    done
  fi

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
  ATHENA_RAN=true
}

run_glue_report() {
  echo "🚀 Collecting Glue jobs..."
  local GLUE_CSV="${CSV_DIR}/aws_glue_job.csv"

  echo "name,description,role,created_on,last_modified_on,glue_version,python_version,max_concurrent_runs,worker_type,number_of_workers,max_retries,timeout,job_mode,execution_class,bookmark_option,region" > "$GLUE_CSV"

  if [ "$AWS_MULTI_ACCOUNT" = true ]; then
    for i in "${!AWS_ALL_PROFILES[@]}"; do
      local profile="${AWS_ALL_PROFILES[$i]}"
      local connection="${AWS_ALL_CONNECTIONS[$i]}"
      local regions_str="${AWS_ALL_REGIONS[$i]}"
      local -a regions=()
      IFS=' ' read -r -a regions <<< "$regions_str"
      if [ ${#regions[@]} -eq 0 ]; then
        regions=("sa-east-1")
      fi
      echo "🔑 Account: ${connection} (profile: ${profile})"
      local -a profile_param=()
      if [ -n "$profile" ]; then
        profile_param=(--profile "$profile")
      fi

      for region in "${regions[@]}"; do
        echo "  🌍 Querying region: $region"
        glue_jobs=$(aws glue get-jobs "${profile_param[@]}" --region "$region" --output json 2>&1)

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
        else
          echo "$glue_jobs" >> "$LOG_FILE"
          exit_on_expired_token "$glue_jobs"
        fi
      done
    done
  else
    local -a profile_param=()
    if [ -n "$AWS_PROFILE" ]; then
      profile_param=(--profile "$AWS_PROFILE")
    fi
    for region in "${AWS_EXPANDED_REGIONS[@]}"; do
      echo "  🌍 Querying region: $region"
      glue_jobs=$(aws glue get-jobs "${profile_param[@]}" --region "$region" --output json 2>&1)

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
      else
        echo "$glue_jobs" >> "$LOG_FILE"
        exit_on_expired_token "$glue_jobs"
      fi
    done
  fi

  if [ "$(wc -l < "$GLUE_CSV")" -le 1 ]; then
    echo "🟡 No data found for Glue jobs"
    rm -f "$GLUE_CSV"
  else
    linhas=$(( $(wc -l < "$GLUE_CSV") - 1 ))
    echo "✅ OK: aws_glue_job (${linhas} lines)"
  fi
  GLUE_RAN=true
}

run_athena_glue_report() {
  ensure_aws_config "$AWS_RUN_MODE" || return 1
  if [ "$ATHENA_RAN" != true ]; then
    run_athena_report
  fi
  if [ "$GLUE_RAN" != true ]; then
    run_glue_report
  fi
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

resume_selected=false

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
      resume_selected=true
      while true; do
        echo "🔧 Resume mode:"
        echo "  1) Continue for all accounts"
        echo "  2) Continue for one account (choose from list)"
        read -p "Choose an option (1-2): " resume_mode
        if [[ "$resume_mode" =~ ^[12]$ ]]; then
          break
        fi
        echo "❌ Invalid option. Choose 1 or 2."
      done

      if [ "$resume_mode" = "1" ]; then
        AWS_RUN_MODE="all"
      else
        AWS_RUN_MODE="single"
      fi

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

PARTIAL_RUN=false
if $single_table || [ "$resume_selected" = true ]; then
  PARTIAL_RUN=true
fi

if [ "$PARTIAL_RUN" = true ]; then
  if [ -z "$AWS_RUN_MODE" ] || [ "$AWS_RUN_MODE" != "all" ]; then
    AWS_RUN_MODE="single"
  fi
else
  AWS_RUN_MODE="all"
fi

start_all=$(date +%s)

echo "📌 Total tables: $TOTAL"
echo "📂 CSV_DIR: $CSV_DIR"
echo "🧾 LOG_FILE: $LOG_FILE"
echo

echo "🧪 Testing Steampipe connection..."
sp_err=$(steampipe query "select 1" > /dev/null 2>&1)
if [ $? -ne 0 ]; then
  echo "$sp_err" >> "$LOG_FILE"
  exit_on_expired_token "$sp_err"
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
    if ! ensure_aws_config "$AWS_RUN_MODE"; then
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
    if ! ensure_aws_config "$AWS_RUN_MODE"; then
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
      exit_on_expired_token "$error_output"
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
run_athena_glue_report

# Generate summary with CSV names and line counts (without header)
echo "🧮 Generating line summary..."
echo "file,lines" > "$RESUMO_CSV"

for csv_file in "$CSV_DIR"/*.csv; do
  [ -f "$csv_file" ] || continue
  linhas_total=$(wc -l < "$csv_file")
  linhas=$((linhas_total > 0 ? linhas_total - 1 : 0))
  nome_arquivo=$(basename "$csv_file")
  echo "${nome_arquivo},${linhas}" >> "$RESUMO_CSV"
done

echo "📝 Summary saved to: $RESUMO_CSV"

# Excel consolidation (summary first)
echo "📦 Consolidating CSVs into Excel... (this may take a while depending on volume)"

python3 - <<EOF
import pandas as pd
import os
import sys
import traceback

csv_dir = "$CSV_DIR"
xlsx_path = "$OUTPUT_XLSX"
resumo_path = "$RESUMO_CSV"
log_path = "$LOG_FILE"

with pd.ExcelWriter(xlsx_path, engine="openpyxl") as writer:
    used_sheet_names = set()

    def unique_sheet_name(base):
        base = (base or "sheet")[:31]
        name = base
        i = 1
        while name in used_sheet_names:
            suffix = f"_{i}"
            name = (base[: max(0, 31 - len(suffix))] + suffix)
            i += 1
        used_sheet_names.add(name)
        return name

    # Write the summary as the first sheet
    try:
        df_resumo = pd.read_csv(resumo_path)
        summary_name = unique_sheet_name("00_summary")
        df_resumo.to_excel(writer, sheet_name=summary_name, index=False)
        summary_files = df_resumo["file"].astype(str).tolist()
    except Exception as e:
        msg = f"❗ Error adding summary: {e}"
        print(msg)
        with open(log_path, "a") as log_file:
            log_file.write(msg + "\n")
            log_file.write(traceback.format_exc() + "\n")
        summary_files = []

    # Write remaining CSVs in the same order as the summary
    for csv_file in summary_files:
        if not csv_file.endswith(".csv"):
            continue
        if csv_file == "resumo_quantidade_linhas.csv":
            continue
        csv_path = os.path.join(csv_dir, csv_file)
        if not os.path.isfile(csv_path):
            msg = f"❗ CSV not found: {csv_file}"
            print(msg)
            with open(log_path, "a") as log_file:
                log_file.write(msg + "\n")
            continue
        try:
            df = pd.read_csv(csv_path)
            base_name = csv_file[:-4]
            sheet_name = unique_sheet_name(base_name)
            df.to_excel(writer, sheet_name=sheet_name, index=False)
        except Exception as e:
            msg = f"❗ Error processing {csv_file}: {e}"
            print(msg)
            with open(log_path, "a") as log_file:
                log_file.write(msg + "\n")
                log_file.write(traceback.format_exc() + "\n")
EOF
