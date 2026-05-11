-- Tage nach Wetterlage kategorisieren
WITH base AS (
    SELECT * FROM {{ ref('daily_summary') }}
    WHERE region_name = 'Hamburg'
),

kategorisiert AS (
    SELECT
        datum,
        saison,
        avg_temperatur,
        avg_windgeschwindigkeit,
        sum_solarstrahlung,
        avg_wind_mw,
        avg_solar_mw,
        avg_erneuerbar_mw,
        avg_preis_eur,
        min_preis_eur,

        -- === WINDKATEGORIE ===
        CASE
            WHEN avg_windgeschwindigkeit < 3  THEN '1_Flaute'
            WHEN avg_windgeschwindigkeit < 6  THEN '2_Leicht'
            WHEN avg_windgeschwindigkeit < 10 THEN '3_Maessig'
            WHEN avg_windgeschwindigkeit < 15 THEN '4_Stark'
            ELSE                                   '5_Sturm'
        END AS wind_kategorie,

        -- === SONNENKATEGORIE ===
        CASE
            WHEN sum_solarstrahlung < 500   THEN '1_Bedeckt'
            WHEN sum_solarstrahlung < 2000  THEN '2_Bewoelkt'
            WHEN sum_solarstrahlung < 4000  THEN '3_Teilweise_Sonnig'
            ELSE                                 '4_Sonnig'
        END AS solar_kategorie,

        -- === TEMPERATURKATEGORIE ===
        CASE
            WHEN avg_temperatur < 0   THEN '1_Frost'
            WHEN avg_temperatur < 8   THEN '2_Kalt'
            WHEN avg_temperatur < 15  THEN '3_Mild'
            WHEN avg_temperatur < 22  THEN '4_Warm'
            ELSE                          '5_Heiss'
        END AS temp_kategorie,

        -- === GESAMTWETTERLAGE ===
        CASE
            WHEN avg_windgeschwindigkeit >= 10 AND sum_solarstrahlung < 500
                THEN 'Sturm_Bedeckt'
            WHEN avg_windgeschwindigkeit >= 10 AND sum_solarstrahlung >= 2000
                THEN 'Sturm_Sonnig'
            WHEN avg_windgeschwindigkeit < 3 AND sum_solarstrahlung >= 4000
                THEN 'Flaute_Sonnig'
            WHEN avg_windgeschwindigkeit < 3 AND sum_solarstrahlung < 500
                THEN 'Flaute_Bedeckt'
            WHEN avg_windgeschwindigkeit BETWEEN 3 AND 10 AND sum_solarstrahlung >= 2000
                THEN 'Mittel_Sonnig'
            ELSE
                'Mittel_Bedeckt'
        END AS wetterlage,

        -- === NEGATIVE PREISE FLAG ===
        CASE
            WHEN min_preis_eur < 0 THEN true
            ELSE false
        END AS hat_negativen_preis

    FROM base
)

SELECT * FROM kategorisiert
ORDER BY datum

