{{ config(enabled=var('ad_reporting__google_ads_enabled', True)) }}

with stats as (

    select *
    from {{ ref('stg_google_ads__keyword_stats') }}
), 

campaigns_accounts as (

    select *
    from {{ ref('int_google_ads__campaigns_accounts') }}
), 

ad_groups as (

    select *
    from {{ ref('stg_google_ads__ad_group_history') }}
    where is_most_recent_record = True
), 

criterions as (

    select *
    from {{ ref('stg_google_ads__ad_group_criterion_history') }}
    where is_most_recent_record = True
), 

fields as (

    select
        stats.source_relation,
        stats.date_day,
        campaigns_accounts.account_name,
        stats.account_id,
        campaigns_accounts.currency_code,
        campaigns_accounts.campaign_name,
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
        sum(stats.impressions) as impressions,
        sum(conversions) as conversions,
        sum(conversions_value) as conversions_value,
        sum(view_through_conversions) as view_through_conversions

        {{ google_ads_persist_pass_through_columns(pass_through_variable='google_ads__keyword_stats_passthrough_metrics', identifier='stats', transform='sum', coalesce_with=0, exclude_fields=['conversions','conversions_value','view_through_conversions']) }}

    from stats
    left join criterions
        on stats.criterion_id = criterions.criterion_id
        and stats.source_relation = criterions.source_relation
    left join ad_groups
        on stats.ad_group_id = ad_groups.ad_group_id
        and stats.source_relation = ad_groups.source_relation
    left join campaigns_accounts
        on stats.campaign_id = campaigns_accounts.campaign_id
        and stats.source_relation = campaigns_accounts.source_relation
    {{ dbt_utils.group_by(14) }}
)

select *
from fields
