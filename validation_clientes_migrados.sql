-- models/validation/validation_clientes_migrados.sql
{{
  config(
    materialized = 'table'
  )
}}

-- EXEMPLO DE VALIDAÇÃO DE MIGRAÇÃO
-- Compara tabela legada vs nova implementação

{% set old_query %}
select
  CLIENTE_ID
  , NOME
  , EMAIL
  , DATA_CADASTRO
  , STATUS
from {{ ref('raw_clientes_legado') }}
{% endset %}

{% set new_query %}
select
  CLIENTE_ID
  , NOME
  , EMAIL
  , DATA_CADASTR
  , STATUS
from {{ ref('stg_clientes') }}
{% endset %}

{{ audit_helper.compare_queries(
    a_query=old_query,
    b_query=new_query,
    primary_key="CLIENTE_ID"
) }}
