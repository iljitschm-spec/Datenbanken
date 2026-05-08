-- Bereinigung der SMARD-Erzeugungsdaten
-- Quelle: raw.smard_generation (SMARD API)

WITH source AS (
    SELECT * FROM "wetter_strom"."raw"."smard_generation"
),

cleaned AS (
    SELECT
        timestamp,
        COALESCE(biomass, 0)        AS biomass_mw,
        COALESCE(hydro, 0)          AS hydro_mw,
        COALESCE(wind_offshore, 0)  AS wind_offshore_mw,
        COALESCE(wind_onshore, 0)   AS wind_onshore_mw,
        COALESCE(solar, 0)          AS solar_mw,

        -- Berechnete Felder
        COALESCE(wind_offshore, 0) + COALESCE(wind_onshore, 0)  AS wind_gesamt_mw,
        COALESCE(wind_offshore, 0) + COALESCE(wind_onshore, 0)
            + COALESCE(solar, 0)                                 AS erneuerbar_gesamt_mw

    FROM source
    WHERE timestamp IS NOT NULL
)

SELECT * FROM cleaned