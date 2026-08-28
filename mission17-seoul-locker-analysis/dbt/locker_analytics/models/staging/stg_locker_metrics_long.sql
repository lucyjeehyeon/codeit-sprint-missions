-- ============================================================
-- dbt Staging Model
-- stg_locker_metrics_long
-- ============================================================
-- Grain:
--   locker_stat_id × period = 1행
-- ============================================================

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
    occupancy_rate,
    usage_count,
    year,
    period_end,
    months_observed,
    is_partial_year,
    installed_year_conflict,
    data_quality_status,
    occupancy_rate_pct,
    monthly_avg_usage

FROM {{ source('locker_source', 'stg_locker_metrics_long') }}