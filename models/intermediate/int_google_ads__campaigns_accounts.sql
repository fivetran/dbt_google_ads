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

final as (
    select
        -- Campaign dimensional data
        campaigns.source_relation,
        campaigns.campaign_id,
        campaigns.campaign_name,
        campaigns.status as campaign_status,
        campaigns.serving_status,
        campaigns.advertising_channel_type,
        campaigns.advertising_channel_subtype,

        -- Account dimensional data
        accounts.account_id,
        accounts.account_name,
        accounts.currency_code,
        accounts.time_zone,
        accounts.auto_tagging_enabled

    from campaigns
    left join accounts
        on campaigns.account_id = accounts.account_id
        and campaigns.source_relation = accounts.source_relation
)

select *
from final