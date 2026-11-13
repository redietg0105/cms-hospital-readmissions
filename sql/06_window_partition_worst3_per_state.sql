-- Query 6: Window functions with PARTITION BY — worst 3 hospitals in every state
-- Question: Within each state, which 3 hospitals have the highest average
--           excess readmission ratio? (Only hospitals with 3+ measured conditions.)
-- Skills: ROW_NUMBER() OVER (PARTITION BY ... ORDER BY ...), filtering on a window
--         result via a CTE ("top N per group" pattern)

WITH hospital_avg AS (
  -- Step 1: one row per hospital
  SELECT
    facility_id,
    facility_name,
    state,
    COUNT(excess_ratio)          AS conditions_measured,
    ROUND(AVG(excess_ratio), 4)  AS avg_ratio
  FROM cms_hospitals.v_hrrp_clean
  GROUP BY facility_id, facility_name, state
),
ranked AS (
  -- Step 2: number hospitals within each state, worst first
  SELECT
    *,
    ROW_NUMBER() OVER (
      PARTITION BY state
      ORDER BY avg_ratio DESC
    ) AS rank_in_state
  FROM hospital_avg
  WHERE conditions_measured >= 3     -- enough data to judge fairly
)
-- Step 3: keep the top 3 per state
SELECT
  state,
  rank_in_state,
  facility_name,
  conditions_measured,
  avg_ratio
FROM ranked
WHERE rank_in_state <= 3
ORDER BY state, rank_in_state;
