{{
    config(
        materialized='incremental',
        unique_key = 'organization_id',
        cluster_by = ["organization_id"],
        incremental_strategy = 'merge'
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
    "ORGANIZATION_ID" as organization_id,
    MIN("TIMESTAMP") as min_timestamp,
    MAX("TIMESTAMP") as max_timestamp,
    (MAX("TIMESTAMP") - MIN("TIMESTAMP") ) as trial_timedelta
    FROM {{ source('planday', 'interactions') }}
    {% if is_incremental() %}
      WHERE "ORGANIZATION_ID" in (select organization_id from organzation_changed)
    {% endif %}
    GROUP BY "ORGANIZATION_ID"
