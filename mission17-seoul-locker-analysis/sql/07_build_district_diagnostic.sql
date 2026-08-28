-- ============================================================
-- STEP 13. 자치구별 공급압력 × 실제활용 진단 Mart
-- ============================================================
-- 테이블:
--   mart_district_diagnostic
--
-- Grain:
--   자치구 1개 = 1행
--
-- 핵심 개념
--
-- [공급 압력]
--   one_person_households_per_facility
--   → 시설 1개가 담당하는 1인가구 수
--   → 높을수록 상대적 공급 부족 신호
--
-- [실제 활용 강도]
--   weighted_monthly_usage_per_locker
--   → 함 개수와 관측기간을 보정한 실제 이용
--   → 높을수록 시설 활용도가 높은 신호
--
-- 주의
--   이것은 정책 결정의 "정답"이 아니라
--   자치구 간 상대 비교를 위한 진단 프레임임.
--
--   이용 데이터 커버리지가 80% 미만인 자치구는
--   전략 그룹에 강제로 배정하지 않고
--   '데이터 확인 필요'로 별도 관리함.
-- ============================================================


CREATE OR REPLACE TABLE
`mission17-locker-jh-2608.analytics_seoul_locker.mart_district_diagnostic`
AS


WITH

-- ============================================================
-- 1. 기존 수요·공급·이용 Mart
-- ============================================================

base AS (

    SELECT
        *

    FROM
        `mission17-locker-jh-2608.analytics_seoul_locker.mart_district_demand_supply`
),


-- ============================================================
-- 2. 비교 가능 자치구 정의
-- ============================================================
-- 이용 커버리지 80% 이상인 자치구만
-- 활용도 비교용 기준 산정에 사용
-- ============================================================

eligible AS (

    SELECT
        *

    FROM base

    WHERE
        usage_coverage_pct >= 80
        AND weighted_monthly_usage_per_locker IS NOT NULL
        AND one_person_households_per_facility IS NOT NULL
),


-- ============================================================
-- 3. 비교 가능 자치구의 중앙값 산출
-- ============================================================
-- 단순 평균보다 극단값의 영향을 덜 받기 위해
-- 중앙값을 2×2 기준선으로 사용
-- ============================================================

thresholds AS (

    SELECT

        APPROX_QUANTILES(
            one_person_households_per_facility,
            2
        )[OFFSET(1)] AS pressure_median,


        APPROX_QUANTILES(
            weighted_monthly_usage_per_locker,
            2
        )[OFFSET(1)] AS utilization_median

    FROM eligible
),


-- ============================================================
-- 4. 상대 순위 계산
-- ============================================================

ranked AS (

    SELECT

        district,


        -- ----------------------------------------------------
        -- 공급압력 Percentile
        -- ----------------------------------------------------
        -- 1에 가까울수록
        -- 시설당 담당 1인가구가 많은 지역
        -- ----------------------------------------------------

        PERCENT_RANK() OVER (
            ORDER BY one_person_households_per_facility
        ) AS supply_pressure_percentile,


        -- ----------------------------------------------------
        -- 활용도 Percentile
        -- ----------------------------------------------------
        -- 1에 가까울수록
        -- 함당 월평균 이용이 높은 지역
        -- ----------------------------------------------------

        PERCENT_RANK() OVER (
            ORDER BY weighted_monthly_usage_per_locker
        ) AS utilization_percentile,


        -- ----------------------------------------------------
        -- 20~39세 1인가구 규모 상대순위
        -- ----------------------------------------------------
        -- 전략 그룹 결정에는 직접 사용하지 않음.
        -- 수요 특성 설명용 보조 지표.
        -- ----------------------------------------------------

        PERCENT_RANK() OVER (
            ORDER BY one_person_age_20_39
        ) AS age20_39_demand_percentile

    FROM eligible
),


-- ============================================================
-- 5. 최종 진단
-- ============================================================

diagnostic AS (

    SELECT

        b.*,


        -- ====================================================
        -- 비교 기준선
        -- ====================================================

        t.pressure_median,
        t.utilization_median,


        -- ====================================================
        -- 상대 순위
        -- ====================================================

        r.supply_pressure_percentile,
        r.utilization_percentile,
        r.age20_39_demand_percentile,


        -- ====================================================
        -- 데이터 신뢰도 등급
        -- ====================================================

        CASE

            WHEN
                b.usage_coverage_pct >= 90
                AND b.locker_count_coverage_pct >= 90
                THEN 'high'

            WHEN
                b.usage_coverage_pct >= 80
                AND b.locker_count_coverage_pct >= 80
                THEN 'medium'

            ELSE 'low'

        END AS data_confidence,


        -- ====================================================
        -- 데이터 주의 플래그
        -- ====================================================

        CASE

            WHEN b.usage_coverage_pct < 80
                THEN TRUE

            WHEN b.locker_count_coverage_pct < 80
                THEN TRUE

            WHEN b.status_conflict_facility_count > 0
                THEN TRUE

            ELSE FALSE

        END AS has_data_caution,


        -- ====================================================
        -- 진단 그룹 CODE
        -- ====================================================

        CASE

            -- 데이터 부족
            WHEN
                b.usage_coverage_pct < 80
                OR b.weighted_monthly_usage_per_locker IS NULL
                THEN 'DATA_CHECK'


            -- 공급압력 ↑ + 활용 ↑
            WHEN
                b.one_person_households_per_facility
                    >= t.pressure_median

                AND

                b.weighted_monthly_usage_per_locker
                    >= t.utilization_median

                THEN 'EXPANSION_CANDIDATE'


            -- 공급압력 ↓ + 활용 ↑
            WHEN
                b.one_person_households_per_facility
                    < t.pressure_median

                AND

                b.weighted_monthly_usage_per_locker
                    >= t.utilization_median

                THEN 'HIGH_UTILIZATION'


            -- 공급압력 ↑ + 활용 ↓
            WHEN
                b.one_person_households_per_facility
                    >= t.pressure_median

                AND

                b.weighted_monthly_usage_per_locker
                    < t.utilization_median

                THEN 'LOCATION_REVIEW'


            -- 공급압력 ↓ + 활용 ↓
            ELSE 'LOW_UTILIZATION'

        END AS diagnostic_group_code,


        -- ====================================================
        -- Looker / 발표용 한글 라벨
        -- ====================================================

        CASE

            WHEN
                b.usage_coverage_pct < 80
                OR b.weighted_monthly_usage_per_locker IS NULL
                THEN '데이터 확인 필요'


            WHEN
                b.one_person_households_per_facility
                    >= t.pressure_median

                AND

                b.weighted_monthly_usage_per_locker
                    >= t.utilization_median

                THEN '증설 우선 후보'


            WHEN
                b.one_person_households_per_facility
                    < t.pressure_median

                AND

                b.weighted_monthly_usage_per_locker
                    >= t.utilization_median

                THEN '고활용 유지·운영 최적화'


            WHEN
                b.one_person_households_per_facility
                    >= t.pressure_median

                AND

                b.weighted_monthly_usage_per_locker
                    < t.utilization_median

                THEN '공급·입지 적합성 점검'


            ELSE
                '저활용 재검토'

        END AS diagnostic_group_label


    FROM base b

    CROSS JOIN thresholds t

    LEFT JOIN ranked r
        USING (district)

)


SELECT
    *

FROM diagnostic;

-- ============================================================
-- STEP 13 QA
-- ============================================================


-- 1. 25개 자치구 유지
ASSERT (

    SELECT COUNT(*) = 25

    FROM
        `mission17-locker-jh-2608.analytics_seoul_locker.mart_district_diagnostic`

) AS '자치구 Diagnostic Mart가 25행이 아닙니다.';


-- 2. 자치구 중복 없음
ASSERT (

    SELECT
        COUNT(*) = COUNT(DISTINCT district)

    FROM
        `mission17-locker-jh-2608.analytics_seoul_locker.mart_district_diagnostic`

) AS 'Diagnostic Mart에서 자치구가 중복되었습니다.';


-- 3. 기준 중앙값 생성 여부
ASSERT (

    SELECT
        COUNTIF(
            pressure_median IS NULL
            OR utilization_median IS NULL
        ) = 0

    FROM
        `mission17-locker-jh-2608.analytics_seoul_locker.mart_district_diagnostic`

) AS '진단 기준 중앙값 생성에 실패했습니다.';


-- 4. 커버리지 80% 이상 자치구는 반드시 그룹 분류
ASSERT (

    SELECT
        COUNTIF(
            usage_coverage_pct >= 80
            AND diagnostic_group_code IS NULL
        ) = 0

    FROM
        `mission17-locker-jh-2608.analytics_seoul_locker.mart_district_diagnostic`

) AS '분석 가능 자치구 중 진단 그룹 누락이 있습니다.';



-- ============================================================
-- 1차 결과 확인
-- ============================================================

SELECT

    district,

    diagnostic_group_label,

    data_confidence,

    ROUND(
        usage_coverage_pct,
        1
    ) AS usage_coverage_pct,

    one_person_total,

    current_facility_count,

    ROUND(
        one_person_households_per_facility,
        0
    ) AS households_per_facility,

    ROUND(
        weighted_monthly_usage_per_locker,
        2
    ) AS monthly_usage_per_locker,

    ROUND(
        supply_pressure_percentile * 100,
        1
    ) AS supply_pressure_percentile,

    ROUND(
        utilization_percentile * 100,
        1
    ) AS utilization_percentile,

    ROUND(
        age_20_39_share_pct,
        1
    ) AS age_20_39_share_pct,

    status_conflict_facility_count

FROM
    `mission17-locker-jh-2608.analytics_seoul_locker.mart_district_diagnostic`

ORDER BY

    CASE diagnostic_group_code

        WHEN 'EXPANSION_CANDIDATE' THEN 1
        WHEN 'HIGH_UTILIZATION' THEN 2
        WHEN 'LOCATION_REVIEW' THEN 3
        WHEN 'LOW_UTILIZATION' THEN 4
        WHEN 'DATA_CHECK' THEN 5

        ELSE 6

    END,

    supply_pressure_percentile DESC;