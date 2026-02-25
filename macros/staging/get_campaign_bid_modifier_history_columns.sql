{% macro get_campaign_bid_modifier_history_columns() %}

{% set columns = [
    {"name": "campaign_id", "datatype": dbt.type_int()},
    {"name": "criterion_id", "datatype": dbt.type_int()},
    {"name": "bid_modifier", "datatype": dbt.type_float()},
    {"name": "interaction_type", "datatype": dbt.type_string()},
    {"name": "interaction_event_types", "datatype": dbt.type_string()},
    {"name": "updated_at", "datatype": dbt.type_timestamp()},
    {"name": "_fivetran_active", "datatype": "boolean"}
] %}

{{ return(columns) }}

{% endmacro %}