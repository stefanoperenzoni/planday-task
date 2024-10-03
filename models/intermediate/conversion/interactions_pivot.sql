{{
    config(
        unique_key='organization_id'
    )
}}

WITH latest_data AS (
        SELECT *
        FROM {{ source('planday', 'interactions') }}
    {% if is_incremental() %}
        WHERE "TIMESTAMP" > (SELECT MAX(max_timestamp) FROM {{ this }})
    {% endif %}
),

--Aggregate the new data
new_data AS (
    SELECT
        "ORGANIZATION_ID" as organization_id,
        COUNT(CASE WHEN "ACTIVITY_NAME" = 'Shift.Created' THEN 1 END) AS shift_created_count,
        COUNT(CASE WHEN "ACTIVITY_NAME" = 'Hr.Employee.Invited' THEN 1 END) AS employee_invited_count,
        COUNT(CASE WHEN "ACTIVITY_NAME" = 'PunchClock.PunchedIn' THEN 1 END) AS punch_in_count,
        COUNT(CASE WHEN "ACTIVITY_NAME" = 'PunchClock.Approvals.EntryApproved' THEN 1 END) AS punch_in_entry_approved_count,
        COUNT(CASE WHEN "ACTIVITY_NAME" = 'Page.Viewed' THEN 1 END) AS viewed_count,
        COUNT(CASE WHEN "ACTIVITY_DETAIL" = 'revenue' THEN 1 END) AS revenue_viewed_count,
        COUNT(CASE WHEN "ACTIVITY_DETAIL" = 'integrations-overview' THEN 1 END) AS integrations_viewed_count,
        COUNT(CASE WHEN "ACTIVITY_DETAIL" = 'absence-accounts' THEN 1 END) AS absence_viewed_count,
        COUNT(CASE WHEN "ACTIVITY_DETAIL" = 'availability' THEN 1 END) AS availability_viewed_count,
        MAX("TIMESTAMP") AS max_timestamp
    FROM latest_data
    GROUP BY "ORGANIZATION_ID"
),

--Get the existing data if this is an incremental run
existing_data AS (
    {% if is_incremental() %}
        SELECT *
        FROM {{ this }}
    {% else %}
        --In a full refresh, we don't need existing data
        SELECT NULL AS organization_id, 0 AS shift_created_count, 0 AS employee_invited_count, 0 AS punch_in_count,
               0 AS punch_in_entry_approved_count, 0 AS viewed_count, 0 AS revenue_viewed_count,
               0 AS integrations_viewed_count, 0 AS absence_viewed_count, 0 AS availability_viewed_count,
               TIMESTAMP '0001-01-01 00:00:01.000' AS max_timestamp
        WHERE 1 = 0
    {% endif %}
)

-- Combine existing data with new data
SELECT
    COALESCE(new_data.organization_id, existing_data.organization_id) AS organization_id,
    COALESCE(existing_data.shift_created_count, 0) + COALESCE(new_data.shift_created_count, 0) AS shift_created_count,
    COALESCE(existing_data.employee_invited_count, 0) + COALESCE(new_data.employee_invited_count, 0) AS employee_invited_count,
    COALESCE(existing_data.punch_in_count, 0) + COALESCE(new_data.punch_in_count, 0) AS punch_in_count,
    COALESCE(existing_data.punch_in_entry_approved_count, 0) + COALESCE(new_data.punch_in_entry_approved_count, 0) AS punch_in_entry_approved_count,
    COALESCE(existing_data.viewed_count, 0) + COALESCE(new_data.viewed_count, 0) AS viewed_count,
    COALESCE(existing_data.revenue_viewed_count, 0) + COALESCE(new_data.revenue_viewed_count, 0) AS revenue_viewed_count,
    COALESCE(existing_data.integrations_viewed_count, 0) + COALESCE(new_data.integrations_viewed_count, 0) AS integrations_viewed_count,
    COALESCE(existing_data.absence_viewed_count, 0) + COALESCE(new_data.absence_viewed_count, 0) AS absence_viewed_count,
    COALESCE(existing_data.availability_viewed_count, 0) + COALESCE(new_data.availability_viewed_count, 0) AS availability_viewed_count,
    GREATEST(new_data.max_timestamp, existing_data.max_timestamp) AS max_timestamp
FROM new_data
LEFT JOIN existing_data
    ON new_data.organization_id = existing_data.organization_id
