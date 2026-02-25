{{ config(
    tags="fivetran_validations",
    enabled=var('fivetran_validation_tests_enabled', false)
) }}

with prod as (
    select
        campaign_id,
        count(*) as total_rows,
        sum(daily_budget) as total_daily_budget,
        sum(spend) as total_spend,
        avg(budget_utilization_percent) as avg_budget_utilization,
        count(case when constraint_status = 'budget constrained' then 1 end) as budget_constrained_count,
        count(case when constraint_severity = 'high' then 1 end) as high_severity_count,
        sum(impressions) as total_impressions
    from {{ target.schema }}_google_ads_prod.google_ads__campaign_budget_diagnostics_report
    group by 1
),

dev as (
    select
        campaign_id,
        count(*) as total_rows,
        sum(daily_budget) as total_daily_budget,
        sum(spend) as total_spend,
        avg(budget_utilization_percent) as avg_budget_utilization,
        count(case when constraint_status = 'budget constrained' then 1 end) as budget_constrained_count,
        count(case when constraint_severity = 'high' then 1 end) as high_severity_count,
        sum(impressions) as total_impressions
    from {{ target.schema }}_google_ads_dev.google_ads__campaign_budget_diagnostics_report
    group by 1
),

final as (
    select
        prod.campaign_id,
        prod.total_rows as prod_total_rows,
        dev.total_rows as dev_total_rows,
        prod.total_daily_budget as prod_total_daily_budget,
        dev.total_daily_budget as dev_total_daily_budget,
        prod.total_spend as prod_total_spend,
        dev.total_spend as dev_total_spend,
        prod.avg_budget_utilization as prod_avg_budget_utilization,
        dev.avg_budget_utilization as dev_avg_budget_utilization,
        prod.budget_constrained_count as prod_budget_constrained_count,
        dev.budget_constrained_count as dev_budget_constrained_count,
        prod.high_severity_count as prod_high_severity_count,
        dev.high_severity_count as dev_high_severity_count,
        prod.total_impressions as prod_total_impressions,
        dev.total_impressions as dev_total_impressions
    from prod
    full outer join dev
        on dev.campaign_id = prod.campaign_id
)

select *
from final
where
    abs(prod_total_rows - dev_total_rows) >= 1
    or abs(coalesce(prod_total_daily_budget, 0) - coalesce(dev_total_daily_budget, 0)) >= .01
    or abs(coalesce(prod_total_spend, 0) - coalesce(dev_total_spend, 0)) >= .01
    or abs(coalesce(prod_avg_budget_utilization, 0) - coalesce(dev_avg_budget_utilization, 0)) >= .01
    or abs(prod_budget_constrained_count - dev_budget_constrained_count) >= 1
    or abs(prod_high_severity_count - dev_high_severity_count) >= 1
    or abs(coalesce(prod_total_impressions, 0) - coalesce(dev_total_impressions, 0)) >= 1