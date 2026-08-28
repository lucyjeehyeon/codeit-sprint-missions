-- ============================================================
-- STEP 14. 동일 시설 Balanced Panel 장기 추세
-- ============================================================
-- 테이블:
--   mart_balanced_panel_trend
--
-- 목적:
--   기간마다 관측 시설 수가 달라 발생할 수 있는
--   구성효과(composition effect)를 제거하고
--   동일 시설의 이용 추세를 비교
--
-- Balanced Panel 기준:
--   2021 ~ 2026 H1 6개 기간 모두
--   usage_count가 존재하는 시설
--
-- 기대 시설 수:
--   202개
--
-- 주의:
--   2026은 H1(6개월)이므로 연간 총량 비교 금지.
--   모든 기간은 월평균 지표를 중심으로 비교.
-- ============================================================


CREATE OR REPLACE TABLE
`mission17-locker-jh-2608.analytics_seoul_locker.mart_balanced_panel_trend`
AS


WITH

-- ============================================================
-- 1. 6개 기간 모두 이용건수가 존재하는 시설 선별
-- ============================================================

balanced_facilities AS (

    SELECT
        locker_stat_id

    FROM
        `mission17-locker-jh-2608.analytics_seoul_locker.int_locker_period_metrics`

    WHERE
        has_usage_observation = TRUE

    GROUP BY
        locker_stat_id

    HAVING
        COUNT(DISTINCT period) = 6
),


-- ============================================================
-- 2. Balanced Panel 데이터
-- ============================================================

panel AS (

    SELECT
        p.*

    FROM
        `mission17-locker-jh-2608.analytics_seoul_locker.int_locker_period_metrics` p

    INNER JOIN balanced_facilities b
        USING (locker_stat_id)

),


-- ============================================================
-- 3. 기간별 동일 시설 집계
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


        -- ----------------------------------------------------
        -- 해당 기간 실제 총 이용건수
        -- ----------------------------------------------------

        SUM(
            usage_count
        ) AS total_usage,


        -- ----------------------------------------------------
        -- 시설별 월평균 이용건수의 평균
        -- ----------------------------------------------------

        AVG(
            calculated_monthly_avg_usage
        ) AS avg_monthly_usage_per_facility,


        -- ----------------------------------------------------
        -- 동일 시설 전체 월평균 이용량
        -- ----------------------------------------------------

        SUM(
            calculated_monthly_avg_usage
        ) AS total_monthly_usage,


        -- ----------------------------------------------------
        -- 함 개수를 고려한 가중 이용효율
        -- ----------------------------------------------------

        SAFE_DIVIDE(

            SUM(
                calculated_monthly_avg_usage
            ),

            SUM(
                locker_count
            )

        ) AS weighted_monthly_usage_per_locker,


        -- ----------------------------------------------------
        -- 시설 단위 이용효율 분포
        -- ----------------------------------------------------

        APPROX_QUANTILES(
            calculated_monthly_avg_usage,
            100
        )[OFFSET(50)] AS median_monthly_usage_per_facility,


        APPROX_QUANTILES(
            monthly_usage_per_locker,
            100
        )[OFFSET(50)] AS median_monthly_usage_per_locker


    FROM panel

    GROUP BY
        year,
        period,
        period_label,
        months_observed,
        is_partial_year
),


-- ============================================================
-- 4. 전기 변화 계산
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


    -- ========================================================
    -- 전기 대비 시설당 월평균 이용 증감률
    -- ========================================================

    SAFE_MULTIPLY(

        SAFE_DIVIDE(

            avg_monthly_usage_per_facility
            - previous_avg_monthly_usage,

            previous_avg_monthly_usage

        ),

        100

    ) AS monthly_usage_change_pct,


    -- ========================================================
    -- 전기 대비 함당 월평균 이용 증감률
    -- ========================================================

    SAFE_MULTIPLY(

        SAFE_DIVIDE(

            weighted_monthly_usage_per_locker
            - previous_weighted_usage_per_locker,

            previous_weighted_usage_per_locker

        ),

        100

    ) AS locker_efficiency_change_pct,


    -- ========================================================
    -- 비교 해석 플래그
    -- ========================================================

    CASE

        WHEN period = '2026_h1'
            THEN 'H1 월평균 참고 비교 - 계절성 주의'

        ELSE '완결연도 월평균 비교'

    END AS comparison_note


FROM trend;

-- ============================================================
-- STEP 14 QA
-- ============================================================


-- 1. Balanced Panel 시설 수 = 202
ASSERT (

    SELECT
        COUNT(DISTINCT locker_stat_id) = 202

    FROM
        `mission17-locker-jh-2608.analytics_seoul_locker.int_locker_period_metrics`

    WHERE locker_stat_id IN (

        SELECT
            locker_stat_id

        FROM
            `mission17-locker-jh-2608.analytics_seoul_locker.int_locker_period_metrics`

        WHERE
            has_usage_observation = TRUE

        GROUP BY
            locker_stat_id

        HAVING
            COUNT(DISTINCT period) = 6
    )

) AS 'Balanced Panel 시설 수가 202개와 일치하지 않습니다.';


-- 2. 결과 기간은 6개
ASSERT (

    SELECT COUNT(*) = 6

    FROM
        `mission17-locker-jh-2608.analytics_seoul_locker.mart_balanced_panel_trend`

) AS 'Balanced Panel 기간 수가 6개가 아닙니다.';


-- 3. 모든 기간 동일 시설 수 확인
ASSERT (

    SELECT
        COUNTIF(
            balanced_facility_count != 202
        ) = 0

    FROM
        `mission17-locker-jh-2608.analytics_seoul_locker.mart_balanced_panel_trend`

) AS '기간별 Balanced Panel 시설 수가 동일하지 않습니다.';



-- ============================================================
-- 결과 확인
-- ============================================================

SELECT

    period_label,

    balanced_facility_count,

    ROUND(
        avg_monthly_usage_per_facility,
        2
    ) AS avg_monthly_usage_per_facility,

    ROUND(
        median_monthly_usage_per_facility,
        2
    ) AS median_monthly_usage_per_facility,

    ROUND(
        weighted_monthly_usage_per_locker,
        2
    ) AS weighted_monthly_usage_per_locker,

    ROUND(
        median_monthly_usage_per_locker,
        2
    ) AS median_monthly_usage_per_locker,

    ROUND(
        monthly_usage_change_pct,
        2
    ) AS monthly_usage_change_pct,

    ROUND(
        locker_efficiency_change_pct,
        2
    ) AS locker_efficiency_change_pct,

    comparison_note

FROM
    `mission17-locker-jh-2608.analytics_seoul_locker.mart_balanced_panel_trend`

ORDER BY
    year;