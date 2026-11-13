-- Query 4: CTE — hospitals worse than expected on 3+ conditions
-- Question: Which hospitals have more readmissions than expected on at least
--           3 of the 6 conditions? (A broad, repeated problem — not a one-off.)
-- Skills: WITH (CTE), GROUP BY on several columns, COUNTIF, multi-key ORDER BY

WITH hospital_scores AS (
  -- Step 1: turn 6 rows per hospital into 1 summary row per hospital
  SELECT
    facility_id,
    facility_name,
    state,
    COUNT(excess_ratio)          AS conditions_measured,
    COUNTIF(excess_ratio > 1)    AS conditions_worse,
    ROUND(AVG(excess_ratio), 4)  AS avg_excess_ratio
  FROM cms_hospitals.v_hrrp_clean
  GROUP BY facility_id, facility_name, state
)
-- Step 2: keep only hospitals worse than expected on 3 or more conditions
SELECT *
FROM hospital_scores
WHERE conditions_worse >= 3
ORDER BY conditions_worse DESC, avg_excess_ratio DESC;

-- Query 4b: How common is this? Summary using two CTEs chained together
WITH hospital_scores AS (
  SELECT
    facility_id,
    COUNT(excess_ratio)        AS conditions_measured,
    COUNTIF(excess_ratio > 1)  AS conditions_worse
  FROM cms_hospitals.v_hrrp_clean
  GROUP BY facility_id
),
eligible AS (
  -- only hospitals with enough data to judge (3+ conditions measured)
  SELECT * FROM hospital_scores WHERE conditions_measured >= 3
)
SELECT
  COUNT(*)                                              AS hospitals_with_3plus_measures,
  COUNTIF(conditions_worse >= 3)                        AS worse_on_3plus,
  ROUND(100 * COUNTIF(conditions_worse >= 3) / COUNT(*), 1) AS pct_worse_on_3plus
FROM eligible;
