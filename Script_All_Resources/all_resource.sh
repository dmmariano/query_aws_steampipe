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

export TABLE_PREFIX="${TABLE_PREFIX:-aws_all}"
export SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export CSV_DIR="${CSV_DIR:-${SCRIPT_DIR}/csv}"
export OUTPUT_XLSX="${OUTPUT_XLSX:-${SCRIPT_DIR}/all_resources_consolidado_aws.xlsx}"
export ACCOUNT_XLSX_DIR="${ACCOUNT_XLSX_DIR:-${SCRIPT_DIR}/xlsx_por_conta}"
export LOG_FILE="${LOG_FILE:-${SCRIPT_DIR}/erro_execucao.log}"
export RESUMO_CSV="${RESUMO_CSV:-${CSV_DIR}/resumo_quantidade_linhas.csv}"
export DISCOVERY_SUMMARY_JSON="${DISCOVERY_SUMMARY_JSON:-${SCRIPT_DIR}/discovery_summary.json}"
export DEPENDENCY_GRAPH_JSON="${DEPENDENCY_GRAPH_JSON:-${SCRIPT_DIR}/dependency_graph.json}"
export DEPENDENCY_OUTPUT_DIR="${DEPENDENCY_OUTPUT_DIR:-${SCRIPT_DIR}/dependencies}"
export AWS_LOG_CSV_PREVIEW_LINES="${AWS_LOG_CSV_PREVIEW_LINES:-5}"
export AWS_TABLE_CONCURRENCY="${AWS_TABLE_CONCURRENCY:-1}"
export AWS_MAX_ATTEMPTS="${AWS_MAX_ATTEMPTS:-8}"
export AWS_RETRY_MODE="${AWS_RETRY_MODE:-adaptive}"
export AWS_ATHENA_MAX_QUERY_EXECUTIONS="${AWS_ATHENA_MAX_QUERY_EXECUTIONS:-50}"

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
AWS_SELECTED_CONNECTIONS="${AWS_SELECTED_CONNECTIONS:-}"
AWS_SELECTED_TABLES="${AWS_SELECTED_TABLES:-}"
ATHENA_RAN=false
GLUE_RAN=false
WANT_ATHENA=false
WANT_GLUE=false

if ! [[ "$AWS_TABLE_CONCURRENCY" =~ ^[0-9]+$ ]] || [ "$AWS_TABLE_CONCURRENCY" -lt 1 ]; then
  AWS_TABLE_CONCURRENCY=1
fi
if [ "$AWS_TABLE_CONCURRENCY" -gt 1 ]; then
  AWS_TABLE_CONCURRENCY=1
fi
if ! [[ "$AWS_ATHENA_MAX_QUERY_EXECUTIONS" =~ ^[0-9]+$ ]]; then
  AWS_ATHENA_MAX_QUERY_EXECUTIONS=50
fi

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
        "eu-north-") EXPANDED_REGIONS+=("eu-north-1") ;;
        "eu-south-") EXPANDED_REGIONS+=("eu-south-1") ;;
        "af-south-") EXPANDED_REGIONS+=("af-south-1") ;;
        "ca-central-") EXPANDED_REGIONS+=("ca-central-1") ;;
        "ap-south-") EXPANDED_REGIONS+=("ap-south-1") ;;
        "ap-southeast-") EXPANDED_REGIONS+=("ap-southeast-1" "ap-southeast-2") ;;
        "ap-northeast-") EXPANDED_REGIONS+=("ap-northeast-1" "ap-northeast-2" "ap-northeast-3") ;;
        "me-south-") EXPANDED_REGIONS+=("me-south-1") ;;
        "me-central-") EXPANDED_REGIONS+=("me-central-1") ;;
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

  connection_is_selected() {
    local candidate="$1"
    if [ -z "$AWS_SELECTED_CONNECTIONS" ]; then
      return 0
    fi
    IFS=',' read -ra selected_connections <<< "$AWS_SELECTED_CONNECTIONS"
    for selected in "${selected_connections[@]}"; do
      selected="$(trim_value "$selected")"
      if [ "$candidate" = "$selected" ]; then
        return 0
      fi
    done
    return 1
  }

  while IFS= read -r conn_line; do
    connection=$(echo "$conn_line" | sed 's/connection "\(.*\)".*/\1/')
    if ! connection_is_selected "$connection"; then
      continue
    fi
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

append_log() {
  local context="$1"
  local output="$2"

  [ -z "$output" ] && return 0

  {
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$context"
    printf '%s\n\n' "$output"
  } >> "$LOG_FILE"
}

trim_value() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

run_steampipe_table_query() {
  local table="$1"
  local csv_file="$2"
  local error_file="$3"
  local idx_display="$4"
  local total="$5"
  local query_sql="${6:-select * from ${TABLE_PREFIX}.${table};}"
  local region_label="${7:-}"
  local max_attempts="${AWS_STEAMPIPE_QUERY_ATTEMPTS:-3}"

  if ! [[ "$max_attempts" =~ ^[0-9]+$ ]] || [ "$max_attempts" -lt 1 ]; then
    max_attempts=1
  fi

  echo "STEAMPIPE table=${table}"
  if [ -n "$region_label" ]; then
    echo "STEAMPIPE region=${region_label}"
  fi
  echo "STEAMPIPE command=steampipe query --output csv \"${query_sql}\""
  echo "STEAMPIPE sql=${query_sql}"
  echo "STEAMPIPE csv=${csv_file}"
  echo "STEAMPIPE stderr=${error_file}"
  echo "STEAMPIPE start=$(date '+%Y-%m-%d %H:%M:%S')"

  local query_start
  query_start=$(date +%s)
  local query_status=1
  local attempt=1

  while [ "$attempt" -le "$max_attempts" ]; do
    echo "STEAMPIPE attempt=${attempt}/${max_attempts}"
    if [ "$attempt" -gt 1 ]; then
      local retry_delay=$((attempt * 10))
      echo "STEAMPIPE retry_wait_seconds=${retry_delay}"
      sleep "$retry_delay"
    fi

    local plugin_log
    plugin_log=$(ls -t "${HOME}/.steampipe/logs"/plugin-*.log 2>/dev/null | head -n 1)
    local plugin_start_bytes=0
    if [ -n "$plugin_log" ] && [ -f "$plugin_log" ]; then
      echo "STEAMPIPE plugin_log=${plugin_log}"
      plugin_start_bytes=$(wc -c < "$plugin_log" 2>/dev/null || echo 0)
    fi

    > "$error_file"
    > "$csv_file"
    local status_file
    status_file=$(mktemp)
    (
      steampipe query --output csv "$query_sql" 2> >(
        while IFS= read -r line || [ -n "$line" ]; do
          printf 'STEAMPIPE stderr: %s\n' "$line"
          printf '%s\n' "$line" >> "$error_file"
        done
      ) | {
        output_line_count=0
        while IFS= read -r output_line || [ -n "$output_line" ]; do
          printf '%s\n' "$output_line" >> "$csv_file"
          output_line_count=$((output_line_count + 1))
          if [ "$AWS_LOG_CSV_PREVIEW_LINES" -gt 0 ] && [ "$output_line_count" -le "$AWS_LOG_CSV_PREVIEW_LINES" ]; then
            printf 'STEAMPIPE stdout: %s\n' "$output_line"
          elif [ "$AWS_LOG_CSV_PREVIEW_LINES" -gt 0 ] && [ "$output_line_count" -eq $((AWS_LOG_CSV_PREVIEW_LINES + 1)) ]; then
            echo "STEAMPIPE stdout: ... preview limit reached, continuing only in CSV file"
          fi
        done
      }
      printf '%s\n' "${PIPESTATUS[0]}" > "$status_file"
    ) &
    local query_pid=$!
    local attempt_start
    attempt_start=$(date +%s)
    local next_heartbeat=$((attempt_start + 10))

    while kill -0 "$query_pid" 2>/dev/null; do
      sleep 1
      local now
      now=$(date +%s)
      local running_for
      running_for=$((now - attempt_start))
      if [ "$now" -ge "$next_heartbeat" ] && kill -0 "$query_pid" 2>/dev/null; then
        echo "⏳ [$idx_display/$total] Ainda executando: $table (${running_for}s)"
        next_heartbeat=$((now + 10))
      fi
    done

    wait "$query_pid"
    query_status=$?
    if [ -n "$plugin_log" ] && [ -f "$plugin_log" ]; then
      local plugin_end_bytes
      plugin_end_bytes=$(wc -c < "$plugin_log" 2>/dev/null || echo 0)
      if [ "$plugin_end_bytes" -gt "$plugin_start_bytes" ]; then
        echo "STEAMPIPE plugin_delta_begin"
        tail -c "+$((plugin_start_bytes + 1))" "$plugin_log" 2>/dev/null | while IFS= read -r plugin_line || [ -n "$plugin_line" ]; do
          case "$plugin_line" in
            *"PluginManager Get failed for hub.steampipe.io/plugins/turbot/aws@latest: plugin manager is shutting down"*|\
            *"handleConnectionConfigChanges failed: context canceled"*|\
            *"setAllConnectionStateToError failed to acquire connection from pool: closed pool"*|\
            *"RefreshConnections failed with error: failed to update connection state table: closed pool"*|\
            *"failed to send error notification, error"*)
              continue
              ;;
          esac
          printf 'STEAMPIPE plugin: %s\n' "$plugin_line"
        done
        echo "STEAMPIPE plugin_delta_end"
      fi
    fi
    if [ -f "$status_file" ]; then
      query_status="$(cat "$status_file")"
      rm -f "$status_file"
    fi

    if [ "$query_status" -eq 0 ]; then
      break
    fi
    if grep -Eiq 'AccessDenied|AccessDeniedException|not authorized|explicit deny|ExpiredToken|InvalidClientToken|AuthFailure|Unauthorized|Only existing Timestream' "$error_file"; then
      break
    fi
    if [ "$attempt" -ge "$max_attempts" ]; then
      break
    fi
    echo "STEAMPIPE retry_reason=transient_error"
    attempt=$((attempt + 1))
  done

  local query_end
  query_end=$(date +%s)
  if [ -f "$csv_file" ]; then
    echo "STEAMPIPE csv_bytes=$(wc -c < "$csv_file")"
    echo "STEAMPIPE csv_lines=$(wc -l < "$csv_file")"
    if [ "$(wc -l < "$csv_file")" -gt 0 ] && [ "$AWS_LOG_CSV_PREVIEW_LINES" -gt 0 ]; then
      echo "STEAMPIPE csv_preview_begin lines=${AWS_LOG_CSV_PREVIEW_LINES}"
      head -n "$AWS_LOG_CSV_PREVIEW_LINES" "$csv_file" | sed 's/^/STEAMPIPE csv: /'
      echo "STEAMPIPE csv_preview_end"
    fi
  fi
  echo "STEAMPIPE end=$(date '+%Y-%m-%d %H:%M:%S')"
  echo "STEAMPIPE exit_code=${query_status}"
  if [ "$query_status" -eq 0 ]; then
    echo "STEAMPIPE result=success"
  else
    echo "STEAMPIPE result=error"
  fi
  echo "STEAMPIPE duration_seconds=$((query_end - query_start))"
  return "$query_status"
}

run_athena_report() {
  echo "🚀 Collecting Athena executions..."
  local ATHENA_CSV="${CSV_DIR}/aws_athena_query_execution.csv"
  local ATHENA_TMP="${CSV_DIR}/aws_athena_query_execution.tmp"

  echo "account_id,sp_connection_name,region,database,query,executions" > "$ATHENA_CSV"
  > "$ATHENA_TMP"

  if [ "$AWS_MULTI_ACCOUNT" = true ]; then
    for i in "${!AWS_ALL_PROFILES[@]}"; do
      local profile="${AWS_ALL_PROFILES[$i]}"
      local connection="${AWS_ALL_CONNECTIONS[$i]}"
      local account_id="${connection#aws_}"
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

        local REGION_QUERY_COUNT=0
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

            local query_ids
            query_ids=$(echo "$resp" | jq -r '.QueryExecutionIds[]? // empty')
            if [ -n "$query_ids" ]; then
              printf "%s\n" "$query_ids" >> /tmp/query_ids_${region}.txt
              local added_count
              added_count=$(printf "%s\n" "$query_ids" | grep -c . || true)
              REGION_QUERY_COUNT=$((REGION_QUERY_COUNT + added_count))
            fi
            if [ "$AWS_ATHENA_MAX_QUERY_EXECUTIONS" -gt 0 ] && [ "$REGION_QUERY_COUNT" -ge "$AWS_ATHENA_MAX_QUERY_EXECUTIONS" ]; then
              echo "  ℹ️ Athena query execution limit reached for $connection/$region: ${AWS_ATHENA_MAX_QUERY_EXECUTIONS}"
              break
            fi
            NEXT_TOKEN=$(echo "$resp" | jq -r '.NextToken // empty')
            if [ -z "$NEXT_TOKEN" ]; then
              break
            fi
          done
          if [ "$AWS_ATHENA_MAX_QUERY_EXECUTIONS" -gt 0 ] && [ "$REGION_QUERY_COUNT" -ge "$AWS_ATHENA_MAX_QUERY_EXECUTIONS" ]; then
            break
          fi
        done

        while read -r query_id; do
          if [ ! -z "$query_id" ] && [ "$query_id" != "None" ]; then
            query_info=$(aws athena get-query-execution --query-execution-id "$query_id" \
              "${profile_param[@]}" --region "$region" --output json 2>&1)

            if [ $? -eq 0 ]; then
              database=$(echo "$query_info" | jq -r '.QueryExecution.QueryExecutionContext.Database // empty')
              query=$(echo "$query_info" | jq -r '.QueryExecution.Query // empty' | tr '\r\n\t' '   ')
              if [ ! -z "$query" ]; then
                printf "%s\t%s\t%s\t%s\t%s\n" "$account_id" "$connection" "$region" "$database" "$query" >> "$ATHENA_TMP"
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
    local account_id="${AWS_CONNECTION_NAME#aws_}"
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

      local REGION_QUERY_COUNT=0
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

          local query_ids
          query_ids=$(echo "$resp" | jq -r '.QueryExecutionIds[]? // empty')
          if [ -n "$query_ids" ]; then
            printf "%s\n" "$query_ids" >> /tmp/query_ids_${region}.txt
            local added_count
            added_count=$(printf "%s\n" "$query_ids" | grep -c . || true)
            REGION_QUERY_COUNT=$((REGION_QUERY_COUNT + added_count))
          fi
          if [ "$AWS_ATHENA_MAX_QUERY_EXECUTIONS" -gt 0 ] && [ "$REGION_QUERY_COUNT" -ge "$AWS_ATHENA_MAX_QUERY_EXECUTIONS" ]; then
            echo "  ℹ️ Athena query execution limit reached for $AWS_CONNECTION_NAME/$region: ${AWS_ATHENA_MAX_QUERY_EXECUTIONS}"
            break
          fi
          NEXT_TOKEN=$(echo "$resp" | jq -r '.NextToken // empty')
          if [ -z "$NEXT_TOKEN" ]; then
            break
          fi
        done
        if [ "$AWS_ATHENA_MAX_QUERY_EXECUTIONS" -gt 0 ] && [ "$REGION_QUERY_COUNT" -ge "$AWS_ATHENA_MAX_QUERY_EXECUTIONS" ]; then
          break
        fi
      done

      while read -r query_id; do
        if [ ! -z "$query_id" ] && [ "$query_id" != "None" ]; then
          query_info=$(aws athena get-query-execution --query-execution-id "$query_id" \
            "${profile_param[@]}" --region "$region" --output json 2>&1)

          if [ $? -eq 0 ]; then
            database=$(echo "$query_info" | jq -r '.QueryExecution.QueryExecutionContext.Database // empty')
            query=$(echo "$query_info" | jq -r '.QueryExecution.Query // empty' | tr '\r\n\t' '   ')
            if [ ! -z "$query" ]; then
                printf "%s\t%s\t%s\t%s\t%s\n" "$account_id" "$AWS_CONNECTION_NAME" "$region" "$database" "$query" >> "$ATHENA_TMP"
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
      key = $1 FS $2 FS $3 FS $4 FS $5
      count[key]++
    }
    END {
      for (k in count) {
        split(k, parts, FS)
        account_id = parts[1]
        connection = parts[2]
        region = parts[3]
        db = parts[4]
        q = parts[5]
        gsub(/"/, "\"\"", account_id)
        gsub(/"/, "\"\"", connection)
        gsub(/"/, "\"\"", region)
        gsub(/"/, "\"\"", db)
        gsub(/"/, "\"\"", q)
        printf "\"%s\",\"%s\",\"%s\",\"%s\",\"%s\",%d\n", account_id, connection, region, db, q, count[k]
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

  echo "account_id,sp_connection_name,region,name,description,role,created_on,last_modified_on,glue_version,python_version,max_concurrent_runs,worker_type,number_of_workers,max_retries,timeout,job_mode,execution_class,bookmark_option" > "$GLUE_CSV"

  if [ "$AWS_MULTI_ACCOUNT" = true ]; then
    for i in "${!AWS_ALL_PROFILES[@]}"; do
      local profile="${AWS_ALL_PROFILES[$i]}"
      local connection="${AWS_ALL_CONNECTIONS[$i]}"
      local account_id="${connection#aws_}"
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
          echo "$glue_jobs" | jq -r --arg account_id "$account_id" --arg connection "$connection" --arg region "$region" '.Jobs[] | [
            $account_id,
            $connection,
            $region,
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
            .JobBookmarkOption
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
    local account_id="${AWS_CONNECTION_NAME#aws_}"
    for region in "${AWS_EXPANDED_REGIONS[@]}"; do
      echo "  🌍 Querying region: $region"
      glue_jobs=$(aws glue get-jobs "${profile_param[@]}" --region "$region" --output json 2>&1)

      if [ $? -eq 0 ] && [ ! -z "$glue_jobs" ]; then
        echo "$glue_jobs" | jq -r --arg account_id "$account_id" --arg connection "$AWS_CONNECTION_NAME" --arg region "$region" '.Jobs[] | [
          $account_id,
          $connection,
          $region,
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
          .JobBookmarkOption
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
echo "📋 Carregando lista de tabelas..."
TABLES=()
SEEN_TABLES=","
while IFS= read -r line; do
  if [[ "$SEEN_TABLES" == *",$line,"* ]]; then
    continue
  fi
    TABLES+=("$line")
    SEEN_TABLES="${SEEN_TABLES}${line},"
done < <(grep -vE '^\s*$|^\s*#' "$TABLE_LIST")
echo "📋 Tabelas carregadas: ${#TABLES[@]}"

if [ -n "$AWS_SELECTED_TABLES" ]; then
  echo "📋 Aplicando filtro de tabelas selecionadas..."
  FILTERED_TABLES=()
  IFS=',' read -ra selected_tables <<< "$AWS_SELECTED_TABLES"
  TRIMMED_SELECTED_TABLES=()
  for selected in "${selected_tables[@]}"; do
    TRIMMED_SELECTED_TABLES+=("$(trim_value "$selected")")
  done
  for table in "${TABLES[@]}"; do
    for selected in "${TRIMMED_SELECTED_TABLES[@]}"; do
      if [ "$table" = "$selected" ]; then
        FILTERED_TABLES+=("$table")
        break
      fi
    done
  done
  TABLES=("${FILTERED_TABLES[@]}")
  echo "📋 Selected tables from web app: ${#TABLES[@]}"
fi

for selected_table in "${TABLES[@]}"; do
  if [ "$selected_table" = "aws_athena_query_execution" ]; then
    WANT_ATHENA=true
  elif [ "$selected_table" = "aws_glue_job" ]; then
    WANT_GLUE=true
  fi
done

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
    if [ "${AWS_WEB_NONINTERACTIVE:-}" = "1" ] || $force; then
      echo "🤖 Non-interactive mode: starting from table 1 with clean generated outputs."
      rm -rf "$CSV_DIR"
      rm -f "$OUTPUT_XLSX"
      rm -rf "$ACCOUNT_XLSX_DIR"
      rm -f "$DISCOVERY_SUMMARY_JSON"
      rm -f "$LOG_FILE"
      start_idx=0
    else
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
      rm -rf "$ACCOUNT_XLSX_DIR"
      rm -f "$LOG_FILE"
      start_idx=0
    fi
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
sp_err_file=$(mktemp)
if ! steampipe query "select 1" > /dev/null 2>"$sp_err_file"; then
  sp_err=$(cat "$sp_err_file")
  append_log "Erro ao testar conexão do Steampipe" "$sp_err"
  rm -f "$sp_err_file"
  exit_on_expired_token "$sp_err"
  echo "❌ Steampipe connection failed. Check $LOG_FILE"
  exit 1
fi
rm -f "$sp_err_file"
echo "✅ Connection OK"
echo

process_normal_table() {
  local idx="$1"
  local table="${TABLES[$idx]}"
  local idx_display=$((idx + 1))
  local table_start
  table_start=$(date +%s)

  echo "🚀 [$idx_display/$TOTAL] Starting: $table"

  local csv_file="${CSV_DIR}/${table}.csv"
  local error_file
  error_file=$(mktemp)
  local query_sql="select * from ${TABLE_PREFIX}.${table};"
  if [ "$table" = "aws_account" ]; then
    query_sql="select account_id, arn, title, partition, sp_connection_name from ${TABLE_PREFIX}.aws_account;"
  fi

  if ! run_steampipe_table_query "$table" "$csv_file" "$error_file" "$idx_display" "$TOTAL" "$query_sql"; then
    local error_output
    error_output=$(cat "$error_file")
    rm -f "$error_file"
    append_log "Erro na tabela ${table}" "$error_output"
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
        return 1
      fi
    fi
  else
    rm -f "$error_file"
  fi

  if [ ! -f "$csv_file" ] || [ "$(wc -l < "$csv_file")" -le 1 ]; then
    echo "🟡 [$idx_display/$TOTAL] No data (removed): $table"
    rm -f "$csv_file"
  else
    local linhas_total
    linhas_total=$(wc -l < "$csv_file")
    local linhas=$((linhas_total > 0 ? linhas_total - 1 : 0))
    echo "✅ [$idx_display/$TOTAL] OK: $table (${linhas} lines)"
  fi

  local table_end
  table_end=$(date +%s)
  local dur=$((table_end - table_start))
  local elapsed=$((table_end - start_all))
  local completed=$((idx - start_idx + 1))
  [ "$completed" -lt 1 ] && completed=1
  local avg=$((elapsed / completed))
  local remaining=$((TOTAL - idx - 1))
  [ "$remaining" -lt 0 ] && remaining=0
  local eta=$((avg * remaining))

  printf "⏱️  [%s/%s] Time: %ss | Avg: %ss | ETA approx.: %ss\n\n" "$idx_display" "$TOTAL" "$dur" "$avg" "$eta"
  return 0
}

RUNNING_PIDS=()

wait_one_parallel_table() {
  local pid="${RUNNING_PIDS[0]}"
  RUNNING_PIDS=("${RUNNING_PIDS[@]:1}")
  wait "$pid"
  local status=$?
  if [ "$status" -ne 0 ] && ! $force; then
    for running_pid in "${RUNNING_PIDS[@]}"; do
      kill "$running_pid" 2>/dev/null || true
    done
    exit "$status"
  fi
}

wait_all_parallel_tables() {
  while [ ${#RUNNING_PIDS[@]} -gt 0 ]; do
    wait_one_parallel_table
  done
}

for ((idx=start_idx; idx<end_idx; idx++)); do
  table="${TABLES[$idx]}"
  idx_display=$((idx + 1))

  # Check for special AWS CLI tables
  if [[ "$table" == "aws_athena_query_execution" ]]; then
    wait_all_parallel_tables
    table_start=$(date +%s)
    echo "🚀 [$idx_display/$TOTAL] Starting: $table"
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
    table_end=$(date +%s)
    printf "⏱️  Time: %ss\n\n" "$((table_end - table_start))"
  elif [[ "$table" == "aws_glue_job" ]]; then
    wait_all_parallel_tables
    table_start=$(date +%s)
    echo "🚀 [$idx_display/$TOTAL] Starting: $table"
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
    table_end=$(date +%s)
    printf "⏱️  Time: %ss\n\n" "$((table_end - table_start))"
  else
    if [ "$AWS_TABLE_CONCURRENCY" -le 1 ]; then
      process_normal_table "$idx"
    else
      process_normal_table "$idx" &
      RUNNING_PIDS+=("$!")
      if [ ${#RUNNING_PIDS[@]} -ge "$AWS_TABLE_CONCURRENCY" ]; then
        wait_one_parallel_table
      fi
    fi
  fi
done
wait_all_parallel_tables

echo
if [ "$WANT_ATHENA" = true ] || [ "$WANT_GLUE" = true ]; then
  # The selected special reports normally run inside the main loop. This guard
  # keeps partial web executions from collecting Athena/Glue when they were not selected.
  if [ "$WANT_ATHENA" != true ]; then
    ATHENA_RAN=true
  fi
  if [ "$WANT_GLUE" != true ]; then
    GLUE_RAN=true
  fi
  run_athena_glue_report
fi

# Generate summary with CSV names and line counts (without header)
echo "🧮 Generating line summary..."
echo "file,lines" > "$RESUMO_CSV"

for csv_file in "$CSV_DIR"/*.csv; do
  [ -f "$csv_file" ] || continue
  nome_arquivo=$(basename "$csv_file")
  case "$nome_arquivo" in
    resumo_quantidade_linhas.csv|discovery_summary_*.csv)
      continue
      ;;
  esac
  if [ ! -s "$csv_file" ]; then
    echo "🟡 Empty CSV removed from summary: $(basename "$csv_file")"
    rm -f "$csv_file"
    continue
  fi
  linhas_total=$(wc -l < "$csv_file")
  if [ "$linhas_total" -le 0 ]; then
    echo "🟡 CSV without header removed from summary: $(basename "$csv_file")"
    rm -f "$csv_file"
    continue
  fi
  linhas=$((linhas_total > 0 ? linhas_total - 1 : 0))
  echo "${nome_arquivo},${linhas}" >> "$RESUMO_CSV"
done

echo "📝 Summary saved to: $RESUMO_CSV"

# Discovery analytics and Excel consolidation
echo "📊 Building discovery dashboard data..."
python3 "${SCRIPT_DIR}/build_discovery_summary.py" \
  --csv-dir "$CSV_DIR" \
  --xlsx "$OUTPUT_XLSX" \
  --summary-csv "$RESUMO_CSV" \
  --summary-json "$DISCOVERY_SUMMARY_JSON" \
  --log "$LOG_FILE" \
  --account-xlsx-dir "$ACCOUNT_XLSX_DIR"

echo "🔗 Building dependency graph..."
python3 "${SCRIPT_DIR}/build_dependency_graph.py" \
  --csv-dir "$CSV_DIR" \
  --output-json "$DEPENDENCY_GRAPH_JSON" \
  --output-dir "$DEPENDENCY_OUTPUT_DIR"
