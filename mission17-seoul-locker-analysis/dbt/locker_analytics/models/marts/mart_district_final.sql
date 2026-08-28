-- ============================================================
-- Final Mart Model
-- mart_district_final
-- ============================================================
--
-- Grain:
--   서울시 자치구 1개 = 1행 (25행)
--
-- 결합 정보:
--   - 2025년 1인가구 잠재수요
--   - 2026-08 현재 공급
--   - 2026 H1 실제 이용 강도
--   - 2021~2025 Balanced Panel 장기 추세
--   - 2024→2025 최근 변화
--   - 데이터 신뢰도 / 분류 경계 / 원천 충돌
--
-- 목적:
--   Looker Studio / 보고서 / 최종 정책 진단에서
--   사용할 단일 최종 Mart
--
-- 주의:
--   final_action은 정책의 확정 답이 아니라
--   데이터 기반 '우선 검토 방향'을 의미
-- ============================================================


WITH

-- ============================================================
-- 1. 현재 수요·공급·이용 진단
-- ============================================================

diagnostic AS (

    SELECT *
    FROM {{ ref('mart_district_diagnostic') }}

),


-- ============================================================
-- 2. 장기 이용 추세
-- ============================================================

trend AS (

    SELECT
        district,

        balanced_facility_count,
        trend_data_confidence,

        avg_monthly_usage_2021,
        avg_monthly_usage_2022,
        avg_monthly_usage_2023,
        avg_monthly_usage_2024,
        avg_monthly_usage_2025,
        avg_monthly_usage_2026_h1,

        locker_efficiency_2021,
        locker_efficiency_2025,
        locker_efficiency_2026_h1,

        usage_change_2021_2025_pct,
        usage_change_2024_2025_pct,
        efficiency_change_2021_2025_pct,

        long_term_trend,
        recent_trend

    FROM {{ ref('mart_district_trend') }}

),


-- ============================================================
-- 3. 현재 + 장기 결합
-- ============================================================

combined AS (

    SELECT
        d.*,

        t.balanced_facility_count,
        t.trend_data_confidence,

        t.avg_monthly_usage_2021,
        t.avg_monthly_usage_2022,
        t.avg_monthly_usage_2023,
        t.avg_monthly_usage_2024,
        t.avg_monthly_usage_2025,
        t.avg_monthly_usage_2026_h1,

        t.locker_efficiency_2021,
        t.locker_efficiency_2025,
        t.locker_efficiency_2026_h1,

        t.usage_change_2021_2025_pct,
        t.usage_change_2024_2025_pct,
        t.efficiency_change_2021_2025_pct,

        t.long_term_trend,
        t.recent_trend

    FROM diagnostic d

    LEFT JOIN trend t
        USING (district)

),


-- ============================================================
-- 4. 장기 / 최근 신호
-- ============================================================

signals AS (

    SELECT
        *,

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
        END AS recent_signal,


        -- 공급압력 중앙값과 거리
        SAFE_MULTIPLY(
            SAFE_DIVIDE(
                one_person_households_per_facility
                    - pressure_median,
                pressure_median
            ),
            100
        ) AS pressure_distance_from_median_pct,


        -- 활용도 중앙값과 거리
        SAFE_MULTIPLY(
            SAFE_DIVIDE(
                weighted_monthly_usage_per_locker
                    - utilization_median,
                utilization_median
            ),
            100
        ) AS utilization_distance_from_median_pct

    FROM combined

),


-- ============================================================
-- 5. Robustness 정보
-- ============================================================

robustness AS (

    SELECT
        *,

        ABS(
            pressure_distance_from_median_pct
        ) <= 10
            AS is_pressure_borderline,


        ABS(
            utilization_distance_from_median_pct
        ) <= 10
            AS is_utilization_borderline,


        CASE

            WHEN
                long_term_signal = 'positive'
                AND recent_signal = 'negative'
                THEN TRUE

            WHEN
                long_term_signal = 'negative'
                AND recent_signal = 'positive'
                THEN TRUE

            ELSE FALSE

        END AS has_trend_signal_conflict

    FROM signals

),


-- ============================================================
-- 6. 최종 전략
-- ============================================================

finalized AS (

    SELECT
        *,


        -- ====================================================
        -- 최종 Action Code
        -- ====================================================

        CASE

            WHEN diagnostic_group_code = 'DATA_CHECK'
                THEN 'DATA_REVIEW'


            WHEN
                diagnostic_group_code = 'EXPANSION_CANDIDATE'
                AND trend_data_confidence = 'limited'

                THEN 'EXPANSION_AFTER_DATA_CHECK'


            WHEN
                diagnostic_group_code = 'EXPANSION_CANDIDATE'
                AND long_term_signal = 'negative'
                AND recent_signal = 'negative'

                THEN 'DEMAND_DECLINE_CHECK'


            WHEN
                diagnostic_group_code = 'EXPANSION_CANDIDATE'
                AND long_term_signal = 'positive'
                AND recent_signal = 'positive'

                THEN 'EXPANSION_PRIORITY'


            WHEN
                diagnostic_group_code = 'EXPANSION_CANDIDATE'
                AND long_term_signal = 'stable'
                AND recent_signal = 'positive'

                THEN 'EXPANSION_PRIORITY'


            WHEN diagnostic_group_code = 'EXPANSION_CANDIDATE'
                THEN 'EXPANSION_CONDITIONAL'


            WHEN
                diagnostic_group_code = 'HIGH_UTILIZATION'
                AND long_term_signal = 'negative'

                THEN 'MAINTAIN_AND_RECOVER'


            WHEN diagnostic_group_code = 'HIGH_UTILIZATION'
                THEN 'MAINTAIN_OPTIMIZE'


            WHEN
                diagnostic_group_code = 'LOCATION_REVIEW'
                AND long_term_signal = 'negative'

                THEN 'LOCATION_OPERATION_REVIEW'


            WHEN diagnostic_group_code = 'LOCATION_REVIEW'
                THEN 'LOCATION_FIT_CHECK'


            WHEN
                diagnostic_group_code = 'LOW_UTILIZATION'
                AND long_term_signal = 'positive'
                AND recent_signal = 'negative'

                THEN 'ACTIVATE_AND_MONITOR'


            WHEN
                diagnostic_group_code = 'LOW_UTILIZATION'
                AND long_term_signal = 'negative'
                AND recent_signal = 'positive'

                THEN 'RECOVERY_POTENTIAL_CHECK'


            WHEN
                diagnostic_group_code = 'LOW_UTILIZATION'
                AND long_term_signal = 'negative'

                THEN 'LOW_UTILIZATION_REVIEW'


            WHEN
                diagnostic_group_code = 'LOW_UTILIZATION'
                AND long_term_signal = 'positive'

                THEN 'ACTIVATION_PRIORITY'


            WHEN diagnostic_group_code = 'LOW_UTILIZATION'
                THEN 'LOW_UTILIZATION_IMPROVEMENT'


            ELSE 'OTHER_REVIEW'

        END AS final_action_code,


        -- ====================================================
        -- 발표 / Looker용 한글 Action
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
        -- Action Tier
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


            ELSE 4

        END AS action_tier,


        -- ====================================================
        -- 최종 Evidence Strength
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
        -- 최우선 주의사항
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
        -- 대시보드 Tooltip / 보고서용 판단 근거
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


    FROM robustness

)


SELECT *
FROM finalized