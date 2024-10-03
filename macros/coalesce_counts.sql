{% macro coalesce_counts(ed, nd, column_name) %}
    COALESCE({{ ed }}.{{ column_name }}, 0) + COALESCE({{ nd }}.{{ column_name }}, 0)
{% endmacro %}