{{ config(enabled=var('ad_reporting__google_ads_enabled', True) and var('google_ads__using_campaign_budget_history', True)) }}

{% set using_campaign_bidding_strategy_history = var('google_ads__using_campaign_bidding_strategy_history', True) %}
{% set using_campaign_criterion_history = var('google_ads__using_campaign_criterion_history', True) %}

-- Initialize threshold variables with defaults
{% set budget_thresholds = var('google_ads__budget_high_low_thresholds', [0.75, 0.95]) | map('float') | list %}
{% set ctr_thresholds = var('google_ads__ctr_high_low_thresholds', [0.015, 0.03]) | map('float') | list %}
{% set cpc_thresholds = var('google_ads__cpc_high_low_thresholds', [1.0, 3.0]) | map('float') | list %}
{% set spend_thresholds = var('google_ads__spend_high_low_thresholds', [100.0, 500.0]) | map('float') | list %}
{% set location_targeting_thresholds = var('google_ads__location_targeting_high_low_thresholds', [5.0, 50.0]) | map('float') | list %}
{% set bid_modifier_thresholds = var('google_ads__bid_modifier_high_low_thresholds', [0.7, 1.5]) | map('float') | list %}

-- Calculate high/low values (users could input in any order, convert to floats)
{% set budget_low = budget_thresholds | min %}
{% set budget_high = budget_thresholds | max %}
{% set ctr_low = ctr_thresholds | min %}
{% set ctr_high = ctr_thresholds | max %}
{% set cpc_low = cpc_thresholds | min %}
{% set cpc_high = cpc_thresholds | max %}
{% set spend_low = spend_thresholds | min %}
{% set spend_high = spend_thresholds | max %}
{% set location_targeting_low = location_targeting_thresholds | min %}
{% set location_targeting_high = location_targeting_thresholds | max %}
{% set bid_modifier_low = bid_modifier_thresholds | min %}
{% set bid_modifier_high = bid_modifier_thresholds | max %}

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
            when location_targets_count < {{ location_targeting_low }} then 'limited'
            when location_targets_count > {{ location_targeting_high }} then 'broad'
            else 'normal'
        end as location_targeting_breadth,

        device_targets_count > 0 as is_device_targeting,
        audience_targets_count > 0 as is_audience_targeting

    from campaign_targeting_counts
),
{% endif %}



-- Base data gathering with joins and basic field calculations
campaign_base as (
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
        coalesce(campaign_budget.daily_budget, 0) as daily_budget,
        coalesce(campaign_budget.total_budget, 0) as total_budget,
        campaign_budget.budget_type,
        campaign_budget.budget_status,
        campaign_budget.has_recommended_budget,
        -- Use Google's recommendation when available, otherwise fall back to current budget
        case
            when campaign_budget.recommended_daily_budget > 0
            then campaign_budget.recommended_daily_budget
            else coalesce(campaign_budget.daily_budget, 0)
        end as recommended_daily_budget,

        {% if using_campaign_bidding_strategy_history %}
        -- Bidding strategy information
        campaign_bidding_strategy.bidding_strategy_type,
        coalesce(campaign_bidding_strategy.target_cpa, 0) as target_cpa,
        campaign_bidding_strategy.target_roas,
        campaign_bidding_strategy.enhanced_cpc,
        {% endif %}

        -- Performance metrics
        campaign_report.impressions,
        campaign_report.spend,
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
        campaign_report.ctr,
        -- Budget usage (shows if budget constraints are limiting performance)
        {{ dbt_utils.safe_divide('campaign_report.spend', 'campaign_budget.daily_budget') }} as budget_utilization,
        -- Helper field for live campaigns
        case
            when upper(campaign_report.status) = 'ENABLED' and upper(campaign_report.serving_status) = 'SERVING' then true
            else false
        end as is_campaign_live

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
recommendation_logic as (
    select
        *,
        
        -- Budget increase opportunity (simple difference since recommended_daily_budget falls back to current when no recommendation)
        recommended_daily_budget - daily_budget as budget_increase_opportunity,

        -- Inferred performance observation that drives the recommendation
        case
            when campaign_status in ('REMOVED', 'PAUSED')
                then 'campaign disabled'
            when serving_status = 'ENDED'
                then 'campaign ended'
            when serving_status != 'SERVING'
                then 'not serving'
            when budget_utilization >= {{ budget_high }}
                and daily_budget > 0
                and is_campaign_live
                then 'budget constrained'
            {% if using_campaign_criterion_history %}
            when budget_utilization >= {{ budget_low }} -- ">= budget_low" translates to moderate budget utlization
                and location_targeting_breadth = 'limited'
                and daily_budget > 0
                and is_campaign_live
                then 'budget + targeting constrained'
            when spend > 0
                and location_targeting_breadth = 'limited'
                and not is_audience_targeting
                and is_campaign_live
                then 'targeting constrained'
            when spend > 0
                and impressions > 0
                and ctr < {{ ctr_low }}
                and not is_audience_targeting
                and is_campaign_live
                then 'quality/relevance + targeting constrained'
            {% endif %}
            when spend > 0
                and impressions > 0
                and ctr < {{ ctr_low }}
                and is_campaign_live
                then 'quality/relevance constrained'
            when spend > {{ spend_high }}
                and impressions > 0
                and ctr >= {{ ctr_high }}
                and is_campaign_live
                then 'high spend + good performance'
            when spend > {{ spend_high }}
                and impressions > 0
                and ctr < {{ ctr_low }}
                and is_campaign_live
                then 'high spend + poor performance'
            when spend >= {{ spend_low }}
                and spend <= {{ spend_high }}
                and ctr >= {{ ctr_low }}
                and ctr < {{ ctr_high }}
                and is_campaign_live
                then 'moderate spend + normal performance'
            when spend < {{ spend_low }}
                and spend > 0
                and budget_utilization < {{ budget_low }}
                and is_campaign_live
                then 'low spend + low budget utilization'
            when spend < {{ spend_low }}
                and spend > 0
                and budget_utilization >= {{ budget_low }}
                and is_campaign_live
                then 'low spend + budget constrained'
            when spend < {{ spend_low }}
                and spend > 0
                and is_campaign_live
                then 'low spend'
            {% if using_campaign_criterion_history %}
            when spend = 0
                and total_targeting_criteria = 0
                then 'no spend + no targeting'
            {% endif %}
            when spend = 0
                then 'no spend'
            when budget_status != 'ENABLED'
                then 'budget disabled'
            when campaign_status != 'ENABLED'
                then 'campaign disabled'
            else 'normal'
        end as calculated_observation

    from campaign_base
),

-- Derive action and priority from observation
final as (
    select
        *,
        -- Inferred action based on the performance observation
        case
            when calculated_observation = 'campaign disabled' then 'enable campaign'
            when calculated_observation = 'campaign ended' then 'review or restart campaign'
            when calculated_observation = 'not serving' then 'resolve serving issues'
            when calculated_observation in ('budget constrained', 'budget + targeting constrained') then 'increase budget'
            when calculated_observation = 'targeting constrained' then 'expand targeting'
            when calculated_observation in ('quality/relevance constrained', 'quality/relevance + targeting constrained') then 'improve relevance'
            when calculated_observation in ('no spend + no targeting', 'no spend') then 'diagnose setup'
            when calculated_observation in ('budget disabled', 'campaign disabled') then 'enable campaign'
            when calculated_observation = 'high spend + good performance' then 'maintain and scale'
            when calculated_observation = 'high spend + poor performance' then 'improve efficiency'
            when calculated_observation = 'moderate spend + normal performance' then 'optimize gradually'
            when calculated_observation = 'low spend + low budget utilization' then 'diagnose targeting and bidding'
            when calculated_observation = 'low spend + budget constrained' then 'increase budget'
            when calculated_observation = 'low spend' then 'consider increasing budget'
            else 'monitor'
        end as calculated_recommendation,

        -- Inferred priority level for focusing on most critical issues first
        case
            when calculated_observation = 'campaign disabled' then 'high'
            when calculated_observation = 'not serving' then 'high'
            when calculated_observation in ('budget constrained', 'budget disabled') then 'high'
            when calculated_observation = 'campaign ended' then 'medium'
            when calculated_observation in ('budget + targeting constrained', 'no spend + no targeting', 'no spend') then 'high'
            when calculated_observation = 'high spend + poor performance' then 'high'
            when calculated_observation in ('targeting constrained', 'quality/relevance constrained', 'quality/relevance + targeting constrained') then 'medium'
            when calculated_observation = 'high spend + good performance' then 'low'
            when calculated_observation = 'moderate spend + normal performance' then 'low'
            when calculated_observation = 'low spend + low budget utilization' then 'medium'
            when calculated_observation = 'low spend + budget constrained' then 'medium'
            when calculated_observation = 'low spend' then 'low'
            else 'low'
        end as calculated_priority
    from recommendation_logic
)

select
    *,
    {{ dbt_utils.generate_surrogate_key(['source_relation', 'account_id', 'campaign_id', 'date_day']) }} as budget_diagnostics_report_key
from final