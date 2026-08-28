-- ============================================================
-- dbt Staging Model
-- stg_households_by_age
-- ============================================================
-- Grain:
--   district × age_group = 1행
-- ============================================================

SELECT
    district,
    age_group,
    one_person_households,
    reference_year,
    source_table_id,
    source_name

FROM {{ source('locker_source', 'stg_households_by_age') }}