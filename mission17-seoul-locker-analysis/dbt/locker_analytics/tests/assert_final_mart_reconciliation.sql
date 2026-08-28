-- ============================================================
-- Final Mart Reconciliation Test
-- 기존 수작업 SQL 결과 vs dbt 최종 Mart
-- ============================================================
--
-- 목적:
--   dbt 리팩터링 과정에서 최종 자치구 진단 및
--   실행전략이 변하지 않았는지 검증
--
-- 정상:
--   차이 0행 → PASS
-- ============================================================


WITH manual_result AS (

    SELECT
        district,

        diagnostic_group_code,
        diagnostic_group_label,

        long_term_trend,
        recent_trend,

        final_action_code,
        final_action_label,

        action_tier,
        final_evidence_strength,

        primary_caution,

        usage_change_2021_2025_pct,
        usage_change_2024_2025_pct,

        one_person_households_per_facility,
        weighted_monthly_usage_per_locker

    FROM
        `mission17-locker-jh-2608.analytics_seoul_locker.mart_district_final`
),


dbt_result AS (

    SELECT
        district,

        diagnostic_group_code,
        diagnostic_group_label,

        long_term_trend,
        recent_trend,

        final_action_code,
        final_action_label,

        action_tier,
        final_evidence_strength,

        primary_caution,

        usage_change_2021_2025_pct,
        usage_change_2024_2025_pct,

        one_person_households_per_facility,
        weighted_monthly_usage_per_locker

    FROM {{ ref('mart_district_final') }}
),


comparison AS (

    SELECT

        COALESCE(
            m.district,
            d.district
        ) AS district,

        -- --------------------------------------------
        -- 자치구 존재 여부
        -- --------------------------------------------

        m.district IS NULL
            AS missing_in_manual,

        d.district IS NULL
            AS missing_in_dbt,


        -- --------------------------------------------
        -- 현재 진단
        -- --------------------------------------------

        m.diagnostic_group_code
            IS DISTINCT FROM
        d.diagnostic_group_code
            AS diagnostic_code_diff,

        m.diagnostic_group_label
            IS DISTINCT FROM
        d.diagnostic_group_label
            AS diagnostic_label_diff,


        -- --------------------------------------------
        -- 추세
        -- --------------------------------------------

        m.long_term_trend
            IS DISTINCT FROM
        d.long_term_trend
            AS long_term_trend_diff,

        m.recent_trend
            IS DISTINCT FROM
        d.recent_trend
            AS recent_trend_diff,


        -- --------------------------------------------
        -- 최종 전략
        -- --------------------------------------------

        m.final_action_code
            IS DISTINCT FROM
        d.final_action_code
            AS action_code_diff,

        m.final_action_label
            IS DISTINCT FROM
        d.final_action_label
            AS action_label_diff,

        m.action_tier
            IS DISTINCT FROM
        d.action_tier
            AS action_tier_diff,

        m.final_evidence_strength
            IS DISTINCT FROM
        d.final_evidence_strength
            AS evidence_diff,

        m.primary_caution
            IS DISTINCT FROM
        d.primary_caution
            AS caution_diff,


        -- --------------------------------------------
        -- 핵심 숫자
        -- FLOAT는 아주 작은 계산 오차 허용
        -- --------------------------------------------

        ABS(
            COALESCE(
                m.usage_change_2021_2025_pct,
                0
            )
            -
            COALESCE(
                d.usage_change_2021_2025_pct,
                0
            )
        ) > 0.000001
            AS long_term_change_diff,


        ABS(
            COALESCE(
                m.usage_change_2024_2025_pct,
                0
            )
            -
            COALESCE(
                d.usage_change_2024_2025_pct,
                0
            )
        ) > 0.000001
            AS recent_change_diff,


        ABS(
            COALESCE(
                m.one_person_households_per_facility,
                0
            )
            -
            COALESCE(
                d.one_person_households_per_facility,
                0
            )
        ) > 0.000001
            AS supply_pressure_diff,


        ABS(
            COALESCE(
                m.weighted_monthly_usage_per_locker,
                0
            )
            -
            COALESCE(
                d.weighted_monthly_usage_per_locker,
                0
            )
        ) > 0.000001
            AS utilization_diff


    FROM manual_result m

    FULL OUTER JOIN dbt_result d
        USING (district)
)


-- ============================================================
-- 차이가 발생한 자치구만 반환
-- ============================================================

SELECT *

FROM comparison

WHERE
       missing_in_manual
    OR missing_in_dbt

    OR diagnostic_code_diff
    OR diagnostic_label_diff

    OR long_term_trend_diff
    OR recent_trend_diff

    OR action_code_diff
    OR action_label_diff
    OR action_tier_diff
    OR evidence_diff
    OR caution_diff

    OR long_term_change_diff
    OR recent_change_diff
    OR supply_pressure_diff
    OR utilization_diff