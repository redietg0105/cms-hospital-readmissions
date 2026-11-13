-- Query 5: Window functions — rank states from best to worst
-- Question: Which states have the best and worst readmission performance?
-- Method: average each hospital first (so a hospital with 6 conditions doesn't count
--         6 times), then average hospitals within each state, then rank the states.
-- Skills: chained CTEs, RANK(), DENSE_RANK(), ROW_NUMBER(), OVER (ORDER BY ...)

WITH hospital_avg AS (
  -- Step 1: one average ratio per hospital
  SELECT
    facility_id,
    state,
    AVG(excess_ratio) AS avg_ratio
  FROM cms_hospitals.v_hrrp_clean
  GROUP BY facility_id, state
),
state_avg AS (
  -- Step 2: one average per state (each hospital counts once)
  SELECT
    state,
    COUNT(avg_ratio)            AS hospitals,
    ROUND(AVG(avg_ratio), 3)    AS state_avg_ratio
  FROM hospital_avg
  GROUP BY state
)
-- Step 3: rank the states (1 = best = lowest ratio)
SELECT
  state,
  hospitals,
  state_avg_ratio,
  RANK()       OVER (ORDER BY state_avg_ratio) AS rank_with_gaps,
  DENSE_RANK() OVER (ORDER BY state_avg_ratio) AS dense_rank_no_gaps,
  ROW_NUMBER() OVER (ORDER BY state_avg_ratio) AS row_num
FROM state_avg
WHERE hospitals >= 5          -- ignore states with too few hospitals to judge
ORDER BY rank_with_gaps;
