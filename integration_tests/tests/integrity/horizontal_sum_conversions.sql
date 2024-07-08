{{ config(
    tags="fivetran_validations",
    enabled=var('fivetran_validation_tests_enabled', false)
) }}

with ad_report as (

    select 
        sum(conversions) as total_conversions,
        sum(conversion_value) as total_value,
        sum(view_through_conversions) as total_view_through_conversions
    from {{ ref('google_ads__ad_report') }}
),

account_report as (

    select 
        sum(conversions) as total_conversions,
        sum(conversion_value) as total_value,
        sum(view_through_conversions) as total_view_through_conversions
    from {{ ref('google_ads__account_report') }}
),

ad_group_report as (

    select 
        sum(conversions) as total_conversions,
        sum(conversion_value) as total_value,
        sum(view_through_conversions) as total_view_through_conversions
    from {{ ref('google_ads__ad_group_report') }}
),

campaign_report as (

    select 
        sum(conversions) as total_conversions,
        sum(conversion_value) as total_value,
        sum(view_through_conversions) as total_view_through_conversions
    from {{ ref('google_ads__campaign_report') }}
),

url_report as (

    select 
        sum(conversions) as total_conversions,
        sum(conversion_value) as total_value,
        sum(view_through_conversions) as total_view_through_conversions
    from {{ ref('google_ads__url_report') }}
),

ad_w_url_report as (

    select 
        sum(ads.conversions) as total_conversions,
        sum(ads.conversion_value) as total_value,
        sum(ads.view_through_conversions) as total_view_through_conversions
    from {{ ref('google_ads__ad_report') }} ads
    join {{ ref('google_ads__url_report') }} urls
        on ads.ad_id = urls.ad_id
        and ads.date_day = urls.date_day
),

keyword_report as (

    select 
        sum(conversions) as total_conversions,
        sum(conversion_value) as total_value,
        sum(view_through_conversions) as total_view_through_conversions
    from {{ ref('google_ads__keyword_report') }}
),

ad_w_keyword_report as (

    select 
        sum(ads.conversions) as total_conversions,
        sum(ads.conversion_value) as total_value,
        sum(ads.view_through_conversions) as total_view_through_conversions
    from {{ ref('google_ads__ad_report') }} ads
    join {{ ref('google_ads__keywords_report') }} keywords
        on ads.ad_id = keywords.ad_id
        and ads.date_day = keywords.date_day
),

select 
    'ad vs account' as comparison
from ad_report 
join account_report on true
where ad_report.total_value != account_report.total_value
    or ad_report.total_conversions != account_report.total_conversions
    or ad_report.view_through_conversions != account_report.view_through_conversions

union all 

select 
    'ad vs ad group' as comparison
from ad_report 
join ad_group_report on true
where ad_report.total_value != ad_group_report.total_value
    or ad_report.total_conversions != ad_group_report.total_conversions
    or ad_report.view_through_conversions != ad_group_report.view_through_conversions

union all 

select 
    'ad vs campaign' as comparison
from ad_report 
join campaign_report on true
where ad_report.total_value != campaign_report.total_value
    or ad_report.total_conversions != campaign_report.total_conversions
    or ad_report.view_through_conversions != campaign_report.view_through_conversions

union all 

select 
    'ad vs url' as comparison
from ad_w_url_report 
join url_report on true
where ad_w_url_report.total_value != url_report.total_value
    or ad_w_url_report.total_conversions != url_report.total_conversions
    or ad_w_url_report.view_through_conversions != url_report.view_through_conversions


union all 

select 
    'ad vs keyword' as comparison
from ad_w_keyword_report 
join keyword_report on true
where ad_w_keyword_report.total_value != keyword_report.total_value
    or ad_w_keyword_report.total_conversions != keyword_report.total_conversions
    or ad_w_keyword_report.view_through_conversions != keyword_report.view_through_conversions