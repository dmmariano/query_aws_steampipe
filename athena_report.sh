#!/bin/bash

# ─────────────────────────────────────────────────────────────
# 📊 Script para Relatório de Uso do Amazon Athena
# ─────────────────────────────────────────────────────────────
#
# Este script coleta e analisa dados de execuções de queries no Athena,
# fornecendo insights sobre:
# - Origem das chamadas (workgroups)
# - Bancos de dados acessados
# - Queries executadas e frequência
# - Estatísticas mensais
#
# ─────────────────────────────────────────────────────────────

export SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export OUTPUT_DIR="${SCRIPT_DIR}/athena_reports"
export CSV_FILE="${OUTPUT_DIR}/athena_executions.csv"
export REPORT_FILE="${OUTPUT_DIR}/athena_report.txt"

mkdir -p "$OUTPUT_DIR"

echo "🧪 Testando conexão Steampipe..."
if ! steampipe query "select 1" --search-path aws_datalakeprd > /dev/null 2>&1; then
  echo "❌ Conexão Steampipe falhou."
  exit 1
fi
echo "✅ Conexão OK"

echo "📊 Coletando dados de execuções do Athena (últimos 30 dias)..."
steampipe query --output csv --search-path aws_datalakeprd > "$CSV_FILE" << 'EOF'
select
  id,
  workgroup,
  database,
  statement_type,
  submission_date_time,
  query
from
  aws_athena_query_execution
where
  submission_date_time >= now() - interval '30 days'
order by
  submission_date_time desc;
EOF

if [ $? -ne 0 ]; then
  echo "❌ Erro ao coletar dados do Athena."
  exit 1
fi

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
