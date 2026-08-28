-- ============================================================
-- STEP 11. 시설 × 기간 실적 Intermediate 생성
-- ============================================================
-- 테이블:
--   int_locker_period_metrics
--
-- Grain:
--   locker_stat_id × period = 1행
--
-- 목적:
-- 1. 원천 실적 데이터에 Facility Master 정보를 연결
-- 2. 총 이용건수뿐 아니라 월·함 규모를 보정한 지표 생성
-- 3. 2026 H1과 완결연도를 안전하게 구분
-- 4. 점유율의 제한된 관측범위를 별도 플래그로 관리
-- ============================================================


CREATE OR REPLACE TABLE
`mission17-locker-jh-2608.analytics_seoul_locker.int_locker_period_metrics`
AS


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

    FROM
        `mission17-locker-jh-2608.analytics_seoul_locker.stg_locker_metrics_long`
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
        -- 현재 위치 Master 정보
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
            WHEN m.is_partial_year = FALSE
                 AND m.months_observed = 12
                THEN 'full_year'

            WHEN m.is_partial_year = TRUE
                THEN 'partial_year'

            ELSE 'other'
        END AS period_completeness,


        -- ====================================================
        -- 이용건수 원지표
        -- ====================================================

        m.usage_count,


        -- ====================================================
        -- 월평균 이용건수
        -- ====================================================
        -- 기존 Python 가공값을 보존하되
        -- BigQuery에서도 재계산하여 검증 가능하도록 생성
        -- ====================================================

        m.monthly_avg_usage,

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
        -- 향후 시설 효율 비교의 핵심 지표
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
        -- 전체 시설이 아닌 일부 25개 시설만 관측됨.
        -- 따라서 메인 KPI가 아니라 보조 분석지표로 사용.
        -- ====================================================

        m.occupancy_rate,
        m.occupancy_rate_pct,

        m.occupancy_rate IS NOT NULL
            AS has_occupancy_observation,


        -- ====================================================
        -- 이용건수 관측 플래그
        -- ====================================================

        m.usage_count IS NOT NULL
            AS has_usage_observation,


        -- ====================================================
        -- 분석용 기간 구분
        -- ====================================================

        CASE
            WHEN m.period = '2026_h1'
                THEN '2026 H1'

            ELSE CAST(m.year AS STRING)
        END AS period_label,


        -- ====================================================
        -- 연간 총량 직접 비교 가능 여부
        -- ====================================================
        -- 2026 H1은 6개월 관측이므로
        -- 연간 usage_count 비교에서 제외
        -- ====================================================

        CASE
            WHEN m.is_partial_year = FALSE
                 AND m.months_observed = 12
                 AND m.usage_count IS NOT NULL
                THEN TRUE

            ELSE FALSE
        END AS usable_for_annual_total_comparison,


        -- ====================================================
        -- 월평균 비교 가능 여부
        -- ====================================================

        CASE
            WHEN m.usage_count IS NOT NULL
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

    LEFT JOIN
        `mission17-locker-jh-2608.analytics_seoul_locker.int_locker_facility_master` f

        ON m.locker_stat_id = f.locker_stat_id
)


SELECT
    *

FROM joined;

-- ============================================================
-- STEP 11 QA
-- ============================================================


-- ------------------------------------------------------------
-- 1. 원천 행 수 보존
-- ------------------------------------------------------------

ASSERT (

    SELECT COUNT(*) = 1656

    FROM
        `mission17-locker-jh-2608.analytics_seoul_locker.int_locker_period_metrics`

) AS '시설×기간 Intermediate 행 수가 1,656개가 아닙니다.';


-- ------------------------------------------------------------
-- 2. Grain 중복 검사
-- ------------------------------------------------------------

ASSERT (

    SELECT
        COUNT(*)
        =
        COUNT(
            DISTINCT CONCAT(
                locker_stat_id,
                '||',
                period
            )
        )

    FROM
        `mission17-locker-jh-2608.analytics_seoul_locker.int_locker_period_metrics`

) AS 'locker_stat_id × period가 중복되었습니다.';


-- ------------------------------------------------------------
-- 3. Facility Master 연결 누락 검사
-- ------------------------------------------------------------

ASSERT (

    SELECT
        COUNTIF(facility_entity_id IS NULL) = 0

    FROM
        `mission17-locker-jh-2608.analytics_seoul_locker.int_locker_period_metrics`

) AS 'Facility Master와 연결되지 않은 실적 시설이 있습니다.';


-- ------------------------------------------------------------
-- 4. 월평균 이용건수 계산값 일치 검사
-- ------------------------------------------------------------
-- Python에서 계산된 monthly_avg_usage와
-- BigQuery 재계산값이 실질적으로 같은지 확인
-- 부동소수점 오차를 고려하여 0.0001 이하 허용
-- ------------------------------------------------------------

ASSERT (

    SELECT
        COUNTIF(
            monthly_avg_usage IS NOT NULL
            AND calculated_monthly_avg_usage IS NOT NULL
            AND ABS(
                monthly_avg_usage
                - calculated_monthly_avg_usage
            ) > 0.0001
        ) = 0

    FROM
        `mission17-locker-jh-2608.analytics_seoul_locker.int_locker_period_metrics`

) AS '월평균 이용건수 계산값이 Python 결과와 일치하지 않습니다.';


-- ============================================================
-- 결과 확인
-- ============================================================

SELECT
    period_label,

    COUNT(*) AS total_rows,

    COUNTIF(
        has_usage_observation
    ) AS usage_observed_rows,

    COUNTIF(
        has_occupancy_observation
    ) AS occupancy_observed_rows,

    COUNTIF(
        usable_for_annual_total_comparison
    ) AS annual_comparison_rows,

    COUNTIF(
        usable_for_monthly_comparison
    ) AS monthly_comparison_rows,

    COUNTIF(
        has_quality_issue
    ) AS quality_issue_rows,

    ROUND(
        AVG(monthly_avg_usage),
        2
    ) AS avg_monthly_usage,

    ROUND(
        AVG(monthly_usage_per_locker),
        2
    ) AS avg_monthly_usage_per_locker

FROM
    `mission17-locker-jh-2608.analytics_seoul_locker.int_locker_period_metrics`

GROUP BY
    period_label,
    year

ORDER BY
    year;