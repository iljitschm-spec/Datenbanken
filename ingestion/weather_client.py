"""
Weather Client - Holt historische Wetterdaten von Open-Meteo.

Nutzung:
  Einmalig ausfuehren (innerhalb Docker):
    docker exec -it airflow_scheduler python /opt/airflow/ingestion/weather_client.py

  Oder lokal:
    python ingestion/weather_client.py
"""

import requests
import psycopg2
from psycopg2.extras import execute_values
from datetime import datetime, timezone
import time


def get_db_connection(config):
    """Stellt eine Verbindung zur PostgreSQL-Datenbank her."""
    return psycopg2.connect(**config)


def fetch_weather_for_region(region, start_date, end_date):
    """
    Holt stuendliche Wetterdaten fuer EINE Region von Open-Meteo.
    Gibt eine Liste von Dictionaries zurueck (ein Dict pro Stunde).
    """
    from ingestion.config import OPEN_METEO_URL, WEATHER_VARIABLES

    params = {
        "latitude": region["lat"],
        "longitude": region["lon"],
        "start_date": start_date,
        "end_date": end_date,
        "hourly": ",".join(WEATHER_VARIABLES),
        "timezone": "UTC",
    }

    resp = requests.get(OPEN_METEO_URL, params=params, timeout=60)
    resp.raise_for_status()
    hourly = resp.json().get("hourly", {})
    times = hourly.get("time", [])

    rows = []
    for i, time_str in enumerate(times):
        rows.append({
            "timestamp": datetime.strptime(
                time_str, "%Y-%m-%dT%H:%M"
            ).replace(tzinfo=timezone.utc),
            "latitude": region["lat"],
            "longitude": region["lon"],
            "region_name": region["name"],
            "temperature_2m": hourly.get("temperature_2m", [None])[i],
            "windspeed_10m": hourly.get("windspeed_10m", [None])[i],
            "windspeed_100m": hourly.get("windspeed_100m", [None])[i],
            "wind_direction_10m": hourly.get("winddirection_10m", [None])[i],
            "shortwave_radiation": hourly.get("shortwave_radiation", [None])[i],
            "direct_radiation": hourly.get("direct_radiation", [None])[i],
            "diffuse_radiation": hourly.get("diffuse_radiation", [None])[i],
            "cloud_cover": hourly.get("cloudcover", [None])[i],
        })
    return rows


def fetch_all_weather(start_date, end_date, db_config):
    """
    Hauptfunktion: Holt Wetterdaten fuer ALLE 7 Regionen
    und schreibt sie in raw.weather_hourly.
    """
    from ingestion.config import WEATHER_REGIONS

    print(f"Hole Wetterdaten von {start_date} bis {end_date}...")
    conn = get_db_connection(db_config)
    cur = conn.cursor()
    total = 0

    columns = [
        "timestamp", "latitude", "longitude", "region_name",
        "temperature_2m", "windspeed_10m", "windspeed_100m",
        "wind_direction_10m", "shortwave_radiation",
        "direct_radiation", "diffuse_radiation", "cloud_cover",
    ]

    for region in WEATHER_REGIONS:
        name = region["name"]
        print(f"  -> {name}...")
        try:
            rows = fetch_weather_for_region(region, start_date, end_date)
            values = [tuple(r[c] for c in columns) for r in rows]

            col_str = ", ".join(columns)
            insert_sql = (
                f"INSERT INTO raw.weather_hourly ({col_str}) "
                f"VALUES %s ON CONFLICT DO NOTHING"
            )
            execute_values(cur, insert_sql, values, page_size=1000)
            conn.commit()

            total += len(values)
            print(f"     {len(values)} Zeilen geschrieben.")

            # Open-Meteo Rate Limit: max 1 Request pro Sekunde
            time.sleep(1)

        except Exception as e:
            print(f"     FEHLER: {e}")

    cur.close()
    conn.close()
    print(f"Insgesamt {total} Wetter-Zeilen geschrieben.")
    return total


# ─── Direktausfuehrung (einmaliger historischer Load) ───
if __name__ == "__main__":
    try:
        from ingestion.config import DB_CONFIG as cfg
        from ingestion.config import DATE_START, DATE_END
    except ImportError:
        from config import DB_CONFIG_LOCAL as cfg
        from config import DATE_START, DATE_END

    print("=== Wetter Historischer Datenload ===")
    fetch_all_weather(DATE_START, DATE_END, cfg)
    print("=== FERTIG ===")

