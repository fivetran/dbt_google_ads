{{ config(enabled=var('ad_reporting__google_ads_enabled', True) and var('google_ads__using_campaign_bid_modifier_history', True)) }}

{% set using_campaign_bidding_strategy_history = var('google_ads__using_campaign_bidding_strategy_history', True) %}
{% set using_campaign_criterion_history = var('google_ads__using_campaign_criterion_history', True) %}

-- Initialize consolidated threshold variable with defaults
{% set thresholds = var('google_ads__campaign_bid_modifiers_thresholds', {
    'cpc': {'low': 1.0, 'high': 3.0},
    'ctr': {'low': 1.5, 'high': 3.0},
    'spend': {'low': 100.0, 'high': 500.0},
    'bid_modifier': {'low': 0.7, 'high': 1.5}
}) %}

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
        {{ dbt_utils.safe_divide('sum(clicks)', 'sum(impressions)') }} * 100 as avg_ctr_percent,
        -- CPC = Cost Per Click (shows actual cost impact of bid modifications)
        {{ dbt_utils.safe_divide('sum(spend)', 'sum(clicks)') }} as avg_cpc
    from {{ ref('stg_google_ads__campaign_stats') }}
    where date_day >= {{ dbt.dateadd('day', -30, dbt.current_timestamp()) }}
    group by 1, 2
),

-- Determine recommendation reason based on performance thresholds and current bid settings
recommendation_logic as (
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

        -- Bid modifier percentage
        case
            when bid_modifiers.bid_modifier is not null then (bid_modifiers.bid_modifier - 1) * 100
            else 0
        end as modifier_percentage,

        -- Performance metrics to evaluate bid modifier effectiveness
        recent_campaign_performance.total_spend,
        recent_campaign_performance.avg_ctr_percent,
        recent_campaign_performance.avg_cpc,

        -- Inferred performance observation that drives the recommendation
        case
            when recent_campaign_performance.avg_cpc > {{ thresholds['cpc']['high'] }}
                and bid_modifiers.bid_modifier is null
                then 'high cpc'
            when recent_campaign_performance.avg_ctr_percent < {{ thresholds['ctr']['low'] }}
                and bid_modifiers.bid_modifier > 1
                then 'low ctr'
            when recent_campaign_performance.total_spend > {{ thresholds['spend']['high'] }}
                and bid_modifiers.bid_modifier is null
                then 'high spend'
            {% if var('google_ads__using_campaign_bidding_strategy_history', True) %}
            when lower(bidding_strategy.bidding_strategy_type) in ('manual_cpc', 'enhanced_cpc')
                and bid_modifiers.bid_modifier is null
                then 'manual bidding'
            {% endif %}
            when bid_modifiers.bid_modifier = 0
                then 'disabled modifier'
            when bid_modifiers.bid_modifier > {{ thresholds['bid_modifier']['high'] }}
                then 'high positive modifier'
            when bid_modifiers.bid_modifier < {{ thresholds['bid_modifier']['low'] }} and bid_modifiers.bid_modifier > 0
                then 'significant negative modifier'
            when recent_campaign_performance.avg_ctr_percent >= {{ thresholds['ctr']['high'] }}
                and recent_campaign_performance.avg_cpc <= {{ thresholds['cpc']['low'] }}
                then 'high performance'
            when recent_campaign_performance.total_spend > {{ thresholds['spend']['high'] }}
                and recent_campaign_performance.avg_ctr_percent < {{ thresholds['ctr']['low'] }}
                then 'high spend + poor performance'
            when recent_campaign_performance.total_spend >= {{ thresholds['spend']['low'] }}
                and recent_campaign_performance.total_spend <= {{ thresholds['spend']['high'] }}
                and recent_campaign_performance.avg_ctr_percent >= {{ thresholds['ctr']['low'] }}
                then 'moderate performance'
            when recent_campaign_performance.total_spend < {{ thresholds['spend']['low'] }}
                and recent_campaign_performance.total_spend > 0
                then 'low spend'
            else 'normal performance'
        end as _fivetran_observation

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

-- derive action from reason to avoid duplicating threshold logic
final as (
    select
        *,
        -- inferred action based on the performance observation
        case
            when _fivetran_observation in ('high cpc', 'high spend', 'manual bidding') then 'add modifiers'
            when _fivetran_observation in ('low ctr', 'significant negative modifier', 'disabled modifier') then 'review adjustments'
            when _fivetran_observation = 'high positive modifier' then 'monitor performance'
            when _fivetran_observation = 'high performance' then 'scale successful modifiers'
            when _fivetran_observation = 'high spend + poor performance' then 'optimize bid modifiers'
            when _fivetran_observation = 'moderate performance' then 'optimize gradually'
            when _fivetran_observation = 'low spend' then 'consider increasing budget'
            else 'monitor'
        end as _fivetran_recommendation,

        -- inferred priority level for focusing on most critical issues first
        case
            when _fivetran_observation in ('high cpc', 'high spend') then 'high'
            when _fivetran_observation = 'high spend + poor performance' then 'high'
            when _fivetran_observation in ('significant negative modifier', 'low ctr', 'disabled modifier') then 'medium'
            when _fivetran_observation in ('manual bidding', 'high positive modifier') then 'medium'
            when _fivetran_observation = 'high performance' then 'low'
            when _fivetran_observation = 'moderate performance' then 'low'
            when _fivetran_observation = 'low spend' then 'low'
            else 'low'
        end as _fivetran_priority
    from recommendation_logic
)

select
    *,
    {{ dbt_utils.generate_surrogate_key(['source_relation', 'account_id', 'campaign_id', 'criterion_id']) }} as bid_modifier_report_key
from final