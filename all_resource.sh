#!/bin/bash

# ─────────────────────────────────────────────────────────────
# 📋 Script para coleta de dados AWS via Steampipe
# ─────────────────────────────────────────────────────────────
#
# Este script executa queries em tabelas AWS usando Steampipe,
# salva os resultados em CSVs e consolida tudo em um arquivo Excel.
#
# 📁 Arquivos necessários:
#   - tables_query.txt: lista de tabelas a serem processadas
#
# 🚀 Opções de execução:
#   --list          : Lista todas as tabelas com seus números
#   --table N       : Executa apenas a tabela de número N
#   --force         : Continua executando mesmo com erros
#   (sem opções)    : Modo interativo, permite continuar execuções anteriores
#
# 📊 Saídas:
#   - csv/*.csv     : Arquivos CSV individuais por tabela
#   - *.xlsx        : Arquivo Excel consolidado
#   - erro_execucao.log : Log de erros
#
# ─────────────────────────────────────────────────────────────

export TABLE_PREFIX="aws_all"
export SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export CSV_DIR="${SCRIPT_DIR}/csv"
export OUTPUT_XLSX="${SCRIPT_DIR}/all_resources_consolidado_aws.xlsx"
export LOG_FILE="${SCRIPT_DIR}/erro_execucao.log"
export RESUMO_CSV="${CSV_DIR}/resumo_quantidade_linhas.csv"

TABLE_LIST="${SCRIPT_DIR}/tables_query.txt"
[ ! -f "$TABLE_LIST" ] && { echo "Arquivo de tabelas não encontrado: $TABLE_LIST"; exit 1; }

# Verificar opções
force=false
single_table=false
table_num=0

if [[ "$1" == "--force" ]]; then
  force=true
  echo "⚡ Modo force ativado: ignorando erros e continuando."
elif [[ "$1" == "--table" ]]; then
  if [[ "$2" =~ ^[0-9]+$ ]]; then
    table_num=$2
    single_table=true
    echo "🎯 Executando apenas a tabela $table_num"
  else
    echo "❌ Uso: --table <número>"
    exit 1
  fi
elif [[ "$1" == "--list" ]]; then
  echo "📋 Lista de tabelas:"
  idx=1
  while IFS= read -r line; do
    echo "$idx: $line"
    ((idx++))
  done < <(grep -vE '^\s*$|^\s*#' "$TABLE_LIST")
  exit 0
fi

# Monta lista limpa (remove vazias e comentários) para saber o total
TABLES=()
while IFS= read -r line; do
    TABLES+=("$line")
done < <(grep -vE '^\s*$|^\s*#' "$TABLE_LIST")

TOTAL=${#TABLES[@]}
[ "$TOTAL" -eq 0 ] && { echo "Nenhuma tabela válida em: $TABLE_LIST"; exit 1; }

if $single_table; then
  if [ $table_num -gt $TOTAL ]; then
    echo "❌ Tabela $table_num não existe. Total: $TOTAL"
    exit 1
  fi
  start_idx=$((table_num - 1))
  end_idx=$((start_idx + 1))
else
  end_idx=$TOTAL
  # Verificar se há execução anterior
  if [ -d "$CSV_DIR" ] && [ "$(ls -A "$CSV_DIR" 2>/dev/null)" ]; then
    echo "📁 Encontrados arquivos CSV de execução anterior em $CSV_DIR"
    read -p "🔄 Continuar onde parou? (y/n): " choice
    if [[ "$choice" =~ ^[Yy]$ ]]; then
      # Não limpar
      echo "📋 Total de tabelas: $TOTAL"
      while true; do
        read -p "▶️ Digite o número da tabela para continuar (1-$TOTAL): " table_num
        if [[ "$table_num" =~ ^[0-9]+$ ]] && [ "$table_num" -ge 1 ] && [ "$table_num" -le "$TOTAL" ]; then
          start_idx=$((table_num - 1))
          echo "⏭️ Continuando da tabela $table_num: ${TABLES[$start_idx]}"
          break
        else
          echo "❌ Número inválido. Digite um número entre 1 e $TOTAL."
        fi
      done
    else
      echo "🗑️ Iniciando do zero..."
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

echo "📌 Total de tabelas: $TOTAL"
echo "📂 CSV_DIR: $CSV_DIR"
echo "🧾 LOG_FILE: $LOG_FILE"
echo

echo "🧪 Testando conexão Steampipe..."
if ! steampipe query "select 1" > /dev/null 2>>"$LOG_FILE"; then
  echo "❌ Conexão Steampipe falhou. Verifique $LOG_FILE"
  exit 1
fi
echo "✅ Conexão OK"
echo

for ((idx=start_idx; idx<end_idx; idx++)); do
  table="${TABLES[$idx]}"
  idx_display=$((idx + 1))
  csv_file="${CSV_DIR}/${table}.csv"

  table_start=$(date +%s)

  # Cabeçalho de progresso
  echo "🚀 [$idx_display/$TOTAL] Iniciando: $table"

  # Execução (captura erro no LOG_FILE)
  error_output=$(steampipe query --output csv "select * from ${TABLE_PREFIX}.${table};" 2>&1 > "$csv_file")
  exit_code=$?
  if [ $exit_code -ne 0 ]; then
    echo "$error_output" >> "$LOG_FILE"
    if echo "$error_output" | grep -q "AccessDeniedException"; then
      echo "⚠️ [$idx_display/$TOTAL] Acesso negado na tabela: $table (pulando)"
      rm -f "$csv_file"
    else
      if $force; then
        echo "⚠️ [$idx_display/$TOTAL] Erro ignorado na tabela: $table (continuando)"
        rm -f "$csv_file"
      else
        echo "❌ [$idx_display/$TOTAL] Erro na tabela: $table (ver $LOG_FILE)"
        rm -f "$csv_file"
        exit 1
      fi
    fi
  else
    # Remove CSVs vazios (só cabeçalho)
    if [ "$(wc -l < "$csv_file")" -le 1 ]; then
      echo "🟡 [$idx_display/$TOTAL] Sem dados (removido): $table"
      rm -f "$csv_file"
    else
      linhas_total=$(wc -l < "$csv_file")
      linhas=$((linhas_total > 0 ? linhas_total - 1 : 0))
      echo "✅ [$idx_display/$TOTAL] OK: $table (${linhas} linhas)"
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

  # Linha de andamento/ETA
  printf "⏱️  Tempo: %ss | Média: %ss | ETA aprox.: %ss\n\n" "$dur" "$avg" "$eta"
done

# Gerar resumo com nome dos CSVs e quantidade de linhas (sem o cabeçalho)
echo "🧮 Gerando resumo de linhas..."
echo "arquivo,linhas" > "$RESUMO_CSV"

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

echo "📝 Resumo salvo em: $RESUMO_CSV"

# Consolidação em Excel (resumo primeiro)
echo "📦 Consolidando CSVs em Excel... (isso pode demorar dependendo do volume)"

python3 - <<EOF
import pandas as pd
import os

csv_dir = "$CSV_DIR"
xlsx_path = "$OUTPUT_XLSX"
resumo_path = "$RESUMO_CSV"

with pd.ExcelWriter(xlsx_path, engine="openpyxl") as writer:
    # Escreve o resumo como primeira aba
    try:
        df_resumo = pd.read_csv(resumo_path)
        df_resumo.to_excel(writer, sheet_name="00_resumo", index=False)
    except Exception as e:
        print(f"❗ Erro ao adicionar resumo: {e}")

    # Escreve os demais CSVs, exceto o próprio resumo
    for csv_file in os.listdir(csv_dir):
        if csv_file.endswith('.csv') and csv_file != 'resumo_quantidade_linhas.csv':
            csv_path = os.path.join(csv_dir, csv_file)
            try:
                df = pd.read_csv(csv_path)
                sheet_name = csv_file[:-4][:31]  # remove .csv and truncate to 31 chars
                df.to_excel(writer, sheet_name=sheet_name, index=False)
            except Exception as e:
                print(f"❗ Erro ao processar {csv_file}: {e}")
EOF
