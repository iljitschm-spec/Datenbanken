CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS marts;

CREATE EXTENSION IF NOT EXISTS timescaledb;

CREATE TABLE IF NOT EXISTS raw.smard_generation (
    timestamp         TIMESTAMPTZ NOT NULL,
    biomass           DOUBLE PRECISION,
    hydro             DOUBLE PRECISION,
    wind_offshore     DOUBLE PRECISION,
    wind_onshore      DOUBLE PRECISION,
    solar             DOUBLE PRECISION,
    other_renewable   DOUBLE PRECISION,
    nuclear           DOUBLE PRECISION,
    brown_coal        DOUBLE PRECISION,
    hard_coal         DOUBLE PRECISION,
    natural_gas       DOUBLE PRECISION,
    pumped_storage    DOUBLE PRECISION,
    other_conv        DOUBLE PRECISION,
    ingested_at       TIMESTAMPTZ DEFAULT NOW()
);
SELECT create_hypertable('raw.smard_generation', 'timestamp', if_not_exists => TRUE);

CREATE TABLE IF NOT EXISTS raw.weather_hourly (
    timestamp             TIMESTAMPTZ NOT NULL,
    latitude              DOUBLE PRECISION,
    longitude             DOUBLE PRECISION,
    region_name           TEXT,
    temperature_2m        DOUBLE PRECISION,
    windspeed_10m         DOUBLE PRECISION,
    windspeed_100m        DOUBLE PRECISION,
    wind_direction_10m    DOUBLE PRECISION,
    shortwave_radiation   DOUBLE PRECISION,
    direct_radiation      DOUBLE PRECISION,
    diffuse_radiation     DOUBLE PRECISION,
    cloud_cover           DOUBLE PRECISION,
    ingested_at           TIMESTAMPTZ DEFAULT NOW()
);
SELECT create_hypertable('raw.weather_hourly', 'timestamp', if_not_exists => TRUE);

CREATE TABLE IF NOT EXISTS raw.smard_prices (
    timestamp        TIMESTAMPTZ NOT NULL,
    price_eur_mwh    DOUBLE PRECISION,
    ingested_at      TIMESTAMPTZ DEFAULT NOW()
);
SELECT create_hypertable('raw.smard_prices', 'timestamp', if_not_exists => TRUE);

