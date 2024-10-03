{% macro count_column_value(column_name, column_value) %}
    COUNT(CASE WHEN "{{ column_name }}" = '{{ column_value }}' THEN 1 END)
{% endmacro %}