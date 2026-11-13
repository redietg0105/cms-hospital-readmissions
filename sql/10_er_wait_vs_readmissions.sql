-- Query 10: Do hospitals with longer ER visits also have worse readmissions?
-- Data: OP_18b = median minutes patients spend in the ER from arrival to departure
--       (excluding psychiatric and transfer patients). Lower is better.
-- Skills: joining three sources, INNER JOIN (on purpose), NTILE on a second measure,
--         CORR() for correlation

WITH er_times AS (
  -- Source 1: median ER time per hospital
  SELECT
    facility_id,
    SAFE_CAST(score AS INT64) AS er_minutes
  FROM cms_hospitals.timely_care
  WHERE measure_id = 'OP_18b'
    AND SAFE_CAST(score AS INT64) IS NOT NULL
),
hospital_avg AS (
  -- Source 2: average readmission ratio per hospital (3+ conditions)
  SELECT
    facility_id,
    AVG(excess_ratio)          AS avg_ratio
  FROM cms_hospitals.v_hrrp_clean
  GROUP BY facility_id
  HAVING COUNT(excess_ratio) >= 3
),
combined AS (
  -- Join all three: readmissions + ER times + star ratings
  SELECT
    a.facility_id,
    a.avg_ratio,
    e.er_minutes,
    h.star_rating,
    NTILE(4) OVER (ORDER BY e.er_minutes) AS er_quartile
  FROM hospital_avg AS a
  INNER JOIN er_times AS e
    ON a.facility_id = e.facility_id          -- need BOTH measures to compare
  LEFT JOIN cms_hospitals.v_hospital_clean AS h
    ON a.facility_id = h.facility_id
)
SELECT
  er_quartile,
  CASE er_quartile
    WHEN 1 THEN 'Fastest 25% of ERs'
    WHEN 2 THEN 'Fast-middle 25%'
    WHEN 3 THEN 'Slow-middle 25%'
    WHEN 4 THEN 'Slowest 25% of ERs'
  END                                                AS er_speed_group,
  COUNT(*)                                           AS hospitals,
  MIN(er_minutes)                                    AS min_er_minutes,
  MAX(er_minutes)                                    AS max_er_minutes,
  ROUND(AVG(er_minutes), 0)                          AS avg_er_minutes,
  ROUND(AVG(avg_ratio), 4)                           AS avg_excess_ratio,
  ROUND(100 * COUNTIF(avg_ratio > 1) / COUNT(*), 1)  AS pct_worse_than_expected,
  ROUND(AVG(star_rating), 2)                         AS avg_star_rating
FROM combined
GROUP BY er_quartile
ORDER BY er_quartile;

-- Query 10b: One-number summary — correlation between ER time and readmission ratio
-- CORR returns -1 to +1:  +1 = move together perfectly, 0 = no linear relationship
WITH er_times AS (
  SELECT facility_id, SAFE_CAST(score AS INT64) AS er_minutes
  FROM cms_hospitals.timely_care
  WHERE measure_id = 'OP_18b' AND SAFE_CAST(score AS INT64) IS NOT NULL
),
hospital_avg AS (
  SELECT facility_id, AVG(excess_ratio) AS avg_ratio
  FROM cms_hospitals.v_hrrp_clean
  GROUP BY facility_id
  HAVING COUNT(excess_ratio) >= 3
)
SELECT
  COUNT(*)                                      AS hospitals_compared,
  ROUND(CORR(e.er_minutes, a.avg_ratio), 3)     AS correlation
FROM hospital_avg AS a
INNER JOIN er_times AS e
  ON a.facility_id = e.facility_id;
