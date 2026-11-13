-- Query 8: Compare hospital ownership types
-- Question: Do for-profit, non-profit, and government hospitals differ in readmissions?
-- Skills: CASE with STARTS_WITH to group categories, LEFT JOIN, GROUP BY + HAVING,
--         percentages with COUNTIF

WITH hospital_scores AS (
  -- Step 1: one row per hospital with enough data (3+ conditions)
  SELECT
    facility_id,
    AVG(excess_ratio)          AS avg_ratio,
    COUNTIF(excess_ratio > 1)  AS conditions_worse
  FROM cms_hospitals.v_hrrp_clean
  GROUP BY facility_id
  HAVING COUNT(excess_ratio) >= 3
),
with_ownership AS (
  -- Step 2: attach ownership + star rating, and collapse 12 ownership labels into 3 groups
  SELECT
    s.*,
    h.star_rating,
    CASE
      WHEN h.hospital_ownership IS NULL                          THEN 'Unknown'
      WHEN STARTS_WITH(h.hospital_ownership, 'Government')       THEN 'Government'
      WHEN STARTS_WITH(h.hospital_ownership, 'Voluntary non-profit') THEN 'Non-profit'
      WHEN h.hospital_ownership IN ('Proprietary', 'Physician')  THEN 'For-profit'
      ELSE 'Other'
    END AS ownership_group
  FROM hospital_scores AS s
  LEFT JOIN cms_hospitals.v_hospital_clean AS h
    ON s.facility_id = h.facility_id
)
-- Step 3: compare the groups
SELECT
  ownership_group,
  COUNT(*)                                                AS hospitals,
  ROUND(AVG(avg_ratio), 4)                                AS avg_excess_ratio,
  ROUND(100 * COUNTIF(avg_ratio > 1) / COUNT(*), 1)       AS pct_worse_than_expected,
  ROUND(100 * COUNTIF(conditions_worse >= 3) / COUNT(*), 1) AS pct_worse_on_3plus,
  ROUND(AVG(star_rating), 2)                              AS avg_star_rating
FROM with_ownership
GROUP BY ownership_group
HAVING COUNT(*) >= 30          -- drop groups too small to compare fairly
ORDER BY avg_excess_ratio;
