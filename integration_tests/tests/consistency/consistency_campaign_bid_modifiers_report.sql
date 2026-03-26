{{ config(
    tags="fivetran_validations",
    enabled=var('fivetran_validation_tests_enabled', false)
) }}

with prod as (
    select
        campaign_id,
        count(*) as total_bid_modifiers,
        count(case when bid_modifier > 1 then 1 end) as positive_modifiers,
        count(case when bid_modifier < 1 then 1 end) as negative_modifiers,
        avg(bid_modifier) as avg_bid_modifier,
        sum(total_spend) as total_spend,
        avg(avg_ctr) as avg_ctr
    from {{ target.schema }}_google_ads_prod.google_ads__campaign_bid_modifiers_report
    group by 1
),

dev as (
    select
        campaign_id,
        count(*) as total_bid_modifiers,
        count(case when bid_modifier > 1 then 1 end) as positive_modifiers,
        count(case when bid_modifier < 1 then 1 end) as negative_modifiers,
        avg(bid_modifier) as avg_bid_modifier,
        sum(total_spend) as total_spend,
        avg(avg_ctr) as avg_ctr
    from {{ target.schema }}_google_ads_dev.google_ads__campaign_bid_modifiers_report
    group by 1
),

final as (
    select
        prod.campaign_id,
        prod.total_bid_modifiers as prod_total_bid_modifiers,
        dev.total_bid_modifiers as dev_total_bid_modifiers,
        prod.positive_modifiers as prod_positive_modifiers,
        dev.positive_modifiers as dev_positive_modifiers,
        prod.negative_modifiers as prod_negative_modifiers,
        dev.negative_modifiers as dev_negative_modifiers,
        prod.avg_bid_modifier as prod_avg_bid_modifier,
        dev.avg_bid_modifier as dev_avg_bid_modifier,
        prod.total_spend as prod_total_spend,
        dev.total_spend as dev_total_spend
    from prod
    full outer join dev
        on dev.campaign_id = prod.campaign_id
)

select *
from final
where
    abs(prod_total_bid_modifiers - dev_total_bid_modifiers) >= 1
    or abs(prod_positive_modifiers - dev_positive_modifiers) >= 1
    or abs(prod_negative_modifiers - dev_negative_modifiers) >= 1
    or abs(coalesce(prod_avg_bid_modifier, 0) - coalesce(dev_avg_bid_modifier, 0)) >= .01
    or abs(coalesce(prod_total_spend, 0) - coalesce(dev_total_spend, 0)) >= .01