{#
  Builds a dictionary of high/low threshold values using individual low/high variables.
  Uses customer-defined variables if set, otherwise falls back to package defaults.

  For each threshold type, checks for individual low/high variables:
  - google_ads__cpc_low / google_ads__cpc_high
  - google_ads__ctr_low / google_ads__ctr_high
  - etc.

  Returns:
    dict: Nested dictionary with structure:
    {
      'budget': {'low': 0.75, 'high': 0.95},
      'ctr': {'low': 0.015, 'high': 0.03},
      ...
    }
#}
{% macro get_threshold_high_lows() %}
  {{ return(adapter.dispatch('get_threshold_high_lows', 'google_ads')()) }}
{% endmacro %}

{% macro default__get_threshold_high_lows() %}
  {%- set diagnostic_thresholds = {
    'cpc': {
      'low': var('google_ads__cpc_low', 1.0),
      'high': var('google_ads__cpc_high', 3.0)
    },
    'ctr': {
      'low': var('google_ads__ctr_low', 0.015),
      'high': var('google_ads__ctr_high', 0.03)
    },
    'spend': {
      'low': var('google_ads__spend_low', 100.0),
      'high': var('google_ads__spend_high', 500.0)
    },
    'bid_modifier': {
      'low': var('google_ads__bid_modifier_low', 0.7),
      'high': var('google_ads__bid_modifier_high', 1.5)
    },
    'budget': {
      'low': var('google_ads__budget_low', 0.75),
      'high': var('google_ads__budget_high', 0.95)
    },
    'location_targeting': {
      'low': var('google_ads__location_targeting_low', 5.0),
      'high': var('google_ads__location_targeting_high', 50.0)
    }
  } -%}

  {{ return(diagnostic_thresholds) }}
{% endmacro %}