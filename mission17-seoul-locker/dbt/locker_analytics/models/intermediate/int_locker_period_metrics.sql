-- ============================================================
-- Intermediate Model
-- int_locker_period_metrics
-- ============================================================
--
-- Grain:
--   locker_stat_id × period = 1행
--
-- 목적:
--   1. 시설별 기간 실적에 Facility Master 정보 연결
--   2. 관측기간과 보관함 규모를 보정한 이용지표 생성
--   3. 완결연도와 2026 H1을 구분
--   4. 점유율 / 이용건수 관측 가능 여부 관리
--
-- Materialization:
--   TABLE
-- ============================================================


WITH metrics AS (

    SELECT
        locker_stat_id,
        district,
        facility_name,
        address,
        operation_status,

        installed_year,
        removed_year,
        locker_count,

        snapshot_date,
        period,
        year,
        period_end,

        months_observed,
        is_partial_year,

        occupancy_rate,
        occupancy_rate_pct,

        usage_count,
        monthly_avg_usage,

        installed_year_conflict,
        data_quality_status

    FROM {{ ref('stg_locker_metrics_long') }}

),


joined AS (

    SELECT

        -- ====================================================
        -- 식별자
        -- ====================================================

        m.locker_stat_id,
        f.facility_entity_id,

        m.period,
        m.year,
        m.period_end,


        -- ====================================================
        -- 시설 정보
        -- ====================================================

        m.district,
        m.facility_name,
        m.address,

        m.operation_status,

        m.installed_year,
        m.removed_year,
        m.locker_count,


        -- ====================================================
        -- Facility Master 정보
        -- ====================================================

        f.is_in_current_location_source,

        f.latitude,
        f.longitude,

        f.source_match_status,
        f.facility_analysis_status,

        f.current_vs_metrics_status_conflict,


        -- ====================================================
        -- 관측기간 정보
        -- ====================================================

        m.snapshot_date,
        m.months_observed,
        m.is_partial_year,


        CASE

            WHEN
                m.is_partial_year = FALSE
                AND m.months_observed = 12

                THEN 'full_year'

            WHEN
                m.is_partial_year = TRUE

                THEN 'partial_year'

            ELSE 'other'

        END AS period_completeness,


        -- ====================================================
        -- 이용건수
        -- ====================================================

        m.usage_count,


        -- Python 전처리에서 만든 월평균 값
        m.monthly_avg_usage,


        -- ====================================================
        -- BigQuery에서 월평균 재계산
        -- ====================================================

        SAFE_DIVIDE(
            m.usage_count,
            m.months_observed
        ) AS calculated_monthly_avg_usage,


        -- ====================================================
        -- 함당 이용건수
        -- ====================================================

        SAFE_DIVIDE(
            m.usage_count,
            m.locker_count
        ) AS usage_per_locker,


        -- ====================================================
        -- 함당 월평균 이용건수
        -- ====================================================
        -- 시설 규모와 관측기간을 동시에 보정
        -- ====================================================

        SAFE_DIVIDE(
            SAFE_DIVIDE(
                m.usage_count,
                m.months_observed
            ),
            m.locker_count
        ) AS monthly_usage_per_locker,


        -- ====================================================
        -- 점유율
        -- ====================================================

        m.occupancy_rate,
        m.occupancy_rate_pct,


        m.occupancy_rate IS NOT NULL
            AS has_occupancy_observation,


        -- ====================================================
        -- 이용건수 관측 여부
        -- ====================================================

        m.usage_count IS NOT NULL
            AS has_usage_observation,


        -- ====================================================
        -- 기간 표시
        -- ====================================================

        CASE

            WHEN m.period = '2026_h1'
                THEN '2026 H1'

            ELSE CAST(m.year AS STRING)

        END AS period_label,


        -- ====================================================
        -- 연간 총량 직접 비교 가능 여부
        -- ====================================================

        CASE

            WHEN
                m.is_partial_year = FALSE
                AND m.months_observed = 12
                AND m.usage_count IS NOT NULL

                THEN TRUE

            ELSE FALSE

        END AS usable_for_annual_total_comparison,


        -- ====================================================
        -- 월평균 비교 가능 여부
        -- ====================================================

        CASE

            WHEN
                m.usage_count IS NOT NULL
                AND m.months_observed > 0

                THEN TRUE

            ELSE FALSE

        END AS usable_for_monthly_comparison,


        -- ====================================================
        -- 품질 정보
        -- ====================================================

        m.installed_year_conflict,
        m.data_quality_status,


        CASE

            WHEN m.installed_year_conflict = TRUE
                THEN TRUE

            WHEN m.data_quality_status != 'ok'
                THEN TRUE

            ELSE FALSE

        END AS has_quality_issue


    FROM metrics m


    LEFT JOIN {{ ref('int_locker_facility_master') }} f

        ON m.locker_stat_id = f.locker_stat_id

)


SELECT *
FROM joined