-- ============================================================
-- Balanced Panel Mart QA
-- ============================================================

WITH overall AS (

    SELECT
        COUNT(*) AS period_count,

        COUNTIF(
            balanced_facility_count != 202
        ) AS wrong_facility_count

    FROM {{ ref('mart_balanced_panel_trend') }}
),


district AS (

    SELECT
        COUNT(*) AS district_count,

        COUNT(DISTINCT district)
            AS unique_district_count,

        SUM(balanced_facility_count)
            AS balanced_facility_total

    FROM {{ ref('mart_district_trend') }}
)


SELECT
    'overall_panel_error' AS issue

FROM overall

WHERE
       period_count != 6
    OR wrong_facility_count != 0


UNION ALL


SELECT
    'district_panel_error' AS issue

FROM district

WHERE
       district_count != 25
    OR unique_district_count != 25
    OR balanced_facility_total != 202