{% macro get_campaign_bidding_strategy_history_columns() %}

{% set columns = [
    {"name": "campaign_id", "datatype": dbt.type_int()},
    {"name": "updated_at", "datatype": dbt.type_timestamp()},
    {"name": "cpc_bid_ceiling_micros", "datatype": dbt.type_int()},
    {"name": "cpc_bid_floor_micros", "datatype": dbt.type_int()},
    {"name": "enhanced_cpc", "datatype": "boolean"},
    {"name": "enhanced_cpc_enabled", "datatype": "boolean"},
    {"name": "location", "datatype": dbt.type_string()},
    {"name": "location_fraction_micros", "datatype": dbt.type_int()},
    {"name": "manual_cpa", "datatype": dbt.type_float()},
    {"name": "manual_cpm", "datatype": dbt.type_float()},
    {"name": "manual_cpv", "datatype": dbt.type_float()},
    {"name": "name", "datatype": dbt.type_string()},
    {"name": "status", "datatype": dbt.type_string()},
    {"name": "target_cpa_micros", "datatype": dbt.type_int()},
    {"name": "target_cpm", "datatype": dbt.type_float()},
    {"name": "target_roas", "datatype": dbt.type_float()},
    {"name": "type", "datatype": dbt.type_string()},
    {"name": "_fivetran_active", "datatype": "boolean"}
] %}

{{ return(columns) }}

{% endmacro %}