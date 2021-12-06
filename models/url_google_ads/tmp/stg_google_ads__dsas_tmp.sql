{{ config(enabled=var('api_source') == 'google_ads') }}

with staged as (
    -- this contains ALL campaigns
    select * from {{ ref('stg_google_ads__campaign_spend_tmp') }}
),
adapter as (
    -- this contains ALL campaigns MINUS dsa's since it's built off of ad_stats
    select * from {{ ref('google_ads__url_ad_adapter')}}
),
joined as (
    -- get rows that exist in staged that do not exist in adapter
    SELECT
        a.*
    FROM
        staged a
        LEFT JOIN 
        adapter b 
        ON a.campaign_id = b.campaign_id
    WHERE
        b.campaign_id IS NULL
)

select * from joined

