{{ config(enabled=var('ad_reporting__google_ads_enabled', True)) }}

with campaigns as (
    select *
    from {{ ref('stg_google_ads__campaign_history') }}
    where is_most_recent_record = True
),

accounts as (
    select *
    from {{ ref('stg_google_ads__account_history') }}
    where is_most_recent_record = True
),

campaign_criterion as (
    select *
    from {{ ref('stg_google_ads__campaign_criterion_history') }}
    where is_most_recent_record = True
),

-- Targeting constraints by campaign
campaign_targeting_analysis as (
    select
        campaign_id,
        source_relation,
        count(*) as total_criteria_count,
        count(case when geo_target_constant_id is not null then 1 end) as location_targets_count,
        count(case when device_type is not null then 1 end) as device_targets_count,
        count(case when age_range_type is not null then 1 end) as age_targets_count,
        count(case when gender_type is not null then 1 end) as gender_targets_count,
        count(case when user_list_id is not null then 1 end) as audience_targets_count,
        count(case when keyword_text is not null then 1 end) as keyword_targets_count,

        -- targeting constraint flags
        case
            when count(case when geo_target_constant_id is not null then 1 end) < 5 then 'limited location targeting'
            when count(case when geo_target_constant_id is not null then 1 end) > 50 then 'broad location targeting'
            else 'normal location targeting'
        end as location_targeting_assessment,

        case
            when count(case when device_type is not null then 1 end) = 0 then 'no device targeting'
            else 'device targeting active'
        end as device_targeting_assessment,

        case
            when count(case when user_list_id is not null then 1 end) > 0 then 'audience targeting active'
            else 'no audience targeting'
        end as audience_targeting_assessment

    from campaign_criterion
    group by 1, 2
),

campaign_budget as (
    select *
    from {{ ref('stg_google_ads__campaign_budget_history') }}
    where is_most_recent_record = True
),

campaign_bidding_strategy as (
    select *
    from {{ ref('stg_google_ads__campaign_bidding_strategy_history') }}
    where is_most_recent_record = True
),

campaign_stats as (
    select *
    from {{ ref('stg_google_ads__campaign_stats') }}
),

-- Campaign performance metrics with casting
campaign_stats_cast as (
    select
        campaign_id,
        source_relation,
        date_day,
        spend,
        cast(clicks as {{ dbt.type_float() }}) as clicks, -- Cast to float for accurate division in CTR calculations
        cast(impressions as {{ dbt.type_float() }}) as impressions -- Cast to float to avoid integer division truncation
    from campaign_stats
),

-- Campaign performance metrics aggregated
campaign_performance_agg as (
    select
        campaign_id,
        source_relation,
        date_day,
        sum(impressions) as impressions,
        sum(spend) as spend,
        {{ dbt_utils.safe_divide('sum(clicks)', 'sum(impressions)') }} * 100 as ctr_percent
    from campaign_stats_cast
    group by 1, 2, 3
),

{% if var('google_ads__using_search_term_keyword_stats', true) %}
-- Search term stats for impression share (if available)
search_term_stats as (
    select *
    from {{ ref('stg_google_ads__search_term_keyword_stats') }}
),
-- Aggregate impression share metrics by primary keys
impression_share_agg as (
    select
        campaign_id,
        source_relation,
        date_day,
        avg(coalesce(top_impression_percentage, 0)) as avg_top_impression_share,
        avg(coalesce(absolute_top_impression_percentage, 0)) as avg_absolute_top_impression_share

    from search_term_stats
    group by 1, 2, 3
),

{% else %}
-- Dummy CTE when search term stats are not available
impression_share_agg as (
    select
        cast(null as {{ dbt.type_int() }}) as campaign_id,
        cast(null as {{ dbt.type_string() }}) as source_relation,
        cast(null as {{ dbt.type_date() }}) as date_day,
        cast(0 as {{ dbt.type_float() }}) as avg_top_impression_share,
        cast(0 as {{ dbt.type_float() }}) as avg_absolute_top_impression_share
),
{% endif %}

-- Join performance with dimensional data
campaign_performance as (
    select
        perf.campaign_id,
        perf.source_relation,
        perf.date_day,
        campaigns.campaign_name,
        accounts.account_name,
        accounts.account_id,
        campaigns.advertising_channel_type,
        campaigns.advertising_channel_subtype,
        campaigns.status as campaign_status,
        campaigns.serving_status,

        -- Budget information
        coalesce(budget.amount_micros / 1000000.0, 0) as daily_budget,
        coalesce(budget.total_amount_micros / 1000000.0, 0) as total_budget,
        budget.budget_type,
        budget.budget_status,
        budget.has_recommended_budget,
        coalesce(budget.recommended_budget_amount_micros / 1000000.0, 0) as recommended_daily_budget,

        -- Bidding strategy information
        bidding.bidding_strategy_type,
        coalesce(bidding.target_cpa_micros / 1000000.0, 0) as target_cpa,
        bidding.target_roas,
        bidding.enhanced_cpc,

        -- Performance metrics
        perf.impressions,
        perf.spend,
        perf.ctr_percent,

        -- Budget utilization
        {{ dbt_utils.safe_divide('perf.spend', 'budget.amount_micros / 1000000.0') }} * 100 as budget_utilization_percent,

        -- Targeting constraint information
        coalesce(targeting.total_criteria_count, 0) as total_targeting_criteria,
        coalesce(targeting.location_targets_count, 0) as location_targeting_count,
        coalesce(targeting.audience_targets_count, 0) as audience_targeting_count,
        coalesce(targeting.location_targeting_assessment, 'no location targeting') as location_targeting_assessment,
        coalesce(targeting.device_targeting_assessment, 'no device targeting') as device_targeting_assessment,
        coalesce(targeting.audience_targeting_assessment, 'no audience targeting') as audience_targeting_assessment

    from campaign_performance_agg perf
    left join campaigns
        on perf.campaign_id = campaigns.campaign_id
        and perf.source_relation = campaigns.source_relation
    left join accounts
        on campaigns.account_id = accounts.account_id
        and campaigns.source_relation = accounts.source_relation
    left join campaign_budget budget
        on campaigns.campaign_id = budget.campaign_id
        and campaigns.source_relation = budget.source_relation
    left join campaign_bidding_strategy bidding
        on campaigns.campaign_id = bidding.campaign_id
        and campaigns.source_relation = bidding.source_relation
    left join campaign_targeting_analysis targeting
        on campaigns.campaign_id = targeting.campaign_id
        and campaigns.source_relation = targeting.source_relation
),

-- Join impression share back to campaign performance
campaign_impression_share as (
    select
        cp.*,
        coalesce(isa.avg_top_impression_share, 0) as avg_top_impression_share,
        coalesce(isa.avg_absolute_top_impression_share, 0) as avg_absolute_top_impression_share

    from campaign_performance cp
    left join impression_share_agg isa
        on cp.campaign_id = isa.campaign_id
        and cp.date_day = isa.date_day
        and cp.source_relation = isa.source_relation
),

-- Diagnose constraint types
budget_diagnostics as (
    select
        *,

        -- Enhanced budget constraint analysis
        case
            when budget_utilization_percent >= 95
                and daily_budget > 0
                then 'budget constrained'
            when budget_utilization_percent >= 80
                and avg_top_impression_share < 50
                then 'budget + placement constrained'
            when avg_top_impression_share < 30
                and spend > 0
                and location_targeting_assessment = 'limited location targeting'
                then 'targeting + placement constrained'
            when avg_top_impression_share < 30
                and spend > 0
                then 'placement/bid constrained'
            when avg_absolute_top_impression_share < 20
                and avg_top_impression_share < 40
                then 'bid position constrained'
            when spend > 0
                and impressions > 0
                and ctr_percent < 1.0
                and audience_targeting_assessment = 'no audience targeting'
                then 'quality/relevance + targeting constrained'
            when spend > 0
                and impressions > 0
                and ctr_percent < 1.0
                then 'quality/relevance constrained'
            when spend = 0
                and total_targeting_criteria = 0
                then 'no spend - check targeting & campaign status'
            when spend = 0 then 'no spend - check campaign status'
            when budget_status != 'enabled' then 'budget disabled'
            when campaign_status != 'enabled' then 'campaign disabled'
            else 'performance normal'
        end as constraint_status,

        -- Constraint severity based on multiple factors
        case
            when budget_utilization_percent >= 98
                or avg_top_impression_share < 15
                then 'high'
            when budget_utilization_percent >= 85
                or avg_top_impression_share < 40
                then 'medium'
            when budget_utilization_percent >= 70
                or avg_top_impression_share < 60
                then 'low'
            else 'minimal'
        end as constraint_severity,

        -- Enhanced recommendations based on actual data
        case
            when budget_utilization_percent >= 95
                and has_recommended_budget
                and recommended_daily_budget > daily_budget
                then {{ dbt.concat([
                    "'increase daily budget from $'",
                    "round(daily_budget, 2)",
                    "' to $'",
                    "round(recommended_daily_budget, 2)",
                    "' (google recommended)'"
                ]) }}
            when budget_utilization_percent >= 95
                then {{ dbt.concat([
                    "'increase daily budget (currently $'",
                    "round(daily_budget, 2)",
                    "', 95%+ utilized)'"
                ]) }}
            when avg_top_impression_share < 30
                and location_targeting_assessment = 'limited location targeting'
                then 'expand geographic targeting - limited location targets may be constraining reach'
            when avg_top_impression_share < 30
                and bidding_strategy_type in ('manual_cpc', 'enhanced_cpc')
                then 'consider increasing manual bids or switching to automated bidding'
            when avg_top_impression_share < 30
                and target_cpa > 0
                then {{ dbt.concat([
                    "'consider increasing target cpa (currently $'",
                    "round(target_cpa, 2)",
                    "')'"
                ]) }}
            when spend = 0
                and campaign_status = 'enabled'
                and total_targeting_criteria = 0
                then 'campaign enabled but no spend and no targeting criteria - add targeting settings'
            when spend = 0
                and campaign_status = 'enabled'
                then 'campaign enabled but no spend - check targeting, bids, and ad approval status'
            when ctr_percent < 1.0
                and impressions > 100
                and audience_targeting_assessment = 'no audience targeting'
                then 'low ctr with no audience targeting - consider adding audience segments for better relevance'
            when ctr_percent < 1.0
                and impressions > 100
                then 'low ctr - review ad copy, keywords, and landing page relevance'
            when budget_utilization_percent < 50
                and avg_top_impression_share > 80
                then 'performance appears optimal - monitor for opportunities'
            else 'monitor performance trends and adjust based on goals'
        end as recommendation,

        -- Budget efficiency metrics
        {{ dbt_utils.safe_divide('spend', 'daily_budget') }} * 100 as daily_budget_efficiency_percent,

        -- Opportunity indicators
        case
            when has_recommended_budget
                and recommended_daily_budget > daily_budget
                then (recommended_daily_budget - daily_budget) * 30  -- Monthly potential increase
            else 0
        end as monthly_budget_opportunity

    from campaign_impression_share
)

select *
from budget_diagnostics