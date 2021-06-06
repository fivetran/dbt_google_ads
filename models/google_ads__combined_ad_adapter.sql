with url as (

    select *
    from {{ ref('google_ads__url_ad_adapter') }}

), criteria as (

    select *
    from {{ ref('google_ads__criteria_ad_adapter') }}

), unioned as (

    select     
        'final url' as source,    
        date_day,
        account_name,
        external_customer_id,
        campaign_name,
        campaign_id,
        ad_group_name,
        ad_group_id,
        base_url,
        url_host,
        url_path,
        utm_source,
        utm_medium,
        utm_campaign,
        utm_content,
        utm_term,
        spend,
        clicks,
        impressions
    from url

    union all

    select      
        'criteria' as source,
        date_day,
        account_name,
        external_customer_id,
        campaign_name,
        campaign_id,
        ad_group_name,
        ad_group_id,
        cast(null as string) as base_url,
        cast(null as string) as url_host,
        cast(null as string) as url_path,
        cast(null as string) as utm_source,
        cast(null as string) as utm_medium,
        cast(null as string) as utm_campaign,
        cast(null as string) as utm_content,
        cast(null as string) as utm_term,
        spend,
        clicks,
        impressions
    from criteria
    where daily_ad_group_id not in (select daily_ad_group_id from url)

)

select *
from unioned