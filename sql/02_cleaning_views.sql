-- Query 2: Cleaning views
-- Converts text columns to real numbers/dates, gives conditions readable names.
-- CMS uses 'N/A' and 'Too Few to Report' inside number columns;
-- SAFE_CAST turns those into NULL instead of failing.
-- Skills: CREATE VIEW, SAFE_CAST, CASE, SAFE.PARSE_DATE

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
  END                                                  AS condition,
  SAFE_CAST(number_of_discharges       AS INT64)       AS discharges,
  SAFE_CAST(excess_readmission_ratio   AS FLOAT64)     AS excess_ratio,
  SAFE_CAST(predicted_readmission_rate AS FLOAT64)     AS predicted_rate_pct,
  SAFE_CAST(expected_readmission_rate  AS FLOAT64)     AS expected_rate_pct,
  SAFE_CAST(number_of_readmissions     AS INT64)       AS readmissions,
  SAFE.PARSE_DATE('%m/%d/%Y', start_date)              AS period_start,
  SAFE.PARSE_DATE('%m/%d/%Y', end_date)                AS period_end
FROM cms_hospitals.hrrp;

CREATE OR REPLACE VIEW cms_hospitals.v_hospital_clean AS
SELECT
  facility_id,
  INITCAP(facility_name)                       AS facility_name,
  INITCAP(city_town)                           AS city,
  state,
  zip_code,
  hospital_type,
  hospital_ownership,
  emergency_services = 'Yes'                   AS has_er,
  SAFE_CAST(hospital_overall_rating AS INT64)  AS star_rating
FROM cms_hospitals.hospital_info;
