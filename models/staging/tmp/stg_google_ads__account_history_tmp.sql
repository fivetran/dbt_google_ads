{{ config(enabled=var('ad_reporting__google_ads_enabled', True)) }}

{% if var('google_ads_union_schemas', []) | length > 0 or var('google_ads_union_databases', []) | length > 0 %}

{{
    fivetran_utils.union_data(
        table_identifier='account_history', 
        database_variable='google_ads_database', 
        schema_variable='google_ads_schema', 
        default_database=target.database,
        default_schema='google_ads',
        default_variable='account_history',
        union_schema_variable='google_ads_union_schemas',
        union_database_variable='google_ads_union_databases'
    )
}}

{% else %}

{{
    fivetran_utils.union_connections(
        connection_dictionary='google_ads_sources',
        single_source_name='google_ads',
        single_table_name='account_history'
    )
}}

{% endif %}