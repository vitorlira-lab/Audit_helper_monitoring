# Padrão de Monitoramento com dbt e Audit Helper

![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)
![dbt-version](https://img.shields.io/badge/dbt-1.0.0%2B-blue.svg)

> Este repositório contém o código-fonte do artigo **"Guia Prático: Construindo um Sistema de Monitoramento de Dados com dbt"**.
>
> **Parte 1 de 2:** Este guia cobre a construção do sistema de monitoramento. A Parte 2 abordará dashboards e alertas.

Quem nunca sentiu aquele frio na espinha depois de rodar uma migração de dados? Este projeto implementa um **Guardião de Dados automático** usando dbt e o pacote `dbt_audit_helper` para transformar a validação de dados de um evento estressante para um processo contínuo, robusto e transparente.

## 🎯 O Problema

A validação manual de dados após migrações ou alterações de lógica é lenta, propensa a erros e não escala. Isso drena a energia da equipe de dados e, pior, a confiança dos stakeholders nos dados que consomem.

## ✨ A Solução: Um Guardião de Dados

Este projeto não é apenas um script, mas um **padrão de monitoramento** que usa um modelo dbt incremental para:

* **Descobrir e executar dinamicamente** todos os seus testes de auditoria.
* **Consolidar os resultados** em uma única tabela de monitoramento.
* **Construir um histórico temporal** da qualidade dos seus dados, permitindo a análise de tendências.
* **Servir como base para dashboards** e alertas proativos, transformando a qualidade de dados em um processo ativo, e não reativo.

## 🚀 Começando

### Pré-requisitos
* dbt Core (v1.0.0 ou superior)
* Conhecimento básico de Jinja e macros dbt.

### Instalação

1.  Adicione os pacotes `dbt_audit_helper` e `dbt_utils` ao seu arquivo `packages.yml`:

    ```yaml
    # packages.yml
    packages:
      - package: dbt-labs/audit_helper
        version: [">=0.9.0"]
      - package: dbt-labs/dbt_utils
        version: [">=1.0.0"]
    ```

2.  Instale os pacotes executando:
    ```bash
    dbt deps
    ```

### Estrutura de Pastas

Recomendamos a seguinte estrutura para organizar sua lógica de validação:
```
models/
├── staging/
├── marts/
├── validation/                # <-- Seus modelos de auditoria ficam aqui
│   ├── validation_clientes_migrados.sql
│   └── ...
└── monitoring/                # <-- O guardião de dados fica aqui
    └── audit_helper_monitoring.sql
```

## Como Usar

### Passo 1: Crie seus Modelos de Auditoria

Na sua pasta `models/validation/`, crie modelos que usem a macro `audit_helper.compare_queries`. O Guardião irá encontrar automaticamente qualquer modelo cujo nome comece com `validation_`.

**Exemplo: `models/validation/validation_clientes_migrados.sql`**
```sql
{{
  config(
    materialized = 'table'
  )
}}

{% set old_query %}
select
  CLIENTE_ID, NOME, EMAIL, DATA_CADASTRO, STATUS
from {{ ref('raw_clientes_legado') }}
{% endset %}

{% set new_query %}
select
  CLIENTE_ID, NOME, EMAIL, DATA_CADASTR, STATUS
from {{ ref('stg_clientes') }}
{% endset %}

{{ audit_helper.compare_queries(
    a_query=old_query,
    b_query=new_query,
    primary_key="CLIENTE_ID"
) }}
```

### Passo 2: Adicione o Guardião de Dados

Copie o código deste repositório para o arquivo `models/monitoring/audit_helper_monitoring.sql`.

**Importante:** O guardião usa comentários `-- depends_on:` para construir a DAG corretamente, pois as referências `ref()` são dinâmicas. Você precisará adicionar uma linha para cada modelo de validação que criar, garantindo que o dbt entenda a ordem de execução.

```sql
-- DENTRO DE models/monitoring/audit_helper_monitoring.sql

/*
DEPENDÊNCIAS EXPLÍCITAS:
-- depends_on: {{ ref('validation_clientes_migrados') }}
-- depends_on: {{ ref('validation_pedidos_migrados') }}
*/

with match_snapshot as (
    ...
```

### Passo 3: Documente seu Modelo (Recomendado)

Crie um arquivo `.yml` em `models/monitoring/` para documentar a tabela final e adicionar testes de qualidade sobre o próprio monitoramento.

**Exemplo: `models/monitoring/monitoring.yml`**
```yaml
version: 2

models:
  - name: audit_helper_monitoring
    description: "Tabela de monitoramento histórico dos resultados dos testes de auditoria, construindo uma série temporal da qualidade dos dados."
    columns:
      - name: validation_monitoring_sk
        description: "Chave substituta única para o registro de monitoramento (nome do modelo + data)."
        data_tests:
          - unique
          - not_null
      - name: validation_table_name
        description: "Nome do modelo dbt de validação que gerou o resultado de match."
      - name: equal_percentage
        description: "Percentual de linhas que são exatamente iguais entre as bases comparadas. O ideal é 100%."
      # ... (demais colunas)
```

### Passo 4: Execute o Guardião

Finalmente, execute o modelo de monitoramento. Ele irá rodar todas as suas validações dependentes e consolidar os resultados.

```bash
dbt run --select audit_helper_monitoring
```

## 📈 Resultado Esperado

A execução criará ou atualizará a tabela `audit_helper_monitoring` com os resultados mais recentes de suas validações, pronta para ser consumida por dashboards ou sistemas de alerta.

| validation_table_name          | equal_percentage | in_legacy_but_not_in_new_percentage |
| ------------------------------ | ---------------- | ----------------------------------- |
| `validation_clientes_migrados` | 1.0000           | 0.0000                              |
| `validation_pedidos_migrados`  | 0.9950           | 0.0030                              |

## 🔮 O que vem a seguir?

Ter o sistema rodando é apenas o começo! Na **Parte 2** desta série, vamos explorar como transformar esses dados de monitoramento em:
* Dashboards de impacto no seu BI.
* Alertas proativos no Slack.
* Otimizações de performance na sua DAG.

## 🤝 Contribuições

Contribuições são bem-vindas! Sinta-se à vontade para abrir um Pull Request ou criar uma Issue.

## ✍️ Autor

* **Vitor Lira** - Engenheiro de Analytics
