-- ============================================================
-- Mart Model
-- mart_district_trend
-- ============================================================
--
-- Grain:
--   서울시 자치구 1개 = 1행
--
-- 핵심 비교:
--   2021 → 2025 완결연도
--
-- 2026 H1:
--   최신 월평균 참고값
--
-- 목적:
--   동일 시설 기준 자치구별 장기 이용 방향 진단
-- ============================================================


WITH

-- ============================================================
-- 1. Balanced Panel 시설
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
-- 2. Balanced Panel 데이터
-- ============================================================

panel AS (

    SELECT p.*

    FROM {{ ref('int_locker_period_metrics') }} p

    INNER JOIN balanced_facilities b
        USING (locker_stat_id)

),


-- ============================================================
-- 3. 자치구 × 기간
-- ============================================================

district_period AS (

    SELECT

        district,
        year,
        period,
        period_label,

        COUNT(DISTINCT locker_stat_id)
            AS balanced_facility_count,

        AVG(calculated_monthly_avg_usage)
            AS avg_monthly_usage_per_facility,

        SUM(calculated_monthly_avg_usage)
            AS district_monthly_usage,

        SAFE_DIVIDE(
            SUM(calculated_monthly_avg_usage),
            SUM(locker_count)
        ) AS weighted_monthly_usage_per_locker

    FROM panel

    GROUP BY
        district,
        year,
        period,
        period_label
),


-- ============================================================
-- 4. 자치구별 연도 Pivot
-- ============================================================

district_pivot AS (

    SELECT

        district,

        MAX(balanced_facility_count)
            AS balanced_facility_count,


        MAX(
            IF(
                year = 2021,
                avg_monthly_usage_per_facility,
                NULL
            )
        ) AS avg_monthly_usage_2021,


        MAX(
            IF(
                year = 2022,
                avg_monthly_usage_per_facility,
                NULL
            )
        ) AS avg_monthly_usage_2022,


        MAX(
            IF(
                year = 2023,
                avg_monthly_usage_per_facility,
                NULL
            )
        ) AS avg_monthly_usage_2023,


        MAX(
            IF(
                year = 2024,
                avg_monthly_usage_per_facility,
                NULL
            )
        ) AS avg_monthly_usage_2024,


        MAX(
            IF(
                year = 2025,
                avg_monthly_usage_per_facility,
                NULL
            )
        ) AS avg_monthly_usage_2025,


        MAX(
            IF(
                period = '2026_h1',
                avg_monthly_usage_per_facility,
                NULL
            )
        ) AS avg_monthly_usage_2026_h1,


        MAX(
            IF(
                year = 2021,
                weighted_monthly_usage_per_locker,
                NULL
            )
        ) AS locker_efficiency_2021,


        MAX(
            IF(
                year = 2025,
                weighted_monthly_usage_per_locker,
                NULL
            )
        ) AS locker_efficiency_2025,


        MAX(
            IF(
                period = '2026_h1',
                weighted_monthly_usage_per_locker,
                NULL
            )
        ) AS locker_efficiency_2026_h1

    FROM district_period

    GROUP BY district
),


-- ============================================================
-- 5. 변화율
-- ============================================================

calculated AS (

    SELECT
        *,

        SAFE_MULTIPLY(
            SAFE_DIVIDE(
                avg_monthly_usage_2025
                    - avg_monthly_usage_2021,
                avg_monthly_usage_2021
            ),
            100
        ) AS usage_change_2021_2025_pct,


        SAFE_MULTIPLY(
            SAFE_DIVIDE(
                avg_monthly_usage_2025
                    - avg_monthly_usage_2024,
                avg_monthly_usage_2024
            ),
            100
        ) AS usage_change_2024_2025_pct,


        SAFE_MULTIPLY(
            SAFE_DIVIDE(
                locker_efficiency_2025
                    - locker_efficiency_2021,
                locker_efficiency_2021
            ),
            100
        ) AS efficiency_change_2021_2025_pct

    FROM district_pivot
),


-- ============================================================
-- 6. 추세 분류
-- ============================================================

classified AS (

    SELECT
        *,

        CASE
            WHEN balanced_facility_count >= 8
                THEN 'high'
            WHEN balanced_facility_count >= 5
                THEN 'medium'
            ELSE 'limited'
        END AS trend_data_confidence,


        CASE
            WHEN usage_change_2021_2025_pct >= 5
                THEN '장기 증가'
            WHEN usage_change_2021_2025_pct <= -5
                THEN '장기 감소'
            ELSE '대체로 유지'
        END AS long_term_trend,


        CASE
            WHEN usage_change_2024_2025_pct >= 5
                THEN '최근 증가'
            WHEN usage_change_2024_2025_pct <= -5
                THEN '최근 감소'
            ELSE '최근 유지'
        END AS recent_trend

    FROM calculated
)


SELECT *
FROM classified