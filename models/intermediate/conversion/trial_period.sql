{{
    config(
        materialized='incremental',
        unique_key = 'organization_id',
        cluster_by = ["organization_id"],
        incremental_strategy = 'merge',
        merge_update_columns = ['max_timestamp', 'trial_timedelta']
    )
}}


WITH organzation_changed as (
{% if is_incremental() %}
    SELECT
        "ORGANIZATION_ID" as organization_id,
        MIN("TIMESTAMP") as min_timestamp,
        MAX("TIMESTAMP") as max_timestamp
    FROM {{ source('planday', 'interactions') }}
    WHERE "TIMESTAMP" > (SELECT MAX(max_timestamp) from {{this}})
    GROUP BY "ORGANIZATION_ID"
{% else %}
    SELECT
        "ORGANIZATION_ID" as organization_id,
        MIN("TIMESTAMP") as min_timestamp,
        MAX("TIMESTAMP") as max_timestamp
    FROM {{ source('planday', 'interactions') }}
    GROUP BY "ORGANIZATION_ID"
{% endif %}
)

SELECT
organization_id,
min_timestamp,
max_timestamp,
max_timestamp - min_timestamp as trial_timedelta
FROM organzation_changed