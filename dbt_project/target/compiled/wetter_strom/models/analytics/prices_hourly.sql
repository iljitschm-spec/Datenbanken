-- SMARD-Preise aggregiert auf Stundenbasis

WITH src AS (
    SELECT * FROM "wetter_strom"."public_staging"."stg_smard_prices"
)

SELECT
    date_trunc('hour', timestamp)                  AS timestamp_hour,
    ROUND(AVG(price_eur_mwh)::numeric, 2)          AS avg_price_eur_mwh,
    ROUND(MIN(price_eur_mwh)::numeric, 2)          AS min_price_eur_mwh,
    ROUND(MAX(price_eur_mwh)::numeric, 2)          AS max_price_eur_mwh
FROM src
GROUP BY date_trunc('hour', timestamp)