-- =====================================================================
-- CMS Hospital Readmissions Analysis (FY 2026)
-- Author: Rediet Gelaw
-- Platform: Google BigQuery (GoogleSQL)
--
-- Raw tables loaded from CMS public data into dataset `cms_hospitals`:
--   hrrp           Hospital Readmissions Reduction Program (FY 2026)
--   hospital_info  Hospital General Information (ownership, star rating)
--   timely_care    Timely and Effective Care (ER wait times, measure OP_18b)
--
-- Rule used throughout: a hospital is included only if it has an
-- excess readmission ratio for 3 or more of the 6 HRRP conditions
-- (2,392 hospitals).
-- =====================================================================


-- =====================================================================
-- STEP 1: CLEANING VIEWS
-- =====================================================================

-- View: v_hrrp_clean
-- One row per hospital per condition. Converts text fields to numbers
-- and dates, and replaces CMS measure codes with readable names.
CREATE OR REPLACE VIEW cms_hospitals.v_hrrp_clean AS
SELECT
  facility_id,
  INITCAP(facility_name) AS facility_name,
  state,
  CASE measure_name
    WHEN 'READM-30-AMI-HRRP'      THEN 'Heart attack'
    WHEN 'READM-30-HF-HRRP'       THEN 'Heart failure'
    WHEN 'READM-30-PN-HRRP'       THEN 'Pneumonia'
    WHEN 'READM-30-COPD-HRRP'     THEN 'COPD'
    WHEN 'READM-30-HIP-KNEE-HRRP' THEN 'Hip/knee replacement'
    WHEN 'READM-30-CABG-HRRP'     THEN 'Bypass surgery (CABG)'
  END                                              AS condition,
  SAFE_CAST(number_of_discharges       AS INT64)   AS discharges,
  SAFE_CAST(excess_readmission_ratio   AS FLOAT64) AS excess_ratio,
  SAFE_CAST(predicted_readmission_rate AS FLOAT64) AS predicted_rate_pct,
  SAFE_CAST(expected_readmission_rate  AS FLOAT64) AS expected_rate_pct,
  SAFE_CAST(number_of_readmissions     AS INT64)   AS readmissions,
  SAFE.PARSE_DATE('%m/%d/%Y', start_date)          AS period_start,
  SAFE.PARSE_DATE('%m/%d/%Y', end_date)            AS period_end
FROM cms_hospitals.hrrp;


-- View: v_hospital_clean
-- One row per hospital with location, type, ownership and CMS star rating.
CREATE OR REPLACE VIEW cms_hospitals.v_hospital_clean AS
SELECT
  facility_id,
  INITCAP(facility_name)                      AS facility_name,
  INITCAP(city_town)                          AS city,
  state,
  zip_code,
  hospital_type,
  hospital_ownership,
  emergency_services = 'Yes'                  AS has_er,
  SAFE_CAST(hospital_overall_rating AS INT64) AS star_rating
FROM cms_hospitals.hospital_info;


-- =====================================================================
-- STEP 2: EXPORTS FOR TABLEAU
-- =====================================================================

-- EXPORT 1: State summary  ->  state_summary.csv
-- One row per state (hospitals with 3+ measured conditions).
-- Feeds the US map and the state ranking chart.
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


-- EXPORT 2: Hospital summary  ->  hospital_summary.csv
-- One row per hospital (3+ measured conditions). Feeds the hospital
-- lookup table, the ownership chart, and filters.
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
  -- OP_18b: median time patients spent in the ER (minutes)
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


-- EXPORT 3: Hospital x condition detail  ->  hospital_condition.csv
-- One row per hospital per condition (only rows with a ratio).
-- Supports condition-level drill-downs.
SELECT
  r.facility_id,
  r.facility_name,
  h.city,
  r.state,
  r.condition,
  r.excess_ratio,
  r.predicted_rate_pct,
  r.expected_rate_pct,
  r.discharges,
  r.readmissions
FROM cms_hospitals.v_hrrp_clean AS r
LEFT JOIN cms_hospitals.v_hospital_clean AS h
  ON r.facility_id = h.facility_id
WHERE r.excess_ratio IS NOT NULL
ORDER BY r.state, r.facility_name, r.condition;


-- =====================================================================
-- STEP 3: ANALYSIS QUERIES (one per key finding)
-- =====================================================================

-- A1: What share of hospitals are worse than expected on 3+ conditions?
WITH hospital_avg AS (
  SELECT
    facility_id,
    COUNTIF(excess_ratio > 1) AS conditions_worse
  FROM cms_hospitals.v_hrrp_clean
  GROUP BY facility_id
  HAVING COUNT(excess_ratio) >= 3
)
SELECT
  COUNT(*)                                                 AS hospitals,
  ROUND(100 * COUNTIF(conditions_worse >= 3) / COUNT(*), 1) AS pct_worse_on_3_plus
FROM hospital_avg;


-- A2: Does ownership type relate to readmission performance?
WITH hospital_avg AS (
  SELECT facility_id, AVG(excess_ratio) AS avg_ratio
  FROM cms_hospitals.v_hrrp_clean
  GROUP BY facility_id
  HAVING COUNT(excess_ratio) >= 3
),
grouped AS (
  SELECT
    a.avg_ratio,
    CASE
      WHEN STARTS_WITH(h.hospital_ownership, 'Government')           THEN 'Government'
      WHEN STARTS_WITH(h.hospital_ownership, 'Voluntary non-profit') THEN 'Non-profit'
      WHEN h.hospital_ownership IN ('Proprietary', 'Physician')      THEN 'For-profit'
    END AS ownership_group
  FROM hospital_avg AS a
  LEFT JOIN cms_hospitals.v_hospital_clean AS h ON a.facility_id = h.facility_id
)
SELECT
  ownership_group,
  COUNT(*)                                           AS hospitals,
  ROUND(100 * COUNTIF(avg_ratio > 1) / COUNT(*), 1)  AS pct_worse_than_expected
FROM grouped
WHERE ownership_group IS NOT NULL   -- excludes unclassified ownership
GROUP BY ownership_group
ORDER BY pct_worse_than_expected DESC;


-- A3: Do CMS star ratings track readmission performance?
WITH hospital_avg AS (
  SELECT facility_id, AVG(excess_ratio) AS avg_ratio
  FROM cms_hospitals.v_hrrp_clean
  GROUP BY facility_id
  HAVING COUNT(excess_ratio) >= 3
),
ranked AS (
  SELECT
    a.facility_id,
    h.star_rating,
    NTILE(4) OVER (ORDER BY a.avg_ratio) AS quartile   -- 1 = best readmissions
  FROM hospital_avg AS a
  LEFT JOIN cms_hospitals.v_hospital_clean AS h ON a.facility_id = h.facility_id
)
SELECT
  quartile,
  COUNT(star_rating)          AS hospitals_with_rating,
  ROUND(AVG(star_rating), 1)  AS avg_star_rating
FROM ranked
GROUP BY quartile
ORDER BY quartile;


-- A4: Are longer ER wait times related to higher readmissions?
WITH hospital_avg AS (
  SELECT facility_id, AVG(excess_ratio) AS avg_ratio
  FROM cms_hospitals.v_hrrp_clean
  GROUP BY facility_id
  HAVING COUNT(excess_ratio) >= 3
),
er_times AS (
  SELECT facility_id, SAFE_CAST(score AS INT64) AS er_minutes
  FROM cms_hospitals.timely_care
  WHERE measure_id = 'OP_18b' AND SAFE_CAST(score AS INT64) IS NOT NULL
)
SELECT
  COUNT(*)                                 AS hospitals_with_er_data,
  ROUND(CORR(e.er_minutes, a.avg_ratio), 3) AS correlation
FROM hospital_avg AS a
JOIN er_times AS e ON a.facility_id = e.facility_id;
