# dbt_google_ads v0.6.0

## Features
- Allow for multiple sources by unioning source tables across multiple Google Ads connectors.
  - Refer to the [README](https://github.com/fivetran/dbt_google_ads#unioning-multiple-klaviyo-connectors) for more details.

## Under the Hood
- Unioning: The unioning occurs in the staging tmp models using the `fivetran_utils.union_data` macro.
- Source Relation column: To distinguish which source each record comes from, we added a new `source_relation` column in each staging and final model and applied the `fivetran_utils.source_relation` macro.
    - The `source_relation` column is included in all joins and window function partition clauses in the transform package. Note that an event from one Google Ads source will _never_ be attributed to an event from a different Google Ads connector.

## Contributors
- [@pawelngei](https://github.com/pawelngei)

# dbt_google_ads v0.1.0 -> v0.5.0
Refer to the relevant release notes on the Github repository for specific details for the previous releases. Thank you!