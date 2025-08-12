# dbt_google_ads v1.0.0

[PR #82](https://github.com/fivetran/dbt_google_ads/pull/82) includes the following updates:

## Breaking Changes

### Source Package Consolidation
- Removed the dependency on the `fivetran/google_ads_source` package.
  - All functionality from the source package has been merged into this transformation package for improved maintainability and clarity.
  - If you reference `fivetran/google_ads_source` in your `packages.yml`, you must remove this dependency to avoid conflicts.
  - Any source overrides referencing the `fivetran/google_ads_source` package will also need to be removed or updated to reference this package.
  - Update any google_ads_source-scoped variables to be scoped to only under this package. See the [README](https://github.com/fivetran/dbt_google_ads/blob/main/README.md) for how to configure the build schema of staging models.
- As part of the consolidation, vars are no longer used to reference staging models, and only sources are represented by vars. Staging models are now referenced directly with `ref()` in downstream models.

### dbt Fusion Compatibility Updates
- Updated package to maintain compatibility with dbt-core versions both before and after v1.10.6, which introduced a breaking change to multi-argument test syntax (e.g., `unique_combination_of_columns`).
- Temporarily removed unsupported tests to avoid errors and ensure smoother upgrades across different dbt-core versions. These tests will be reintroduced once a safe migration path is available.
  - Removed all `dbt_utils.unique_combination_of_columns` tests.
  - Removed all `accepted_values` tests.
  - Moved `loaded_at_field: _fivetran_synced` under the `config:` block in `src_google_ads.yml`.

# dbt_google_ads v0.14.0

[PR #79](https://github.com/fivetran/dbt_google_ads/pull/79) includes the following updates:

## Breaking Change for dbt Core < 1.9.6
> *Note: This is not relevant to Fivetran Quickstart users.*

Migrated `freshness` from a top-level source property to a source `config` in alignment with [recent updates](https://github.com/dbt-labs/dbt-core/issues/11506) from dbt Core ([Source PR #68](https://github.com/fivetran/dbt_google_ads_source/pull/68)). This will resolve the following deprecation warning that users running dbt >= 1.9.6 may have received:

```
[WARNING]: Deprecated functionality
Found `freshness` as a top-level property of `google_ads` in file
`models/src_google_ads.yml`. The `freshness` top-level property should be moved
into the `config` of `google_ads`.
```

**IMPORTANT:** Users running dbt Core < 1.9.6 will not be able to utilize freshness tests in this release or any subsequent releases, as older versions of dbt will not recognize freshness as a source `config` and therefore not run the tests.

If you are using dbt Core < 1.9.6 and want to continue running Google Ads freshness tests, please elect **one** of the following options:
  1. (Recommended) Upgrade to dbt Core >= 1.9.6
  2. Do not upgrade your installed version of the `google_ads` package. Pin your dependency on v0.13.0 in your `packages.yml` file.
  3. Utilize a dbt [override](https://docs.getdbt.com/reference/resource-properties/overrides) to overwrite the package's `google_ads` source and apply freshness via the [old](https://github.com/fivetran/dbt_google_ads_source/blob/main/models/src_google_ads.yml#L11-L13) top-level property route. This will require you to copy and paste the entirety of the `src_google_ads.yml` [file](https://github.com/fivetran/dbt_google_ads_source/blob/main/models/src_google_ads.yml#L4-L327) and add an `overrides: google_ads_source` property.

## Under the Hood
- Updated the package maintainer PR template.

# dbt_google_ads v0.13.0

[PR #77](https://github.com/fivetran/dbt_google_ads/pull/77) introduces the following updates:

## Schema Updates

**2 total changes • 1 possible breaking change**
| **Model/Column** | **Change type** | **Old name** | **New name** | **Notes** |
| ---------------- | --------------- | ------------ | ------------ | --------- |
| [google_ads__search_term_report](https://fivetran.github.io/dbt_google_ads/#!/model/model.google_ads.google_ads__search_term_report) | New Column |   |  `criterion_id` | **BREAKING:** This may change the model's grain, as a single `keyword_text` can have multiple `criterion_id` values. `criterion_id` is included in uniqueness tests for this model. |
| [stg_google_ads__search_term_keyword_stats](https://fivetran.github.io/dbt_google_ads/#!/model/model.google_ads_source.stg_google_ads__search_term_keyword_stats) | New Column |   |  `criterion_id` |  Parsed out of `keyword_ad_group_criterion` field |

## Feature Updates
- Added `criterion_id` to the recently introduced `google_ads__search_term_report` model. This was added to align with other advertising platforms in the downstream [Ad Reporting](https://github.com/fivetran/dbt_ad_reporting/tree/main?tab=readme-ov-file) data model, which includes keyword IDs in the combined [search report](https://fivetran.github.io/dbt_ad_reporting/#!/model/model.ad_reporting.ad_reporting__search_report) end model.
- Removed `keyword_text` from the uniqueness test for `google_ads__search_term_report` in favor of `criterion_id`.

## Under the Hood
- Added a consistency data validation test for `google_ads__search_term_report`. 

# dbt_google_ads v0.12.0

## Schema Updates

**3 total changes • 0 possible breaking changes**
| **Model/Column** | **Change type** | **Old name** | **New name** | **Notes** |
| ---------------- | --------------- | ------------ | ------------ | --------- |
| [google_ads__search_term_report](https://fivetran.github.io/dbt_google_ads/#!/model/model.google_ads.google_ads__search_term_report)  | New Transform Model |   |   |  Each record represents daily performance of search terms matching tracked keywords, at the ad group level.  |
| stg_google_ads__search_term_keyword_stats | New Staging Model |   |   |  Uses new `search_term_keyword_stats` source table  |
| stg_google_ads__search_term_keyword_stats_tmp | New Staging Model |   |   | Uses new `search_term_keyword_stats` source table   |

## Feature Updates
- Added the `google_ads__using_search_term_keyword_stats` variable, which can be used to disable the above transformations related to the new `search_term_keyword_stats` table. This variable is dynamically set for Fivetran Quickstart users. See [README](https://github.com/fivetran/dbt_google_ads?tab=readme-ov-file#disable-search-term-keyword-stats) for more details. ([#76](https://github.com/fivetran/dbt_google_ads/pull/76))
- Introduced the `google_ads__search_term_keyword_stats_passthrough_metrics` variable, which can be used to pass through additional metrics fields from the `search_term_keyword_stats` report to the above models. See [README](https://github.com/fivetran/dbt_google_ads?tab=readme-ov-file#adding-passthrough-metrics) for more details. ([#76](https://github.com/fivetran/dbt_google_ads/pull/76))

## Documentation
- Added Quickstart model counts to README. ([#73](https://github.com/fivetran/dbt_google_ads/pull/73))
- Corrected references to connectors and connections in the README. ([#73](https://github.com/fivetran/dbt_google_ads/pull/73))
- Updated the LICENSE. ([#76](https://github.com/fivetran/dbt_google_ads/pull/76))
- Adjusted README header format. ([#76](https://github.com/fivetran/dbt_google_ads/pull/76))
- Added discussion of `keyword_text` qualifiers to the [DECISIONLOG](https://github.com/fivetran/dbt_google_ads_source/blob/main/DECISIONLOG.md). ([#76](https://github.com/fivetran/dbt_google_ads/pull/76))

## Under the Hood
- Removed the `horizontal_sum_conversions` integrity test, as it is based on a false premise of metrics tying out across different grains, which we discuss [here](https://github.com/fivetran/dbt_google_ads/blob/main/DECISIONLOG.md#why-dont-metrics-add-up-across-different-grains-ex-ad-level-vs-campaign-level). ([#76](https://github.com/fivetran/dbt_google_ads/pull/76))
- Added integrity test to verify transformations of the `search_term_keyword_stats` source table. ([#76](https://github.com/fivetran/dbt_google_ads/pull/76))
- Added `google_ads__using_search_term_keyword_stats` variable to the `quickstart.yml` file.
- Included `google_ads__using_search_term_keyword_stats` in Buildkite run.

# dbt_google_ads v0.11.0

[PR #66](https://github.com/fivetran/dbt_google_ads/pull/66) includes the following updates:

## Feature Updates: Conversion Support!
- We have added the following source fields to each `google_ads` end model:
  - `conversions`: The number of conversions you've received, across your conversion actions. Conversions are measured with conversion tracking and may include [modeled](https://support.google.com/google-ads/answer/10081327?sjid=12862894247631803415-NC) conversions in cases where you are not able to observe all conversions that took place. You can use this column to see how often your ads led customers to actions that you’ve defined as valuable for your business.
  - `conversions_value`: The sum of monetary values for your `conversions`. You have to enter a value in the Google Ads UI for your conversion actions to make this metric useful.
  - `view_through_conversions`: For video campaigns, view-through conversions tell you when an _impression_ of your video ad leads to a conversion on your site. The last impression of a video ad will get credit for the view-through conversion. An impression is different than a “view” of a video ad. A “view” is counted when someone watches 30 seconds (or the whole ad if it’s shorter than 30 seconds) or clicks on a part of the ad. A “view” that leads to a conversion is counted in the `conversions` column.
- In the event that you were already passing the above fields in via our [passthrough columns](https://github.com/fivetran/dbt_google_ads?tab=readme-ov-file#passing-through-additional-metrics), the package will dynamically avoid "duplicate column" errors.
> The above new field additions are 🚨 **breaking changes** 🚨 for users who were not already bringing in conversion fields via passthrough columns.

## Under the Hood
- Updated the package maintainer PR template.
- Created `google_ads_persist_pass_through_columns` macro to ensure that the new conversion fields are backwards compatible with users who have already included them via passthrough fields.
- Added integrity and consistency validation tests within `integration_tests` folder for the transformation models (to be used by maintainers only).

## Contributors
- [Seer Interactive](https://www.seerinteractive.com/?utm_campaign=Fivetran%20%7C%20Models&utm_source=Fivetran&utm_medium=Fivetran%20Documentation)
- [@fivetran-poonamagate](https://github.com/fivetran-poonamagate)

# dbt_google_ads v0.10.1
[PR #62](https://github.com/fivetran/dbt_google_ads/pull/62) includes the following updates: 

## Bug Fixes 
- This package now leverages the new `google_ads_extract_url_parameter()` (located within the dbt_google_ads_source package) macro for use in parsing out url parameters. This was added to create special logic for Databricks instances not supported by `dbt_utils.get_url_parameter()`.
  - This macro will be replaced with the `fivetran_utils.extract_url_parameter()` macro in the next breaking change of this package.

## Under the Hood 
- Included auto-releaser GitHub Actions workflow to automate future releases.

# dbt_google_ads v0.10.0
[PR #52](https://github.com/fivetran/dbt_google_ads/pull/52) includes the following updates:
## Feature update 🎉
- Unioning capability! This adds the ability to union source data from multiple google_ads connectors. Refer to the [Union Multiple Connectors README section](https://github.com/fivetran/dbt_google_ads/blob/main/README.md#union-multiple-connectors) for more details.

## Under the Hood 🚘
- In the source package, updated tmp models to union source data using the `fivetran_utils.union_data` macro. 
- To distinguish which source each field comes from, added `source_relation` column in each staging and downstream model and applied the `fivetran_utils.source_relation` macro. 
    - The `source_relation` column is included in all joins in the transform package. 
- Updated tests to account for the new `source_relation` column. 

[PR #60](https://github.com/fivetran/dbt_google_ads/pull/60) includes the following update:
## Dependency Updates
- Removes the dependency on `dbt-expectations`. Upstream we specifically removed the `dbt_expectations.expect_column_values_to_not_match_regex_list` test.
## Under the Hood 
- Updates the [DECISIONLOG](DECISIONLOG.md) to clarify why there exist differences among aggregations across different grains. 

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
