# Decision Log
## Ads Associated with Multiple Ad Groups
It was discovered within the `google_ads.ads_stats` source table that a single Ad can be associated with multiple ad groups on any given day. Because of this, it was determined that the `is_most_recent_record` logic within the `stg_google_ads__ad_history` model needed to account for the `ad_group_id` as well as the individual `ad_id`. As a result, the most recent record of an ad could possibly contain a unique combination of the `ad_id` and the `ad_group_id`.

The final `google_ads__url_report` and `google_ads__ad_report` models also take this into account and include an addition join condition between the `stg_google__ad_stats` and `stg_google__ad_history` models to account for the varying grain of the ad -> ad group relationship within the two tables. This additional join condition ensures the final models are accurately capturing **all** metrics for the ads that are associated with multiple ad groups.

This logic was only applied to the `google_ads__url_report` and `google_ads__ad_report` models as it was discovered this relationship was unique to ads and ad groups. If you experience this relationship among any of the other ad hierarchies, please open and [issue](https://github.com/fivetran/dbt_google_ads/issues/new?assignees=&labels=bug%2Ctriage&template=bug-report.yml&title=%5BBug%5D+%3Ctitle%3E) and we can continue the discussion!

## UTM Report Filtering
This package contains a `google_ads__url_report` which provides daily metrics for your utm compatible ads. It is important to note that not all Ads within Google's `ad_stats` report do not leverage utm parameters. Therefore, this package takes an opinionated approach to filter out any records that do not contain utm parameters or leverage a url within the ad.

If you would like to leverage a report that contains all ads and their daily metrics, I would suggest you leverage the `google_ads__ad_report` which does not apply any filtering.

## Why don't metrics add up across different grains (Ex. ad level vs campaign level)?
Not all ads are served at the ad level. In other words, there are some ads that are served only at the ad group, campaign, etc. levels. The implications are that since not ads are included in the ad-level report, their associated spend, for example, won't be included at that grain. Therefore your spend totals may differ across the ad grain and another grain. 

This is a reason why we have broken out the ad reporting packages into separate hierarchical end models (Ad, Ad Group, Campaign, and more). Because if we only used ad-level reports, we could be missing data.

## Inclusion of Search Term Keyword Qualifiers
In the `google_ads__search_term_report` model, some keywords may be prepended with plus signs (`+`) or may be wrapped in 2 single quotes (`''keyword''`). The former is a legacy of Broad Match Modifier (BMM), which was [deprecated](https://support.google.com/google-ads/answer/10286719?hl=en) and merged into Phrase Match in July 2021 by Google. The latter likely indicates a phrase match for the keyword, though it may not match the `search_term_match_type` value for the record.

We have opted to leave these qualifiers in the `keyword_text` values, rather than strip them out. Please reach out and create an [issue](https://github.com/fivetran/dbt_google_ads/issues) if you would like cleaned `keyword_text` values for standardization.