-- EXPORT 2: Hospital summary  →  save as hospital_summary.csv
-- One row per hospital (3+ measured conditions). Feeds the hospital lookup table,
-- the ownership chart, and filters.
WITH hospital_avg AS (
  SELECT
    facility_id,
    ANY_VALUE(facility_name)     AS facility_name,
    ANY_VALUE(state)             AS state,
    COUNT(excess_ratio)          AS conditions_measured,
    COUNTIF(excess_ratio > 1)    AS conditions_worse,
    AVG(excess_ratio)            AS avg_ratio
  FROM cms_hospitals.v_hrrp_clean
  GROUP BY facility_id
  HAVING COUNT(excess_ratio) >= 3
),
er_times AS (
  SELECT facility_id, SAFE_CAST(score AS INT64) AS er_minutes
  FROM cms_hospitals.timely_care
  WHERE measure_id = 'OP_18b' AND SAFE_CAST(score AS INT64) IS NOT NULL
),
enriched AS (
  SELECT
    a.*,
    h.city,
    h.hospital_type,
    h.star_rating,
    CASE
      WHEN h.hospital_ownership IS NULL                              THEN 'Unknown'
      WHEN STARTS_WITH(h.hospital_ownership, 'Government')           THEN 'Government'
      WHEN STARTS_WITH(h.hospital_ownership, 'Voluntary non-profit') THEN 'Non-profit'
      WHEN h.hospital_ownership IN ('Proprietary', 'Physician')      THEN 'For-profit'
      ELSE 'Other'
    END                                          AS ownership_group,
    e.er_minutes,
    AVG(a.avg_ratio) OVER (PARTITION BY a.state) AS state_avg,
    NTILE(4) OVER (ORDER BY a.avg_ratio)         AS quartile
  FROM hospital_avg AS a
  LEFT JOIN cms_hospitals.v_hospital_clean AS h ON a.facility_id = h.facility_id
  LEFT JOIN er_times AS e                       ON a.facility_id = e.facility_id
)
SELECT
  facility_id,
  facility_name,
  city,
  state,
  hospital_type,
  ownership_group,
  star_rating,
  er_minutes,
  conditions_measured,
  conditions_worse,
  ROUND(avg_ratio, 4)              AS avg_ratio,
  ROUND(state_avg, 4)              AS state_avg,
  ROUND(avg_ratio - state_avg, 4)  AS diff_from_state,
  CASE
    WHEN avg_ratio - state_avg >=  0.05 THEN 'Much worse than state'
    WHEN avg_ratio - state_avg >   0    THEN 'Slightly worse than state'
    WHEN avg_ratio - state_avg <= -0.05 THEN 'Much better than state'
    ELSE 'Slightly better than state'
  END                              AS vs_state,
  CASE quartile
    WHEN 1 THEN '1 - Best 25%'
    WHEN 2 THEN '2 - Better-middle 25%'
    WHEN 3 THEN '3 - Worse-middle 25%'
    WHEN 4 THEN '4 - Worst 25%'
  END                              AS performance_group
FROM enriched
ORDER BY state, facility_name;
