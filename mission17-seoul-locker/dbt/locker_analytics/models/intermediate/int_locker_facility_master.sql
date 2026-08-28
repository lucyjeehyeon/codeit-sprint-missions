-- ============================================================
-- Intermediate Model
-- int_locker_facility_master
-- ============================================================
-- Grain:
--   통합 시설 Entity 1개 = 1행
--
-- 목적:
--   현재 위치 데이터와 과거 실적 데이터를
--   자치구 + 정규화 주소 기준으로 연결하여
--   하나의 시설 Master 구성
--
-- Materialization:
--   TABLE
-- ============================================================


WITH

-- ============================================================
-- 1. 현재 위치 데이터
-- ============================================================

location_base AS (

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
        quality_status,

        REGEXP_REPLACE(
            LOWER(TRIM(COALESCE(address, ''))),
            r'[^가-힣a-z0-9]',
            ''
        ) AS address_key

    FROM {{ ref('stg_locker_locations') }}

),


-- ============================================================
-- 2. 실적 데이터를 시설 1행으로 축약
-- ============================================================

metrics_facility AS (

    SELECT
        locker_stat_id,

        ANY_VALUE(district) AS district,
        ANY_VALUE(facility_name) AS facility_name,
        ANY_VALUE(address) AS address,
        ANY_VALUE(operation_status) AS operation_status,

        MIN(installed_year) AS installed_year,
        MAX(removed_year) AS removed_year,
        MAX(locker_count) AS locker_count,

        MAX(snapshot_date) AS metrics_snapshot_date,

        COUNT(*) AS metric_period_count,

        COUNTIF(
            usage_count IS NOT NULL
        ) AS usage_period_count,

        COUNTIF(
            occupancy_rate IS NOT NULL
        ) AS occupancy_period_count,

        LOGICAL_OR(
            installed_year_conflict
        ) AS installed_year_conflict,

        COUNTIF(
            data_quality_status != 'ok'
        ) > 0 AS has_metrics_quality_issue,

        REGEXP_REPLACE(
            LOWER(
                TRIM(
                    COALESCE(
                        ANY_VALUE(address),
                        ''
                    )
                )
            ),
            r'[^가-힣a-z0-9]',
            ''
        ) AS address_key

    FROM {{ ref('stg_locker_metrics_long') }}

    GROUP BY
        locker_stat_id

),


-- ============================================================
-- 3. 두 원천 통합
-- ============================================================

joined AS (

    SELECT

        -- 통합 Entity ID
        COALESCE(
            m.locker_stat_id,
            l.locker_id
        ) AS facility_entity_id,


        -- 원천 ID
        l.locker_id,
        m.locker_stat_id,


        -- 기본 시설 정보
        COALESCE(
            l.district,
            m.district
        ) AS district,

        COALESCE(
            l.locker_name,
            m.facility_name
        ) AS facility_name,

        l.locker_name
            AS current_location_name,

        m.facility_name
            AS metrics_facility_name,

        l.address
            AS current_location_address,

        m.address
            AS metrics_address,

        COALESCE(
            l.address,
            m.address
        ) AS representative_address,

        l.full_address,
        l.latitude,
        l.longitude,


        -- ====================================================
        -- 현재 위치 원천
        -- ====================================================

        l.locker_id IS NOT NULL
            AS is_in_current_location_source,

        l.collection_date
            AS location_collection_date,

        l.quality_status
            AS location_quality_status,

        l.district_source,
        l.address_source,


        -- ====================================================
        -- 실적 원천
        -- ====================================================

        m.locker_stat_id IS NOT NULL
            AS has_metrics_history,

        m.operation_status
            AS metrics_operation_status,

        m.installed_year,
        m.removed_year,
        m.locker_count,

        m.metrics_snapshot_date,
        m.metric_period_count,
        m.usage_period_count,
        m.occupancy_period_count,

        COALESCE(
            m.installed_year_conflict,
            FALSE
        ) AS installed_year_conflict,

        COALESCE(
            m.has_metrics_quality_issue,
            FALSE
        ) AS has_metrics_quality_issue,


        -- ====================================================
        -- 원천 연결 상태
        -- ====================================================

        CASE

            WHEN
                l.locker_id IS NOT NULL
                AND m.locker_stat_id IS NOT NULL
                THEN 'matched'

            WHEN
                l.locker_id IS NOT NULL
                AND m.locker_stat_id IS NULL
                THEN 'location_only'

            WHEN
                l.locker_id IS NULL
                AND m.locker_stat_id IS NOT NULL
                THEN 'metrics_only'

            ELSE 'unknown'

        END AS source_match_status,


        -- ====================================================
        -- 상태 충돌
        -- ====================================================

        CASE

            WHEN
                l.locker_id IS NOT NULL
                AND m.operation_status = '철거'
                THEN TRUE

            ELSE FALSE

        END AS current_vs_metrics_status_conflict,


        -- ====================================================
        -- 분석용 시설 상태
        -- ====================================================

        CASE

            WHEN
                l.locker_id IS NOT NULL
                AND m.operation_status = '운영'
                THEN 'current_matched_operating'

            WHEN
                l.locker_id IS NOT NULL
                AND m.operation_status = '철거'
                THEN 'current_status_conflict'

            WHEN
                l.locker_id IS NOT NULL
                AND m.locker_stat_id IS NULL
                THEN 'current_location_only'

            WHEN
                l.locker_id IS NULL
                AND m.operation_status = '운영'
                THEN 'metrics_operating_not_current'

            WHEN
                l.locker_id IS NULL
                AND m.operation_status = '철거'
                THEN 'historical_removed'

            ELSE 'other'

        END AS facility_analysis_status,


        -- ====================================================
        -- 지표 사용가능 여부
        -- ====================================================

        COALESCE(
            m.usage_period_count,
            0
        ) > 0 AS has_usage_data,

        COALESCE(
            m.occupancy_period_count,
            0
        ) > 0 AS has_occupancy_data,


        -- 현재 공급 분석 대상
        l.locker_id IS NOT NULL
            AS include_current_supply_analysis,


        -- 이용이력 분석 대상
        m.locker_stat_id IS NOT NULL
        AND COALESCE(
            m.usage_period_count,
            0
        ) > 0
            AS include_usage_history_analysis


    FROM location_base l

    FULL OUTER JOIN metrics_facility m

        ON l.district = m.district

        AND l.address_key = m.address_key

        AND l.address_key != ''

)


SELECT *
FROM joined