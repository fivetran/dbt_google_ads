{{ config(enabled=var('ad_reporting__google_ads_enabled', True) and var('google_ads__using_search_term_keyword_stats', True)) }}

with stats as (

    select *
    from {{ var('search_term_keyword_stats') }}
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

fields as (

    select
        stats.source_relation,
        stats.date_day,
        accounts.account_name,
        stats.account_id,
        accounts.currency_code,
        campaigns.campaign_name,
        stats.campaign_id,
        ad_groups.ad_group_name,
        stats.ad_group_id,
        stats.search_term,
        stats.keyword_text,
        stats.search_term_match_type,
        stats.status,
        sum(stats.spend) as spend,
        sum(stats.clicks) as clicks,
        sum(stats.impressions) as impressions,
        sum(stats.conversions) as conversions,
        sum(stats.conversions_value) as conversions_value,
        sum(stats.view_through_conversions) as view_through_conversions

        {{ google_ads_persist_pass_through_columns(pass_through_variable='google_ads__search_term_keyword_stats_passthrough_metrics', identifier='stats', transform='sum', coalesce_with=0) }}

    from stats
    left join ad_groups
        on stats.ad_group_id = ad_groups.ad_group_id
        and stats.source_relation = ad_groups.source_relation
    left join campaigns
        on stats.campaign_id = campaigns.campaign_id
        and stats.source_relation = campaigns.source_relation
    left join accounts
        on stats.account_id = accounts.account_id
        and stats.source_relation = accounts.source_relation
    {{ dbt_utils.group_by(13) }}
)

select *
from fields
