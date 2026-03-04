{{ config(enabled=var('ad_reporting__google_ads_enabled', True) and var('google_ads__using_campaign_budget_history', True)) }}

{% set using_campaign_bidding_strategy_history = var('google_ads__using_campaign_bidding_strategy_history', True) %}
{% set using_campaign_criterion_history = var('google_ads__using_campaign_criterion_history', True) %}

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
            when location_targets_count < {{ var('google_ads__limited_location_threshold', 5) }} then 'limited'
            when location_targets_count > {{ var('google_ads__limited_location_threshold', 5) }} * 10 then 'broad'
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
        coalesce(campaign_budget.recommended_daily_budget, 0) as recommended_daily_budget,

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

        -- Performance observation that drives the recommendation
        case
            when budget_utilization_percent >= {{ var('google_ads__budget_constrained_threshold', 95) }}
                and daily_budget > 0
                then 'budget constrained'
            {% if using_campaign_criterion_history %}
            when budget_utilization_percent >= {{ var('google_ads__budget_constrained_threshold', 95) }} * 0.75
                and location_targeting_breadth = 'limited'
                and daily_budget > 0
                then 'budget + targeting constrained'
            when spend > 0
                and location_targeting_breadth = 'limited'
                and not is_audience_targeting
                then 'targeting constrained'
            when spend > 0
                and impressions > 0
                and ctr_percent < 1.0
                and not is_audience_targeting
                then 'quality/relevance + targeting constrained'
            {% endif %}
            when spend > 0
                and impressions > 0
                and ctr_percent < 1.0
                then 'quality/relevance constrained'
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
        end as performance_observation

    from campaign_diagnostics_base
),

-- Derive action and priority from observation
final as (
    select
        *,
        -- Recommended action based on the performance observation
        case
            when performance_observation in ('budget constrained', 'budget + targeting constrained') then 'increase budget'
            when performance_observation = 'targeting constrained' then 'expand targeting'
            when performance_observation in ('quality/relevance constrained', 'quality/relevance + targeting constrained') then 'improve relevance'
            when performance_observation in ('no spend + no targeting', 'no spend') then 'diagnose setup'
            when performance_observation in ('budget disabled', 'campaign disabled') then 'enable campaign'
            else 'monitor'
        end as recommended_action,

        -- Priority level for focusing on most critical issues first
        case
            when performance_observation in ('budget constrained', 'campaign disabled', 'budget disabled') then 'high'
            when performance_observation in ('budget + targeting constrained', 'no spend + no targeting', 'no spend') then 'high'
            when performance_observation in ('targeting constrained', 'quality/relevance constrained', 'quality/relevance + targeting constrained') then 'medium'
            else 'low'
        end as priority
    from campaign_diagnostics_logic
)

select
    {{ dbt_utils.generate_surrogate_key(['source_relation', 'account_id', 'campaign_id', 'date_day']) }} as budget_diagnostics_report_key,
    *
from final