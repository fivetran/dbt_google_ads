{{ config(enabled=var('ad_reporting__google_ads_enabled', True)) }}

with stats as (

    select *
    from {{ ref('stg_google_ads__campaign_stats') }}
),

campaigns_accounts as (

    select *
    from {{ ref('int_google_ads__campaigns_accounts') }}
),

fields as (

    select
        stats.source_relation,
        stats.date_day,
        campaigns_accounts.account_name,
        campaigns_accounts.account_id,
        campaigns_accounts.currency_code,
        campaigns_accounts.campaign_name,
        stats.campaign_id,
        campaigns_accounts.advertising_channel_type,
        campaigns_accounts.advertising_channel_subtype,
        campaigns_accounts.campaign_status as status,
        campaigns_accounts.serving_status,
        sum(stats.spend) as spend,
        sum(stats.clicks) as clicks,
        sum(stats.impressions) as impressions,
        sum(stats.conversions) as conversions,
        sum(stats.conversions_value) as conversions_value,
        sum(stats.view_through_conversions) as view_through_conversions

        {{ google_ads_persist_pass_through_columns(pass_through_variable='google_ads__campaign_stats_passthrough_metrics', identifier='stats', transform='sum', coalesce_with=0, exclude_fields=['conversions','conversions_value','view_through_conversions']) }}

    from stats
    left join campaigns_accounts
        on stats.campaign_id = campaigns_accounts.campaign_id
        and stats.source_relation = campaigns_accounts.source_relation
    {{ dbt_utils.group_by(11) }}
)

select *
from fields