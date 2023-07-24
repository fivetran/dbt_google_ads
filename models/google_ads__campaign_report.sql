{{ config(enabled=var('ad_reporting__google_ads_enabled', True)) }}

with stats as (

    select *
    from {{ var('campaign_stats') }}
), 

accounts as (

    select *
    from {{ var('account_history') }}
    where is_most_recent_record = True
), 

campaigns as (

    select *
    from {{ var('campaign_history') }}
    where is_most_recent_record = True
), 

fields as (

    select
        stats.date_day,
        accounts.account_name,
        accounts.account_id,
        accounts.currency_code,
        campaigns.campaign_name,
        campaigns.campaign_id,
        campaigns.advertising_channel_type,
        campaigns.advertising_channel_subtype,
        campaigns.status,

        {% if var('google_auto_tagging_enabled', false) %}
        coalesce(campaigns.utm_source, 'google')  as utm_source,
        coalesce(campaigns.utm_medium, 'cpc') as utm_medium,
        coalesce(campaigns.utm_campaign, campaigns.campaign_name) as utm_campaign,

        {% else %}
        campaigns.utm_source,
        campaigns.utm_medium,
        campaigns.utm_campaign,

        {% endif %}
        sum(stats.spend) as spend,
        sum(stats.clicks) as clicks,
        sum(stats.impressions) as impressions

        {{ fivetran_utils.persist_pass_through_columns(pass_through_variable='google_ads__campaign_stats_passthrough_metrics', transform = 'sum') }}

    from stats
    left join campaigns
        on stats.campaign_id = campaigns.campaign_id
    left join accounts
        on campaigns.account_id = accounts.account_id

    {{ dbt_utils.group_by(12) }}

)

select *
from fields