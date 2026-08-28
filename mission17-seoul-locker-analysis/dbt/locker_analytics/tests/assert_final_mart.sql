-- ============================================================
-- Final Mart QA
-- ============================================================

WITH qa AS (

    SELECT

        COUNT(*) AS row_count,

        COUNT(DISTINCT district)
            AS district_count,

        COUNTIF(
            final_action_label IS NULL
        ) AS missing_action_count,


        COUNTIF(
            action_tier = 1
            AND final_evidence_strength = 'limited'
        ) AS limited_tier1_count,


        COUNTIF(
            action_tier = 1
            AND has_trend_signal_conflict = TRUE
        ) AS conflict_tier1_count

    FROM {{ ref('mart_district_final') }}

)

SELECT *
FROM qa

WHERE
       row_count != 25
    OR district_count != 25
    OR missing_action_count != 0
    OR limited_tier1_count != 0
    OR conflict_tier1_count != 0