
  
    

  create  table "wetter_strom"."public_analytics"."daily_summary__dbt_tmp"
  
  
    as
  
  (
    -- Tagesaggregation fuer Dashboards

WITH hourly AS (
    SELECT * FROM "wetter_strom"."public_analytics"."weather_energy_hourly"
)

SELECT
    datum,
    region_name,
    saison,

    -- Wetter
    ROUND(AVG(temperature_2m)::numeric, 1)       AS avg_temperatur,
    ROUND(MAX(temperature_2m)::numeric, 1)       AS max_temperatur,
    ROUND(MIN(temperature_2m)::numeric, 1)       AS min_temperatur,
    ROUND(AVG(windspeed_100m)::numeric, 1)       AS avg_windgeschwindigkeit,
    ROUND(SUM(shortwave_radiation)::numeric, 0)  AS sum_solarstrahlung,

    -- Strom
    ROUND(AVG(wind_gesamt_mw)::numeric, 0)       AS avg_wind_mw,
    ROUND(AVG(solar_mw)::numeric, 0)             AS avg_solar_mw,
    ROUND(AVG(erneuerbar_gesamt_mw)::numeric, 0) AS avg_erneuerbar_mw,

    -- Preise
    ROUND(AVG(avg_price_eur_mwh)::numeric, 2)   AS avg_preis_eur,
    ROUND(MIN(avg_price_eur_mwh)::numeric, 2)   AS min_preis_eur,
    ROUND(MAX(avg_price_eur_mwh)::numeric, 2)   AS max_preis_eur

FROM hourly
GROUP BY datum, region_name, saison
  );
  