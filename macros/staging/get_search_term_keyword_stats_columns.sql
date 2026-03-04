{% macro get_search_term_keyword_stats_columns() %}

{% set columns = [
    {"name": "_fivetran_id", "datatype": dbt.type_string()},
    {"name": "_fivetran_synced", "datatype": dbt.type_timestamp()},
    {"name": "ad_group_id", "datatype": dbt.type_int()},
    {"name": "campaign_id", "datatype": dbt.type_int()},
    {"name": "clicks", "datatype": dbt.type_int()},
    {"name": "conversions", "datatype": dbt.type_float()},
    {"name": "conversions_value", "datatype": dbt.type_float()},
    {"name": "cost_micros", "datatype": dbt.type_int()},
    {"name": "customer_id", "datatype": dbt.type_int()},
    {"name": "date", "datatype": "date"},
    {"name": "impressions", "datatype": dbt.type_int()},
    {"name": "info_text", "datatype": dbt.type_string()},
    {"name": "keyword_ad_group_criterion", "datatype": dbt.type_string()},
    {"name": "search_term", "datatype": dbt.type_string()},
    {"name": "search_term_match_type", "datatype": dbt.type_string()},
    {"name": "status", "datatype": dbt.type_string()},
    {"name": "view_through_conversions", "datatype": dbt.type_int()}
] %}

{{ google_ads_add_pass_through_columns(base_columns=columns, pass_through_fields=var('google_ads__search_term_keyword_stats_passthrough_metrics')) }}

{{ return(columns) }}

{% endmacro %}
