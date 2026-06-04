{{ config(enabled=var('ad_reporting__google_ads_enabled', True) and var('google_ads__using_campaign_budget_history', True)) }}

with base as (

    select *
    from {{ ref('stg_google_ads__campaign_budget_history_tmp') }}

),

fields as (

    select
        {{
            fivetran_utils.fill_staging_columns(
                source_columns=adapter.get_columns_in_relation(ref('stg_google_ads__campaign_budget_history_tmp')),
                staging_columns=get_campaign_budget_history_columns()
            )
        }}


        {{ fivetran_utils.apply_source_relation(package_name='google_ads') }}

    from base
),

final as (

    select
        source_relation,
        updated_at,
        campaign_id,
        amount_micros / 1000000.0 as daily_budget,
        status as budget_status,
        has_recommended_budget,
        recommended_budget_amount_micros / 1000000.0 as recommended_daily_budget,
        total_amount_micros / 1000000.0 as total_budget,
        type as budget_type,
        row_number() over (partition by campaign_id {{ fivetran_utils.partition_by_source_relation(package_name='google_ads') }} order by updated_at desc) = 1 as is_most_recent_record
    from fields
    where coalesce(_fivetran_active, true)
)

select *
from final