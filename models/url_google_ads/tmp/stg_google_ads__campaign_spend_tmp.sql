{{ config(enabled=var('api_source') == 'google_ads') }}

-- creating a view similar to the google_ads_url_ad_adapter
-- with null values on ad_group fields and static values for source (google),medium (cpc) and term
-- for unioning back into google_ads_url_ad_adapter later
with stats as (

    select *
    from {{ var('campaign_stats') }}

), accounts as (

    select *
    from {{ var('account') }}
    
), campaigns as (

    select *
    from {{ var('campaign_history') }}
    where is_most_recent_record = True
    
), fields as (

    select
        stats.date_day,
        lower(accounts.account_name) as account_name,
        accounts.account_id,
        lower(campaigns.campaign_name) as campaign_name,
        campaigns.campaign_id,
        null as ad_group_name,
        null as ad_group_id,
        null as base_url,
        null as url_host,
        null as url_path,
        'google' as utm_source,
        'cpc' as utm_medium,
        lower(campaigns.campaign_name) as utm_campaign,
        null as utm_content,
        'dsa' as utm_term,
        sum(stats.spend) as spend,
        sum(stats.clicks) as clicks,
        sum(stats.impressions) as impressions


    from stats
    left join campaigns
        on stats.campaign_id = campaigns.campaign_id
    left join accounts
        on campaigns.account_id = accounts.account_id
    {{ dbt_utils.group_by(15) }}

)

select *
from fields
