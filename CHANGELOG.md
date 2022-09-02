# dbt_google_ads v0.8.0
## 🚨 Breaking Changes 🚨
- The `adwords` api version of the package has been fully removed. As the Fivetran Google Ads connector now requires the Google Ads API, this functionality is no longer used. ([#34](https://github.com/fivetran/dbt_google_ads/pull/34))
- Removal of the `google_ads__ad_adapter` model. ([#34](https://github.com/fivetran/dbt_google_ads/pull/34))
- Major updates have also been applied to the [dbt_google_ads_source](https://github.com/fivetran/dbt_google_ads_source) package which is a dependency of this package. Please refer to the [v0.8.0](https://github.com/fivetran/dbt_google_ads_source/releases/tag/v0.8.0) release notes for more details before upgrading your package.
- The declaration of passthrough variables within your root `dbt_project.yml` has changed. To allow for more flexibility and better tracking of passthrough columns, you will now want to define passthrough metrics in the following format:
> This applies to all passthrough metrics within the `dbt_google_ads` package and not just the `google_ads__ad_stats_passthrough_metrics` example.
```yml
vars:
  google_ads__ad_stats_passthrough_metrics:
    - name: "my_field_to_include" # Required: Name of the field within the source.
      alias: "field_alias" # Optional: If you wish to alias the field within the staging model.
```

## 🎉 Feature Enhancements 🎉
- Addition of the following new end models. These models were added to provide further flexibility and ensure greater accuracy of your Google Ads reporting. Additionally, these new end models will be leveraged in the respective downstream [dbt_ad_reporting](https://github.com/fivetran/dbt_ad_reporting) models.
  - `google_ads__account_report`
    - Each record in this table represents the daily performance at the account level.
  - `google_ads__campaign_report`
    - Each record in this table represents the daily performance of a campaign at the campaign/advertising_channel/advertising_channel_subtype level.
  - `google_ads__ad_group_report`
    - Each record in this table represents the daily performance at the ad group level.
  - `google_ads__keyword_report`
    - Each record in this table represents the daily performance at the ad group level for keywords.
  - `google_ads__ad_report`
    - Each record in this table represents the daily performance at the ad level.
  - `google_ads__url_report`
    - Each record in this table represents the daily performance of URLs at the ad level.

- Added testing for each end model to ensure granularity and accuracy of the modeled data. ([#34](https://github.com/fivetran/dbt_google_ads/pull/34))
- README updates for easier navigation and use of the package. ([#34](https://github.com/fivetran/dbt_google_ads/pull/34))
- Inclusion of additional passthrough metrics within the respective end state models detailed above: ([#34](https://github.com/fivetran/dbt_google_ads/pull/34))
  - `google_ads__ad_group_stats_passthrough_metrics`
  - `google_ads__campaign_stats_passthrough_metrics`
  - `google_ads__keyword_stats_passthrough_metrics`
  - `google_ads__account_stats_passthrough_metrics`

## Contributors
- [@bnealdefero](https://github.com/bnealdefero) ([#20](https://github.com/fivetran/dbt_google_ads/pull/20))
# dbt_google_ads v0.7.0
## 🚨 Breaking Changes 🚨
- The `api_source` variable is now defaulted to `google_ads` as opposed to `adwords`. The Adwords API has since been deprecated by Google and is now no longer the standard API for the Google Ads connector. Please ensure you are using a Google Ads API version of the Fivetran connector before upgrading this package. ([#32](https://github.com/fivetran/dbt_google_ads/pull/32))
  - Please note, the `adwords` version of this package will be fully removed from the package in August of 2022. This means, models under `models/adwords_connector` will be removed in favor of `models/google_ads_connector` models.
# dbt_google_ads v0.6.1
- Updated google_ads__url_ad_adapter link in README (Thank you to @bkimjin! ([#26](https://github.com/fivetran/dbt_google_ads/issues/26)))
# dbt_google_ads v0.6.0
## 🚨 Breaking Changes 🚨
- The `account` source table has been renamed to be `account_history`. This has been reflected in the source model references within this release. ([#24](https://github.com/fivetran/dbt_google_ads_source/pull/24))
- The `ad_final_url_history` model has been removed from the connector. The url fields are now references within the `final_urls` field within the `ad_history` table. These changes are reflected in the `google_ads__url_adapter` model. ([#24](https://github.com/fivetran/dbt_google_ads_source/pull/24))
# dbt_google_ads v0.5.0
🎉 dbt v1.0.0 Compatibility 🎉
## 🚨 Breaking Changes 🚨
- Adjusts the `require-dbt-version` to now be within the range [">=1.0.0", "<2.0.0"]. Additionally, the package has been updated for dbt v1.0.0 compatibility. If you are using a dbt version <1.0.0, you will need to upgrade in order to leverage the latest version of the package.
  - For help upgrading your package, I recommend reviewing this GitHub repo's Release Notes on what changes have been implemented since your last upgrade.
  - For help upgrading your dbt project to dbt v1.0.0, I recommend reviewing dbt-labs [upgrading to 1.0.0 docs](https://docs.getdbt.com/docs/guides/migration-guide/upgrading-to-1-0-0) for more details on what changes must be made.
- Upgrades the package dependency to refer to the latest `dbt_google_ads_source`. Additionally, the latest `dbt_google_ads_source` package has a dependency on the latest `dbt_fivetran_utils`. Further, the latest `dbt_fivetran_utils` package also has a dependency on `dbt_utils` [">=0.8.0", "<0.9.0"].
  - Please note, if you are installing a version of `dbt_utils` in your `packages.yml` that is not in the range above then you will encounter a package dependency error.

# dbt_google_ads v0.1.0 -> v0.4.0
Refer to the relevant release notes on the Github repository for specific details for the previous releases. Thank you!
