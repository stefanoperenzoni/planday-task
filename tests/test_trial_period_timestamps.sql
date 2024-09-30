-- Test to assert the the max_timestamp in the trial_period model is never smaller than min_timestamp
select
   organization_id,
   trial_timedelta
from {{ ref('trial_period')}}
where max_timestamp < min_timestamp