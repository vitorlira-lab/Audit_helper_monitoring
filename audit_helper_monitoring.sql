-- models/monitoring/audit_helper_monitoring.sql
{{
    config(
        materialized = 'incremental'
        , unique_key = 'validation_monitoring_sk'
        , full_refresh = (var('override_fr', 'no') == 'yes')
    )
}}

/*
    Este modelo é o nosso "Guardião da Qualidade de Dados".
    1. Ele usa a variável `graph.nodes` para encontrar dinamicamente todos os modelos de validação (com 'validation_' no nome).
    2. Consolida os percentuais de match de cada um.
    3. Salva o histórico de forma incremental para análise temporal.
    4. Permite a criação de dashboards e alertas proativos sobre a qualidade dos dados.

    CONVENÇÃO: Modelos de validação devem ter 'validation_' no nome para serem detectados automaticamente.
*/

{% set validation_models_to_monitor = [] %}

{#
    Itera sobre todos os nós do grafo do dbt para encontrar os modelos de validação.
    A condição "node.name != this.name" é a chave para evitar a dependência circular,
    garantindo que o modelo de monitoramento não tente ler a si mesmo.
#}
{%- for node in graph.nodes.values() -%}
    {%- if 'validation_' in node.name and node.resource_type == 'model' and node.name != this.name -%}
        {%- do validation_models_to_monitor.append(node.name) -%}
    {%- endif -%}
{%- endfor -%}

/*
DEPENDÊNCIAS EXPLÍCITAS:
Este comentário com depends_on é ESSENCIAL para o dbt construir corretamente a DAG. Sem ele, o modelo pode executar antes das validações, causando falhas. 

Por quê? O dbt precisa ver ref() explicitamente para entender dependências. Referências dinâmicas em loops Jinja são "invisíveis" para o parser de dependências.

-- depends_on: {{ ref('validation_clientes_migrados') }}
-- depends_on: {{ ref('validation_pedidos_migrados') }}
*/

with match_snapshot as (

    {%- for validation_model_name in validation_models_to_monitor %}
    select
        '{{ validation_model_name }}' as validation_table_name
        , current_date as match_analysis_check_date
        , cast(max(case when in_a = true and in_b = true 
            then percent_of_total else 0.0 end) as decimal(10,4)) as equal_percentage
        , cast(max(case when in_a = true and in_b = false 
            then percent_of_total else 0.0 end) as decimal(10,4)) as in_legacy_but_not_in_new_percentage
        , cast(max(case when in_a = false and in_b = true 
            then percent_of_total else 0.0 end) as decimal(10,4)) as in_new_but_not_in_legacy_percentage
        , current_timestamp as match_analysis_check_ts
    from {{ ref(validation_model_name) }}

    {% if not loop.last -%}
    union all
    {%- endif -%}

    {%- endfor %}

)

{# 
    GERAÇÃO DA CHAVE SUBSTITUTA 
    Combina nome do modelo + data para criar uma chave única que permite histórico sem duplicatas. 
#} 

, added_sk as (

    select
        {{ dbt_utils.generate_surrogate_key(['validation_table_name', 'match_analysis_check_date']) }} as validation_monitoring_sk
        , *
    from match_snapshot

)

select
    validation_monitoring_sk
    , validation_table_name
    , match_analysis_check_date
    , equal_percentage
    , in_legacy_but_not_in_new_percentage
    , in_new_but_not_in_legacy_percentage
    , match_analysis_check_ts
from added_sk

{% if is_incremental() %}
    -- Filtra os registros para inserir apenas os dados mais recentes que ainda não existem na tabela de destino.
    where match_analysis_check_ts > (select max(match_analysis_check_ts) from {{ this }})
{% endif %}
