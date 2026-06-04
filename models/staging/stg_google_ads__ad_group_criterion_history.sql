{{ config(enabled=var('ad_reporting__google_ads_enabled', True)) }}

with base as (

    select * 
    from {{ ref('stg_google_ads__ad_group_criterion_history_tmp') }}
),

fields as (

    select
        {{
            fivetran_utils.fill_staging_columns(
                source_columns=adapter.get_columns_in_relation(ref('stg_google_ads__ad_group_criterion_history_tmp')),
                staging_columns=get_ad_group_criterion_history_columns()
            )
        }}
    
        {{ fivetran_utils.apply_source_relation(package_name='google_ads') }}

    from base
),

final as (

    select
        source_relation, 
        id as criterion_id,
        cast(ad_group_id as {{ dbt.type_string() }}) as ad_group_id,
        base_campaign_id,
        updated_at,
        type,
        status,
        keyword_match_type,
        keyword_text,
        row_number() over (partition by id {{ fivetran_utils.partition_by_source_relation(package_name='google_ads') }} order by updated_at desc) = 1 as is_most_recent_record
    from fields
    where coalesce(_fivetran_active, true)
)

select *
from final