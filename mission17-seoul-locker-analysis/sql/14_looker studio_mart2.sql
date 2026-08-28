CREATE OR REPLACE VIEW
`mission17-locker-jh-2608.analytics_seoul_locker.mart_facility_dashboard`
AS

WITH base AS (

    SELECT
        locker_stat_id,
        district,
        facility_name,

        CONCAT(
            district,
            ' · ',
            facility_name
        ) AS facility_display_name,

        address,

        CASE
            WHEN address IS NULL THEN NULL
            ELSE CONCAT(address, ', 대한민국')
        END AS map_address,

        operation_status,
        installed_year,
        locker_count,
        snapshot_date,
        period,
        year,
        period_end,
        months_observed,
        data_quality_status,
        occupancy_rate_pct,
        monthly_avg_usage,
        installed_year_conflict,

        SAFE_DIVIDE(
            monthly_avg_usage,
            locker_count
        ) AS monthly_usage_per_locker

    FROM
        `mission17-locker-jh-2608.analytics_seoul_locker.stg_locker_metrics_long`

    WHERE
        year = 2026
        AND removed_year IS NULL
),

benchmarked AS (

    SELECT
        *,

        PERCENTILE_CONT(
            CAST(locker_count AS FLOAT64),
            0.5
        ) OVER () AS median_locker_count,

        PERCENTILE_CONT(
            monthly_avg_usage,
            0.5
        ) OVER () AS median_monthly_usage,

        PERCENTILE_CONT(
            monthly_usage_per_locker,
            0.25
        ) OVER () AS efficiency_q1,

        PERCENTILE_CONT(
            monthly_usage_per_locker,
            0.5
        ) OVER () AS median_efficiency,

        PERCENTILE_CONT(
            monthly_usage_per_locker,
            0.75
        ) OVER () AS efficiency_q3

    FROM base
)

SELECT
    *,

    -- 지도에서 모든 시설 점을 같은 크기로 표시
    1 AS map_marker_size,

    -- 서울 중앙값을 100으로 환산한 시설 프로필
    ROUND(
        100 * SAFE_DIVIDE(
            locker_count,
            median_locker_count
        ),
        1
    ) AS locker_count_index,

    ROUND(
        100 * SAFE_DIVIDE(
            monthly_avg_usage,
            median_monthly_usage
        ),
        1
    ) AS monthly_usage_index,

    ROUND(
        100 * SAFE_DIVIDE(
            monthly_usage_per_locker,
            median_efficiency
        ),
        1
    ) AS efficiency_index,

    -- 시설의 상대적 프로필
    CASE
        WHEN monthly_usage_per_locker IS NULL
            THEN '데이터 확인'

        WHEN
            monthly_usage_per_locker >= efficiency_q3
            AND locker_count < median_locker_count
            THEN '소규모 고효율'

        WHEN monthly_usage_per_locker >= efficiency_q3
            THEN '대규모 고효율'

        WHEN
            monthly_usage_per_locker <= efficiency_q1
            AND locker_count >= median_locker_count
            THEN '대규모 저효율'

        WHEN monthly_usage_per_locker <= efficiency_q1
            THEN '소규모 저효율'

        ELSE '중간 효율'
    END AS facility_profile_type,

    CASE
        WHEN monthly_avg_usage IS NULL
            THEN '이용 데이터 확인'

        WHEN occupancy_rate_pct IS NULL
            THEN '점유율 미관측'

        ELSE '주요 지표 관측'
    END AS metric_data_status

FROM benchmarked;