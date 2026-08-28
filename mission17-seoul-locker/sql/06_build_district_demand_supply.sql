-- ============================================================
-- STEP 12. 자치구별 수요 × 공급 × 이용 통합 Mart
-- ============================================================
-- 테이블:
--   mart_district_demand_supply
--
-- Grain:
--   서울 자치구 1개 = 1행 (총 25행)
--
-- 분석 기준:
--   현재 공급 : 2026-08-26 위치 데이터
--   최근 이용 : 2026 H1
--   잠재 수요 : 2025년 1인가구
--
-- 핵심 목적:
--   1. 자치구별 현재 안심택배함 공급 수준 측정
--   2. 1인가구 규모 대비 공급 수준 측정
--   3. 최근 실제 이용 강도 측정
--   4. 향후 증설/유지/활성화/재검토 진단의 기반 생성
-- ============================================================


CREATE OR REPLACE TABLE
`mission17-locker-jh-2608.analytics_seoul_locker.mart_district_demand_supply`
AS


WITH

-- ============================================================
-- 1. 최신 1인가구 수요
-- ============================================================
-- 이미 자치구 1개 = 1행이므로 그대로 사용
-- ============================================================

households AS (

    SELECT
        district,

        reference_year AS household_reference_year,

        one_person_total,
        one_person_under_20,
        one_person_age_20_39,
        one_person_age_40_64,
        one_person_age_65_plus,

        age_20_39_share_pct,
        age_65_plus_share_pct

    FROM
        `mission17-locker-jh-2608.analytics_seoul_locker.stg_households_district`

),


-- ============================================================
-- 2. 현재 공급
-- ============================================================
-- 기준:
--   2026-08-26 현재 위치 데이터에 실제 등장하는 232개 시설
--
-- 실적 데이터와 상태가 충돌하더라도
-- 최신 위치 목록에 존재하면 현재 공급 수에는 포함.
--
-- 대신 conflict 수를 별도 컬럼으로 보존.
-- ============================================================

current_supply AS (

    SELECT
        district,

        COUNTIF(
            include_current_supply_analysis
        ) AS current_facility_count,


        -- 함 개수가 알려진 현재 시설 수
        COUNTIF(
            include_current_supply_analysis
            AND locker_count IS NOT NULL
        ) AS facilities_with_locker_count,


        -- 함 개수가 확인 가능한 시설의 총 보관함 수
        SUM(
            CASE
                WHEN include_current_supply_analysis
                    THEN locker_count
            END
        ) AS known_locker_count,


        -- 최신 위치에만 있고 과거 실적에는 없는 시설
        COUNTIF(
            include_current_supply_analysis
            AND source_match_status = 'location_only'
        ) AS location_only_facility_count,


        -- 최신 위치에는 존재하지만
        -- 실적 원천에서는 철거 상태인 시설
        COUNTIF(
            include_current_supply_analysis
            AND current_vs_metrics_status_conflict = TRUE
        ) AS status_conflict_facility_count,


        -- 위치 데이터에서 주소가 보정된 시설
        COUNTIF(
            include_current_supply_analysis
            AND location_quality_status = 'corrected'
        ) AS corrected_location_count

    FROM
        `mission17-locker-jh-2608.analytics_seoul_locker.int_locker_facility_master`

    GROUP BY
        district

),


-- ============================================================
-- 3. 최신 이용실적: 2026 H1
-- ============================================================
-- 현재 위치 목록에 존재하는 시설만 대상으로 제한.
--
-- 2026년은 반년치이므로 usage_count 총량 대신
-- calculated_monthly_avg_usage를 핵심 비교지표로 사용.
-- ============================================================

latest_usage AS (

    SELECT
        district,

        '2026_h1' AS usage_period,


        -- 현재 공급시설 중 실적 테이블과 연결된 시설
        COUNT(*) AS facilities_with_2026h1_metric_row,


        -- 실제 이용건수가 관측된 현재시설
        COUNTIF(
            has_usage_observation
        ) AS facilities_with_usage,


        -- 이용건수 관측 커버리지 계산에 사용
        COUNTIF(
            has_occupancy_observation
        ) AS facilities_with_occupancy,


        -- H1 실제 총 이용건수
        SUM(
            usage_count
        ) AS total_usage_2026_h1,


        -- 자치구 전체의 월평균 이용량
        -- 시설별 월평균을 합산
        SUM(
            calculated_monthly_avg_usage
        ) AS district_monthly_usage,


        -- 관측시설 1개당 월평균 이용량
        AVG(
            calculated_monthly_avg_usage
        ) AS avg_monthly_usage_per_observed_facility,


        -- 이용건수가 있는 시설의 총 함 수
        SUM(
            CASE
                WHEN has_usage_observation
                    THEN locker_count
            END
        ) AS locker_count_with_usage_observation,


        -- 함 규모를 보정한 자치구 이용 효율
        SAFE_DIVIDE(
            SUM(calculated_monthly_avg_usage),
            SUM(
                CASE
                    WHEN has_usage_observation
                        THEN locker_count
                END
            )
        ) AS weighted_monthly_usage_per_locker,


        -- 점유율은 일부 25개 시설만 존재하므로 보조지표
        AVG(
            occupancy_rate_pct
        ) AS avg_observed_occupancy_rate_pct


    FROM
        `mission17-locker-jh-2608.analytics_seoul_locker.int_locker_period_metrics`

    WHERE
        period = '2026_h1'

        AND is_in_current_location_source = TRUE

    GROUP BY
        district

),


-- ============================================================
-- 4. 세 데이터셋을 모두 자치구 Grain에서 결합
-- ============================================================

combined AS (

    SELECT

        -- ----------------------------------------------------
        -- 기본 정보
        -- ----------------------------------------------------

        h.district,

        h.household_reference_year,

        DATE '2026-08-26'
            AS supply_reference_date,

        COALESCE(
            u.usage_period,
            '2026_h1'
        ) AS usage_period,


        -- ----------------------------------------------------
        -- 수요
        -- ----------------------------------------------------

        h.one_person_total,

        h.one_person_under_20,
        h.one_person_age_20_39,
        h.one_person_age_40_64,
        h.one_person_age_65_plus,

        h.age_20_39_share_pct,
        h.age_65_plus_share_pct,


        -- ----------------------------------------------------
        -- 현재 공급
        -- ----------------------------------------------------

        COALESCE(
            s.current_facility_count,
            0
        ) AS current_facility_count,

        COALESCE(
            s.facilities_with_locker_count,
            0
        ) AS facilities_with_locker_count,

        COALESCE(
            s.known_locker_count,
            0
        ) AS known_locker_count,

        COALESCE(
            s.location_only_facility_count,
            0
        ) AS location_only_facility_count,

        COALESCE(
            s.status_conflict_facility_count,
            0
        ) AS status_conflict_facility_count,

        COALESCE(
            s.corrected_location_count,
            0
        ) AS corrected_location_count,


        -- ----------------------------------------------------
        -- 최신 이용
        -- ----------------------------------------------------

        COALESCE(
            u.facilities_with_2026h1_metric_row,
            0
        ) AS facilities_with_2026h1_metric_row,

        COALESCE(
            u.facilities_with_usage,
            0
        ) AS facilities_with_usage,

        COALESCE(
            u.facilities_with_occupancy,
            0
        ) AS facilities_with_occupancy,

        COALESCE(
            u.total_usage_2026_h1,
            0
        ) AS total_usage_2026_h1,

        COALESCE(
            u.district_monthly_usage,
            0
        ) AS district_monthly_usage,

        u.avg_monthly_usage_per_observed_facility,

        u.weighted_monthly_usage_per_locker,

        u.avg_observed_occupancy_rate_pct,


        -- ====================================================
        -- 5. 수요 대비 공급 지표
        -- ====================================================

        SAFE_MULTIPLY(
            SAFE_DIVIDE(
                COALESCE(s.current_facility_count, 0),
                h.one_person_total
            ),
            10000
        ) AS facilities_per_10k_one_person_households,


        SAFE_MULTIPLY(
            SAFE_DIVIDE(
                COALESCE(s.known_locker_count, 0),
                h.one_person_total
            ),
            10000
        ) AS locker_slots_per_10k_one_person_households,


        SAFE_DIVIDE(
            h.one_person_total,
            NULLIF(
                COALESCE(s.current_facility_count, 0),
                0
            )
        ) AS one_person_households_per_facility,


        -- ====================================================
        -- 6. 수요 대비 실제 이용 지표
        -- ====================================================

        SAFE_MULTIPLY(
            SAFE_DIVIDE(
                COALESCE(u.district_monthly_usage, 0),
                h.one_person_total
            ),
            10000
        ) AS monthly_usage_per_10k_one_person_households,


        -- ====================================================
        -- 7. 이용 데이터 커버리지
        -- ====================================================

        SAFE_MULTIPLY(
            SAFE_DIVIDE(
                COALESCE(u.facilities_with_usage, 0),
                COALESCE(s.current_facility_count, 0)
            ),
            100
        ) AS usage_coverage_pct,


        SAFE_MULTIPLY(
            SAFE_DIVIDE(
                COALESCE(u.facilities_with_occupancy, 0),
                COALESCE(s.current_facility_count, 0)
            ),
            100
        ) AS occupancy_coverage_pct,


        SAFE_MULTIPLY(
            SAFE_DIVIDE(
                COALESCE(s.facilities_with_locker_count, 0),
                COALESCE(s.current_facility_count, 0)
            ),
            100
        ) AS locker_count_coverage_pct


    FROM households h

    LEFT JOIN current_supply s
        USING (district)

    LEFT JOIN latest_usage u
        USING (district)

)


SELECT
    *

FROM combined;

-- ============================================================
-- STEP 12 QA
-- ============================================================


-- 1. 서울 25개 자치구 보존
ASSERT (

    SELECT COUNT(*) = 25

    FROM
        `mission17-locker-jh-2608.analytics_seoul_locker.mart_district_demand_supply`

) AS '자치구 Mart가 25행이 아닙니다.';


-- 2. 자치구 중복 방지
ASSERT (

    SELECT
        COUNT(*) = COUNT(DISTINCT district)

    FROM
        `mission17-locker-jh-2608.analytics_seoul_locker.mart_district_demand_supply`

) AS '자치구가 중복되었습니다.';


-- 3. 현재 위치 232개가 자치구 집계 후에도 보존되는지 확인
ASSERT (

    SELECT
        SUM(current_facility_count) = 232

    FROM
        `mission17-locker-jh-2608.analytics_seoul_locker.mart_district_demand_supply`

) AS '현재 공급시설 총합이 232개와 일치하지 않습니다.';


-- 4. 1인가구 수요 결측 방지
ASSERT (

    SELECT
        COUNTIF(one_person_total IS NULL) = 0

    FROM
        `mission17-locker-jh-2608.analytics_seoul_locker.mart_district_demand_supply`

) AS '1인가구 데이터가 없는 자치구가 있습니다.';



-- ============================================================
-- 결과 확인
-- ============================================================

SELECT
    district,

    one_person_total,

    current_facility_count,

    known_locker_count,

    facilities_with_usage,

    ROUND(
        usage_coverage_pct,
        1
    ) AS usage_coverage_pct,

    ROUND(
        facilities_per_10k_one_person_households,
        2
    ) AS facilities_per_10k_households,

    ROUND(
        one_person_households_per_facility,
        0
    ) AS households_per_facility,

    ROUND(
        district_monthly_usage,
        1
    ) AS monthly_usage,

    ROUND(
        weighted_monthly_usage_per_locker,
        2
    ) AS monthly_usage_per_locker,

    ROUND(
        monthly_usage_per_10k_one_person_households,
        1
    ) AS monthly_usage_per_10k_households,

    ROUND(
        age_20_39_share_pct,
        1
    ) AS age_20_39_share_pct,

    status_conflict_facility_count

FROM
    `mission17-locker-jh-2608.analytics_seoul_locker.mart_district_demand_supply`

ORDER BY
    one_person_households_per_facility DESC;