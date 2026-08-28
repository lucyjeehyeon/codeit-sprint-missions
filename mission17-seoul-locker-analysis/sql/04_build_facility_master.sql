-- ============================================================
-- STEP 10. 시설 Master 테이블 생성
-- ============================================================
-- 테이블:
--   int_locker_facility_master
--
-- Grain:
--   시설(Entity) 1개 = 1행
--
-- 목적:
-- 1. 현재 위치 데이터와 과거 실적 데이터를 하나의 시설 Master로 통합
-- 2. 현재 위치 여부 / 실적 존재 여부를 동시에 보존
-- 3. 운영·철거 상태 충돌을 삭제하지 않고 품질 플래그로 관리
-- 4. 향후 이용실적 / 수요 데이터 JOIN의 기준 테이블로 활용
--
-- 중요:
-- 현재 위치 데이터 수집일 : 2026-08-26
-- 실적 데이터 snapshot    : 2026-06-30
--
-- 두 원천의 기준시점이 다르므로
-- 상태가 불일치해도 임의로 한쪽을 오류 처리하지 않음.
-- ============================================================


CREATE OR REPLACE TABLE
`mission17-locker-jh-2608.analytics_seoul_locker.int_locker_facility_master`
AS


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

        -- JOIN 전용 정규화 주소
        REGEXP_REPLACE(
            LOWER(TRIM(COALESCE(address, ''))),
            r'[^가-힣a-z0-9]',
            ''
        ) AS address_key

    FROM
        `mission17-locker-jh-2608.analytics_seoul_locker.stg_locker_locations`
),


-- ============================================================
-- 2. 실적 데이터를 시설당 1행으로 축약
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
            LOWER(TRIM(COALESCE(ANY_VALUE(address), ''))),
            r'[^가-힣a-z0-9]',
            ''
        ) AS address_key

    FROM
        `mission17-locker-jh-2608.analytics_seoul_locker.stg_locker_metrics_long`

    GROUP BY
        locker_stat_id
),


-- ============================================================
-- 3. 현재 위치 + 실적 Full Outer Join
-- ============================================================
-- 주소 정규화키 + 자치구 기준
--
-- 지금까지 검증:
-- 현재 위치 232개
-- 228개 1:1 매칭
-- 중복 매칭 0개
-- ============================================================

joined AS (

    SELECT

        -- ----------------------------------------------------
        -- Entity ID
        -- ----------------------------------------------------
        -- 실적 ID가 있으면 이를 우선 사용.
        -- 실적이 없는 현재 위치 시설은 위치 ID 사용.
        -- ----------------------------------------------------

        COALESCE(
            m.locker_stat_id,
            l.locker_id
        ) AS facility_entity_id,


        -- 원천 ID 보존
        l.locker_id,
        m.locker_stat_id,


        -- ----------------------------------------------------
        -- 기본 시설 정보
        -- ----------------------------------------------------

        COALESCE(
            l.district,
            m.district
        ) AS district,

        COALESCE(
            l.locker_name,
            m.facility_name
        ) AS facility_name,

        l.locker_name AS current_location_name,
        m.facility_name AS metrics_facility_name,

        l.address AS current_location_address,
        m.address AS metrics_address,

        COALESCE(
            l.address,
            m.address
        ) AS representative_address,

        l.full_address,

        l.latitude,
        l.longitude,


        -- ----------------------------------------------------
        -- 현재 위치 데이터 관련
        -- ----------------------------------------------------

        l.locker_id IS NOT NULL
            AS is_in_current_location_source,

        l.collection_date AS location_collection_date,

        l.quality_status AS location_quality_status,

        l.district_source,
        l.address_source,


        -- ----------------------------------------------------
        -- 실적 데이터 관련
        -- ----------------------------------------------------

        m.locker_stat_id IS NOT NULL
            AS has_metrics_history,

        m.operation_status AS metrics_operation_status,

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


        -- ----------------------------------------------------
        -- 연결 상태
        -- ----------------------------------------------------

        CASE

            WHEN l.locker_id IS NOT NULL
                 AND m.locker_stat_id IS NOT NULL
                THEN 'matched'

            WHEN l.locker_id IS NOT NULL
                 AND m.locker_stat_id IS NULL
                THEN 'location_only'

            WHEN l.locker_id IS NULL
                 AND m.locker_stat_id IS NOT NULL
                THEN 'metrics_only'

            ELSE 'unknown'

        END AS source_match_status,


        -- ----------------------------------------------------
        -- 상태 충돌
        -- ----------------------------------------------------
        -- 최신 위치 목록에는 존재하지만
        -- 실적 snapshot에서는 철거로 기록된 경우
        -- ----------------------------------------------------

        CASE

            WHEN l.locker_id IS NOT NULL
                 AND m.operation_status = '철거'
                THEN TRUE

            ELSE FALSE

        END AS current_vs_metrics_status_conflict,


        -- ----------------------------------------------------
        -- 분석용 시설 상태
        -- ----------------------------------------------------
        -- "실제 정답"을 강제로 지정하는 컬럼이 아님.
        -- 분석 시 어떤 모집단으로 사용할지 구분하기 위한
        -- 진단용 분류 변수.
        -- ----------------------------------------------------

        CASE

            -- 최신 위치 데이터에 존재하고
            -- 실적도 운영으로 기록
            WHEN l.locker_id IS NOT NULL
                 AND m.operation_status = '운영'
                THEN 'current_matched_operating'


            -- 최신 위치에는 존재하지만 실적에서는 철거
            WHEN l.locker_id IS NOT NULL
                 AND m.operation_status = '철거'
                THEN 'current_status_conflict'


            -- 최신 위치 데이터에만 존재
            WHEN l.locker_id IS NOT NULL
                 AND m.locker_stat_id IS NULL
                THEN 'current_location_only'


            -- 실적에서는 운영 중이지만
            -- 최신 위치 데이터에는 없음
            WHEN l.locker_id IS NULL
                 AND m.operation_status = '운영'
                THEN 'metrics_operating_not_current'


            -- 과거 철거 시설
            WHEN l.locker_id IS NULL
                 AND m.operation_status = '철거'
                THEN 'historical_removed'


            ELSE 'other'

        END AS facility_analysis_status,


        -- ----------------------------------------------------
        -- 사용 가능 지표 플래그
        -- ----------------------------------------------------

        COALESCE(
            m.usage_period_count,
            0
        ) > 0 AS has_usage_data,

        COALESCE(
            m.occupancy_period_count,
            0
        ) > 0 AS has_occupancy_data,


        -- ----------------------------------------------------
        -- 현재 공급 분석 대상 플래그
        -- ----------------------------------------------------
        -- 현재 위치 데이터에 있는 시설을
        -- 현재 공급 분포 분석의 모집단으로 사용.
        --
        -- 단, status conflict는 별도 플래그로 반드시 보존.
        -- ----------------------------------------------------

        l.locker_id IS NOT NULL
            AS include_current_supply_analysis,


        -- ----------------------------------------------------
        -- 과거 이용실적 분석 대상
        -- ----------------------------------------------------

        m.locker_stat_id IS NOT NULL
        AND COALESCE(m.usage_period_count, 0) > 0
            AS include_usage_history_analysis


    FROM location_base l

    FULL OUTER JOIN metrics_facility m

        ON l.district = m.district
        AND l.address_key = m.address_key
        AND l.address_key != ''
)


SELECT
    *

FROM joined;

-- ============================================================
-- STEP 10 QA
-- Facility Master 품질검사
-- ============================================================


-- Entity ID 중복 방지
ASSERT (

    SELECT
        COUNT(*) = COUNT(DISTINCT facility_entity_id)

    FROM
        `mission17-locker-jh-2608.analytics_seoul_locker.int_locker_facility_master`

) AS 'Facility Master의 Entity ID가 중복되었습니다.';


-- 현재 위치 시설 수 보존
ASSERT (

    SELECT
        COUNTIF(is_in_current_location_source) = 232

    FROM
        `mission17-locker-jh-2608.analytics_seoul_locker.int_locker_facility_master`

) AS '현재 위치 시설 수가 232개와 일치하지 않습니다.';


-- 실적 시설 수 보존
ASSERT (

    SELECT
        COUNTIF(has_metrics_history) = 276

    FROM
        `mission17-locker-jh-2608.analytics_seoul_locker.int_locker_facility_master`

) AS '실적 시설 수가 276개와 일치하지 않습니다.';


-- ============================================================
-- 생성 결과 요약
-- ============================================================

SELECT
    facility_analysis_status,
    COUNT(*) AS facility_count

FROM
    `mission17-locker-jh-2608.analytics_seoul_locker.int_locker_facility_master`

GROUP BY
    facility_analysis_status

ORDER BY
    facility_count DESC;