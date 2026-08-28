-- ============================================================
-- Staging Model
-- stg_district_boundary
-- ============================================================
--
-- 서울시 25개 자치구 경계
-- WKT STRING → BigQuery GEOGRAPHY 변환
--
-- 일부 복잡한 행정경계에서 발생할 수 있는
-- polygon self-intersection을 make_valid로 보정
-- ============================================================

SELECT

    CAST(district_code AS STRING) AS district_code,

    district,

    ST_GEOGFROMTEXT(
        geometry_wkt,
        make_valid => TRUE
    ) AS district_geom,

    centroid_latitude,

    centroid_longitude,

    ST_GEOGPOINT(
        centroid_longitude,
        centroid_latitude
    ) AS district_centroid

FROM {{ source('boundary_source', 'district_boundary') }}