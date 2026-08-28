-- ============================================================
-- Reconciliation Test
-- 기존 수작업 SQL vs dbt int_locker_period_metrics
-- ============================================================
--
-- 차이가 0행이면 PASS
-- ============================================================


WITH manual_result AS (

    SELECT
        locker_stat_id,
        facility_entity_id,
        period,
        year,
        period_end,

        district,
        facility_name,
        operation_status,

        installed_year,
        removed_year,
        locker_count,

        is_in_current_location_source,
        source_match_status,
        facility_analysis_status,
        current_vs_metrics_status_conflict,

        months_observed,
        is_partial_year,
        period_completeness,

        usage_count,
        monthly_avg_usage,
        calculated_monthly_avg_usage,
        usage_per_locker,
        monthly_usage_per_locker,

        occupancy_rate,
        occupancy_rate_pct,

        has_occupancy_observation,
        has_usage_observation,

        period_label,

        usable_for_annual_total_comparison,
        usable_for_monthly_comparison,

        installed_year_conflict,
        data_quality_status,
        has_quality_issue

    FROM
        `mission17-locker-jh-2608.analytics_seoul_locker.int_locker_period_metrics`

),


dbt_result AS (

    SELECT
        locker_stat_id,
        facility_entity_id,
        period,
        year,
        period_end,

        district,
        facility_name,
        operation_status,

        installed_year,
        removed_year,
        locker_count,

        is_in_current_location_source,
        source_match_status,
        facility_analysis_status,
        current_vs_metrics_status_conflict,

        months_observed,
        is_partial_year,
        period_completeness,

        usage_count,
        monthly_avg_usage,
        calculated_monthly_avg_usage,
        usage_per_locker,
        monthly_usage_per_locker,

        occupancy_rate,
        occupancy_rate_pct,

        has_occupancy_observation,
        has_usage_observation,

        period_label,

        usable_for_annual_total_comparison,
        usable_for_monthly_comparison,

        installed_year_conflict,
        data_quality_status,
        has_quality_issue

    FROM {{ ref('int_locker_period_metrics') }}

),


manual_only AS (

    SELECT *
    FROM manual_result

    EXCEPT DISTINCT

    SELECT *
    FROM dbt_result

),


dbt_only AS (

    SELECT *
    FROM dbt_result

    EXCEPT DISTINCT

    SELECT *
    FROM manual_result

)


SELECT
    'manual_only' AS difference_type,
    *

FROM manual_only


UNION ALL


SELECT
    'dbt_only' AS difference_type,
    *

FROM dbt_only