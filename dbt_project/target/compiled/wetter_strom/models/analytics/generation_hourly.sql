-- SMARD-Erzeugung aggregiert auf Stundenbasis

WITH src AS (
    SELECT * FROM "wetter_strom"."public_staging"."stg_smard_generation"
)

SELECT
    date_trunc('hour', timestamp)   AS timestamp_hour,
    ROUND(AVG(biomass_mw)::numeric, 2)           AS biomass_mw,
    ROUND(AVG(hydro_mw)::numeric, 2)             AS hydro_mw,
    ROUND(AVG(wind_offshore_mw)::numeric, 2)     AS wind_offshore_mw,
    ROUND(AVG(wind_onshore_mw)::numeric, 2)      AS wind_onshore_mw,
    ROUND(AVG(solar_mw)::numeric, 2)             AS solar_mw,
    ROUND(AVG(wind_gesamt_mw)::numeric, 2)       AS wind_gesamt_mw,
    ROUND(AVG(erneuerbar_gesamt_mw)::numeric, 2) AS erneuerbar_gesamt_mw
FROM src
GROUP BY date_trunc('hour', timestamp)