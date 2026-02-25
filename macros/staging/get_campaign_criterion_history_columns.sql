{% macro get_campaign_criterion_history_columns() %}

{% set columns = [
    {"name": "id", "datatype": dbt.type_int()},
    {"name": "updated_at", "datatype": dbt.type_timestamp()},
    {"name": "campaign_id", "datatype": dbt.type_int()},
    {"name": "geo_target_constant_id", "datatype": dbt.type_int()},
    {"name": "mobile_device_id", "datatype": dbt.type_int()},
    {"name": "operating_system_version_id", "datatype": dbt.type_int()},
    {"name": "topic_constant_id", "datatype": dbt.type_int()},
    {"name": "user_interest_id", "datatype": dbt.type_int()},
    {"name": "user_list_id", "datatype": dbt.type_int()},
    {"name": "age_range_type", "datatype": dbt.type_string()},
    {"name": "bid_modifier", "datatype": dbt.type_float()},
    {"name": "carrier_country_code", "datatype": dbt.type_string()},
    {"name": "carrier_name", "datatype": dbt.type_string()},
    {"name": "content_label_type", "datatype": dbt.type_string()},
    {"name": "device_type", "datatype": dbt.type_string()},
    {"name": "display_name", "datatype": dbt.type_string()},
    {"name": "gender_type", "datatype": dbt.type_string()},
    {"name": "income_range_type", "datatype": dbt.type_string()},
    {"name": "ip_block_ip_address", "datatype": dbt.type_string()},
    {"name": "negative", "datatype": "boolean"},
    {"name": "keyword_match_type", "datatype": dbt.type_string()},
    {"name": "keyword_text", "datatype": dbt.type_string()},
    {"name": "language_code", "datatype": dbt.type_string()},
    {"name": "language_name", "datatype": dbt.type_string()},
    {"name": "mobile_app_category_constant_id", "datatype": dbt.type_int()},
    {"name": "mobile_app_category_constant_name", "datatype": dbt.type_string()},
    {"name": "mobile_application_app_id", "datatype": dbt.type_string()},
    {"name": "mobile_application_name", "datatype": dbt.type_string()},
    {"name": "parental_status_type", "datatype": dbt.type_string()},
    {"name": "placement_url", "datatype": dbt.type_string()},
    {"name": "status", "datatype": dbt.type_string()},
    {"name": "type", "datatype": dbt.type_string()},
    {"name": "youtube_channel_id", "datatype": dbt.type_string()},
    {"name": "youtube_video_id", "datatype": dbt.type_string()},
    {"name": "_fivetran_active", "datatype": "boolean"}
] %}

{{ return(columns) }}

{% endmacro %}