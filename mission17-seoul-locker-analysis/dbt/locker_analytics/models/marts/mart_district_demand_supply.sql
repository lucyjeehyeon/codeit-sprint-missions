-- ============================================================
-- Mart Model
-- mart_district_demand_supply
-- ============================================================
--
-- Grain:
--   서울시 자치구 1개 = 1행
--
-- 기준:
--   잠재수요 : 2025년 1인가구
--   현재공급 : 2026-08-26 위치 데이터
--   실제이용 : 2026 H1
--
-- 목적:
--   자치구별 잠재수요, 현재 공급, 실제 이용을
--   동일 Grain에서 결합하여 공급압력과 활용수준 진단
--
-- Materialization:
--   TABLE
-- ============================================================


WITH

-- ============================================================
-- 1. 자치구별 1인가구 수요
-- ============================================================

households AS (

    SELECT
        district,

        reference_year AS household_reference_year,

        one_person_total,
        one_person_under_20,
        one_person_age_20_39,
        one_person_age_40_64,
        one_person_age_65_plus,

        age_20_39_share_pct,
        age_65_plus_share_pct

    FROM {{ ref('stg_households_district') }}

),


-- ============================================================
-- 2. 현재 공급
-- ============================================================

current_supply AS (

    SELECT
        district,


        COUNTIF(
            include_current_supply_analysis
        ) AS current_facility_count,


        COUNTIF(
            include_current_supply_analysis
            AND locker_count IS NOT NULL
        ) AS facilities_with_locker_count,


        SUM(
            CASE
                WHEN include_current_supply_analysis
                    THEN locker_count
            END
        ) AS known_locker_count,


        COUNTIF(
            include_current_supply_analysis
            AND source_match_status = 'location_only'
        ) AS location_only_facility_count,


        COUNTIF(
            include_current_supply_analysis
            AND current_vs_metrics_status_conflict = TRUE
        ) AS status_conflict_facility_count,


        COUNTIF(
            include_current_supply_analysis
            AND location_quality_status = 'corrected'
        ) AS corrected_location_count


    FROM {{ ref('int_locker_facility_master') }}

    GROUP BY
        district

),


-- ============================================================
-- 3. 2026 H1 최신 이용실적
-- ============================================================

latest_usage AS (

    SELECT
        district,

        '2026_h1' AS usage_period,


        COUNT(*)
            AS facilities_with_2026h1_metric_row,


        COUNTIF(
            has_usage_observation
        ) AS facilities_with_usage,


        COUNTIF(
            has_occupancy_observation
        ) AS facilities_with_occupancy,


        SUM(
            usage_count
        ) AS total_usage_2026_h1,


        SUM(
            calculated_monthly_avg_usage
        ) AS district_monthly_usage,


        AVG(
            calculated_monthly_avg_usage
        ) AS avg_monthly_usage_per_observed_facility,


        SUM(
            CASE
                WHEN has_usage_observation
                    THEN locker_count
            END
        ) AS locker_count_with_usage_observation,


        SAFE_DIVIDE(

            SUM(
                calculated_monthly_avg_usage
            ),

            SUM(
                CASE
                    WHEN has_usage_observation
                        THEN locker_count
                END
            )

        ) AS weighted_monthly_usage_per_locker,


        AVG(
            occupancy_rate_pct
        ) AS avg_observed_occupancy_rate_pct


    FROM {{ ref('int_locker_period_metrics') }}

    WHERE
        period = '2026_h1'
        AND is_in_current_location_source = TRUE

    GROUP BY
        district

),


-- ============================================================
-- 4. 자치구 Grain에서 결합
-- ============================================================

combined AS (

    SELECT

        -- 기본 정보
        h.district,

        h.household_reference_year,

        DATE '2026-08-26'
            AS supply_reference_date,

        COALESCE(
            u.usage_period,
            '2026_h1'
        ) AS usage_period,


        -- ----------------------------------------------------
        -- 수요
        -- ----------------------------------------------------

        h.one_person_total,

        h.one_person_under_20,
        h.one_person_age_20_39,
        h.one_person_age_40_64,
        h.one_person_age_65_plus,

        h.age_20_39_share_pct,
        h.age_65_plus_share_pct,


        -- ----------------------------------------------------
        -- 현재 공급
        -- ----------------------------------------------------

        COALESCE(
            s.current_facility_count,
            0
        ) AS current_facility_count,

        COALESCE(
            s.facilities_with_locker_count,
            0
        ) AS facilities_with_locker_count,

        COALESCE(
            s.known_locker_count,
            0
        ) AS known_locker_count,

        COALESCE(
            s.location_only_facility_count,
            0
        ) AS location_only_facility_count,

        COALESCE(
            s.status_conflict_facility_count,
            0
        ) AS status_conflict_facility_count,

        COALESCE(
            s.corrected_location_count,
            0
        ) AS corrected_location_count,


        -- ----------------------------------------------------
        -- 실제 이용
        -- ----------------------------------------------------

        COALESCE(
            u.facilities_with_2026h1_metric_row,
            0
        ) AS facilities_with_2026h1_metric_row,

        COALESCE(
            u.facilities_with_usage,
            0
        ) AS facilities_with_usage,

        COALESCE(
            u.facilities_with_occupancy,
            0
        ) AS facilities_with_occupancy,

        COALESCE(
            u.total_usage_2026_h1,
            0
        ) AS total_usage_2026_h1,

        COALESCE(
            u.district_monthly_usage,
            0
        ) AS district_monthly_usage,

        u.avg_monthly_usage_per_observed_facility,

        u.weighted_monthly_usage_per_locker,

        u.avg_observed_occupancy_rate_pct,


        -- ====================================================
        -- 5. 수요 대비 공급
        -- ====================================================

        SAFE_MULTIPLY(

            SAFE_DIVIDE(
                COALESCE(
                    s.current_facility_count,
                    0
                ),
                h.one_person_total
            ),

            10000

        ) AS facilities_per_10k_one_person_households,


        SAFE_MULTIPLY(

            SAFE_DIVIDE(
                COALESCE(
                    s.known_locker_count,
                    0
                ),
                h.one_person_total
            ),

            10000

        ) AS locker_slots_per_10k_one_person_households,


        SAFE_DIVIDE(
            h.one_person_total,
            COALESCE(
                s.current_facility_count,
                0
            )
        ) AS one_person_households_per_facility,


        -- ====================================================
        -- 6. 수요 대비 실제 이용
        -- ====================================================

        SAFE_MULTIPLY(

            SAFE_DIVIDE(
                COALESCE(
                    u.district_monthly_usage,
                    0
                ),
                h.one_person_total
            ),

            10000

        ) AS monthly_usage_per_10k_one_person_households,


        -- ====================================================
        -- 7. 데이터 커버리지
        -- ====================================================

        SAFE_MULTIPLY(

            SAFE_DIVIDE(
                COALESCE(
                    u.facilities_with_usage,
                    0
                ),
                COALESCE(
                    s.current_facility_count,
                    0
                )
            ),

            100

        ) AS usage_coverage_pct,


        SAFE_MULTIPLY(

            SAFE_DIVIDE(
                COALESCE(
                    u.facilities_with_occupancy,
                    0
                ),
                COALESCE(
                    s.current_facility_count,
                    0
                )
            ),

            100

        ) AS occupancy_coverage_pct,


        SAFE_MULTIPLY(

            SAFE_DIVIDE(
                COALESCE(
                    s.facilities_with_locker_count,
                    0
                ),
                COALESCE(
                    s.current_facility_count,
                    0
                )
            ),

            100

        ) AS locker_count_coverage_pct


    FROM households h

    LEFT JOIN current_supply s
        USING (district)

    LEFT JOIN latest_usage u
        USING (district)

)


SELECT *
FROM combined