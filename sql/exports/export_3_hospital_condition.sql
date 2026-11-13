-- EXPORT 3: Hospital x condition detail  →  save as hospital_condition.csv
-- One row per hospital per condition (only rows with a ratio).
-- Feeds the condition filter and condition-level charts.
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
