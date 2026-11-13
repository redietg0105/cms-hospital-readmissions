-- Query 7: NTILE — split hospitals into 4 equal performance groups (quartiles)
-- Question: If we sort hospitals from best to worst and cut them into 4 equal groups,
--           how different are the groups — and do star ratings differ between them?
-- Skills: NTILE(), CASE labels, LEFT JOIN inside a CTE, MIN/MAX/AVG per group

WITH hospital_avg AS (
  -- Step 1: one row per hospital, with enough data to judge
  SELECT
    facility_id,
    AVG(excess_ratio)   AS avg_ratio
  FROM cms_hospitals.v_hrrp_clean
  GROUP BY facility_id
  HAVING COUNT(excess_ratio) >= 3
),
quartiles AS (
  -- Step 2: assign each hospital to a quartile (1 = best 25%, 4 = worst 25%)
  SELECT
    a.facility_id,
    a.avg_ratio,
    h.star_rating,
    NTILE(4) OVER (ORDER BY a.avg_ratio) AS quartile
  FROM hospital_avg AS a
  LEFT JOIN cms_hospitals.v_hospital_clean AS h
    ON a.facility_id = h.facility_id
)
-- Step 3: describe each quartile
SELECT
  quartile,
  CASE quartile
    WHEN 1 THEN 'Best 25%'
    WHEN 2 THEN 'Better-middle 25%'
    WHEN 3 THEN 'Worse-middle 25%'
    WHEN 4 THEN 'Worst 25%'
  END                           AS performance_group,
  COUNT(*)                      AS hospitals,
  ROUND(MIN(avg_ratio), 4)      AS lowest_ratio,
  ROUND(MAX(avg_ratio), 4)      AS highest_ratio,
  ROUND(AVG(avg_ratio), 4)      AS avg_ratio,
  ROUND(AVG(star_rating), 2)    AS avg_star_rating
FROM quartiles
GROUP BY quartile
ORDER BY quartile;
