{{ config(enabled=var('ad_reporting__google_ads_enabled', True)) }}

with campaigns as (
    select *
    from {{ ref('stg_google_ads__campaign_history') }}
    where is_most_recent_record = True
),

accounts as (
    select *
    from {{ ref('stg_google_ads__account_history') }}
    where is_most_recent_record = True
),

campaign_stats as (
    select *
    from {{ ref('stg_google_ads__campaign_stats') }}
),

final as (
    select
        -- Campaign dimensional data
        campaigns.source_relation,
        campaigns.campaign_id,
        campaigns.campaign_name,
        campaigns.status as campaign_status,
        campaigns.serving_status,
        campaigns.advertising_channel_type,
        campaigns.advertising_channel_subtype,

        -- Account dimensional data
        accounts.account_id,
        accounts.account_name,
        accounts.currency_code,
        accounts.time_zone,
        accounts.auto_tagging_enabled,

        -- Raw performance data (preserves daily grain)
        campaign_stats.date_day,
        campaign_stats.ad_network_type,
        campaign_stats.device,
        campaign_stats.spend,
        campaign_stats.clicks,
        campaign_stats.impressions,
        campaign_stats.conversions,
        campaign_stats.conversions_value,
        campaign_stats.view_through_conversions

        {{ google_ads_fill_pass_through_columns(pass_through_fields=var('google_ads__campaign_stats_passthrough_metrics'), except=['conversions', "conversions_value", "view_through_conversions"]) }}

    from campaign_stats
    left join campaigns
        on campaign_stats.campaign_id = campaigns.campaign_id
        and campaign_stats.source_relation = campaigns.source_relation
    left join accounts
        on campaigns.account_id = accounts.account_id
        and campaigns.source_relation = accounts.source_relation
)

select *
from final