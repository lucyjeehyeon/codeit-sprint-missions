-- ============================================================
-- dbt Staging Model
-- stg_locker_locations
-- ============================================================
-- 목적:
--   BigQuery에 이미 적재된 안심택배함 위치 원천 데이터를
--   dbt source()를 통해 읽고 분석 계층에 노출
--
-- Materialization:
--   VIEW
--
-- Grain:
--   locker_id 1개 = 1행
-- ============================================================


SELECT
    locker_id,
    district,
    locker_name,
    address,
    full_address,
    latitude,
    longitude,
    collection_date,
    district_source,
    address_source,
    quality_status

FROM
    {{ source('locker_source', 'stg_locker_locations') }}