{{ config(
    tags="fivetran_validations",
    enabled=var('fivetran_validation_tests_enabled', false)
) }}

with account_source as (

    select 
        sum(coalesce(conversions_value, 0)) as total_value,
        sum(coalesce(conversions, 0)) as conversions,
        sum(coalesce(view_through_conversions, 0)) as view_through_conversions
    from {{ source('google_ads', 'account_stats') }}
),

account_model as (

    select 
        sum(coalesce(conversions_value, 0)) as total_value,
        sum(coalesce(conversions, 0)) as conversions,
        sum(coalesce(view_through_conversions, 0)) as view_through_conversions
    from {{ ref('google_ads__account_report') }}
),

ad_source as (

    select 
        sum(coalesce(conversions_value, 0)) as total_value,
        sum(coalesce(conversions, 0)) as conversions,
        sum(coalesce(view_through_conversions, 0)) as view_through_conversions
    from {{ source('google_ads', 'ad_stats') }}
),

ad_model as (

    select 
        sum(coalesce(conversions_value, 0)) as total_value,
        sum(coalesce(conversions, 0)) as conversions,
        sum(coalesce(view_through_conversions, 0)) as view_through_conversions
    from {{ ref('google_ads__ad_report') }}
),

ad_group_source as (

    select 
        sum(coalesce(conversions_value, 0)) as total_value,
        sum(coalesce(conversions, 0)) as conversions,
        sum(coalesce(view_through_conversions, 0)) as view_through_conversions
    from {{ source('google_ads', 'ad_group_stats') }}
),

ad_group_model as (

    select 
        sum(coalesce(conversions_value, 0)) as total_value,
        sum(coalesce(conversions, 0)) as conversions,
        sum(coalesce(view_through_conversions, 0)) as view_through_conversions
    from {{ ref('google_ads__ad_group_report') }}
),

campaign_source as (

    select 
        sum(coalesce(conversions_value, 0)) as total_value,
        sum(coalesce(conversions, 0)) as conversions,
        sum(coalesce(view_through_conversions, 0)) as view_through_conversions
    from {{ source('google_ads', 'campaign_stats') }}
),

campaign_model as (

    select 
        sum(coalesce(conversions_value, 0)) as total_value,
        sum(coalesce(conversions, 0)) as conversions,
        sum(coalesce(view_through_conversions, 0)) as view_through_conversions
    from {{ ref('google_ads__campaign_report') }}
),

url_source as (

    select 
        sum(coalesce(ad_stats.conversions_value, 0)) as total_value,
        sum(coalesce(ad_stats.conversions, 0)) as conversions,
        sum(coalesce(ad_stats.view_through_conversions, 0)) as view_through_conversions
    from {{ source('google_ads', 'ad_stats') }}
    join {{ source('google_ads', 'ad_history') }} on true
    where ad_history.final_urls is not null
),

url_model as (

    select 
        sum(coalesce(conversions_value, 0)) as total_value,
        sum(coalesce(conversions, 0)) as conversions,
        sum(coalesce(view_through_conversions, 0)) as view_through_conversions
    from {{ ref('google_ads__url_report') }}
),

keyword_source as (

    select 
        sum(coalesce(conversions_value, 0)) as total_value,
        sum(coalesce(conversions, 0)) as conversions,
        sum(coalesce(view_through_conversions, 0)) as view_through_conversions
    from {{ source('google_ads', 'keyword_stats') }}
),

keyword_model as (

    select 
        sum(coalesce(conversions_value, 0)) as total_value,
        sum(coalesce(conversions, 0)) as conversions,
        sum(coalesce(view_through_conversions, 0)) as view_through_conversions
    from {{ ref('google_ads__keyword_report') }}
)

select 
    'ads' as comparison
from ad_model 
join ad_source on true
where ad_model.total_value != ad_source.total_value
    or ad_model.total_conversions != ad_source.total_conversions
    or ad_model.view_through_conversions != ad_source.view_through_conversions
    
union all 

select 
    'accounts' as comparison
from account_model 
join account_source on true
where account_model.total_value != account_source.total_value
    or account_model.total_conversions != account_source.total_conversions
    or account_model.view_through_conversions != account_source.view_through_conversions

union all 

select 
    'ad groups' as comparison
from ad_group_model 
join ad_group_source on true
where ad_group_model.total_value != ad_group_source.total_value
    or ad_group_model.total_conversions != ad_group_source.total_conversions
    or ad_group_model.view_through_conversions != ad_group_source.view_through_conversions

union all 

select 
    'campaigns' as comparison
from campaign_model 
join campaign_source on true
where campaign_model.total_value != campaign_source.total_value
    or campaign_model.total_conversions != campaign_source.total_conversions
    or campaign_model.view_through_conversions != campaign_source.view_through_conversions

union all 

select 
    'keywords' as comparison
from keyword_model 
join keyword_source on true
where keyword_model.total_value != keyword_source.total_value
    or keyword_model.total_conversions != keyword_source.total_conversions
    or keyword_model.view_through_conversions != keyword_source.view_through_conversions

union all 

select 
    'urls' as comparison
from url_model 
join url_source on true
where url_model.total_value != url_source.total_value
    or url_model.total_conversions != url_source.total_conversions
    or url_model.view_through_conversions != url_source.view_through_conversions