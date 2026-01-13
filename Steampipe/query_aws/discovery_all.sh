#!/bin/bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────
# 🔧 Configuração de Ambiente
# ─────────────────────────────────────────────────────────────

export TABLE_PREFIX="aws_all"
export SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export CSV_DIR="${SCRIPT_DIR}/csv"
export OUTPUT_XLSX="${SCRIPT_DIR}/consolidado_aws.xlsx"

export REF_EC2="${SCRIPT_DIR}/scripts/info_aws_EC2_Instances.csv"
export REF_RDS="${SCRIPT_DIR}/scripts/info_aws_RDS.csv"
export REF_ELASTICACHE="${SCRIPT_DIR}/scripts/info_aws_ElastiCache.csv"

# ─────────────────────────────────────────────────────────────
# ▶ Execução das queries Steampipe
# ─────────────────────────────────────────────────────────────

declare -a SCRIPTS=(
  query_aws_efs_file_system.sh
  query_aws_elasticache_cluster.sh
  query_aws_rds_db_cluster.sh
  query_aws_eks_node_group.sh
  query_aws_rds_db_instance.sh
  query_aws_ec2_application_load_balancer.sh
  query_aws_ec2_network_load_balancer.sh
  query_aws_ec2_classic_load_balancer.sh
  query_aws_cost_by_service_usage_type_monthly.sh
  query_aws_cost_by_region_monthly.sh
  query_aws_ec2_instance.sh
  query_aws_ec2_block.sh
  query_aws_s3.sh
  query_aws_s3_bash.sh
)

echo "▶ Executando scripts de coleta de dados..."

spinner() {
  local pid=$1
  local delay=0.1
  local spinstr='|/-\'
  tput civis  # Oculta o cursor
  while kill -0 $pid 2>/dev/null; do
    local temp=${spinstr#?}
    printf " [%c]  " "$spinstr"
    spinstr=$temp${spinstr%"$temp"}
    sleep $delay
    printf "\b\b\b\b\b\b"
  done
  tput cnorm  # Restaura o cursor
}

for script in "${SCRIPTS[@]}"; do
  echo -e "\n──────────────────────────────────────────────"
  echo "🚀 Iniciando: ${script}"

  bash "${SCRIPT_DIR}/scripts/${script}" &
  pid=$!
  spinner $pid
  wait $pid
  exit_code=$?

  if [ $exit_code -eq 0 ]; then
    echo "✅ Finalizado com sucesso: ${script}"
  else
    echo "❌ Erro ao executar: ${script}" >&2
    exit 1
  fi
done

# ─────────────────────────────────────────────────────────────
# 🔗 Enriquecimento de EC2, RDS e ElastiCache com vCPU/Memória
# ─────────────────────────────────────────────────────────────

echo "🔄 Enriquecendo arquivos CSV com informações de vCPU e memória..."

env python3 - <<'EOF'
import pandas as pd
import os

csv_enrichment_map = [
    {
        "file_path": os.path.join(os.environ["CSV_DIR"], "aws_ec2_instance.csv"),
        "shape_column": "instance_type",
        "ref_file": os.environ["REF_EC2"],
        "memory_column": "Instance Memory",
        "needs_cleanup": True
    },
    {
        "file_path": os.path.join(os.environ["CSV_DIR"], "aws_ec2_instance_block.csv"),
        "shape_column": "instance_type",
        "ref_file": os.environ["REF_EC2"],
        "memory_column": "Instance Memory",
        "needs_cleanup": True
    },
    {
        "file_path": os.path.join(os.environ["CSV_DIR"], "aws_rds_db_instance.csv"),
        "shape_column": "class",
        "ref_file": os.environ["REF_RDS"],
        "memory_column": "Memory",
        "needs_cleanup": False  # ← Não precisa limpar vCPUs ou GiB
    },
    {
        "file_path": os.path.join(os.environ["CSV_DIR"], "aws_elasticache_cluster.csv"),
        "shape_column": "cache_node_type",
        "ref_file": os.environ["REF_ELASTICACHE"],
        "memory_column": "Memory",
        "needs_cleanup": True
    }
]

for entry in csv_enrichment_map:
    file_path = entry["file_path"]
    shape_column = entry["shape_column"]
    ref_file = entry["ref_file"]
    memory_column = entry["memory_column"]
    needs_cleanup = entry["needs_cleanup"]

    print(f"🔍 Processando: {file_path}")

    # Carrega CSV de referência
    shape_df = pd.read_csv(ref_file)
    shape_df.columns = [c.strip() for c in shape_df.columns]
    shape_df = shape_df.rename(columns={
        "API Name": "instance_type",
        "vCPUs": "vcpu_raw",
        memory_column: "memory_raw"
    })

    if needs_cleanup:
        shape_df["vcpu"] = shape_df["vcpu_raw"].astype(str).str.extract(r'(\d+)')[0].astype(float)
        shape_df["memory_gb"] = shape_df["memory_raw"].astype(str).str.extract(r'([\d\.]+)')[0].astype(float)
    else:
        shape_df["vcpu"] = pd.to_numeric(shape_df["vcpu_raw"], errors="coerce")
        shape_df["memory_gb"] = pd.to_numeric(shape_df["memory_raw"], errors="coerce")

    shape_df = shape_df[["instance_type", "vcpu", "memory_gb"]]

    # Carrega CSV de origem
    df = pd.read_csv(file_path)
    df.columns = [c.strip().lower() for c in df.columns]

    if shape_column not in df.columns:
        print(f"⚠️ Pulando {file_path}: coluna '{shape_column}' não encontrada.")
        continue

    df = df.rename(columns={shape_column: "instance_type"})
    merged_df = df.merge(shape_df, on="instance_type", how="left")

    # Reorganiza colunas
    cols = list(merged_df.columns)
    if "vcpu" in cols and "memory_gb" in cols:
        idx = cols.index("instance_type") + 1
        cols.remove("vcpu")
        cols.remove("memory_gb")
        cols[idx:idx] = ["vcpu", "memory_gb"]
        merged_df = merged_df[cols]

    # Linha de totais
    total_row = {col: "" for col in merged_df.columns}
    total_row["instance_type"] = "TOTAL"
    total_row["vcpu"] = merged_df["vcpu"].sum(min_count=1)
    total_row["memory_gb"] = merged_df["memory_gb"].sum(min_count=1)

    merged_df = pd.concat([merged_df, pd.DataFrame([total_row])], ignore_index=True)
    merged_df.to_csv(file_path, index=False)
    print(f"✅ Enriquecido: {file_path}")

EOF

# ─────────────────────────────────────────────────────────────
# 📦 Geração de planilha consolidada com todos os CSVs/LOGs
# ─────────────────────────────────────────────────────────────

echo "📘 Consolidando CSVs e LOGs em planilha Excel..."

env python3 - <<'EOF'
import pandas as pd
import glob
import os

csv_dir = os.environ["CSV_DIR"]
output_xlsx = os.environ["OUTPUT_XLSX"]

csv_files = glob.glob(os.path.join(csv_dir, "*.csv")) + glob.glob(os.path.join(csv_dir, "*.log"))
writer = pd.ExcelWriter(output_xlsx, engine="openpyxl")

for file in csv_files:
    try:
        df = pd.read_csv(file, encoding="utf-8", sep=",")
    except UnicodeDecodeError:
        df = pd.read_csv(file, encoding="latin1", sep=",")
    sheet_name = os.path.splitext(os.path.basename(file))[0][:31]
    df.to_excel(writer, sheet_name=sheet_name, index=False)

writer.close()
EOF

echo "✅ Planilha Excel gerada: ${OUTPUT_XLSX}"