{{ config(
    tags="fivetran_validations",
    enabled=(var('fivetran_validation_tests_enabled', false) and var('google_ads__using_search_term_keyword_stats', True))
) }}

with prod as (
    select
        search_term,
        sum(clicks) as clicks, 
        sum(impressions) as impressions,
        sum(spend) as spend
    from {{ target.schema }}_google_ads_prod.google_ads__search_term_report
    group by 1
),

dev as (
    select
        search_term,
        sum(clicks) as clicks, 
        sum(impressions) as impressions,
        sum(spend) as spend
    from {{ target.schema }}_google_ads_dev.google_ads__search_term_report
    group by 1
),

final as (
    select 
        prod.search_term,
        prod.clicks as prod_clicks,
        dev.clicks as dev_clicks,
        prod.impressions as prod_impressions,
        dev.impressions as dev_impressions,
        prod.spend as prod_spend,
        dev.spend as dev_spend
    from prod
    full outer join dev 
        on dev.search_term = prod.search_term
)

select *
from final
where
    abs(prod_clicks - dev_clicks) >= .01
    or abs(prod_impressions - dev_impressions) >= .01
    or abs(prod_spend - dev_spend) >= .01