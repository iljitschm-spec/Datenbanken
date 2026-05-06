# === Datenbank-Verbindung ===

# Wenn der Code INNERHALB von Docker laeuft (z.B. via Airflow),
# heisst der Datenbank-Host "postgres" (= der Container-Name)
DB_CONFIG = {
    "host": "postgres",
    "port": 5432,
    "database": "wetter_strom",
    "user": "pipeline",
    "password": "pipeline123",
}

# Wenn ihr den Code LOKAL auf eurem Rechner ausfuehrt (ausserhalb Docker),
# ist der Host "localhost"
DB_CONFIG_LOCAL = {
    "host": "localhost",
    "port": 5432,
    "database": "wetter_strom",
    "user": "pipeline",
    "password": "pipeline123",
}


# === SMARD API (Bundesnetzagentur) ===

# Jeder Energietraeger hat eine eigene Filter-ID bei SMARD
SMARD_GENERATION_FILTERS = {
    "biomass":         4066,
    "hydro":           1226,
    "wind_offshore":   1225,
    "wind_onshore":    4067,
    "solar":           4068,
    "other_renewable": 1228,
    "nuclear":         1224,
    "brown_coal":      1223,
    "hard_coal":       4069,
    "natural_gas":     4071,
    "pumped_storage":  4070,
    "other_conv":      1227,
    "total_consumption" : 410,
}

# Preis-Filter: Day-Ahead Spotmarkt
SMARD_PRICE_FILTER = 8004


# === Open-Meteo API (Wetterdaten) ===

OPEN_METEO_URL = "https://archive-api.open-meteo.com/v1/archive"

# Welche Wettervariablen wir abfragen
WEATHER_VARIABLES = [
    "temperature_2m",        # Temperatur auf 2m Hoehe (Grad C)
    "windspeed_10m",         # Windgeschwindigkeit 10m (km/h)
    "windspeed_100m",        # Windgeschwindigkeit 100m (km/h) - Nabenhoehe Windrad!
    "winddirection_10m",     # Windrichtung (0-360 Grad)
    "shortwave_radiation",   # Globalstrahlung (W/m2) - wichtig fuer Solar
    "direct_radiation",      # Direktstrahlung (W/m2)
    "diffuse_radiation",     # Diffuse Strahlung (W/m2)
    "cloudcover",            # Bewoelkung (0-100%)
]

# 7 repraesentative Standorte in Deutschland
# Norden = viel Wind, Sueden = viel Solar
WEATHER_REGIONS = [
    {"name": "Hamburg",   "lat": 53.55, "lon":  9.99},   # Wind
    {"name": "Rostock",   "lat": 54.09, "lon": 12.10},   # Wind / Offshore-nah
    {"name": "Berlin",    "lat": 52.52, "lon": 13.41},   # Mix
    {"name": "Koeln",     "lat": 50.94, "lon":  6.96},   # Mix
    {"name": "Frankfurt", "lat": 50.11, "lon":  8.68},   # Mix / Solar
    {"name": "Muenchen",  "lat": 48.14, "lon": 11.58},   # Solar
    {"name": "Freiburg",  "lat": 47.99, "lon":  7.85},   # Solar (hoechste Strahlung)
]


# === Zeitraum ===
# 2 volle Jahre: genuegend fuer saisonale Muster
# Train auf 2024, Test auf 2025
DATE_START = "2020-01-01"
DATE_END = "2025-12-31"

