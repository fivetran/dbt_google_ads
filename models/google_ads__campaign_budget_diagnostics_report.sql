{{ config(enabled=var('ad_reporting__google_ads_enabled', True) and var('google_ads__using_campaign_budget_history', True)) }}

{% set using_campaign_bidding_strategy_history = var('google_ads__using_campaign_bidding_strategy_history', True) %}
{% set using_campaign_criterion_history = var('google_ads__using_campaign_criterion_history', True) %}

-- Initialize consolidated threshold variable with defaults
{% set thresholds = var('google_ads__campaign_budget_diagnostics_thresholds', {
    'budget': {'low': 75.0, 'high': 95.0},
    'ctr': {'low': 1.5, 'high': 3.0},
    'cpc': {'low': 1.0, 'high': 3.0},
    'spend': {'low': 200.0, 'high': 500.0},
    'location_targeting': {'low': 5.0, 'high': 50.0},
    'bid_modifier': {'low': 0.7, 'high': 1.5}
}) %}

with campaign_report as (
    select *
    from {{ ref('google_ads__campaign_report') }}
),

campaign_budget as (
    select *
    from {{ ref('stg_google_ads__campaign_budget_history') }}
    where is_most_recent_record = True
),

{% if using_campaign_bidding_strategy_history %}
campaign_bidding_strategy as (
    select *
    from {{ ref('stg_google_ads__campaign_bidding_strategy_history') }}
    where is_most_recent_record = True
),
{% endif %}

{% if using_campaign_criterion_history %}
campaign_criterion as (
    select *
    from {{ ref('stg_google_ads__campaign_criterion_history') }}
    where is_most_recent_record = True
),
{% endif %}

{% if using_campaign_criterion_history %}
-- Raw targeting counts by campaign
campaign_targeting_counts as (
    select
        campaign_id,
        source_relation,
        count(*) as total_criteria_count,
        count(case when geo_target_constant_id is not null then 1 end) as location_targets_count,
        count(case when device_type is not null then 1 end) as device_targets_count,
        count(case when age_range_type is not null then 1 end) as age_targets_count,
        count(case when gender_type is not null then 1 end) as gender_targets_count,
        count(case when user_list_id is not null then 1 end) as audience_targets_count

    from campaign_criterion
    group by 1, 2
),

-- Apply targeting constraint logic
campaign_targeting_analysis as (
    select
        *,
        -- Targeting constraint flags
        case
            when location_targets_count < {{ thresholds['location_targeting']['low'] }} then 'limited'
            when location_targets_count > {{ thresholds['location_targeting']['high'] }} then 'broad'
            else 'normal'
        end as location_targeting_breadth,

        device_targets_count > 0 as is_device_targeting,
        audience_targets_count > 0 as is_audience_targeting

    from campaign_targeting_counts
),
{% endif %}



-- Join all data together and calculate metrics
campaign_diagnostics_base as (
    select
        campaign_report.source_relation,
        campaign_report.date_day,
        campaign_report.campaign_id,
        campaign_report.campaign_name,
        campaign_report.account_name,
        campaign_report.account_id,
        campaign_report.advertising_channel_type,
        campaign_report.advertising_channel_subtype,
        campaign_report.status as campaign_status,
        campaign_report.serving_status,

        -- Budget information
        coalesce(daily_budget, 0) as daily_budget,
        coalesce(campaign_budget.total_budget, 0) as total_budget,
        campaign_budget.budget_type,
        budget_status,
        campaign_budget.has_recommended_budget,
        -- Use Google's recommendation when available, otherwise fall back to current budget
        case
            when campaign_budget.recommended_daily_budget > 0
            then campaign_budget.recommended_daily_budget
            else coalesce(daily_budget, 0)
        end as recommended_daily_budget,

        {% if using_campaign_bidding_strategy_history %}
        -- Bidding strategy information
        campaign_bidding_strategy.bidding_strategy_type,
        coalesce(campaign_bidding_strategy.target_cpa, 0) as target_cpa,
        campaign_bidding_strategy.target_roas,
        campaign_bidding_strategy.enhanced_cpc,
        {% endif %}

        -- Performance metrics
        impressions,
        spend,
        campaign_report.clicks,

        {% if using_campaign_criterion_history %}
        -- Targeting constraint information
        coalesce(campaign_targeting_analysis.total_criteria_count, 0) as total_targeting_criteria,
        coalesce(campaign_targeting_analysis.location_targets_count, 0) as location_targeting_count,
        coalesce(campaign_targeting_analysis.audience_targets_count, 0) as audience_targeting_count,
        coalesce(campaign_targeting_analysis.location_targeting_breadth, 'normal') as location_targeting_breadth,
        coalesce(campaign_targeting_analysis.is_device_targeting, false) as is_device_targeting,
        coalesce(campaign_targeting_analysis.is_audience_targeting, false) as is_audience_targeting,
        {% endif %}

        -- Click-through rate (shows ad relevance and quality)
        campaign_report.ctr_percent,
        -- Budget usage (shows if budget constraints are limiting performance)
        {{ dbt_utils.safe_divide('campaign_report.spend', 'campaign_budget.daily_budget') }} * 100 as budget_utilization_percent

    from campaign_report
    left join campaign_budget
        on campaign_report.campaign_id = campaign_budget.campaign_id
        and campaign_report.source_relation = campaign_budget.source_relation
    {% if using_campaign_bidding_strategy_history %}
    left join campaign_bidding_strategy
        on campaign_report.campaign_id = campaign_bidding_strategy.campaign_id
        and campaign_report.source_relation = campaign_bidding_strategy.source_relation
    {% endif %}
    {% if using_campaign_criterion_history %}
    left join campaign_targeting_analysis
        on campaign_report.campaign_id = campaign_targeting_analysis.campaign_id
        and campaign_report.source_relation = campaign_targeting_analysis.source_relation
    {% endif %}
),

-- Apply business logic for diagnostics
campaign_diagnostics_logic as (
    select
        *,
        
        -- Budget increase opportunity (simple difference since recommended_daily_budget falls back to current when no recommendation)
        recommended_daily_budget - daily_budget as budget_increase_opportunity,

        -- Inferred performance observation that drives the recommendation
        case
            when budget_utilization_percent >= {{ thresholds['budget']['high'] }}
                and daily_budget > 0
                then 'budget constrained'
            {% if using_campaign_criterion_history %}
            when budget_utilization_percent >= {{ thresholds['budget']['low'] }}
                and location_targeting_breadth = 'limited'
                and daily_budget > 0
                then 'budget + targeting constrained'
            when spend > 0
                and location_targeting_breadth = 'limited'
                and not is_audience_targeting
                then 'targeting constrained'
            when spend > 0
                and impressions > 0
                and ctr_percent < {{ thresholds['ctr']['low'] }}
                and not is_audience_targeting
                then 'quality/relevance + targeting constrained'
            {% endif %}
            when spend > 0
                and impressions > 0
                and ctr_percent < {{ thresholds['ctr']['low'] }}
                then 'quality/relevance constrained'
            when spend > {{ thresholds['spend']['high'] }}
                and impressions > 0
                and ctr_percent >= {{ thresholds['ctr']['high'] }}
                then 'high spend + good performance'
            when spend >= {{ thresholds['spend']['low'] }}
                and spend <= {{ thresholds['spend']['high'] }}
                and ctr_percent >= {{ thresholds['ctr']['low'] }}
                and ctr_percent < {{ thresholds['ctr']['high'] }}
                then 'moderate spend + normal performance'
            {% if using_campaign_criterion_history %}
            when spend = 0
                and total_targeting_criteria = 0
                then 'no spend + no targeting'
            {% endif %}
            when spend = 0
                then 'no spend'
            when budget_status != 'enabled'
                then 'budget disabled'
            when campaign_status != 'enabled'
                then 'campaign disabled'
            else 'normal'
        end as _fivetran_observation

    from campaign_diagnostics_base
),

-- Derive action and priority from observation
final as (
    select
        *,
        -- Inferred action based on the performance observation
        case
            when _fivetran_observation in ('budget constrained', 'budget + targeting constrained') then 'increase budget'
            when _fivetran_observation = 'targeting constrained' then 'expand targeting'
            when _fivetran_observation in ('quality/relevance constrained', 'quality/relevance + targeting constrained') then 'improve relevance'
            when _fivetran_observation in ('no spend + no targeting', 'no spend') then 'diagnose setup'
            when _fivetran_observation in ('budget disabled', 'campaign disabled') then 'enable campaign'
            when _fivetran_observation = 'high spend + good performance' then 'maintain and scale'
            when _fivetran_observation = 'moderate spend + normal performance' then 'optimize gradually'
            else 'monitor'
        end as _fivetran_recommendation,

        -- Inferred priority level for focusing on most critical issues first
        case
            when _fivetran_observation in ('budget constrained', 'campaign disabled', 'budget disabled') then 'high'
            when _fivetran_observation in ('budget + targeting constrained', 'no spend + no targeting', 'no spend') then 'high'
            when _fivetran_observation in ('targeting constrained', 'quality/relevance constrained', 'quality/relevance + targeting constrained') then 'medium'
            when _fivetran_observation = 'high spend + good performance' then 'low'
            when _fivetran_observation = 'moderate spend + normal performance' then 'low'
            else 'low'
        end as _fivetran_priority
    from campaign_diagnostics_logic
)

select
    {{ dbt_utils.generate_surrogate_key(['source_relation', 'account_id', 'campaign_id', 'date_day']) }} as budget_diagnostics_report_key,
    *
from final