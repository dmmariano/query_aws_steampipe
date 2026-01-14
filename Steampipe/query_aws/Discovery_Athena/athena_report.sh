#!/bin/bash

# ─────────────────────────────────────────────────────────────
# 📊 Script para Relatório de Uso do Amazon Athena
# ─────────────────────────────────────────────────────────────
#
# DESCRIÇÃO:
# Este script coleta e analisa dados de execuções de queries no Amazon Athena
# através do Steampipe, fornecendo insights detalhados sobre o uso do serviço.
# Pode ser executado para todas as contas AWS configuradas ou para uma conta específica.
#
# FUNCIONALIDADES:
# - Seleção personalizada do período do relatório (em dias)
# - Relatório abrangente com:
#   - Origem das chamadas (workgroups)
#   - Bancos de dados acessados
#   - Queries executadas e frequência
#   - Distribuição de execuções por dia
#   - Estatísticas por workgroup e database
#
# PRÉ-REQUISITOS:
# - Steampipe instalado e configurado
# - Conexões AWS configuradas no arquivo .steampipe/config/aws.spc
# - Aggregator "aws_all" configurado para múltiplas contas
# - Python 3 com pandas instalado
#
# USO:
# 1. Execute o script: ./athena_report.sh
# 2. Escolha se deseja executar para todas as contas ou uma específica
# 3. Se escolher uma conta específica, digite o nome da conexão (ex: aws_datalakeprd)
# 4. O script validará a conexão Steampipe
# 5. Digite o número de dias desejado para o relatório
# 6. Coletará os dados e gerará o relatório
#
# SAÍDAS:
# - athena_executions.csv: Dados brutos em formato CSV
# - athena_report.txt: Relatório formatado com análises
#
# ─────────────────────────────────────────────────────────────

export SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export OUTPUT_DIR="${SCRIPT_DIR}/athena_reports"
export CSV_FILE="${OUTPUT_DIR}/athena_executions.csv"
export REPORT_FILE="${OUTPUT_DIR}/athena_report.txt"

mkdir -p "$OUTPUT_DIR"

# Selecionar contas
echo "🔍 Selecionar contas para análise:"
read -p "Executar para todas as contas? (y/n): " RUN_ALL

if [[ "$RUN_ALL" =~ ^[Yy]$ ]]; then
  SEARCH_PATH="aws_all"
  TABLE_NAME="aws_all.aws_athena_query_execution"
  echo "📊 Usando todas as contas (aws_all)."
else
  read -p "Digite o nome da conta (ex: aws_datalakeprd): " ACCOUNT_NAME
  SEARCH_PATH="$ACCOUNT_NAME"
  TABLE_NAME="${ACCOUNT_NAME}.aws_athena_query_execution"
  echo "📊 Usando conta específica: $SEARCH_PATH."
fi

echo "🧪 Testando conexão Steampipe..."
if ! steampipe query "select 1" --search-path "$SEARCH_PATH" > /dev/null 2>&1; then
  echo "❌ Conexão Steampipe falhou."
  exit 1
fi
echo "✅ Conexão OK"

# Solicitar número de dias para o relatório
read -p "🔢 Digite o número de dias para o relatório (ex: 30): " DAYS_REPORT

if ! [[ "$DAYS_REPORT" =~ ^[0-9]+$ ]] || [ "$DAYS_REPORT" -le 0 ]; then
  echo "❌ Número de dias inválido. Usando padrão de 30 dias."
  DAYS_REPORT=30
fi

echo "📊 Coletando dados de execuções do Athena (últimos $DAYS_REPORT dias)..."

# Coletar dados em lotes diários para eficiência
for ((i=0; i<DAYS_REPORT; i++)); do
  echo "📅 Coletando dia $((i+1)) de $DAYS_REPORT..."

  START_DAYS=$((i+1))
  END_DAYS=$i

  if [ $i -eq 0 ]; then
    # Primeira query inclui header
    steampipe query --output csv --search-path "$SEARCH_PATH" >> "$CSV_FILE" << EOF
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
  submission_date_time >= now() - interval '${START_DAYS} days' and submission_date_time < now() - interval '${END_DAYS} days'
order by
  submission_date_time desc;
EOF
  else
    # Queries subsequentes sem header
    steampipe query --output csv --search-path "$SEARCH_PATH" << EOF | tail -n +2 >> "$CSV_FILE"
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
  submission_date_time >= now() - interval '${START_DAYS} days' and submission_date_time < now() - interval '${END_DAYS} days'
order by
  submission_date_time desc;
EOF
  fi

  if [ $? -ne 0 ]; then
    echo "❌ Erro ao coletar dados do dia $((i+1))."
    exit 1
  fi
done

echo "✅ Coleta de dados concluída."

echo "📈 Gerando relatório de análise..."

python3 - <<EOF > "$REPORT_FILE"
import pandas as pd
from collections import Counter
import re

# Carregar dados
df = pd.read_csv('$CSV_FILE')

# Limpar dados vazios
df = df.dropna(subset=['database', 'query', 'workgroup'])

# Converter data
df['submission_date_time'] = pd.to_datetime(df['submission_date_time'])

print("📊 RELATÓRIO DE USO DO AMAZON ATHENA")
print("=" * 50)
print(f"Período: {df['submission_date_time'].min()} até {df['submission_date_time'].max()}")
print(f"Total de execuções: {len(df)}")
print()

# 1. Workgroups (origem das chamadas)
print("🏢 ORIGEM DAS CHAMADAS (Workgroups):")
wg_counts = df['workgroup'].value_counts()
for wg, count in wg_counts.items():
    print(f"  {wg}: {count} execuções")
print()

# 2. Bancos de dados acessados
print("💾 BANCOS DE DADOS ACESSADOS:")
db_counts = df['database'].value_counts()
for db, count in db_counts.items():
    print(f"  {db}: {count} consultas")
print()

# 3. Tipos de statements
print("📝 TIPOS DE STATEMENTS:")
stmt_counts = df['statement_type'].value_counts()
for stmt, count in stmt_counts.items():
    print(f"  {stmt}: {count}")
print()

# 4. Top 10 queries mais executadas
print("🔝 TOP 10 QUERIES MAIS EXECUTADAS:")
# Normalizar queries (remover espaços extras, lowercase)
df['query_norm'] = df['query'].str.strip().str.lower()

# Remover comentários e normalizar
def normalize_query(q):
    # Remover comentários /* */ e --
    q = re.sub(r'/\*.*?\*/', '', q, flags=re.DOTALL)
    q = re.sub(r'--.*', '', q)
    # Remover espaços extras
    q = ' '.join(q.split())
    return q

df['query_norm'] = df['query_norm'].apply(normalize_query)

query_counts = df['query_norm'].value_counts().head(10)
for i, (query, count) in enumerate(query_counts.items(), 1):
    # Mostrar apenas primeiros 100 chars da query
    short_query = query[:100] + "..." if len(query) > 100 else query
    print(f"  {i}. ({count}x) {short_query}")
print()

# 5. Distribuição por dia
print("📅 DISTRIBUIÇÃO DE EXECUÇÕES POR DIA:")
df['date'] = df['submission_date_time'].dt.date
daily_counts = df.groupby('date').size()
for date, count in daily_counts.sort_index(ascending=False).items():
    print(f"  {date}: {count} execuções")
print()

# 6. Queries por workgroup e database
print("🔗 EXECUÇÕES POR WORKGROUP E DATABASE:")
wg_db = df.groupby(['workgroup', 'database']).size().sort_values(ascending=False)
for (wg, db), count in wg_db.items():
    print(f"  {wg} -> {db}: {count}")
print()

print("✅ Relatório salvo em: $REPORT_FILE")
print("📊 Dados brutos salvos em: $CSV_FILE")
EOF

echo "✅ Relatório gerado com sucesso!"
echo "📊 Arquivo de relatório: $REPORT_FILE"
echo "📁 Dados brutos: $CSV_FILE"
