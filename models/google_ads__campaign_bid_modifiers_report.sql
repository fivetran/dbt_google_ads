{{ config(enabled=var('ad_reporting__google_ads_enabled', True)) }}

with bid_modifiers as (
    select *
    from {{ ref('stg_google_ads__campaign_bid_modifier_history') }}
    where is_most_recent_record = True
),

bidding_strategy as (
    select *
    from {{ ref('stg_google_ads__campaign_bidding_strategy_history') }}
    where is_most_recent_record = True
),

campaign_criterion as (
    select *
    from {{ ref('stg_google_ads__campaign_criterion_history') }}
    where is_most_recent_record = True
),

campaigns_enhanced as (
    select *
    from {{ ref('int_google_ads__campaigns_enhanced') }}
),

-- Performance by campaign last 30 days from intermediate model
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
    from campaigns_enhanced
    where date_day >= {{ dbt.dateadd('day', -30, dbt.current_timestamp()) }}
    group by 1, 2
),

-- Determine recommendation reason based on performance thresholds and current bid settings
recommendation_logic as (
    select
        campaigns_enhanced.source_relation,
        campaigns_enhanced.account_name,
        campaigns_enhanced.account_id,
        campaigns_enhanced.campaign_id,
        campaigns_enhanced.campaign_name,
        campaigns_enhanced.advertising_channel_type,
        campaigns_enhanced.advertising_channel_subtype,
        campaigns_enhanced.campaign_status,
        campaigns_enhanced.serving_status,

        -- Bidding strategy information
        coalesce(bidding_strategy.bidding_strategy_type, 'unknown') as bidding_strategy_type,
        coalesce(bidding_strategy.target_cpa_micros / 1000000.0, 0) as target_cpa,
        bidding_strategy.target_roas,
        bidding_strategy.enhanced_cpc,
        bidding_strategy.manual_cpa,
        bidding_strategy.manual_cpm,
        bidding_strategy.manual_cpv,
        bidding_strategy.bidding_status,

        -- Bid modifier information
        bid_modifiers.criterion_id,
        bid_modifiers.bid_modifier,
        bid_modifiers.interaction_type,
        bid_modifiers.interaction_event_types,

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

        case
            when bid_modifiers.bid_modifier > 1 then 'positive adjustment'
            when bid_modifiers.bid_modifier < 1 then 'negative adjustment'
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

        -- Performance observation that drives the recommendation
        case
            when recent_campaign_performance.avg_cpc > {{ var('google_ads__high_cpc_threshold', 3.0) }}
                and bid_modifiers.bid_modifier is null
                then 'high cpc'
            when recent_campaign_performance.avg_ctr_percent < {{ var('google_ads__low_ctr_threshold', 1.5) }}
                and bid_modifiers.bid_modifier > 1
                then 'low ctr'
            when recent_campaign_performance.total_spend > {{ var('google_ads__high_spend_threshold', 500.0) }}
                and bid_modifiers.bid_modifier is null
                then 'high spend'
            when lower(bidding_strategy.bidding_strategy_type) in ('manual_cpc', 'enhanced_cpc')
                and bid_modifiers.bid_modifier is null
                then 'manual bidding'
            when bid_modifiers.bid_modifier > {{ var('google_ads__high_bid_modifier_threshold', 1.5) }}
                then 'high positive modifier'
            when bid_modifiers.bid_modifier < {{ var('google_ads__low_bid_modifier_threshold', 0.7) }}
                then 'significant negative modifier'
            else 'normal performance'
        end as performance_observation

    from campaigns_enhanced
    left join bidding_strategy
        on campaigns_enhanced.campaign_id = bidding_strategy.campaign_id
        and campaigns_enhanced.source_relation = bidding_strategy.source_relation
    left join bid_modifiers
        on campaigns_enhanced.campaign_id = bid_modifiers.campaign_id
        and campaigns_enhanced.source_relation = bid_modifiers.source_relation
    left join campaign_criterion
        on bid_modifiers.criterion_id = campaign_criterion.criterion_id
        and campaigns_enhanced.campaign_id = campaign_criterion.campaign_id
        and campaigns_enhanced.source_relation = campaign_criterion.source_relation
    left join recent_campaign_performance
        on campaigns_enhanced.campaign_id = recent_campaign_performance.campaign_id
        and campaigns_enhanced.source_relation = recent_campaign_performance.source_relation
),

-- derive action from reason to avoid duplicating threshold logic
final as (
    select
        *,
        -- recommended action based on the performance observation
        case
            when performance_observation in ('high cpc', 'high spend', 'manual bidding') then 'add modifiers'
            when performance_observation in ('low ctr', 'significant negative modifier') then 'review adjustments'
            when performance_observation = 'high positive modifier' then 'monitor performance'
            else 'monitor'
        end as recommended_action,

        -- priority level for focusing on most critical issues first
        case
            when performance_observation in ('high cpc', 'high spend') then 'high'
            when performance_observation in ('significant negative modifier', 'low ctr') then 'medium'
            when performance_observation in ('manual bidding', 'high positive modifier') then 'medium'
            else 'low'
        end as priority
    from recommendation_logic
)

select
    *,
    {{ dbt_utils.generate_surrogate_key(['source_relation', 'account_id', 'campaign_id', 'criterion_id']) }} as bid_modifier_report_key
from final