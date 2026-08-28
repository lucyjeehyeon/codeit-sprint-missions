-- ============================================================
-- STEP 17. 최종 자치구 전략 분류 Robustness / QA
-- ============================================================
-- 테이블:
--   qa_district_priority_validation
--
-- 목적:
--   1. 2×2 분류 기준선(중앙값)에 너무 가까운 지역 확인
--   2. 장기 추세와 최근 추세가 충돌하는 지역 확인
--   3. 데이터 신뢰도가 제한적인 지역 확인
--   4. 상태 충돌 시설이 존재하는 지역 확인
--   5. 최종 전략을 확정하기 전에 수동 검토 대상 선별
--
-- 중요:
--   결과를 "바꾸기 위한 QA"가 아니라
--   결과가 얼마나 견고한지를 확인하는 단계
-- ============================================================


CREATE OR REPLACE TABLE
`mission17-locker-jh-2608.analytics_seoul_locker.qa_district_priority_validation`
AS


WITH base AS (

    SELECT
        *

    FROM
        `mission17-locker-jh-2608.analytics_seoul_locker.mart_district_priority`
),


validated AS (

    SELECT
        *,


        -- ====================================================
        -- 1. 공급압력 기준선과의 거리
        -- ====================================================
        -- 0에 가까울수록 중앙값 경계에 가까움
        -- ====================================================

        SAFE_MULTIPLY(
            SAFE_DIVIDE(
                one_person_households_per_facility
                - pressure_median,

                pressure_median
            ),
            100
        ) AS pressure_distance_from_median_pct,


        -- ====================================================
        -- 2. 활용도 기준선과의 거리
        -- ====================================================

        SAFE_MULTIPLY(
            SAFE_DIVIDE(
                weighted_monthly_usage_per_locker
                - utilization_median,

                utilization_median
            ),
            100
        ) AS utilization_distance_from_median_pct,


        -- ====================================================
        -- 3. 공급압력 경계지역
        -- ====================================================
        -- 중앙값 ±10% 이내라면
        -- 분류 기준선과 상당히 가까운 지역으로 표시
        -- ====================================================

        CASE
            WHEN ABS(
                SAFE_MULTIPLY(
                    SAFE_DIVIDE(
                        one_person_households_per_facility
                        - pressure_median,
                        pressure_median
                    ),
                    100
                )
            ) <= 10
            THEN TRUE

            ELSE FALSE
        END AS is_pressure_borderline,


        -- ====================================================
        -- 4. 활용도 경계지역
        -- ====================================================

        CASE
            WHEN ABS(
                SAFE_MULTIPLY(
                    SAFE_DIVIDE(
                        weighted_monthly_usage_per_locker
                        - utilization_median,
                        utilization_median
                    ),
                    100
                )
            ) <= 10
            THEN TRUE

            ELSE FALSE
        END AS is_utilization_borderline,


        -- ====================================================
        -- 5. 장기 / 최근 추세 충돌
        -- ====================================================

        CASE

            WHEN long_term_signal = 'positive'
                 AND recent_signal = 'negative'
                THEN TRUE

            WHEN long_term_signal = 'negative'
                 AND recent_signal = 'positive'
                THEN TRUE

            ELSE FALSE

        END AS has_trend_signal_conflict,


        -- ====================================================
        -- 6. 증설 판단 추가 검토 플래그
        -- ====================================================

        CASE

            WHEN diagnostic_group_code != 'EXPANSION_CANDIDATE'
                THEN FALSE

            WHEN decision_evidence_strength = 'limited'
                THEN TRUE

            WHEN (
                long_term_signal = 'positive'
                AND recent_signal = 'negative'
            )
                THEN TRUE

            WHEN (
                long_term_signal = 'negative'
                AND recent_signal = 'positive'
            )
                THEN TRUE

            ELSE FALSE

        END AS expansion_requires_extra_review,


        -- ====================================================
        -- 7. 전체 수동 검토 필요 여부
        -- ====================================================

        CASE

            WHEN data_confidence = 'low'
                THEN TRUE

            WHEN trend_data_confidence = 'limited'
                THEN TRUE

            WHEN status_conflict_facility_count > 0
                THEN TRUE

            WHEN ABS(
                SAFE_MULTIPLY(
                    SAFE_DIVIDE(
                        one_person_households_per_facility
                        - pressure_median,
                        pressure_median
                    ),
                    100
                )
            ) <= 10
                THEN TRUE

            WHEN ABS(
                SAFE_MULTIPLY(
                    SAFE_DIVIDE(
                        weighted_monthly_usage_per_locker
                        - utilization_median,
                        utilization_median
                    ),
                    100
                )
            ) <= 10
                THEN TRUE

            WHEN (
                long_term_signal = 'positive'
                AND recent_signal = 'negative'
            )
                THEN TRUE

            WHEN (
                long_term_signal = 'negative'
                AND recent_signal = 'positive'
            )
                THEN TRUE

            ELSE FALSE

        END AS requires_manual_review

    FROM base
)


SELECT
    *

FROM validated;


-- ============================================================
-- STEP 17 QA
-- ============================================================


-- 1. 25개 자치구 유지
ASSERT (

    SELECT COUNT(*) = 25

    FROM
        `mission17-locker-jh-2608.analytics_seoul_locker.qa_district_priority_validation`

) AS 'Priority Validation 테이블이 25행이 아닙니다.';


-- 2. 자치구 중복 없음
ASSERT (

    SELECT
        COUNT(*) = COUNT(DISTINCT district)

    FROM
        `mission17-locker-jh-2608.analytics_seoul_locker.qa_district_priority_validation`

) AS 'Priority Validation에서 자치구가 중복되었습니다.';


-- 3. 현재 진단 그룹 누락 없음
ASSERT (

    SELECT
        COUNTIF(diagnostic_group_code IS NULL) = 0

    FROM
        `mission17-locker-jh-2608.analytics_seoul_locker.qa_district_priority_validation`

) AS '현재 진단 그룹이 없는 자치구가 있습니다.';


-- ============================================================
-- 검토 대상 결과
-- ============================================================

SELECT

    district,

    diagnostic_group_label
        AS current_diagnostic,

    recommended_action,

    decision_evidence_strength,

    ROUND(
        pressure_distance_from_median_pct,
        1
    ) AS pressure_distance_pct,

    ROUND(
        utilization_distance_from_median_pct,
        1
    ) AS utilization_distance_pct,

    is_pressure_borderline,

    is_utilization_borderline,

    long_term_trend,

    recent_trend,

    has_trend_signal_conflict,

    status_conflict_facility_count,

    usage_coverage_pct,

    balanced_facility_count,

    requires_manual_review

FROM
    `mission17-locker-jh-2608.analytics_seoul_locker.qa_district_priority_validation`

WHERE
    requires_manual_review = TRUE

ORDER BY

    CASE
        WHEN has_trend_signal_conflict = TRUE THEN 1
        WHEN decision_evidence_strength = 'limited' THEN 2
        WHEN is_pressure_borderline = TRUE
             OR is_utilization_borderline = TRUE THEN 3
        ELSE 4
    END,

    district;