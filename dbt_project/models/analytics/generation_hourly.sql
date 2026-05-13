-- SMARD-Erzeugung aggregiert auf Stundenbasis

WITH src AS (
    SELECT * FROM {{ ref('stg_smard_generation') }}
)

SELECT
    date_trunc('hour', timestamp)   AS timestamp_hour,
    ROUND(AVG(biomass_mw)::numeric, 2)           AS biomass_mw,
    ROUND(AVG(hydro_mw)::numeric, 2)             AS hydro_mw,
    ROUND(AVG(wind_offshore_mw)::numeric, 2)     AS wind_offshore_mw,
    ROUND(AVG(wind_onshore_mw)::numeric, 2)      AS wind_onshore_mw,
    ROUND(AVG(solar_mw)::numeric, 2)             AS solar_mw,
    ROUND(AVG(other_rewnewable_mw)::numeric, 2)  AS other_rewnewable_mw,
    ROUND(AVG(nuclear_mw)::numeric, 2) 		 AS nuclear_mw,
    ROUND(AVG(wind_gesamt_mw)::numeric, 2)       AS wind_gesamt_mw,
    ROUND(AVG(brown_coal_mw)::numeric, 2) 		 AS brown_coal_mw,
    ROUND(AVG(hard_coal_mw)::numeric, 2)   	 AS hard_coal_mw,
    ROUND(AVG(natural_gas_mw)::numeric, 2) 	 AS natural_gas_mw,
    ROUND(AVG(pumped_storage_mw)::numeric, 2)    AS pumped_storage_mw,
    ROUND(AVG(other_conv_mw)::numeric, 2) 	 AS other_conv_mw,
    ROUND(AVG(wetter_depen_erneuerbar_gesamt_mw)::numeric, 2) AS wetter_depen_erneuerbar_mw,
    ROUND(AVG(erneuerbar_gesamt_mw)::numeric, 2) AS erneuerbar_gesamt_mw,
    ROUND(AVG(energie_gesamt_mw)::numeric, 2) 	 AS energie_gesamt_mw 
FROM src
GROUP BY date_trunc('hour', timestamp)

