-- ============================================================
-- 서울 자치구 경계 QA
-- 정상일 경우 0행 반환
-- ============================================================

WITH qa AS (

    SELECT

        COUNT(*) AS row_count,

        COUNT(DISTINCT district)
            AS district_count,

        COUNTIF(district_geom IS NULL)
            AS missing_geometry_count,

        COUNTIF(district_centroid IS NULL)
            AS missing_centroid_count

    FROM {{ ref('stg_district_boundary') }}

)

SELECT *

FROM qa

WHERE
       row_count != 25
    OR district_count != 25
    OR missing_geometry_count != 0
    OR missing_centroid_count != 0