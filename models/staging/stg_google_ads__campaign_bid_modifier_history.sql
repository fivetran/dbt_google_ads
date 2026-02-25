{{ config(enabled=var('ad_reporting__google_ads_enabled', True)) }}

with base as (

    select *
    from {{ ref('stg_google_ads__campaign_bid_modifier_history_tmp') }}

),

fields as (

    select
        {{
            fivetran_utils.fill_staging_columns(
                source_columns=adapter.get_columns_in_relation(ref('stg_google_ads__campaign_bid_modifier_history_tmp')),
                staging_columns=get_campaign_bid_modifier_history_columns()
            )
        }}


        {{ fivetran_utils.source_relation(
            union_schema_variable='google_ads_union_schemas',
            union_database_variable='google_ads_union_databases')
        }}

    from base
),

final as (

    select
        source_relation,
        campaign_id,
        criterion_id,
        bid_modifier,
        interaction_type,
        interaction_event_types,
        updated_at,
        row_number() over (partition by campaign_id, criterion_id {{ google_ads.partition_by_source_relation() }} order by updated_at desc) = 1 as is_most_recent_record
    from fields
    where coalesce(_fivetran_active, true)
)

select *
from final