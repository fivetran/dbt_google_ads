with source as (

    select 
        ad_group_id,
        search_term,
        keyword_text,
        search_term_match_type,
        sum(spend) as spend,
        sum(clicks) as clicks,
        sum(impressions) as impressions,
        sum(conversions) as conversions,
        sum(conversions_value) as conversions_value,
        sum(view_through_conversions) as view_through_conversions
    from {{ ref('stg_google_ads__search_term_keyword_stats')}}
    group by 1,2,3,4
),

model as (

    select 
        ad_group_id,
        search_term,
        keyword_text,
        search_term_match_type,
        sum(spend) as spend,
        sum(clicks) as clicks,
        sum(impressions) as impressions,
        sum(conversions) as conversions,
        sum(conversions_value) as conversions_value,
        sum(view_through_conversions) as view_through_conversions
    from {{ ref('google_ads__search_term_report') }}
    group by 1,2,3,4
),

final as (
    select 
        source.ad_group_id,
        source.search_term,
        source.keyword_text,
        source.search_term_match_type,
        source.spend as source_spend,
        model.spend as model_spend,
        source.clicks as source_clicks,
        model.clicks as model_clicks,
        source.impressions as source_impressions,
        model.impressions as model_impressions,
        source.conversions as source_conversions,
        model.conversions as model_conversions,
        source.conversions_value as source_conversions_value,
        model.conversions_value as model_conversions_value,
        source.view_through_conversions as source_view_through_conversions,
        model.view_through_conversions as model_view_through_conversions
    from source 
    full outer join model
        on source.ad_group_id = model.ad_group_id
        and source.search_term = model.search_term
        and source.keyword_text = model.keyword_text
        and source.search_term_match_type = model.search_term_match_type
)

select * 
from final
where 
    source_spend != model_spend
    or source_clicks != model_clicks
    or source_impressions != model_impressions
    or source_conversions != model_conversions
    or source_conversions_value != model_conversions_value
    or source_view_through_conversions != model_view_through_conversions