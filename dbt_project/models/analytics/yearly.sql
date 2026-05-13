WITH hourly AS (
    SELECT * FROM {{ ref('weather_energy_hourly') }}
)

SELECT
    jahr,
    region_name,

    -- Wetter
    ROUND(AVG(temperature_2m)::numeric, 1)        AS avg_temperatur,
    ROUND(AVG(windspeed_100m)::numeric, 1)        AS avg_windgeschwindigkeit,
    ROUND(AVG(shortwave_radiation)::numeric, 1)   AS avg_solarstrahlung,

    -- Strom: Jahresdurchschnitte (MW)
    ROUND(AVG(wind_gesamt_mw)::numeric, 0)        AS avg_wind_mw,
    ROUND(AVG(wind_onshore_mw)::numeric, 0)       AS avg_wind_onshore_mw,
    ROUND(AVG(wind_offshore_mw)::numeric, 0)      AS avg_wind_offshore_mw,
    ROUND(AVG(solar_mw)::numeric, 0)              AS avg_solar_mw,
    ROUND(AVG(erneuerbar_gesamt_mw)::numeric, 0)  AS avg_erneuerbar_mw,

    -- Strom: Jahressummen (GWh = MW * Stunden / 1000)
    ROUND((SUM(wind_gesamt_mw) / 1000)::numeric, 0)   AS sum_wind_gwh,
    ROUND((SUM(solar_mw) / 1000)::numeric, 0)          AS sum_solar_gwh,
    ROUND((SUM(erneuerbar_gesamt_mw) / 1000)::numeric, 0) AS sum_erneuerbar_gwh,

    -- Preise
    ROUND(AVG(avg_price_eur_mwh)::numeric, 2)     AS avg_preis_eur,
    ROUND(MIN(avg_price_eur_mwh)::numeric, 2)     AS min_preis_eur,
    ROUND(MAX(avg_price_eur_mwh)::numeric, 2)     AS max_preis_eur,

    -- Negative Preise
    COUNT(*) FILTER (WHERE avg_price_eur_mwh < 0) AS stunden_negativer_preis,

    -- Datenpunkte
    COUNT(*)                                       AS anzahl_stunden

FROM hourly
GROUP BY jahr, region_name
ORDER BY jahr, region_name
