-- ============================================================
-- Mart Model
-- mart_balanced_panel_trend
-- ============================================================
--
-- Grain:
--   분석기간 1개 = 1행 (총 6행)
--
-- 목적:
--   2021~2026 H1 모든 기간에 이용건수가 존재하는
--   동일 시설만 고정하여 시설 구성 변화의 영향을 줄인
--   서울 전체 Balanced Panel 이용 추세 산출
--
-- 기대 Balanced Panel:
--   202개 시설
-- ============================================================


WITH

-- ============================================================
-- 1. 6개 기간 모두 이용건수가 있는 시설
-- ============================================================

balanced_facilities AS (

    SELECT
        locker_stat_id

    FROM {{ ref('int_locker_period_metrics') }}

    WHERE has_usage_observation = TRUE

    GROUP BY locker_stat_id

    HAVING COUNT(DISTINCT period) = 6
),


-- ============================================================
-- 2. Balanced Panel
-- ============================================================

panel AS (

    SELECT p.*

    FROM {{ ref('int_locker_period_metrics') }} p

    INNER JOIN balanced_facilities b
        USING (locker_stat_id)

),


-- ============================================================
-- 3. 기간별 집계
-- ============================================================

period_summary AS (

    SELECT

        year,
        period,
        period_label,

        months_observed,
        is_partial_year,

        COUNT(DISTINCT locker_stat_id)
            AS balanced_facility_count,

        SUM(usage_count)
            AS total_usage,

        AVG(calculated_monthly_avg_usage)
            AS avg_monthly_usage_per_facility,

        SUM(calculated_monthly_avg_usage)
            AS total_monthly_usage,

        SAFE_DIVIDE(
            SUM(calculated_monthly_avg_usage),
            SUM(locker_count)
        ) AS weighted_monthly_usage_per_locker,

        APPROX_QUANTILES(
            calculated_monthly_avg_usage,
            100
        )[OFFSET(50)]
            AS median_monthly_usage_per_facility,

        APPROX_QUANTILES(
            monthly_usage_per_locker,
            100
        )[OFFSET(50)]
            AS median_monthly_usage_per_locker

    FROM panel

    GROUP BY
        year,
        period,
        period_label,
        months_observed,
        is_partial_year
),


-- ============================================================
-- 4. 전기 값
-- ============================================================

trend AS (

    SELECT
        *,

        LAG(
            avg_monthly_usage_per_facility
        ) OVER (
            ORDER BY year
        ) AS previous_avg_monthly_usage,

        LAG(
            weighted_monthly_usage_per_locker
        ) OVER (
            ORDER BY year
        ) AS previous_weighted_usage_per_locker

    FROM period_summary
)


SELECT

    * EXCEPT(
        previous_avg_monthly_usage,
        previous_weighted_usage_per_locker
    ),

    SAFE_MULTIPLY(
        SAFE_DIVIDE(
            avg_monthly_usage_per_facility
                - previous_avg_monthly_usage,
            previous_avg_monthly_usage
        ),
        100
    ) AS monthly_usage_change_pct,

    SAFE_MULTIPLY(
        SAFE_DIVIDE(
            weighted_monthly_usage_per_locker
                - previous_weighted_usage_per_locker,
            previous_weighted_usage_per_locker
        ),
        100
    ) AS locker_efficiency_change_pct,

    CASE
        WHEN period = '2026_h1'
            THEN 'H1 월평균 참고 비교 - 계절성 주의'
        ELSE '완결연도 월평균 비교'
    END AS comparison_note

FROM trend