-- Query 3: JOIN readmissions with hospital details
-- Question: Which hospitals have the worst heart-failure readmission ratios,
--           and what kind of hospital are they (city, type, star rating)?
-- Skills: LEFT JOIN, table aliases, WHERE, LIMIT

SELECT
  r.facility_name,
  h.city,
  r.state,
  h.hospital_type,
  h.star_rating,
  r.excess_ratio
FROM cms_hospitals.v_hrrp_clean AS r
LEFT JOIN cms_hospitals.v_hospital_clean AS h
  ON r.facility_id = h.facility_id
WHERE r.condition = 'Heart failure'
  AND r.excess_ratio IS NOT NULL
ORDER BY r.excess_ratio DESC
LIMIT 20;

-- Query 3b: Which readmission hospitals are missing from the hospital info file?
-- (Shows why LEFT JOIN matters: an INNER JOIN would silently drop these.)
SELECT DISTINCT
  r.facility_id,
  r.facility_name,
  r.state
FROM cms_hospitals.v_hrrp_clean AS r
LEFT JOIN cms_hospitals.v_hospital_clean AS h
  ON r.facility_id = h.facility_id
WHERE h.facility_id IS NULL
ORDER BY r.state;
