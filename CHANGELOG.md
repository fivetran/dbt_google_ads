# dbt_google_ads v0.9.3
[PR #57](https://github.com/fivetran/dbt_google_ads/pull/57) includes the following updates:
## Bug fixes
- Updated end models to select key columns from the `stats` source instead of the `reports` source to avoid introducing null values.

## Contributors
- [@edwardskatie](https://github.com/edwardskatie) ([PR #54](https://github.com/fivetran/dbt_google_ads/pull/54))

# dbt_google_ads v0.9.2 

## 🎉 Features 🎉
- Added the column `currency_code` to the following models ([PR #49](https://github.com/fivetran/dbt_google_ads/pull/49)): 
    - `google_ads__ad_group_report`
    - `google_ads__ad_report`
    - `google_ads__campaign_report`
    - `google_ads__keyword_report`
    - `google_ads__url_report`

## Under the Hood:

- Incorporated the new `fivetran_utils.drop_schemas_automation` macro into the end of each Buildkite integration test job. ([PR #46](https://github.com/fivetran/dbt_google_ads/pull/46))
- Updated the pull request [templates](/.github). ([PR #46](https://github.com/fivetran/dbt_google_ads/pull/46))

## Contributors
- [@asmundu](https://github.com/asmundu) ([PR #36](https://github.com/fivetran/dbt_google_ads/pull/36))

# dbt_google_ads v0.9.1
## Bug fixes
- Adjusted keyword report to leverage the stats ids as opposed to the history ids to have more accurate reporting. ([PR #41](https://github.com/fivetran/dbt_google_ads/pull/41))

## Contributors 
- [jkokatjuhhavoila](https://github.com/jkokatjuhhavoila) ([PR #41](https://github.com/fivetran/dbt_google_ads/pull/41))

# dbt_google_ads v0.9.0

## 🚨 Breaking Changes 🚨:
[PR #35](https://github.com/fivetran/dbt_google_ads/pull/35) includes the following breaking changes:
- Dispatch update for dbt-utils to dbt-core cross-db macros migration. Specifically `{{ dbt_utils.<macro> }}` have been updated to `{{ dbt.<macro> }}` for the below macros:
    - `any_value`
    - `bool_or`
    - `cast_bool_to_text`
    - `concat`
    - `date_trunc`
    - `dateadd`
    - `datediff`
    - `escape_single_quotes`
    - `except`
    - `hash`
    - `intersect`
    - `last_day`
    - `length`
    - `listagg`
    - `position`
    - `replace`
    - `right`
    - `safe_cast`
    - `split_part`
    - `string_literal`
    - `type_bigint`
    - `type_float`
    - `type_int`
    - `type_numeric`
    - `type_string`
    - `type_timestamp`
    - `array_append`
    - `array_concat`
    - `array_construct`
- For `current_timestamp` and `current_timestamp_in_utc` macros, the dispatch AND the macro names have been updated to the below, respectively:
    - `dbt.current_timestamp_backcompat`
    - `dbt.current_timestamp_in_utc_backcompat`
- `packages.yml` has been updated to reflect new default `fivetran/fivetran_utils` version, previously `[">=0.3.0", "<0.4.0"]` now `[">=0.4.0", "<0.5.0"]`.

## 🎉 Features 🎉
- For use in the [dbt_ad_reporting package](https://github.com/fivetran/dbt_ad_reporting), users can now allow records having nulls in url fields to be included in the `ad_reporting__url_report` model. See the [dbt_ad_reporting README](https://github.com/fivetran/dbt_ad_reporting) for more details ([#39](https://github.com/fivetran/dbt_google_ads/pull/39)). 
## 🚘 Under the Hood 🚘
- Disabled the `not_null` test for `google_ads__url_report` when null urls are allowed ([#39](https://github.com/fivetran/dbt_google_ads/pull/39)).

# dbt_google_ads v0.8.1

## Updates:
- Updates `google_ads__ad_report` model to get `ad_id` from `ad_stats` table rather than from `ads_history`. ([#37](https://github.com/fivetran/dbt_google_ads/pull/37))

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
