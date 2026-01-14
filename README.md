# AWS Data Collection Script

Este script automatiza a coleta de dados de recursos AWS usando Steampipe, salvando os resultados em arquivos CSV individuais e consolidando tudo em uma planilha Excel.

## 📋 Pré-requisitos

- **Steampipe**: Instalado e configurado com acesso aos recursos AWS
- **AWS CLI**: Configurado com credenciais válidas (não incluído neste repositório)
- **Python 3**: Com as bibliotecas `pandas` e `openpyxl`
- **Bash**: Ambiente Unix-like (Linux/macOS)

### Instalação do Steampipe

```bash
# Instalar Steampipe
sudo /bin/sh -c "$(curl -fsSL https://steampipe.io/install/steampipe.sh)"

Referencia -> https://steampipe.io/downloads?install=linux

# Instalar plugin AWS
steampipe plugin install aws
```

### Configuração de Conexões Steampipe

O script utiliza conexões Steampipe configuradas para acessar múltiplas contas AWS. Configure suas conexões no arquivo `.steampipe/config/aws.spc`:

```hcl
# Exemplo de configuração com múltiplas contas
connection "aws_xxz" {
  plugin      = "aws"
  profile     = "?????_HSLReadOnlyAccess"
  regions     = ["us-east-*", "sa-east-*"]
}

connection "aws_xyz" {
  plugin      = "aws"
  profile     = "????_HSLReadOnlyAccess"
  regions     = ["us-east-*", "sa-east-*"]
}

# Aggregator para combinar todas as contas
connection "aws_all" {
  type        = "aggregator"
  plugin      = "aws"
  connections = ["aws_*"]  # Inclui todas as conexões que começam com "aws_"
}
```

**Detalhes importantes:**
- O script `athena_report.sh` utiliza o aggregator `aws_all` para consultar todas as contas configuradas simultaneamente
- Você pode escolher executar o relatório para todas as contas ou para uma conta específica
- Para mais informações sobre configuração de conexões, consulte: [https://steampipe.io/docs/managing/connections](https://steampipe.io/docs/managing/connections)

### Configuração do AWS

Configure suas credenciais AWS usando AWS CLI:

```bash
aws configure
```

Ou defina variáveis de ambiente:

```bash
export AWS_ACCESS_KEY_ID=your_key
export AWS_SECRET_ACCESS_KEY=your_secret
export AWS_DEFAULT_REGION=us-east-1
```

## 🚀 Como Usar

### 1. Preparar lista de tabelas

Crie um arquivo `tables_query.txt` com a lista de tabelas AWS a serem consultadas, uma por linha:

```
aws_ec2_instance
aws_s3_bucket
aws_rds_db_instance
aws_iam_user
```

### 2. Executar os scripts

#### Script Principal (all_resource.sh)

```bash
# Modo interativo (recomendado para primeira execução)
./all_resource.sh

# Listar tabelas disponíveis
./all_resource.sh --list

# Executar apenas uma tabela específica
./all_resource.sh --table 5

# Modo force (continua mesmo com erros)
./all_resource.sh --force
```

**Opções disponíveis:**
- `--list`: Lista todas as tabelas com seus números de índice
- `--table N`: Executa apenas a tabela de número N
- `--force`: Continua executando mesmo se ocorrerem erros em algumas tabelas
- (sem opções): Modo interativo com opções de continuação

#### Script de Relatório do Athena (athena_report.sh)

```bash
# Gerar relatório completo de uso do Athena
./athena_report.sh
```

Este script gera um relatório detalhado com:
- Origem das chamadas (workgroups)
- Bancos de dados acessados
- Queries mais executadas e suas frequências
- Distribuição temporal das execuções
- Estatísticas por workgroup/database

## 📁 Estrutura de Arquivos

Após execução, o script cria:

```
.
├── csv/
│   ├── aws_ec2_instance.csv
│   ├── aws_s3_bucket.csv
│   └── resumo_quantidade_linhas.csv
├── all_resources_consolidado_aws.xlsx
├── erro_execucao.log
└── tables_query.txt
```

## 📊 Saídas

- **CSVs individuais**: Dados brutos de cada tabela em `csv/*.csv`
- **Excel consolidado**: Todas as tabelas em uma planilha Excel com aba de resumo
- **Log de erros**: `erro_execucao.log` com detalhes de falhas
- **Resumo**: `csv/resumo_quantidade_linhas.csv` com contagem de linhas por tabela

## 🛠️ Solução de Problemas

### Erro de conexão Steampipe

```bash
# Testar conexão
steampipe query "select 1"
```

### Erro de permissões AWS

Certifique-se de que suas credenciais têm permissões adequadas para acessar os recursos AWS desejados.

### Erro de instalação de dependências Python

```bash
pip install pandas openpyxl
```

## 📈 Funcionalidades Avançadas

- **Continuação inteligente**: Permite retomar execuções interrompidas
- **Modo força**: Ignora erros e continua processando outras tabelas
- **Execução seletiva**: Permite executar apenas tabelas específicas
- **Progresso em tempo real**: Mostra progresso, tempos e ETA
- **Consolidação automática**: Gera Excel com todas as tabelas

## 🤝 Contribuição

Sinta-se à vontade para abrir issues e pull requests para melhorias.

## 📄 Licença

Este projeto está sob a licença MIT. Veja o arquivo LICENSE para mais detalhes.
