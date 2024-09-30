{{
    config(
        materialized='incremental',
        unique_key='organization_id'
    )
}}
WITH interactions AS (
    SELECT
        "ORGANIZATION_ID" as organization_id,
        MIN("TIMESTAMP") AS min_timestamp,
        MAX("TIMESTAMP") AS max_timestamp
    FROM {{ source('planday', 'interactions') }}
    {% if is_incremental() %}
        -- Only process new rows in the incremental run
        WHERE "TIMESTAMP" > (SELECT MAX(max_timestamp) FROM {{ this }})
    {% endif %}
    GROUP BY "ORGANIZATION_ID"
)

SELECT
    organization_id,
    min_timestamp,
    max_timestamp,
    (max_timestamp - min_timestamp) as trial_timedelta
FROM interactions