-- Bereinigung der SMARD-Preisdaten
-- Quelle: raw.smard_prices (SMARD API)

WITH source AS (
    SELECT * FROM "wetter_strom"."raw"."smard_prices"
),

cleaned AS (
    SELECT
        timestamp,
        COALESCE(price_eur_mwh, 0)  AS price_eur_mwh
    FROM source
    WHERE timestamp IS NOT NULL
      AND price_eur_mwh IS NOT NULL
)

SELECT * FROM cleaned