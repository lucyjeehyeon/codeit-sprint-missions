-- ============================================================
-- Mart Model
-- mart_district_diagnostic
-- ============================================================
--
-- Grain:
--   서울시 자치구 1개 = 1행
--
-- 목적:
--   수요·공급·이용 Mart를 기반으로
--   공급압력 × 실제 활용의 2×2 진단 수행
--
-- 분석 기준:
--   이용 커버리지 80% 이상 자치구의 중앙값 사용
--
-- Materialization:
--   TABLE
-- ============================================================


WITH

-- ============================================================
-- 1. 수요 × 공급 × 이용 Mart
-- ============================================================

base AS (

    SELECT *
    FROM {{ ref('mart_district_demand_supply') }}

),


-- ============================================================
-- 2. 활용도 비교 가능한 자치구
-- ============================================================

eligible AS (

    SELECT *

    FROM base

    WHERE
        usage_coverage_pct >= 80
        AND weighted_monthly_usage_per_locker IS NOT NULL
        AND one_person_households_per_facility IS NOT NULL
),


-- ============================================================
-- 3. 2×2 기준 중앙값
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
-- 4. 상대순위
-- ============================================================

ranked AS (

    SELECT

        district,

        PERCENT_RANK() OVER (
            ORDER BY one_person_households_per_facility
        ) AS supply_pressure_percentile,

        PERCENT_RANK() OVER (
            ORDER BY weighted_monthly_usage_per_locker
        ) AS utilization_percentile,

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

        t.pressure_median,
        t.utilization_median,

        r.supply_pressure_percentile,
        r.utilization_percentile,
        r.age20_39_demand_percentile,


        -- ----------------------------------------------------
        -- 데이터 신뢰도
        -- ----------------------------------------------------

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


        -- ----------------------------------------------------
        -- 데이터 주의 여부
        -- ----------------------------------------------------

        CASE

            WHEN b.usage_coverage_pct < 80
                THEN TRUE

            WHEN b.locker_count_coverage_pct < 80
                THEN TRUE

            WHEN b.status_conflict_facility_count > 0
                THEN TRUE

            ELSE FALSE

        END AS has_data_caution,


        -- ----------------------------------------------------
        -- 진단 CODE
        -- ----------------------------------------------------

        CASE

            WHEN
                b.usage_coverage_pct < 80
                OR b.weighted_monthly_usage_per_locker IS NULL

                THEN 'DATA_CHECK'


            WHEN
                b.one_person_households_per_facility
                    >= t.pressure_median

                AND

                b.weighted_monthly_usage_per_locker
                    >= t.utilization_median

                THEN 'EXPANSION_CANDIDATE'


            WHEN
                b.one_person_households_per_facility
                    < t.pressure_median

                AND

                b.weighted_monthly_usage_per_locker
                    >= t.utilization_median

                THEN 'HIGH_UTILIZATION'


            WHEN
                b.one_person_households_per_facility
                    >= t.pressure_median

                AND

                b.weighted_monthly_usage_per_locker
                    < t.utilization_median

                THEN 'LOCATION_REVIEW'


            ELSE 'LOW_UTILIZATION'

        END AS diagnostic_group_code,


        -- ----------------------------------------------------
        -- 발표 / Looker용 한글 라벨
        -- ----------------------------------------------------

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


            ELSE '저활용 재검토'

        END AS diagnostic_group_label


    FROM base b

    CROSS JOIN thresholds t

    LEFT JOIN ranked r
        USING (district)

)


SELECT *
FROM diagnostic