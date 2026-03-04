{{ config(enabled=var('ad_reporting__google_ads_enabled', True) and var('google_ads__using_campaign_bid_modifier_history', True)) }}

{{
    fivetran_utils.union_data(
        table_identifier='campaign_bid_modifier_history',
        database_variable='google_ads_database',
        schema_variable='google_ads_schema',
        default_database=target.database,
        default_schema='google_ads',
        default_variable='campaign_bid_modifier_history',
        union_schema_variable='google_ads_union_schemas',
        union_database_variable='google_ads_union_databases'
    )
}}