-- ============================================================
-- Singular Test
-- staging grain 및 데이터 정합성 검사
-- ============================================================
--
-- dbt singular test는
-- "문제가 있는 행을 반환하는 SQL"을 작성한다.
--
-- 결과가 0행이면 PASS
-- 한 행이라도 나오면 FAIL
-- ============================================================


-- ------------------------------------------------------------
-- 1. 실적 데이터
-- locker_stat_id × period 중복 검사
-- ------------------------------------------------------------

SELECT
    'metrics_grain_duplicate' AS issue,
    locker_stat_id AS key_1,
    CAST(period AS STRING) AS key_2,
    COUNT(*) AS row_count

FROM {{ ref('stg_locker_metrics_long') }}

GROUP BY
    locker_stat_id,
    period

HAVING COUNT(*) > 1


UNION ALL


-- ------------------------------------------------------------
-- 2. 연령별 1인가구
-- district × age_group 중복 검사
-- ------------------------------------------------------------

SELECT
    'households_age_grain_duplicate' AS issue,
    district AS key_1,
    age_group AS key_2,
    COUNT(*) AS row_count

FROM {{ ref('stg_households_by_age') }}

GROUP BY
    district,
    age_group

HAVING COUNT(*) > 1


UNION ALL


-- ------------------------------------------------------------
-- 3. 자치구별 1인가구
-- 연령구간 합계와 전체 값 불일치 검사
-- ------------------------------------------------------------

SELECT
    'household_reconciliation_error' AS issue,
    district AS key_1,
    CAST(reference_year AS STRING) AS key_2,
    reconciliation_difference AS row_count

FROM {{ ref('stg_households_district') }}

WHERE reconciliation_difference != 0