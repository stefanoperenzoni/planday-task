SELECT
    p.*,
    CASE WHEN shift_created_count > 2 THEN true else false END AS shift_created_goal,
    CASE WHEN employee_invited_count > 1 THEN true else false END AS employee_invited_goal,
    CASE WHEN punch_in_count > 1 THEN true else false END AS punch_in_goal,
    CASE WHEN punch_in_entry_approved_count > 1 THEN true else false END AS punch_in_approved_goal,
    CASE WHEN viewed_count > 2 THEN true else false END AS advanced_viewed_goal
FROM {{ ref('interactions_pivot') }} i
JOIN {{ ref('trial_period') }} p
ON i.organization_id = p.organization_id

