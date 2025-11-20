{{ config(
    tags="fivetran_validations",
    enabled=var('fivetran_validation_tests_enabled', false)
) }}

with account_source as (

    select 
        sum(coalesce(conversions_value, 0)) as total_value,
        sum(coalesce(conversions, 0)) as conversions,
        sum(coalesce(view_through_conversions, 0)) as view_through_conversions
    from {{ ref('stg_google_ads__account_stats_tmp') }}
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
    from {{ ref('stg_google_ads__ad_stats_tmp') }}
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
    from {{ ref('stg_google_ads__ad_group_stats_tmp') }}
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
    from {{ ref('stg_google_ads__campaign_stats_tmp') }}
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
    from {{ ref('stg_google_ads__ad_stats') }} as ad_stats
    left join (
        select * from {{ ref('stg_google_ads__ad_history') }} 
        where is_most_recent_record = True
        ) as ad_history
    on ad_stats.ad_id = ad_history.ad_id 
    and cast(ad_stats.ad_group_id as {{ dbt.type_string() }}) = ad_history.ad_group_id
    and ad_stats.source_relation = ad_history.source_relation 
    and ad_history.source_final_urls is not null
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
    from {{ ref('stg_google_ads__keyword_stats_tmp') }}
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
where abs(ad_model.total_value - ad_source.total_value) >= .01
    or abs(ad_model.conversions - ad_source.conversions) >= .01
    or abs(ad_model.view_through_conversions - ad_source.view_through_conversions) >= .01
    
union all 

select 
    'accounts' as comparison
from account_model 
join account_source on true
where abs(account_model.total_value - account_source.total_value) >= .01
    or abs(account_model.conversions - account_source.conversions) >= .01
    or abs(account_model.view_through_conversions - account_source.view_through_conversions) >= .01

union all 

select 
    'ad groups' as comparison
from ad_group_model 
join ad_group_source on true
where abs(ad_group_model.total_value - ad_group_source.total_value) >= .01
    or abs(ad_group_model.conversions - ad_group_source.conversions) >= .01
    or abs(ad_group_model.view_through_conversions - ad_group_source.view_through_conversions) >= .01

union all 

select 
    'campaigns' as comparison
from campaign_model 
join campaign_source on true
where abs(campaign_model.total_value - campaign_source.total_value) >= .01
    or abs(campaign_model.conversions - campaign_source.conversions) >= .01
    or abs(campaign_model.view_through_conversions - campaign_source.view_through_conversions) >= .01

union all 

select 
    'keywords' as comparison
from keyword_model 
join keyword_source on true
where abs(keyword_model.total_value - keyword_source.total_value) >= .01
    or abs(keyword_model.conversions - keyword_source.conversions) >= .01
    or abs(keyword_model.view_through_conversions - keyword_source.view_through_conversions) >= .01

union all 

select 
    'urls' as comparison
from url_model 
join url_source on true
where abs(url_model.total_value - url_source.total_value) >= .01
    or abs(url_model.conversions - url_source.conversions) >= .01
    or abs(url_model.view_through_conversions - url_source.view_through_conversions) >= .01