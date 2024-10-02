# planday-task

This repository contains my submission for the "Trial Activation - Analytics Engineering Task"
for the Analytics Engineer role at Planday. 

In this README I go through my proposal. Explaining the choiches I made and reporting on the extracted insights.

## Setup

I created a local dbt project which I run on a Postgre DB.

I chose Postgre because of simplicity since it was faster for me to set it up.
Alternatively, the Snowflake docker image developed by localstack could be used: https://hub.docker.com/r/localstack/snowflake
```bash
# start local postgre
docker-compose up -d

# install dependencies
poetry install
```

Add your data `analytics_engineering_task.csv` into `/data`.
I created a Python script to load that data into the local PostgreDB.
Alternatively we can use dbt seed.

Run
```bash
python initdata.py
```

Finally, run the dbt project:

```bash
# run dbt project
dbt run
```

## Initial Exploratory Analysis

I started with quickly analysing the data through a Python notebook.

I looked at the data to understand its format and, if necessary, make some assumptions.

Besides general statistics such as the distribution of the ACITIVITIES or the TIMESTAMP range, I was interested in understanding the data source.

Looking at this specific ORGANIZATION 3f14a47847fb42bbc7dc119e7e1ef588 (which is Trial Activated), made me realise that the tracking of the source data does not stop once the organization activate. 
I assumed it goes on for the whole trial period.

This finding is quite important otherwise we could have erroneously assumed that the moment an organization activated is the TIMESTAMP of its last activity (if it fulfilled all the goals).

## Model and Architecture Structure

Given the structure of the data, the layers I initially tried to focus on are:
- Staging
- Intermediate
- Marts

### Staging Layers

Despite initially thinking about it, eventually I did not create any staging layer because the data looked already clean enough.

Optionally, a staging model could have been used for:
- Renaming the values in `ACTIVITY_NAME` and `ACTIVITY_DETAIL` for improved readibility
- Fill the missing values in `ACTIVITY_DETAIL` (If necessary for some particular use)
- Normalise the `TIMESTAMP` or give it a different format
- Normalise columns' names format (I've done that in the intermediate model)

In this case, I did not apply any of those transformations as I did not consider them necessary for our use cases at this stage.

### Intermediate Layers

I used two intermediate models where I started structure the data to fit them better to the business logic we wanted to apply later on the marts.
I built `interactions_pivot` and `trial_period` models.

#### Interactions Pivot
As suggested by the name, this model pivot the source interactions data into a wider format.

It aggregates the source rows by `ORGANIZATION_ID` and counts the number of occurrences of each `ACTION_NAME` and `ACTIVITY_DETAIL`.
Since the number of columns was small, I did the pivoting "manually" because I thought it would make the queries logic more understandable.
Alternatively, we can se [dbt_utis.pivot](https://github.com/dbt-labs/dbt-utils/blob/main/macros/sql/pivot.sql).

I decided to use **incremental** materialization for this model. The reason is that I expect the main source interactions to be added regularly and therefore this materialization would make it more efficient.

I set up the incremental logic on the `TIMESTAMP` column and made sure to combine new data with the previous one properly.

A drawback of this pivoting strategy is that we totally lose control over the `TIMESTAMP` of each activity.
By grouping all of them together like this, it won't impossible to later know when a particular activity was performed and therefore extract info such as activation time.

To partially solve this, I created a second intermediate model to better handle the organization's activities TIMESTAMP.
#### Trial Period

This model also aggregates the source interactions at an organization level. For each organization, it stores the earliest and latest TIMESTAMPs as well as the timedelta between them.

I decided to do this in a different model to separate the time logic from the activities counting one mostly for a better modularity and maintainability.

Obviously, this model does not totally solve the loss-of-visibility problem we got by aggregating on ORGANIZATION_ID. 
I will later explain how, through an additional model and logic, we could keep the visibility of info such as activation date.

Similarly, this is also materialized as incremental for the same reason explained earlier.



NB: BOTH INCREMENTAL LAYEWRS COULD HAVE MADE EASIER AND MORE UNDERSTANDABLE BY USING A BETTER INCREMENTAL_STRATEGY. The reason why I did not is because I was not totally proficient with that yet so i preferred pushing a working solution I was confortable with.
However, I took the opportunity to experiment with merging strategy in the branch [feature/incremental_strategy](https://github.com/stefanoperenzoni/planday-task/tree/feature/incremental_strategy) where I applied it for the trial_period model

### Marts Layers

As requested, I provided two marts sources: Trial Goals and Trial Activation.

#### Trial Goals

This model tracks whether an organization has completed each of the trial goals:
- At least 2 Shift created
- At least 1 Employee invited
- At least 1 Punch-In
- At least 1 Punch-In entry approved
- At least 2 advanced features viewed (Revenue, Integrations, Absence or Availability)

This is buitd mainly on top of the previous `interactions_pivot` model.
It simply transforms the data to boolean flag that indicates whether that specific goal was completed.

This model contains most of the logic for the task.

Besides that, I also joined it on the `trial_period` model to add the `TIMESTAMP` info to the new table.

I decided to denormalize this  table to make it more usable to the end user without the necessity of further joins.
Because of its small number of columns, I think it's reasonable to keep it as a wider table.

Alternatively, if the `trial_period` model would get wider and with more info about the timeline of the organization (such as activation date, date of start trial, end trial, etc...), that could be handled as a data mart and kept as a separate table for later joins. 

The model was materialized as `table` because, contrarily to the previous models, here the logic is simpler (Just 5 integer checks) and the size of the source table is smaller (The data is already aggregated on `ORGANIZATION_ID`).

#### Trial Goals

This model tracks which organizations have fully completed all trial goals,
thereby achieving "Trial Activation."

This is built on top of the `trial_goals` mart. Doing this, I separate the logic for goal tracking from the logic for activation and keep it modular.
This approach follows the concept of separation of concerns. I think it makes the models and the queries more understandable

The logic of the model is very simple, it just checks that all the trial goals are met.

In order to have a more completed and informative table, I also joined the timeline info from the `trial_period` model on this mart.

This model's materialization is `table` becasue of similar reasons to those for the model above.

#### Trial Timeline [PROPOSAL - NOT Implemented]

Earlier, when talking about the `trial_period` model. I introduced the opportunity for a mart that tracks the trial timeline of each organization.
The idea is to have a mart that tracks the trial duration for each organization, when they had their first activities and the date they became trial activated, if they did.

The most complicated part of the logic here, would be tracking the exact timestamp when an organisation fulfilled the last missing trial goal and became trial activated.

We can shift the problem at the lower level and try to track the timestamp each organization met each of the trial goal. The latest would indicate the trial activation time for each organization.

We can do that by looking seperately at each activity type. For each organization we retrieve the first (oldest) N occurences of each activity. Where N is the number of activities a company should perform according to the trial goal.
For each (organization, goal) pair, if there are less than N occurrences, the goal was not completed. Otherwise, we can take the max timestamp from those N entries as our goal_fulfillment timestamp.

This logic would have complicated the models presented for this task. My goal was to keep it simple while performing what asked. Because of that, I decided not to implement it but I wanted to share here my reasoning.

I think having a mart like this would be particularly important as it allows us to unlock new insights about the timing of both trial activated and non-trial activated organization.
It would allow us to answer questions such as: "What are the goals that gets met the earliest" and "How long does it take for organizations to activate after their first activity?".

## Marts Exploratory Analysis

I've run some basic descriptive analyses in the Jupyter Notebook in `/notebooks/marts_exploratory_analysis.ipynb` or `/notebooks/marts_exploratory_analysis.html`.

The analysis processed the following:

Input data:
- trial_activation Mart
- trial_goals Mart

Output insights:
- Trial Activation rate
- Goal Completion rate
- Missing goal for closest-to-activate
- Average time from first to last activity in trial period
- Activation rate per month of starting

38 organisations out of 931 activated: 4.08%. 50 completed 4 goals and 51 completed 3.
Shift create was the most frequent completed goal. It was completed by about 56% of organisations.
The approval of punch in was the least completed; with ha rate of 8.4%

The average span of time from first to last activity over the trial period was about 5.31 days.
Besides April 2024, with an extremely small sample, the activation rates for organisations starting in different months is similar. There's a small dip for February.
The reason might be the small number of trial_activated companies for each month (therefore a small sample) and the fact that February had a higher number of organisations that performed their first activity in that month.

More insights and plots can be found in the aforementioned notebook


## Testing and Data Quality

Regarding testing, I would leverage the multiple tools dbt offer for testing.

First of, a simple but effective way to ensure data quality is by using and enforcing constraints.
I have not done it here in this task but we can easily add constraints such as primary_key or other checks.
Ensuring contract for our models with specific constaints would definitely be the first step I'd take to ensure data quality.

Moreover, we can leverage dbt testing:

#### Generic Data Testing

Besides those already provided by dbt, which can all be used in our models, we can define some more tests to check the values in the models we built.

For example, we can define a generic `test_not_negative_count` test that checks that the goal counts are indeed not negative.

#### Singular Data Testing

I also defined a singular test `test_trial_period_timestamps` to check that `max_timestmap` is never smaller than `min_timestmap`

#### Unit Testing

The tests above (and other generic tests that I did not add) are good to ensure data quality and check that the general format of the output data is what we expected.

However, they don't really test the logic of the data transformations in details.

To do that, we can use [dbt unit test](https://docs.getdbt.com/docs/build/unit-tests), a recent feature added in recent dbt Core versions.

This feature does not support all kind of models but it's already good to unit test logic in many models.

For example, in our case we can use it to test the `interaction_pivot` model and make sure that the counts are correct.

Using unit tests, we can define our own mock data and test edge cases on static data.

I tried defining a unit test for the `interactions_pivot` model in `/models/unittests/test_trial_goals.yml`

In addition to that, we could add two more unit tests for the `trial_goals` and `trial_activation` models.
As said, since these unit tests work on seed static data, they allow us to test edge cases of the models' logic

A little fun fact about that: if you try `dbt test` you'll notice that the unittest fail with the error `column "ORGANIZATION_ID" does not exist`.
After debugging for quite some time, I realised that unittests fixtures lower all the column names. So `ORGANIZATION_ID` became `organization_id`.
Very particular behaviour that I did not expect. Perhaps solvable playing with the column quoting values?

## Possible Improvements

The possible improvements of this dbt project lie in two categories.

#### Timeline model

As explained before, I think it would be important having a view over the timeline of the organizations.

#### Better Testing

Testing is never enough. Here I added some different types of tests. However, we could add more generic testing as well as more unit testing for the two marts' logic.
Also, I'd add more constraints and enforce them on the models.
