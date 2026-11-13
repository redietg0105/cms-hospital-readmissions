-- Check: the cleaned view should show real numbers and readable condition names
SELECT
  condition,
  COUNT(*)                     AS hospitals,
  COUNTIF(excess_ratio IS NULL) AS missing_ratio,
  ROUND(AVG(excess_ratio), 4)  AS avg_excess_ratio
FROM cms_hospitals.v_hrrp_clean
GROUP BY condition
ORDER BY avg_excess_ratio DESC;
