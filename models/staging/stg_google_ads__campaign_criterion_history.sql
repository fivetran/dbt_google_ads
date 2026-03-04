{{ config(enabled=var('ad_reporting__google_ads_enabled', True) and var('google_ads__using_campaign_criterion_history', True)) }}

with base as (

    select *
    from {{ ref('stg_google_ads__campaign_criterion_history_tmp') }}

),

fields as (

    select
        {{
            fivetran_utils.fill_staging_columns(
                source_columns=adapter.get_columns_in_relation(ref('stg_google_ads__campaign_criterion_history_tmp')),
                staging_columns=get_campaign_criterion_history_columns()
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
        id as criterion_id,
        updated_at,
        campaign_id,
        geo_target_constant_id,
        mobile_device_id,
        operating_system_version_id,
        topic_constant_id,
        user_interest_id,
        user_list_id,
        age_range_type,
        bid_modifier,
        carrier_country_code,
        carrier_name,
        content_label_type,
        device_type,
        display_name,
        gender_type,
        income_range_type,
        ip_block_ip_address,
        negative,
        keyword_match_type,
        keyword_text,
        language_code,
        language_name,
        mobile_app_category_constant_id,
        mobile_app_category_constant_name,
        mobile_application_app_id,
        mobile_application_name,
        parental_status_type,
        placement_url,
        status,
        type,
        youtube_channel_id,
        youtube_video_id,
        row_number() over (partition by id {{ google_ads.partition_by_source_relation() }} order by updated_at desc) = 1 as is_most_recent_record
    from fields
    where coalesce(_fivetran_active, true)
)

select *
from final