-- ============================================================
-- Singular Test
-- int_locker_period_metrics Grain 검사
-- ============================================================
--
-- locker_stat_id × period 중복이 존재하면 FAIL
-- 정상이라면 0행 반환 → PASS
-- ============================================================

SELECT
    locker_stat_id,
    period,
    COUNT(*) AS row_count

FROM {{ ref('int_locker_period_metrics') }}

GROUP BY
    locker_stat_id,
    period

HAVING COUNT(*) > 1