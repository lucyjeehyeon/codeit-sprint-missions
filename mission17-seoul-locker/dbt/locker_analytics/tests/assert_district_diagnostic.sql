-- ============================================================
-- mart_district_diagnostic QA
-- ============================================================

WITH qa AS (

    SELECT

        COUNT(*) AS row_count,

        COUNT(DISTINCT district)
            AS district_count,

        COUNTIF(
            diagnostic_group_code IS NULL
        ) AS missing_group_count,

        COUNTIF(
            usage_coverage_pct < 80
            AND diagnostic_group_code != 'DATA_CHECK'
        ) AS low_coverage_misclassified_count

    FROM {{ ref('mart_district_diagnostic') }}

)

SELECT *
FROM qa

WHERE
       row_count != 25
    OR district_count != 25
    OR missing_group_count != 0
    OR low_coverage_misclassified_count != 0