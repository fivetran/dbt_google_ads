with base as (

    select *
    from {{ ref('stg_google_ads__click_performance') }}

), fields as (

    select
        date_day,
        campaign_id,
        ad_group_id,
        criteria_id,
        gclid,
        row_number() over (partition by gclid order by date_day) as rn
    from base

), filtered as (

    select *
    from fields
    where gclid is not null 
    and rn = 1

)

select * from filtered