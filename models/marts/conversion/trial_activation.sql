SELECT
    organization_id,
    CASE
        WHEN shift_created_goal = TRUE
            AND employee_invited_goal = TRUE
            AND punch_in_goal = TRUE
            AND punch_in_approved_goal = TRUE
            AND advanced_viewed_goal = TRUE
        THEN TRUE
        ELSE FALSE
    END AS is_trial_activated,
    max_timestamp,
    min_timestamp,
    trial_timedelta
FROM {{ ref('trial_goals') }}
