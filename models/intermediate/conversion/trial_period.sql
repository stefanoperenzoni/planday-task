{{
    config(
        unique_key='organization_id'
    )
}}

WITH new_data AS (
    SELECT
        "ORGANIZATION_ID" AS organization_id,
        MIN("TIMESTAMP") AS min_timestamp,
        MAX("TIMESTAMP") AS max_timestamp
    FROM {{ source('planday', 'interactions') }}
    {% if is_incremental() %}
        -- Only process new rows in the incremental run
        WHERE "TIMESTAMP" > (SELECT COALESCE(MAX(max_timestamp), '1970-01-01') FROM {{ this }})
    {% endif %}
    GROUP BY "ORGANIZATION_ID"
),

existing_data AS (
    {% if is_incremental() %}
    SELECT *
    FROM {{ this }}
    {% else %}
    SELECT
        NULL AS organization_id,
        TIMESTAMP '0001-01-01 00:00:01.000' AS min_timestamp,
        TIMESTAMP '0001-01-01 00:00:01.000' AS max_timestamp,
        NULL as trial_timedelta
    WHERE 1 = 0
    {% endif %}
)

SELECT
    ed.organization_id AS organization_id,
    LEAST(nd.min_timestamp, ed.min_timestamp) AS min_timestamp,
    GREATEST(nd.max_timestamp, ed.max_timestamp) AS max_timestamp,
    (GREATEST(nd.max_timestamp, ed.max_timestamp) - LEAST(nd.min_timestamp, ed.min_timestamp)) AS trial_timedelta
FROM existing_data ed
FULL OUTER JOIN new_data nd
ON ed.organization_id = nd.organization_id