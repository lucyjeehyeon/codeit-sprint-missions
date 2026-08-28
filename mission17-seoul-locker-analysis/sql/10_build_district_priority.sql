-- ============================================================
-- STEP 16. 현재 진단 + 장기 추세 통합 의사결정 Mart
-- ============================================================
-- 테이블:
--   mart_district_priority
--
-- Grain:
--   자치구 1개 = 1행
--
-- 목적:
--   1. 2026 H1 현재 공급압력 / 활용 진단
--   2. 2021~2025 동일시설 장기 이용 추세
--   3. 데이터 신뢰도
--   를 결합해 자치구별 실행 방향을 분류
--
-- 중요:
--   이 분류는 정책의 최종 정답이나 인과추론 결과가 아니라
--   데이터 기반 우선 검토 프레임임.
-- ============================================================


CREATE OR REPLACE TABLE
`mission17-locker-jh-2608.analytics_seoul_locker.mart_district_priority`
AS


WITH

-- ============================================================
-- 1. 현재 수요·공급·이용 진단
-- ============================================================

current_diag AS (

    SELECT
        *

    FROM
        `mission17-locker-jh-2608.analytics_seoul_locker.mart_district_diagnostic`
),


-- ============================================================
-- 2. Balanced Panel 장기 추세
-- ============================================================

long_term AS (

    SELECT
        district,

        balanced_facility_count,
        trend_data_confidence,

        avg_monthly_usage_2021,
        avg_monthly_usage_2025,
        avg_monthly_usage_2026_h1,

        usage_change_2021_2025_pct,
        long_term_trend,

        usage_change_2024_2025_pct,
        recent_trend,

        efficiency_change_2021_2025_pct

    FROM
        `mission17-locker-jh-2608.analytics_seoul_locker.mart_district_trend`
),


-- ============================================================
-- 3. 현재 진단 + 장기 추세 결합
-- ============================================================

combined AS (

    SELECT

        d.*,

        t.balanced_facility_count,
        t.trend_data_confidence,

        t.avg_monthly_usage_2021,
        t.avg_monthly_usage_2025,
        t.avg_monthly_usage_2026_h1,

        t.usage_change_2021_2025_pct,
        t.long_term_trend,

        t.usage_change_2024_2025_pct,
        t.recent_trend,

        t.efficiency_change_2021_2025_pct

    FROM current_diag d

    LEFT JOIN long_term t
        USING (district)
),


-- ============================================================
-- 4. 최종 실행 방향 분류
-- ============================================================

classified AS (

    SELECT
        *,


        -- ====================================================
        -- 최종 판단 근거 신뢰도
        -- ====================================================

        CASE

            -- 현재 데이터 자체가 부족하거나
            -- 장기 Balanced Panel 표본이 제한적인 경우
            WHEN
                data_confidence = 'low'
                OR trend_data_confidence = 'limited'
                THEN 'limited'


            -- 현재와 장기 데이터가 모두 충분하고
            -- 상태 충돌까지 없는 경우
            WHEN
                data_confidence = 'high'
                AND trend_data_confidence = 'high'
                AND status_conflict_facility_count = 0
                THEN 'high'


            ELSE 'medium'

        END AS decision_evidence_strength,


        -- ====================================================
        -- 최종 실행 방향
        -- ====================================================

        CASE

            -- ------------------------------------------------
            -- 데이터 자체가 부족
            -- ------------------------------------------------

            WHEN diagnostic_group_code = 'DATA_CHECK'
                THEN '데이터 보강 후 판단'


            -- ------------------------------------------------
            -- 현재 공급압력 ↑ + 이용 ↑
            -- + 장기 또는 최근 증가
            --
            -- 증설 근거가 가장 강한 유형
            -- ------------------------------------------------

            WHEN
                diagnostic_group_code = 'EXPANSION_CANDIDATE'

                AND trend_data_confidence != 'limited'

                AND (
                    long_term_trend = '장기 증가'
                    OR recent_trend = '최근 증가'
                )

                THEN '증설 적극 검토'


            -- ------------------------------------------------
            -- 현재는 증설 신호가 강하지만
            -- 장기·최근 이용 모두 감소
            --
            -- 바로 증설하지 않고 감소 원인부터 확인
            -- ------------------------------------------------

            WHEN
                diagnostic_group_code = 'EXPANSION_CANDIDATE'

                AND long_term_trend = '장기 감소'
                AND recent_trend = '최근 감소'

                THEN '증설 전 이용감소 원인 점검'


            -- ------------------------------------------------
            -- 현재는 증설 후보이지만
            -- 추세가 결정적인 방향을 주지 않는 경우
            -- ------------------------------------------------

            WHEN
                diagnostic_group_code = 'EXPANSION_CANDIDATE'

                THEN '증설 조건부 검토'


            -- ------------------------------------------------
            -- 현재 이용은 높지만 장기 하락
            -- ------------------------------------------------

            WHEN
                diagnostic_group_code = 'HIGH_UTILIZATION'

                AND long_term_trend = '장기 감소'

                THEN '고활용 유지 + 이용감소 대응'


            -- ------------------------------------------------
            -- 현재 이용 높음 / 공급압력 상대적으로 낮음
            -- ------------------------------------------------

            WHEN
                diagnostic_group_code = 'HIGH_UTILIZATION'

                THEN '현 수준 유지·운영 최적화'


            -- ------------------------------------------------
            -- 공급압력은 상대적으로 높은데 활용 낮음
            -- + 장기 감소까지 존재
            -- ------------------------------------------------

            WHEN
                diagnostic_group_code = 'LOCATION_REVIEW'

                AND long_term_trend = '장기 감소'

                THEN '입지·운영 재점검 우선'


            WHEN
                diagnostic_group_code = 'LOCATION_REVIEW'

                THEN '공급·입지 적합성 점검'


            -- ------------------------------------------------
            -- 현재 저활용 + 장기 감소
            -- ------------------------------------------------

            WHEN
                diagnostic_group_code = 'LOW_UTILIZATION'

                AND long_term_trend = '장기 감소'

                THEN '저활용 구조 재검토 우선'


            -- ------------------------------------------------
            -- 현재는 저활용이지만
            -- 장기 또는 최근 증가 신호가 있음
            -- → 축소보다 활성화 가능성부터 확인
            -- ------------------------------------------------

            WHEN
                diagnostic_group_code = 'LOW_UTILIZATION'

                AND (
                    long_term_trend = '장기 증가'
                    OR recent_trend = '최근 증가'
                )

                THEN '활성화 우선 검토'


            ELSE '저활용 재검토'

        END AS recommended_action,


        -- ====================================================
        -- 해석 보조 플래그
        -- ====================================================

        CASE
            WHEN usage_change_2021_2025_pct >= 5
                THEN 'positive'

            WHEN usage_change_2021_2025_pct <= -5
                THEN 'negative'

            ELSE 'stable'
        END AS long_term_signal,


        CASE
            WHEN usage_change_2024_2025_pct >= 5
                THEN 'positive'

            WHEN usage_change_2024_2025_pct <= -5
                THEN 'negative'

            ELSE 'stable'
        END AS recent_signal

    FROM combined
),


-- ============================================================
-- 5. 결과 출력 순서
-- ============================================================

final AS (

    SELECT
        *,

        CASE recommended_action

            WHEN '증설 적극 검토'
                THEN 1

            WHEN '증설 조건부 검토'
                THEN 2

            WHEN '증설 전 이용감소 원인 점검'
                THEN 3

            WHEN '고활용 유지 + 이용감소 대응'
                THEN 4

            WHEN '현 수준 유지·운영 최적화'
                THEN 5

            WHEN '입지·운영 재점검 우선'
                THEN 6

            WHEN '공급·입지 적합성 점검'
                THEN 7

            WHEN '활성화 우선 검토'
                THEN 8

            WHEN '저활용 구조 재검토 우선'
                THEN 9

            WHEN '저활용 재검토'
                THEN 10

            WHEN '데이터 보강 후 판단'
                THEN 11

            ELSE 99

        END AS action_display_order

    FROM classified
)


SELECT
    *

FROM final;


-- ============================================================
-- STEP 16 QA
-- ============================================================


-- 1. 서울 25개 자치구 유지
ASSERT (

    SELECT COUNT(*) = 25

    FROM
        `mission17-locker-jh-2608.analytics_seoul_locker.mart_district_priority`

) AS '최종 Priority Mart가 25행이 아닙니다.';


-- 2. 자치구 중복 없음
ASSERT (

    SELECT
        COUNT(*) = COUNT(DISTINCT district)

    FROM
        `mission17-locker-jh-2608.analytics_seoul_locker.mart_district_priority`

) AS '최종 Priority Mart에서 자치구가 중복되었습니다.';


-- 3. Trend Mart 연결 누락 없음
ASSERT (

    SELECT
        COUNTIF(
            long_term_trend IS NULL
        ) = 0

    FROM
        `mission17-locker-jh-2608.analytics_seoul_locker.mart_district_priority`

) AS '장기 추세가 연결되지 않은 자치구가 있습니다.';


-- 4. 실행 방향 누락 없음
ASSERT (

    SELECT
        COUNTIF(
            recommended_action IS NULL
        ) = 0

    FROM
        `mission17-locker-jh-2608.analytics_seoul_locker.mart_district_priority`

) AS '실행 방향이 없는 자치구가 있습니다.';


-- ============================================================
-- 최종 결과 확인
-- ============================================================

SELECT

    district,

    diagnostic_group_label
        AS current_diagnostic,

    long_term_trend,

    recent_trend,

    recommended_action,

    decision_evidence_strength,

    ROUND(
        one_person_households_per_facility,
        0
    ) AS households_per_facility,

    ROUND(
        weighted_monthly_usage_per_locker,
        2
    ) AS current_monthly_usage_per_locker,

    ROUND(
        usage_change_2021_2025_pct,
        1
    ) AS long_term_change_pct,

    ROUND(
        usage_change_2024_2025_pct,
        1
    ) AS recent_change_pct,

    balanced_facility_count,

    ROUND(
        usage_coverage_pct,
        1
    ) AS current_usage_coverage_pct

FROM
    `mission17-locker-jh-2608.analytics_seoul_locker.mart_district_priority`

ORDER BY
    action_display_order,
    supply_pressure_percentile DESC;