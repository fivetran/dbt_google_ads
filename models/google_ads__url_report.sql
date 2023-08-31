{{ config(enabled=var('ad_reporting__google_ads_enabled', True)) }}

with stats as (

    select *
    from {{ var('ad_stats') }}
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

ads as (

    select *
    from {{ var('ad_history') }}
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
        ad_groups.ad_group_name,
        stats.ad_group_id,
        stats.ad_id,
        ads.base_url,
        ads.url_host,
        ads.url_path,

        {% if var('google_auto_tagging_enabled', false) %}

        coalesce( {{ dbt_utils.get_url_parameter('ads.final_url', 'utm_source') }} , 'google')  as utm_source,
        coalesce( {{ dbt_utils.get_url_parameter('ads.final_url', 'utm_medium') }} , 'cpc') as utm_medium,
        coalesce( {{ dbt_utils.get_url_parameter('ads.final_url', 'utm_campaign') }} , campaigns.campaign_name) as utm_campaign,
        coalesce( {{ dbt_utils.get_url_parameter('ads.final_url', 'utm_content') }} , ad_groups.ad_group_name) as utm_content,

        {% else %}

        ads.utm_source,
        ads.utm_medium,
        ads.utm_campaign,
        ads.utm_content,
        
        {% endif %}

        ads.utm_term,
        sum(stats.spend) as spend,
        sum(stats.clicks) as clicks,
        sum(stats.impressions) as impressions

        {{ fivetran_utils.persist_pass_through_columns(pass_through_variable='google_ads__ad_stats_passthrough_metrics', transform = 'sum') }}

    from stats
    left join ads
        on stats.ad_id = ads.ad_id
        and stats.ad_group_id = ads.ad_group_id
    left join ad_groups
        on ads.ad_group_id = ad_groups.ad_group_id
    left join campaigns
        on ad_groups.campaign_id = campaigns.campaign_id
    left join accounts
        on campaigns.account_id = accounts.account_id

    {% if var('ad_reporting__url_report__using_null_filter', True) %}
        where ads.source_final_urls is not null
    {% endif %}

    {{ dbt_utils.group_by(17) }}
)

select *
from fields