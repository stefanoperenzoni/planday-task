{{
    config(
        materialized='incremental',
        unique_key = 'organization_id',
        cluster_by = ["organization_id"],
        incremental_strategy = 'merge'
    )
}}

WITH new_interactions AS (
    SELECT *
    FROM {{ source('planday', 'interactions') }}
    {% if is_incremental() %}
    WHERE "TIMESTAMP" > (SELECT MAX("max_timestamp") FROM {{ this }})
    {% endif %}
),

{% if is_incremental() %}
existing_data AS (
    SELECT *
    FROM {{ this }}
),
{% endif %}

new_pivoted AS (
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
    FROM new_interactions
    GROUP BY "ORGANIZATION_ID"
)

{% if is_incremental() %}
SELECT
    COALESCE(new.organization_id, existing.organization_id) AS organization_id,
    COALESCE(existing.shift_created_count, 0) + COALESCE(new.shift_created_count, 0) AS shift_created_count,
    COALESCE(existing.employee_invited_count, 0) + COALESCE(new.employee_invited_count, 0) AS employee_invited_count,
    COALESCE(existing.punch_in_count, 0) + COALESCE(new.punch_in_count, 0) AS punch_in_count,
    COALESCE(existing.punch_in_entry_approved_count, 0) + COALESCE(new.punch_in_entry_approved_count, 0) AS punch_in_entry_approved_count,
    COALESCE(existing.viewed_count, 0) + COALESCE(new.viewed_count, 0) AS viewed_count,
    COALESCE(existing.revenue_viewed_count, 0) + COALESCE(new.revenue_viewed_count, 0) AS revenue_viewed_count,
    COALESCE(existing.integrations_viewed_count, 0) + COALESCE(new.integrations_viewed_count, 0) AS integrations_viewed_count,
    COALESCE(existing.absence_viewed_count, 0) + COALESCE(new.absence_viewed_count, 0) AS absence_viewed_count,
    COALESCE(existing.availability_viewed_count, 0) + COALESCE(new.availability_viewed_count, 0) AS availability_viewed_count,
    GREATEST(COALESCE(existing.max_timestamp, '1900-01-01'::timestamp), COALESCE(new.max_timestamp, '1900-01-01'::timestamp)) AS max_timestamp
FROM new_pivoted new
LEFT JOIN existing_data existing
    ON new.organization_id = existing.organization_id
{% else %}
SELECT
    *
FROM new_pivoted new
{% endif %}
