-- ============================================================
-- Singular Test
-- mart_district_demand_supply 핵심 정합성
-- ============================================================

WITH summary AS (

    SELECT
        COUNT(*) AS row_count,
        COUNT(DISTINCT district) AS district_count,
        SUM(current_facility_count) AS current_facility_total

    FROM {{ ref('mart_district_demand_supply') }}

)

SELECT *
FROM summary

WHERE
       row_count != 25
    OR district_count != 25
    OR current_facility_total != 232