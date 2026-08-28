-- ============================================================
-- Reconciliation Test
-- 기존 수작업 SQL 결과 vs dbt 리팩터링 결과
-- ============================================================
--
-- 목적:
--   기존 BigQuery에서 직접 생성한 Facility Master와
--   dbt로 재구성한 Facility Master의 핵심 결과가
--   동일한지 검증
--
-- dbt singular test:
--   차이가 0행이면 PASS
--   차이가 하나라도 있으면 FAIL
-- ============================================================


WITH

-- ============================================================
-- 1. 기존 수작업 SQL 결과
-- ============================================================

manual_result AS (

    SELECT
        facility_entity_id,
        locker_id,
        locker_stat_id,
        district,
        facility_name,

        is_in_current_location_source,
        has_metrics_history,

        metrics_operation_status,

        installed_year,
        removed_year,
        locker_count,

        metric_period_count,
        usage_period_count,
        occupancy_period_count,

        installed_year_conflict,
        has_metrics_quality_issue,

        source_match_status,
        current_vs_metrics_status_conflict,
        facility_analysis_status,

        has_usage_data,
        has_occupancy_data,

        include_current_supply_analysis,
        include_usage_history_analysis

    FROM
        `mission17-locker-jh-2608.analytics_seoul_locker.int_locker_facility_master`

),


-- ============================================================
-- 2. dbt 결과
-- ============================================================

dbt_result AS (

    SELECT
        facility_entity_id,
        locker_id,
        locker_stat_id,
        district,
        facility_name,

        is_in_current_location_source,
        has_metrics_history,

        metrics_operation_status,

        installed_year,
        removed_year,
        locker_count,

        metric_period_count,
        usage_period_count,
        occupancy_period_count,

        installed_year_conflict,
        has_metrics_quality_issue,

        source_match_status,
        current_vs_metrics_status_conflict,
        facility_analysis_status,

        has_usage_data,
        has_occupancy_data,

        include_current_supply_analysis,
        include_usage_history_analysis

    FROM {{ ref('int_locker_facility_master') }}

),


-- ============================================================
-- 3. 기존 결과에만 존재하는 행
-- ============================================================

manual_only AS (

    SELECT *
    FROM manual_result

    EXCEPT DISTINCT

    SELECT *
    FROM dbt_result

),


-- ============================================================
-- 4. dbt 결과에만 존재하는 행
-- ============================================================

dbt_only AS (

    SELECT *
    FROM dbt_result

    EXCEPT DISTINCT

    SELECT *
    FROM manual_result

)


-- ============================================================
-- 5. 차이가 있는 행만 반환
-- ============================================================

SELECT
    'manual_only' AS difference_type,
    *

FROM manual_only


UNION ALL


SELECT
    'dbt_only' AS difference_type,
    *

FROM dbt_only