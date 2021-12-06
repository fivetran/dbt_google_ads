{{ config(enabled=var('api_source') == 'google_ads') }}

-- union our dsa's back into the google_ads_url_ad_adapter
with unioned as (
    {{ dbt_utils.union_relations(
        relations=[ref('stg_google_ads__dsas_tmp'), ref('google_ads__url_ad_adapter')]
    ) }} 
),
fields as (

    select
        date_day,
        lower(account_name) as account_name,
        account_id,
        lower(campaign_name) as campaign_name,
        campaign_id,
        ad_group_name,
        ad_group_id,
        base_url,
        url_host,
        url_path,
        utm_source,
        utm_medium,
        lower(utm_campaign),
        utm_content,
        utm_term,
        spend,
        clicks,
        impressions
    from unioned
)

select * from fields

