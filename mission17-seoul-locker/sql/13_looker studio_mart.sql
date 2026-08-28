-- ============================================================
-- Looker Studio 이용 추세 페이지용 Mart
-- 시설 × 기간 단위 Long 구조
-- ============================================================

CREATE OR REPLACE VIEW
`mission17-locker-jh-2608.analytics_seoul_locker.mart_usage_trend`
AS

WITH typed AS (
    SELECT
        CAST(locker_stat_id AS STRING) AS locker_stat_id,
        NULLIF(TRIM(CAST(district AS STRING)), '') AS district,
        CAST(facility_name AS STRING) AS facility_name,

        SAFE_CAST(
            CAST(year AS STRING)
            AS INT64
        ) AS usage_year,

        SAFE_CAST(
            CAST(period_end AS STRING)
            AS DATE
        ) AS period_end,

        SAFE_CAST(
            REPLACE(CAST(monthly_avg_usage AS STRING), ',', '')
            AS FLOAT64
        ) AS monthly_avg_usage,

        SAFE_CAST(
            REPLACE(CAST(usage_count AS STRING), ',', '')
            AS FLOAT64
        ) AS usage_count

    FROM
        `mission17-locker-jh-2608.analytics_seoul_locker.stg_locker_metrics_long`
)

SELECT
    t.locker_stat_id,
    t.district,
    t.facility_name,

    t.usage_year,

    CASE
        WHEN t.usage_year = 2026 THEN '2026 H1'
        ELSE CAST(t.usage_year AS STRING)
    END AS period_label,

    t.usage_year AS period_order,
    t.period_end,

    t.usage_year = 2026 AS is_partial_year,

    t.monthly_avg_usage,

    -- 같은 원천값을 차트의 서로 다른 집계에 사용
    -- SUM: 선택 범위의 월평균 총이용
    t.monthly_avg_usage AS district_monthly_usage_component,

    -- AVG: 관측시설 1곳당 월평균 이용
    t.monthly_avg_usage AS facility_monthly_usage,

    t.usage_count,

    -- 자치구 단위 진단 정보
    d.diagnostic_group_label,
    d.final_action_label,

    -- 시설×기간 Long 데이터에서 자치구별 연도 평균 직접 계산
AVG(
    CASE
        WHEN t.usage_year = 2021
        THEN t.monthly_avg_usage
    END
) OVER (
    PARTITION BY t.district
) AS avg_monthly_usage_2021,

AVG(
    CASE
        WHEN t.usage_year = 2022
        THEN t.monthly_avg_usage
    END
) OVER (
    PARTITION BY t.district
) AS avg_monthly_usage_2022,

AVG(
    CASE
        WHEN t.usage_year = 2023
        THEN t.monthly_avg_usage
    END
) OVER (
    PARTITION BY t.district
) AS avg_monthly_usage_2023,

AVG(
    CASE
        WHEN t.usage_year = 2024
        THEN t.monthly_avg_usage
    END
) OVER (
    PARTITION BY t.district
) AS avg_monthly_usage_2024,

AVG(
    CASE
        WHEN t.usage_year = 2025
        THEN t.monthly_avg_usage
    END
) OVER (
    PARTITION BY t.district
) AS avg_monthly_usage_2025,

AVG(
    CASE
        WHEN t.usage_year = 2026
        THEN t.monthly_avg_usage
    END
) OVER (
    PARTITION BY t.district
) AS avg_monthly_usage_2026_h1,

    d.usage_change_2021_2025_pct,
    d.usage_change_2024_2025_pct,

    d.long_term_trend,
    d.recent_trend,
    d.has_trend_signal_conflict

FROM typed AS t

LEFT JOIN
    `mission17-locker-jh-2608.analytics_seoul_locker.mart_district_final` AS d
ON t.district = d.district

WHERE
    t.district IS NOT NULL
    AND t.period_end IS NOT NULL
    AND t.usage_year BETWEEN 2021 AND 2026;

SELECT
    COUNT(*) AS row_count,
    COUNT(DISTINCT district) AS district_count,
    COUNT(DISTINCT period_label) AS period_count,
    COUNT(monthly_avg_usage) AS valid_usage_count
FROM
    `mission17-locker-jh-2608.analytics_seoul_locker.mart_usage_trend`;