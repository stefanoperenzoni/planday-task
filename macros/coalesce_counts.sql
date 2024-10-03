{% macro coalesce_counts(ed, nd, column_name) %}
    {{ ed }}.{{ column_name }} + {{ nd }}.{{ column_name }}
{% endmacro %}