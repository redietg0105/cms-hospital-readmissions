-- Query 9: Compare each hospital with its own state's average
-- Question: Which hospitals are furthest above (worse than) their state's average?
--           Comparing to local peers is fairer than comparing to the whole country.
-- Skills: AVG() OVER (PARTITION BY ...), AVG() OVER () for a national average,
--         COUNT() OVER, calculated difference columns, CASE flags

WITH hospital_avg AS (
  SELECT
    facility_id,
    facility_name,
    state,
    AVG(excess_ratio) AS avg_ratio
  FROM cms_hospitals.v_hrrp_clean
  GROUP BY facility_id, facility_name, state
  HAVING COUNT(excess_ratio) >= 3
),
compared AS (
  SELECT
    *,
    AVG(avg_ratio) OVER (PARTITION BY state) AS state_avg,
    AVG(avg_ratio) OVER ()                   AS national_avg,
    COUNT(*)       OVER (PARTITION BY state) AS hospitals_in_state
  FROM hospital_avg
)
SELECT
  facility_name,
  state,
  hospitals_in_state,
  ROUND(avg_ratio, 4)                AS hospital_ratio,
  ROUND(state_avg, 4)                AS state_avg,
  ROUND(national_avg, 4)             AS national_avg,
  ROUND(avg_ratio - state_avg, 4)    AS diff_from_state,
  CASE
    WHEN avg_ratio - state_avg >=  0.05 THEN 'Much worse than state'
    WHEN avg_ratio - state_avg >   0    THEN 'Slightly worse than state'
    WHEN avg_ratio - state_avg <= -0.05 THEN 'Much better than state'
    ELSE 'Slightly better than state'
  END                                AS vs_state
FROM compared
ORDER BY diff_from_state DESC;
