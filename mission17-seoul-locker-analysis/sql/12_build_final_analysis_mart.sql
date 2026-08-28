-- ============================================================
-- STEP 18. 최종 자치구 의사결정 Analysis Mart
-- ============================================================
-- 테이블:
--   mart_district_final
--
-- Grain:
--   자치구 1개 = 1행 (25행)
--
-- 결합 정보:
--   - 2025년 1인가구 잠재수요
--   - 2026-08 현재 택배함 공급
--   - 2026 H1 실제 이용 강도
--   - 2021~2025 동일시설 Balanced Panel 장기 추세
--   - 최근 2024→2025 변화
--   - 데이터 커버리지 / 상태 충돌 / 경계 여부
--
-- 목적:
--   Looker Studio / Python / 최종 보고서에서 사용할
--   최종 분석용 단일 Mart 확정
--
-- 주의:
--   final_action은 정책의 확정 답안이 아니라
--   데이터 기반 '우선 검토 방향'을 의미함.
-- ============================================================


CREATE OR REPLACE TABLE
`mission17-locker-jh-2608.analytics_seoul_locker.mart_district_final`
AS


WITH base AS (

    SELECT
        *

    FROM
        `mission17-locker-jh-2608.analytics_seoul_locker.qa_district_priority_validation`
),


finalized AS (

    SELECT
        *,


        -- ====================================================
        -- 1. 최종 Action Code
        -- ====================================================

        CASE

            -- ------------------------------------------------
            -- A. 현재 이용 데이터가 불충분
            -- ------------------------------------------------

            WHEN diagnostic_group_code = 'DATA_CHECK'
                THEN 'DATA_REVIEW'


            -- ------------------------------------------------
            -- B. 증설 후보지만 장기 추세 근거가 제한적
            -- ------------------------------------------------

            WHEN
                diagnostic_group_code = 'EXPANSION_CANDIDATE'
                AND trend_data_confidence = 'limited'

                THEN 'EXPANSION_AFTER_DATA_CHECK'


            -- ------------------------------------------------
            -- C. 증설 후보 + 장기/최근 모두 감소
            -- ------------------------------------------------

            WHEN
                diagnostic_group_code = 'EXPANSION_CANDIDATE'

                AND long_term_signal = 'negative'
                AND recent_signal = 'negative'

                THEN 'DEMAND_DECLINE_CHECK'


            -- ------------------------------------------------
            -- D. 증설 후보 + 장기/최근 모두 긍정
            -- ------------------------------------------------

            WHEN
                diagnostic_group_code = 'EXPANSION_CANDIDATE'

                AND long_term_signal = 'positive'
                AND recent_signal = 'positive'

                THEN 'EXPANSION_PRIORITY'


            -- ------------------------------------------------
            -- E. 증설 후보 + 장기 안정 / 최근 증가
            -- ------------------------------------------------

            WHEN
                diagnostic_group_code = 'EXPANSION_CANDIDATE'

                AND long_term_signal = 'stable'
                AND recent_signal = 'positive'

                THEN 'EXPANSION_PRIORITY'


            -- ------------------------------------------------
            -- F. 증설 후보이나 추세 신호가 엇갈리거나
            --    명확한 증가 근거가 부족
            -- ------------------------------------------------

            WHEN
                diagnostic_group_code = 'EXPANSION_CANDIDATE'

                THEN 'EXPANSION_CONDITIONAL'


            -- ------------------------------------------------
            -- G. 현재 고활용
            -- ------------------------------------------------

            WHEN
                diagnostic_group_code = 'HIGH_UTILIZATION'
                AND long_term_signal = 'negative'

                THEN 'MAINTAIN_AND_RECOVER'


            WHEN
                diagnostic_group_code = 'HIGH_UTILIZATION'

                THEN 'MAINTAIN_OPTIMIZE'


            -- ------------------------------------------------
            -- H. 공급압력은 있지만 이용이 낮음
            -- ------------------------------------------------

            WHEN
                diagnostic_group_code = 'LOCATION_REVIEW'
                AND long_term_signal = 'negative'

                THEN 'LOCATION_OPERATION_REVIEW'


            WHEN
                diagnostic_group_code = 'LOCATION_REVIEW'

                THEN 'LOCATION_FIT_CHECK'


            -- ------------------------------------------------
            -- I. 현재 저활용
            --
            -- 장기 증가 ↔ 최근 감소:
            -- 바로 구조조정하지 않고 활성화 실험 후 확인
            -- ------------------------------------------------

            WHEN
                diagnostic_group_code = 'LOW_UTILIZATION'

                AND long_term_signal = 'positive'
                AND recent_signal = 'negative'

                THEN 'ACTIVATE_AND_MONITOR'


            -- ------------------------------------------------
            -- 장기 감소 ↔ 최근 증가:
            -- 최근 반등 신호 확인
            -- ------------------------------------------------

            WHEN
                diagnostic_group_code = 'LOW_UTILIZATION'

                AND long_term_signal = 'negative'
                AND recent_signal = 'positive'

                THEN 'RECOVERY_POTENTIAL_CHECK'


            -- ------------------------------------------------
            -- 장기·최근 모두 감소
            -- ------------------------------------------------

            WHEN
                diagnostic_group_code = 'LOW_UTILIZATION'

                AND long_term_signal = 'negative'

                THEN 'LOW_UTILIZATION_REVIEW'


            -- ------------------------------------------------
            -- 장기적으로 증가
            -- ------------------------------------------------

            WHEN
                diagnostic_group_code = 'LOW_UTILIZATION'

                AND long_term_signal = 'positive'

                THEN 'ACTIVATION_PRIORITY'


            -- ------------------------------------------------
            -- 뚜렷한 추세 없음
            -- ------------------------------------------------

            WHEN
                diagnostic_group_code = 'LOW_UTILIZATION'

                THEN 'LOW_UTILIZATION_IMPROVEMENT'


            ELSE 'OTHER_REVIEW'

        END AS final_action_code,


        -- ====================================================
        -- 2. 최종 발표 / Looker용 Action Label
        -- ====================================================

        CASE

            WHEN diagnostic_group_code = 'DATA_CHECK'
                THEN '데이터 보강 후 판단'


            WHEN
                diagnostic_group_code = 'EXPANSION_CANDIDATE'
                AND trend_data_confidence = 'limited'

                THEN '증설 판단 전 데이터 보강'


            WHEN
                diagnostic_group_code = 'EXPANSION_CANDIDATE'
                AND long_term_signal = 'negative'
                AND recent_signal = 'negative'

                THEN '증설 전 이용감소 원인 점검'


            WHEN
                diagnostic_group_code = 'EXPANSION_CANDIDATE'
                AND long_term_signal = 'positive'
                AND recent_signal = 'positive'

                THEN '증설 우선 검토'


            WHEN
                diagnostic_group_code = 'EXPANSION_CANDIDATE'
                AND long_term_signal = 'stable'
                AND recent_signal = 'positive'

                THEN '증설 우선 검토'


            WHEN diagnostic_group_code = 'EXPANSION_CANDIDATE'
                THEN '증설 조건부 검토'


            WHEN
                diagnostic_group_code = 'HIGH_UTILIZATION'
                AND long_term_signal = 'negative'

                THEN '현 수준 유지 + 이용감소 대응'


            WHEN diagnostic_group_code = 'HIGH_UTILIZATION'
                THEN '현 수준 유지·운영 최적화'


            WHEN
                diagnostic_group_code = 'LOCATION_REVIEW'
                AND long_term_signal = 'negative'

                THEN '입지·운영 재점검 우선'


            WHEN diagnostic_group_code = 'LOCATION_REVIEW'
                THEN '공급·입지 적합성 점검'


            WHEN
                diagnostic_group_code = 'LOW_UTILIZATION'
                AND long_term_signal = 'positive'
                AND recent_signal = 'negative'

                THEN '활성화 실험 후 추세 재확인'


            WHEN
                diagnostic_group_code = 'LOW_UTILIZATION'
                AND long_term_signal = 'negative'
                AND recent_signal = 'positive'

                THEN '최근 반등 가능성 점검'


            WHEN
                diagnostic_group_code = 'LOW_UTILIZATION'
                AND long_term_signal = 'negative'

                THEN '저활용 구조 재검토 우선'


            WHEN
                diagnostic_group_code = 'LOW_UTILIZATION'
                AND long_term_signal = 'positive'

                THEN '활성화 우선 검토'


            WHEN diagnostic_group_code = 'LOW_UTILIZATION'
                THEN '저활용 개선 실험'


            ELSE '추가 검토'

        END AS final_action_label,


        -- ====================================================
        -- 3. 우선순위 Tier
        -- ====================================================
        -- Tier 1:
        --   실제 실행 우선 검토
        --
        -- Tier 2:
        --   원인 확인 / 조건부 판단
        --
        -- Tier 3:
        --   운영 개선 / 구조 점검
        --
        -- Tier 4:
        --   데이터 보강 우선
        -- ====================================================

        CASE

            WHEN
                diagnostic_group_code = 'EXPANSION_CANDIDATE'
                AND (
                    (
                        long_term_signal = 'positive'
                        AND recent_signal = 'positive'
                    )
                    OR
                    (
                        long_term_signal = 'stable'
                        AND recent_signal = 'positive'
                    )
                )
                AND trend_data_confidence != 'limited'

                THEN 1


            WHEN diagnostic_group_code = 'EXPANSION_CANDIDATE'
                THEN 2


            WHEN diagnostic_group_code IN (
                'HIGH_UTILIZATION',
                'LOCATION_REVIEW',
                'LOW_UTILIZATION'
            )
                THEN 3


            WHEN diagnostic_group_code = 'DATA_CHECK'
                THEN 4


            ELSE 4

        END AS action_tier,


        -- ====================================================
        -- 4. 최종 근거 신뢰도
        -- ====================================================

        CASE

            WHEN
                data_confidence = 'low'
                OR trend_data_confidence = 'limited'

                THEN 'limited'


            WHEN
                data_confidence = 'high'
                AND trend_data_confidence = 'high'
                AND status_conflict_facility_count = 0

                THEN 'high'


            ELSE 'medium'

        END AS final_evidence_strength,


        -- ====================================================
        -- 5. 가장 중요한 주의사항
        -- ====================================================

        CASE

            WHEN data_confidence = 'low'
                THEN '현재 이용 데이터 커버리지 제한'


            WHEN trend_data_confidence = 'limited'
                THEN 'Balanced Panel 시설 수가 적어 추세 해석 주의'


            WHEN has_trend_signal_conflict = TRUE
                THEN '장기 추세와 최근 추세 방향이 상충'


            WHEN status_conflict_facility_count > 0
                THEN '위치·실적 원천 간 운영상태 불일치 존재'


            WHEN
                is_pressure_borderline = TRUE
                AND is_utilization_borderline = TRUE

                THEN '공급압력·활용도 모두 중앙값 경계에 가까움'


            WHEN is_pressure_borderline = TRUE
                THEN '공급압력 중앙값 경계에 가까움'


            WHEN is_utilization_borderline = TRUE
                THEN '활용도 중앙값 경계에 가까움'


            ELSE '특이사항 없음'

        END AS primary_caution,


        -- ====================================================
        -- 6. 보고서 / Looker Tooltip용 판단 근거 문장
        -- ====================================================

        FORMAT(
            '현재 진단: %s | 장기: %s (%.1f%%) | 최근: %s (%.1f%%) | 현재 이용 커버리지: %.1f%%',
            diagnostic_group_label,
            long_term_trend,
            usage_change_2021_2025_pct,
            recent_trend,
            usage_change_2024_2025_pct,
            usage_coverage_pct
        ) AS decision_rationale


    FROM base
)


SELECT
    *

FROM finalized;



-- ============================================================
-- STEP 18 QA
-- ============================================================


-- 1. 서울 25개 자치구 유지
ASSERT (

    SELECT COUNT(*) = 25

    FROM
        `mission17-locker-jh-2608.analytics_seoul_locker.mart_district_final`

) AS '최종 Analysis Mart가 25행이 아닙니다.';


-- 2. 자치구 중복 없음
ASSERT (

    SELECT
        COUNT(*) = COUNT(DISTINCT district)

    FROM
        `mission17-locker-jh-2608.analytics_seoul_locker.mart_district_final`

) AS '최종 Analysis Mart에서 자치구가 중복되었습니다.';


-- 3. 최종 Action 누락 없음
ASSERT (

    SELECT
        COUNTIF(
            final_action_code IS NULL
            OR final_action_label IS NULL
        ) = 0

    FROM
        `mission17-locker-jh-2608.analytics_seoul_locker.mart_district_final`

) AS '최종 실행방향이 없는 자치구가 있습니다.';


-- 4. 근거 제한 지역에 Tier 1 증설 판단 금지
ASSERT (

    SELECT
        COUNTIF(
            action_tier = 1
            AND final_evidence_strength = 'limited'
        ) = 0

    FROM
        `mission17-locker-jh-2608.analytics_seoul_locker.mart_district_final`

) AS '근거가 제한적인 지역이 Tier 1로 분류되었습니다.';


-- 5. 장기/최근 추세 충돌 지역을
--    강한 Tier 1 증설로 분류하지 않았는지 확인
ASSERT (

    SELECT
        COUNTIF(
            action_tier = 1
            AND has_trend_signal_conflict = TRUE
        ) = 0

    FROM
        `mission17-locker-jh-2608.analytics_seoul_locker.mart_district_final`

) AS '추세 신호가 충돌하는 지역이 Tier 1에 포함되었습니다.';



-- ============================================================
-- 최종 25개 자치구 결과 확인
-- ============================================================

SELECT

    district,

    final_action_label,

    action_tier,

    final_evidence_strength,

    diagnostic_group_label
        AS current_diagnostic,

    long_term_trend,

    recent_trend,

    ROUND(
        one_person_households_per_facility,
        0
    ) AS households_per_facility,

    ROUND(
        weighted_monthly_usage_per_locker,
        2
    ) AS monthly_usage_per_locker,

    ROUND(
        usage_change_2021_2025_pct,
        1
    ) AS long_term_change_pct,

    ROUND(
        usage_change_2024_2025_pct,
        1
    ) AS recent_change_pct,

    primary_caution

FROM
    `mission17-locker-jh-2608.analytics_seoul_locker.mart_district_final`

ORDER BY
    action_tier,
    final_action_label,
    supply_pressure_percentile DESC;