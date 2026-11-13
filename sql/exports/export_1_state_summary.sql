-- EXPORT 1: State summary  →  save as state_summary.csv
-- One row per state (hospitals with 3+ measured conditions). Feeds the US map and the state ranking chart.
WITH hospital_avg AS (
  SELECT
    facility_id,
    state,
    AVG(excess_ratio) AS avg_ratio
  FROM cms_hospitals.v_hrrp_clean
  GROUP BY facility_id, state
  HAVING COUNT(excess_ratio) >= 3
),
state_avg AS (
  SELECT
    state,
    COUNT(*)                                           AS hospitals,
    ROUND(AVG(avg_ratio), 3)                           AS state_avg_ratio,
    ROUND(100 * COUNTIF(avg_ratio > 1) / COUNT(*), 1)  AS pct_hospitals_worse
  FROM hospital_avg
  GROUP BY state
)
SELECT
  *,
  RANK() OVER (ORDER BY state_avg_ratio) AS state_rank   -- 1 = best
FROM state_avg
ORDER BY state_rank;
