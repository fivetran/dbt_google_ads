{#
  Builds a dictionary of high/low threshold values. Uses customer-defined variables
  if set, otherwise falls back to provided defaults.

  For each threshold type, checks for customer variable (e.g. 'google_ads__budget_high_low_thresholds')
  and uses that value if present, otherwise uses the default configuration.

  Args:
    default_thresholds (dict): Dictionary of threshold names -> default [low, high] arrays

  Returns:
    dict: Nested dictionary with structure:
    {
      'budget': {'low': 0.75, 'high': 0.95},
      'ctr': {'low': 0.015, 'high': 0.03},
      ...
    }
#}
{% macro get_threshold_high_lows(default_thresholds) %}
  {{ return(adapter.dispatch('get_threshold_high_lows', 'google_ads')(default_thresholds)) }}
{% endmacro %}

{% macro default__get_threshold_high_lows(default_thresholds) %}
  {% set threshold_dict = {} %}

  {# Loop through each threshold type (budget, ctr, cpc, etc.) #}
  {% for key, defaults in default_thresholds.items() %}
    {# Construct variable name: google_ads__budget_high_low_thresholds, etc. #}
    {% set var_name = 'google_ads__' + key + '_high_low_thresholds' %}

    {# Get threshold values with empty array protection #}
    {% set var_values = var(var_name, defaults) | map('float') | list %}
    {% set threshold_values = var_values if var_values | length > 0 else defaults %}

    {# Calculate min/max and add to result dictionary #}
    {% do threshold_dict.update({key: {'low': threshold_values|min, 'high': threshold_values|max}}) %}
  {% endfor %}

  {{ return(threshold_dict) }}
{% endmacro %}