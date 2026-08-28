-- ============================================================
-- dbt Staging Model
-- stg_households_district
-- ============================================================
-- Grain:
--   district = 1행
-- ============================================================

SELECT
    district,
    reference_year,
    one_person_total,
    one_person_under_20,
    one_person_age_20_39,
    one_person_age_40_64,
    one_person_age_65_plus,
    age_20_39_share_pct,
    age_65_plus_share_pct,
    age_segment_sum,
    reconciliation_difference,
    source_table_id,
    source_name

FROM {{ source('locker_source', 'stg_households_district') }}