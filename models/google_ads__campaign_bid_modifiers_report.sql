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

bid_modifiers as (
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

campaign_stats as (
    select
        campaign_id,
        source_relation,
        date_day,
        spend,
        cast(clicks as {{ dbt.type_float() }}) as clicks, -- Cast to float for accurate division in CTR/CPC calculations
        cast(impressions as {{ dbt.type_float() }}) as impressions -- Cast to float to avoid integer division truncation
    from {{ ref('stg_google_ads__campaign_stats') }}
    where date_day >= {{ dbt.dateadd('day', -30, dbt.current_timestamp()) }}
),

-- Performance by campaign (last 30 days)
recent_campaign_performance as (
    select
        campaign_id,
        source_relation,
        sum(spend) as total_spend,
        avg({{ dbt_utils.safe_divide('clicks', 'impressions') }} * 100) as avg_ctr_percent,
        avg({{ dbt_utils.safe_divide('spend', 'clicks') }}) as avg_cpc
    from campaign_stats
    group by 1, 2
),

final as (
    select
        campaigns.source_relation,
        accounts.account_name,
        accounts.account_id,
        campaigns.campaign_id,
        campaigns.campaign_name,
        campaigns.advertising_channel_type,
        campaigns.advertising_channel_subtype,
        campaigns.status as campaign_status,
        campaigns.serving_status,

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

        -- Performance context
        recent_campaign_performance.total_spend,
        recent_campaign_performance.avg_ctr_percent,
        recent_campaign_performance.avg_cpc,

        -- Enhanced analysis based on actual data
        case
            when recent_campaign_performance.avg_cpc > 2.0
                and bid_modifiers.bid_modifier is null
                then 'Consider adding bid modifiers to optimize performance'
            when recent_campaign_performance.avg_ctr_percent < 2.0
                and bid_modifiers.bid_modifier > 1
                then 'Review positive bid adjustments - low CTR may indicate poor targeting'
            when recent_campaign_performance.total_spend > 1000
                and bid_modifiers.bid_modifier is null
                then 'High spend campaigns should leverage bid modifiers for better control'
            when lower(bidding_strategy.bidding_strategy_type) in ('manual_cpc', 'enhanced_cpc')
                and bid_modifiers.bid_modifier is null
                then 'Manual bidding campaigns benefit from bid modifier optimization'
            when bid_modifiers.bid_modifier > 1.5
                then 'High positive bid modifier - monitor performance impact'
            when bid_modifiers.bid_modifier < 0.7
                then 'Significant negative bid modifier - ensure targeting is still valuable'
            else 'Monitor bid modifier performance and adjust based on goals'
        end as bid_modifier_recommendation

    from campaigns
    left join accounts
        on campaigns.account_id = accounts.account_id
        and campaigns.source_relation = accounts.source_relation
    left join bidding_strategy
        on campaigns.campaign_id = bidding_strategy.campaign_id
        and campaigns.source_relation = bidding_strategy.source_relation
    left join bid_modifiers
        on campaigns.campaign_id = bid_modifiers.campaign_id
        and campaigns.source_relation = bid_modifiers.source_relation
    left join campaign_criterion
        on bid_modifiers.criterion_id = campaign_criterion.criterion_id
        and campaigns.campaign_id = campaign_criterion.campaign_id
        and campaigns.source_relation = campaign_criterion.source_relation
    left join recent_campaign_performance
        on campaigns.campaign_id = recent_campaign_performance.campaign_id
        and campaigns.source_relation = recent_campaign_performance.source_relation
)

select *
from final