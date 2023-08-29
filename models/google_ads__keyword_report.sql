{{ config(enabled=var('ad_reporting__google_ads_enabled', True)) }}

with stats as (

    select *
    from {{ var('keyword_stats') }}
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

ad_groups as (

    select *
    from {{ var('ad_group_history') }}
    where is_most_recent_record = True
), 

criterions as (

    select *
    from {{ var('ad_group_criterion_history') }}
    where is_most_recent_record = True
), 

fields as (

    select
        stats.date_day,
        accounts.account_name,
        stats.account_id,
        accounts.currency_code,
        campaigns.campaign_name,
        stats.campaign_id,
        ad_groups.ad_group_name,
        stats.ad_group_id,
        stats.criterion_id,
        criterions.type,
        criterions.status,
        criterions.keyword_match_type,
        criterions.keyword_text,
        sum(stats.spend) as spend,
        sum(stats.clicks) as clicks,
        sum(stats.impressions) as impressions

        {{ fivetran_utils.persist_pass_through_columns(pass_through_variable='google_ads__keyword_stats_passthrough_metrics', transform = 'sum') }}

    from stats
    left join criterions
        on stats.criterion_id = criterions.criterion_id
    left join ad_groups
        on stats.ad_group_id = ad_groups.ad_group_id
    left join campaigns
        on stats.campaign_id = campaigns.campaign_id
    left join accounts
        on stats.account_id = accounts.account_id
    {{ dbt_utils.group_by(13) }}
)

select *
from fields
