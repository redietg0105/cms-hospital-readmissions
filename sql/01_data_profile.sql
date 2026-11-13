-- Query 1: Data profiling
-- Question: How complete is the readmissions data for each condition?
-- Skills: GROUP BY, COUNT DISTINCT, COUNTIF, SAFE_CAST

SELECT
  measure_name,
  COUNT(*)                                                         AS total_rows,
  COUNT(DISTINCT facility_id)                                      AS hospitals,
  COUNTIF(SAFE_CAST(excess_readmission_ratio AS FLOAT64) IS NOT NULL) AS hospitals_with_ratio,
  ROUND(100 * COUNTIF(SAFE_CAST(excess_readmission_ratio AS FLOAT64) IS NULL) / COUNT(*), 1)
                                                                   AS pct_missing
FROM cms_hospitals.hrrp
GROUP BY measure_name
ORDER BY pct_missing;
