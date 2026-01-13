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
curl -fsSL https://steampipe.io/install.sh | bash

# Instalar plugin AWS
steampipe plugin install aws
```

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

### 2. Executar o script

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

### Opções disponíveis

- `--list`: Lista todas as tabelas com seus números de índice
- `--table N`: Executa apenas a tabela de número N
- `--force`: Continua executando mesmo se ocorrerem erros em algumas tabelas
- (sem opções): Modo interativo com opções de continuação

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
