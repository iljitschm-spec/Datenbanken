
  create view "wetter_strom"."public_staging"."stg_weather_hourly__dbt_tmp"
    
    
  as (
    -- Bereinigung der Wetterdaten
-- Quelle: raw.weather_hourly (Open-Meteo API)

WITH source AS (
    SELECT * FROM "wetter_strom"."raw"."weather_hourly"
),

cleaned AS (
    SELECT
        timestamp,
        region_name,

        -- NULL-Werte mit 0 ersetzen
        COALESCE(temperature_2m, 0)         AS temperature_2m,
        COALESCE(windspeed_100m, 0)         AS windspeed_100m,
        COALESCE(shortwave_radiation, 0)    AS shortwave_radiation,

        -- Zeitdimensionen
        DATE(timestamp)                     AS datum,
        EXTRACT(YEAR FROM timestamp)::int   AS jahr,
        EXTRACT(MONTH FROM timestamp)::int  AS monat,
        EXTRACT(HOUR FROM timestamp)::int   AS stunde,
        EXTRACT(DOW FROM timestamp)::int    AS wochentag,
        CASE
            WHEN EXTRACT(MONTH FROM timestamp) IN (3,4,5)  THEN 'Fruehling'
            WHEN EXTRACT(MONTH FROM timestamp) IN (6,7,8)  THEN 'Sommer'
            WHEN EXTRACT(MONTH FROM timestamp) IN (9,10,11) THEN 'Herbst'
            ELSE 'Winter'
        END AS saison

    FROM source
    WHERE timestamp IS NOT NULL
)

SELECT * FROM cleaned
  );