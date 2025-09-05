{% macro select_excluding(table, exclude_column) %}
  {% set cols = adapter.get_columns_in_relation(ref(table)) %}
  {% set selected_cols = cols | rejectattr("name", "equalto", exclude_column) | map(attribute="name") | join(", ") %}
  SELECT {{ selected_cols }} FROM {{ ref(table) }}
{% endmacro %}
