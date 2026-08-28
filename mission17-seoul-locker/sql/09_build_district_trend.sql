-- ============================================================
-- STEP 15. 자치구별 Balanced Panel 장기 이용 추세
-- ============================================================
-- 테이블:
--   mart_district_trend
--
-- Grain:
--   자치구 1개 = 1행
--
-- 분석 목적:
--   시설 구성 변화의 영향을 줄이기 위해
--   2021~2026 H1 모든 기간에 이용건수가 존재하는
--   동일 시설(Balanced Panel)만 사용하여
--   자치구별 장기 이용 추세를 비교
--
-- 핵심 장기 비교:
--   2021 ~ 2025 완결연도
--
-- 2026 H1:
--   최신 월평균 참고값으로만 별도 보존
-- ============================================================


CREATE OR REPLACE TABLE
`mission17-locker-jh-2608.analytics_seoul_locker.mart_district_trend`
AS


WITH

-- ============================================================
-- 1. 6기간 모두 이용건수가 존재하는 동일 시설 202개
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
-- 2. Balanced Panel 원자료
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
-- 3. 자치구 × 기간 집계
-- ============================================================

district_period AS (

    SELECT

        district,
        year,
        period,
        period_label,

        COUNT(DISTINCT locker_stat_id)
            AS balanced_facility_count,

        AVG(
            calculated_monthly_avg_usage
        ) AS avg_monthly_usage_per_facility,

        SUM(
            calculated_monthly_avg_usage
        ) AS district_monthly_usage,

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
-- 4. 자치구별 기준연도 Pivot
-- ============================================================

district_pivot AS (

    SELECT

        district,

        -- 자치구 내 Balanced Panel 시설 수
        MAX(
            balanced_facility_count
        ) AS balanced_facility_count,


        -- ----------------------------------------------------
        -- 시설당 월평균 이용
        -- ----------------------------------------------------

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


        -- ----------------------------------------------------
        -- 함당 월평균 이용효율
        -- ----------------------------------------------------

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

    GROUP BY
        district
),


-- ============================================================
-- 5. 장기 변화 계산
-- ============================================================

calculated AS (

    SELECT
        *,


        -- ----------------------------------------------------
        -- 2021 → 2025 시설당 월평균 이용 변화율
        -- ----------------------------------------------------

        SAFE_MULTIPLY(
            SAFE_DIVIDE(
                avg_monthly_usage_2025
                - avg_monthly_usage_2021,

                avg_monthly_usage_2021
            ),
            100
        ) AS usage_change_2021_2025_pct,


        -- ----------------------------------------------------
        -- 최근 완결연도 2024 → 2025 변화율
        -- ----------------------------------------------------

        SAFE_MULTIPLY(
            SAFE_DIVIDE(
                avg_monthly_usage_2025
                - avg_monthly_usage_2024,

                avg_monthly_usage_2024
            ),
            100
        ) AS usage_change_2024_2025_pct,


        -- ----------------------------------------------------
        -- 2021 → 2025 함당 이용효율 변화율
        -- ----------------------------------------------------

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
-- 6. 장기 추세 분류
-- ============================================================

classified AS (

    SELECT
        *,


        -- ----------------------------------------------------
        -- Balanced Panel 시설 수에 따른 참고 신뢰도
        -- ----------------------------------------------------

        CASE

            WHEN balanced_facility_count >= 8
                THEN 'high'

            WHEN balanced_facility_count >= 5
                THEN 'medium'

            ELSE 'limited'

        END AS trend_data_confidence,


        -- ----------------------------------------------------
        -- 장기 변화 방향
        -- ----------------------------------------------------
        -- ±5% 이내는 큰 변화 없음으로 해석
        -- 이 기준은 정책적 절대 기준이 아니라
        -- 설명을 위한 실무적 tolerance band
        -- ----------------------------------------------------

        CASE

            WHEN usage_change_2021_2025_pct >= 5
                THEN '장기 증가'

            WHEN usage_change_2021_2025_pct <= -5
                THEN '장기 감소'

            ELSE '대체로 유지'

        END AS long_term_trend,


        -- ----------------------------------------------------
        -- 최근 변화 방향
        -- ----------------------------------------------------

        CASE

            WHEN usage_change_2024_2025_pct >= 5
                THEN '최근 증가'

            WHEN usage_change_2024_2025_pct <= -5
                THEN '최근 감소'

            ELSE '최근 유지'

        END AS recent_trend


    FROM calculated
)


SELECT
    *

FROM classified;

-- ============================================================
-- STEP 15 QA
-- ============================================================


-- 1. 서울 25개 자치구가 모두 존재
ASSERT (

    SELECT COUNT(*) = 25

    FROM
        `mission17-locker-jh-2608.analytics_seoul_locker.mart_district_trend`

) AS '자치구 Trend Mart가 25행이 아닙니다.';


-- 2. 자치구 중복 없음
ASSERT (

    SELECT
        COUNT(*) = COUNT(DISTINCT district)

    FROM
        `mission17-locker-jh-2608.analytics_seoul_locker.mart_district_trend`

) AS 'Trend Mart에서 자치구가 중복되었습니다.';


-- 3. Balanced Panel 시설 수 총합 = 202
ASSERT (

    SELECT
        SUM(balanced_facility_count) = 202

    FROM
        `mission17-locker-jh-2608.analytics_seoul_locker.mart_district_trend`

) AS '자치구별 Balanced Panel 시설 합계가 202개가 아닙니다.';


-- 4. 핵심 완결연도 값 결측 검사
ASSERT (

    SELECT
        COUNTIF(
            avg_monthly_usage_2021 IS NULL
            OR avg_monthly_usage_2025 IS NULL
        ) = 0

    FROM
        `mission17-locker-jh-2608.analytics_seoul_locker.mart_district_trend`

) AS '2021 또는 2025 이용지표가 없는 자치구가 있습니다.';



-- ============================================================
-- 결과 확인
-- ============================================================

SELECT

    district,

    balanced_facility_count,

    trend_data_confidence,

    ROUND(
        avg_monthly_usage_2021,
        1
    ) AS avg_monthly_usage_2021,

    ROUND(
        avg_monthly_usage_2025,
        1
    ) AS avg_monthly_usage_2025,

    ROUND(
        avg_monthly_usage_2026_h1,
        1
    ) AS avg_monthly_usage_2026_h1,

    ROUND(
        usage_change_2021_2025_pct,
        1
    ) AS change_2021_2025_pct,

    long_term_trend,

    ROUND(
        usage_change_2024_2025_pct,
        1
    ) AS change_2024_2025_pct,

    recent_trend,

    ROUND(
        efficiency_change_2021_2025_pct,
        1
    ) AS efficiency_change_2021_2025_pct

FROM
    `mission17-locker-jh-2608.analytics_seoul_locker.mart_district_trend`

ORDER BY
    usage_change_2021_2025_pct DESC;