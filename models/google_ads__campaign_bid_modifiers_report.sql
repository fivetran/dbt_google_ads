{{ config(enabled=var('ad_reporting__google_ads_enabled', True) and var('google_ads__using_campaign_bid_modifier_history', True)) }}

{% set using_campaign_bidding_strategy_history = var('google_ads__using_campaign_bidding_strategy_history', True) %}
{% set using_campaign_criterion_history = var('google_ads__using_campaign_criterion_history', True) %}

-- Initialize threshold variables with defaults
{% set cpc_thresholds = var('google_ads__cpc_high_low_thresholds', [1.0, 3.0]) | map('float') | list %}
{% set ctr_thresholds = var('google_ads__ctr_high_low_thresholds', [0.015, 0.03]) | map('float') | list %}
{% set spend_thresholds = var('google_ads__spend_high_low_thresholds', [100.0, 500.0]) | map('float') | list %}
{% set bid_modifier_thresholds = var('google_ads__bid_modifier_high_low_thresholds', [0.7, 1.5]) | map('float') | list %}

-- Calculate high/low values (users could input in any order, convert to floats)
{% set cpc_low = cpc_thresholds | min %}
{% set cpc_high = cpc_thresholds | max %}
{% set ctr_low = ctr_thresholds | min %}
{% set ctr_high = ctr_thresholds | max %}
{% set spend_low = spend_thresholds | min %}
{% set spend_high = spend_thresholds | max %}
{% set bid_modifier_low = bid_modifier_thresholds | min %}
{% set bid_modifier_high = bid_modifier_thresholds | max %}

with bid_modifiers as (
    select *
    from {{ ref('stg_google_ads__campaign_bid_modifier_history') }}
    where is_most_recent_record = True
),

{% if using_campaign_bidding_strategy_history %}
bidding_strategy as (
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

campaigns_accounts as (
    select *
    from {{ ref('int_google_ads__campaigns_accounts') }}
),

-- Performance by campaign last 30 days from staging
recent_campaign_performance as (
    select
        campaign_id,
        source_relation,
        sum(spend) as total_spend,
        sum(clicks) as total_clicks,
        sum(impressions) as total_impressions,

        -- CTR = Click-Through Rate (shows if bid adjustments improve engagement)
        {{ dbt_utils.safe_divide('sum(clicks)', 'sum(impressions)') }} as avg_ctr,
        -- CPC = Cost Per Click (shows actual cost impact of bid modifications)
        {{ dbt_utils.safe_divide('sum(spend)', 'sum(clicks)') }} as avg_cpc
    from {{ ref('stg_google_ads__campaign_stats') }}
    where date_day >= {{ dbt.dateadd('day', -30, dbt.current_timestamp()) }}
    group by 1, 2
),

-- Base data gathering with joins and basic field calculations
campaign_base as (
    select
        campaigns_accounts.source_relation,
        campaigns_accounts.account_name,
        campaigns_accounts.account_id,
        campaigns_accounts.campaign_id,
        campaigns_accounts.campaign_name,
        campaigns_accounts.advertising_channel_type,
        campaigns_accounts.advertising_channel_subtype,
        campaigns_accounts.campaign_status,
        campaigns_accounts.serving_status,

        -- Helper field for live campaigns
        case
            when upper(campaigns_accounts.campaign_status) = 'ENABLED' and upper(campaigns_accounts.serving_status) = 'SERVING' then true
            else false
        end as is_campaign_live,

        {% if var('google_ads__using_campaign_bidding_strategy_history', True) %}
        -- Bidding strategy information
        coalesce(bidding_strategy.bidding_strategy_type, 'unknown') as bidding_strategy_type,
        coalesce(bidding_strategy.target_cpa, 0) as target_cpa,
        bidding_strategy.target_roas,
        bidding_strategy.enhanced_cpc,
        bidding_strategy.manual_cpa,
        bidding_strategy.manual_cpm,
        bidding_strategy.manual_cpv,
        bidding_strategy.bidding_status,
        {% endif %}

        -- Bid modifier information
        bid_modifiers.criterion_id,
        bid_modifiers.bid_modifier,
        bid_modifiers.interaction_type,
        bid_modifiers.interaction_event_types,

        {% if var('google_ads__using_campaign_criterion_history', True) %}
        -- Categorize modifier type based on criterion relationships
        case
            when campaign_criterion.device_type is not null then 'device'
            when campaign_criterion.geo_target_constant_id is not null then 'location'
            when campaign_criterion.age_range_type is not null then 'age_range'
            when campaign_criterion.gender_type is not null then 'gender'
            when campaign_criterion.income_range_type is not null then 'income_range'
            when campaign_criterion.parental_status_type is not null then 'parental_status'
            when campaign_criterion.user_list_id is not null then 'audience'
            when campaign_criterion.keyword_text is not null then 'keyword'
            when campaign_criterion.topic_constant_id is not null then 'topic'
            when campaign_criterion.placement_url is not null then 'placement'
            else 'other'
        end as modifier_type,
        {% else %}
        'unknown' as modifier_type,
        {% endif %}

        case
            when bid_modifiers.bid_modifier = 0 then 'disabled'
            when bid_modifiers.bid_modifier > 1 then 'positive adjustment'
            when bid_modifiers.bid_modifier < 1 and bid_modifiers.bid_modifier > 0 then 'negative adjustment'
            when bid_modifiers.bid_modifier = 1 then 'no adjustment'
            else 'no modifier set'
        end as modifier_direction,

        -- Bid modifier change (decimal)
        case
            when bid_modifiers.bid_modifier is not null then (bid_modifiers.bid_modifier - 1)
            else 0
        end as modifier_change,

        -- Performance metrics to evaluate bid modifier effectiveness
        coalesce(recent_campaign_performance.total_spend, 0) as total_spend,
        coalesce(recent_campaign_performance.avg_ctr, 0) as avg_ctr,
        coalesce(recent_campaign_performance.avg_cpc, 0) as avg_cpc

    from campaigns_accounts
    left join bid_modifiers
        on campaigns_accounts.campaign_id = bid_modifiers.campaign_id
        and campaigns_accounts.source_relation = bid_modifiers.source_relation
    left join recent_campaign_performance
        on campaigns_accounts.campaign_id = recent_campaign_performance.campaign_id
        and campaigns_accounts.source_relation = recent_campaign_performance.source_relation

    {% if var('google_ads__using_campaign_bidding_strategy_history', True) %}
    left join bidding_strategy
        on campaigns_accounts.campaign_id = bidding_strategy.campaign_id
        and campaigns_accounts.source_relation = bidding_strategy.source_relation
    {% endif %}

    {% if var('google_ads__using_campaign_criterion_history', True) %}
    left join campaign_criterion
        on bid_modifiers.criterion_id = campaign_criterion.criterion_id
        and campaigns_accounts.campaign_id = campaign_criterion.campaign_id
        and campaigns_accounts.source_relation = campaign_criterion.source_relation
    {% endif %}
),

-- Determine recommendation reason based on performance thresholds and current bid settings
recommendation_logic as (
    select
        *,
        -- Inferred performance observation that drives the recommendation
        case
            when campaign_status in ('REMOVED', 'PAUSED')
                then 'campaign disabled'
            when serving_status = 'ENDED'
                then 'campaign ended'
            when serving_status != 'SERVING'
                then 'not serving'
            when avg_cpc > {{ cpc_high }}
                and bid_modifier is null
                and is_campaign_live
                then 'high cpc'
            when avg_ctr < {{ ctr_low }}
                and bid_modifier > 1
                and is_campaign_live
                then 'low ctr'
            when total_spend > {{ spend_high }}
                and bid_modifier is null
                and is_campaign_live
                then 'high spend'
            {% if var('google_ads__using_campaign_bidding_strategy_history', True) %}
            when lower(bidding_strategy_type) in ('manual_cpc', 'enhanced_cpc')
                and bid_modifier is null
                then 'manual bidding'
            {% endif %}
            when bid_modifier = 0
                then 'disabled modifier'
            when bid_modifier > {{ bid_modifier_high }}
                then 'high positive modifier'
            when bid_modifier < {{ bid_modifier_low }} and bid_modifier > 0
                then 'significant negative modifier'
            when avg_ctr >= {{ ctr_high }}
                and avg_cpc <= {{ cpc_low }}
                then 'high performance'
            when total_spend > {{ spend_high }}
                and avg_ctr < {{ ctr_low }}
                then 'high spend + poor performance'
            when total_spend >= {{ spend_low }}
                and total_spend <= {{ spend_high }}
                and avg_ctr >= {{ ctr_low }}
                then 'moderate performance'
            when total_spend < {{ spend_low }}
                and total_spend > 0
                then 'low spend'
            else 'normal performance'
        end as calculated_observation

    from campaign_base
),

-- derive action from reason to avoid duplicating threshold logic
final as (
    select
        *,
        -- inferred action based on the performance observation
        case
            when calculated_observation = 'campaign disabled' then 'enable campaign'
            when calculated_observation = 'campaign ended' then 'review or restart campaign'
            when calculated_observation = 'not serving' then 'resolve serving issues'
            when calculated_observation in ('high cpc', 'high spend', 'manual bidding') then 'add modifiers'
            when calculated_observation in ('low ctr', 'significant negative modifier', 'disabled modifier') then 'review adjustments'
            when calculated_observation = 'high positive modifier' then 'monitor performance'
            when calculated_observation = 'high performance' then 'scale successful modifiers'
            when calculated_observation = 'high spend + poor performance' then 'optimize bid modifiers'
            when calculated_observation = 'moderate performance' then 'optimize gradually'
            when calculated_observation = 'low spend' then 'consider increasing budget'
            else 'monitor'
        end as calculated_recommendation,

        -- inferred priority level for focusing on most critical issues first
        case
            when calculated_observation = 'campaign disabled' then 'high'
            when calculated_observation = 'not serving' then 'high'
            when calculated_observation in ('high cpc', 'high spend') then 'high'
            when calculated_observation = 'high spend + poor performance' then 'high'
            when calculated_observation = 'campaign ended' then 'medium'
            when calculated_observation in ('significant negative modifier', 'low ctr', 'disabled modifier') then 'medium'
            when calculated_observation in ('manual bidding', 'high positive modifier') then 'medium'
            when calculated_observation = 'high performance' then 'low'
            when calculated_observation = 'moderate performance' then 'low'
            when calculated_observation = 'low spend' then 'low'
            else 'low'
        end as calculated_priority
    from recommendation_logic
)

select
    *,
    {{ dbt_utils.generate_surrogate_key(['source_relation', 'account_id', 'campaign_id', 'criterion_id']) }} as bid_modifier_report_key
from final