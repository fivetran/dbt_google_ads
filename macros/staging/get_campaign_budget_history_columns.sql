{% macro get_campaign_budget_history_columns() %}

{% set columns = [
    {"name": "id", "datatype": dbt.type_int()},
    {"name": "updated_at", "datatype": dbt.type_timestamp()},
    {"name": "campaign_id", "datatype": dbt.type_int()},
    {"name": "amount_micros", "datatype": dbt.type_int()},
    {"name": "delivery_method", "datatype": dbt.type_string()},
    {"name": "explicitly_shared", "datatype": "boolean"},
    {"name": "name", "datatype": dbt.type_string()},
    {"name": "reference_count", "datatype": dbt.type_int()},
    {"name": "status", "datatype": dbt.type_string()},
    {"name": "has_recommended_budget", "datatype": "boolean"},
    {"name": "period", "datatype": dbt.type_string()},
    {"name": "recommended_budget_amount_micros", "datatype": dbt.type_int()},
    {"name": "total_amount_micros", "datatype": dbt.type_int()},
    {"name": "type", "datatype": dbt.type_string()},
    {"name": "_fivetran_active", "datatype": "boolean"}
] %}

{{ return(columns) }}

{% endmacro %}