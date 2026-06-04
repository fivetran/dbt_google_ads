{{ config(enabled=var('ad_reporting__google_ads_enabled', True)) }}

with base as (

    select * 
    from {{ ref('stg_google_ads__campaign_history_tmp') }}

),

fields as (

    select
        {{
            fivetran_utils.fill_staging_columns(
                source_columns=adapter.get_columns_in_relation(ref('stg_google_ads__campaign_history_tmp')),
                staging_columns=get_campaign_history_columns()
            )
        }}
        
    
        {{ fivetran_utils.apply_source_relation(package_name='google_ads') }}

    from base
),

final as (

    select
        source_relation, 
        id as campaign_id, 
        updated_at,
        name as campaign_name,
        customer_id as account_id,
        advertising_channel_type,
        advertising_channel_subtype,
        coalesce(cast(start_date_time as {{ dbt.type_string() }}), cast(start_date as {{ dbt.type_string() }})) as start_date,
        coalesce(cast(end_date_time as {{ dbt.type_string() }}), cast(end_date as {{ dbt.type_string() }})) as end_date,
        serving_status,
        status,
        tracking_url_template,
        row_number() over (partition by id {{ fivetran_utils.partition_by_source_relation(package_name='google_ads') }} order by updated_at desc) = 1 as is_most_recent_record
    from fields
    where coalesce(_fivetran_active, true)
)

select * 
from final