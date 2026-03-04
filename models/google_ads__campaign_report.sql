{{ config(enabled=var('ad_reporting__google_ads_enabled', True)) }}

with campaigns_enhanced as (

    select *
    from {{ ref('int_google_ads__campaigns_enhanced') }}
),

fields as (

    select
        source_relation,
        date_day,
        account_name,
        account_id,
        currency_code,
        campaign_name,
        campaign_id,
        advertising_channel_type,
        advertising_channel_subtype,
        campaign_status as status,
        serving_status,
        sum(spend) as spend,
        sum(clicks) as clicks,
        sum(impressions) as impressions,
        sum(conversions) as conversions,
        sum(conversions_value) as conversions_value,
        sum(view_through_conversions) as view_through_conversions

        {{ google_ads_persist_pass_through_columns(pass_through_variable='google_ads__campaign_stats_passthrough_metrics', identifier='campaigns_enhanced', transform='sum', coalesce_with=0, exclude_fields=['conversions','conversions_value','view_through_conversions']) }}

    from campaigns_enhanced
    {{ dbt_utils.group_by(11) }}
)

select *
from fields