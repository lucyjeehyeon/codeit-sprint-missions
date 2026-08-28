-- ============================================================
-- Dashboard Mart
-- mart_district_dashboard
-- ============================================================
--
-- Grain:
--   서울시 자치구 1개 = 1행
--
-- 목적:
--   기존 최종 의사결정 Mart에
--   자치구 POLYGON / 중심 POINT를 결합해
--   Looker Studio Google Maps에서 사용
-- ============================================================

SELECT

    f.*,

    b.district_code,

    b.district_geom,

    b.centroid_latitude,

    b.centroid_longitude,

    b.district_centroid

FROM {{ ref('mart_district_final') }} AS f

LEFT JOIN {{ ref('stg_district_boundary') }} AS b
    USING (district)