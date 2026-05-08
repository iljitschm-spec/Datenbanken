-- Kerntabelle: Wetter + Erzeugung + Preise verknuepft

WITH weather AS (
    SELECT * FROM {{ ref('stg_weather_hourly') }}
),

generation AS (
    SELECT * FROM {{ ref('generation_hourly') }}
),

prices AS (
    SELECT * FROM {{ ref('prices_hourly') }}
)

SELECT
    w.timestamp         AS timestamp_hour,
    w.region_name,
    w.datum,
    w.jahr,
    w.monat,
    w.stunde,
    w.wochentag,
    w.saison,

    -- Wetter
    w.temperature_2m,
    w.windspeed_100m,
    w.shortwave_radiation,

    -- Erzeugung
    g.wind_onshore_mw,
    g.wind_offshore_mw,
    g.wind_gesamt_mw,
    g.solar_mw,
    g.erneuerbar_gesamt_mw,

    -- Preise
    p.avg_price_eur_mwh

FROM weather w
LEFT JOIN generation g ON w.timestamp = g.timestamp_hour
LEFT JOIN prices p     ON w.timestamp = p.timestamp_hour

