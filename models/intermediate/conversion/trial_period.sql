{{
    config(
        materialized='incremental',
        unique_key = 'organization_id',
        cluster_by = ["organization_id"],
        incremental_strategy = 'merge',
        merge_update_columns = ['max_timestamp', 'trial_timedelta']
    )
}}

{% if is_incremental() %}
WITH organzation_changed as (
    SELECT DISTINCT "ORGANIZATION_ID" as organization_id
    FROM {{ source('planday', 'interactions') }}
    WHERE "TIMESTAMP" > (SELECT MAX("max_timestamp") from {{this}})
)

{% endif %}

SELECT
    organization_id,
    min_timestamp,
    max_timestamp,
    (max_timestamp - min_timestamp) as trial_timedelta
FROM (
    SELECT
    "ORGANIZATION_ID" as organization_id,
    MIN("TIMESTAMP") as min_timestamp,
    MAX("TIMESTAMP") as max_timestamp
    FROM {{ source('planday', 'interactions') }}
    {% if is_incremental() %}
      WHERE "ORGANIZATION_ID" in (select organization_id from organzation_changed)
    {% endif %}
    GROUP BY "ORGANIZATION_ID"
) q