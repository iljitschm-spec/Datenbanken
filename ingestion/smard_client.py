"""
SMARD Client - Holt Stromerzeugungsdaten von der Bundesnetzagentur.

Nutzung:
  Einmalig ausfuehren (innerhalb Docker):
    docker exec -it airflow_scheduler python /opt/airflow/ingestion/smard_client.py

  Oder lokal (wenn DB auf localhost erreichbar):
    python ingestion/smard_client.py
"""

import requests
import psycopg2
from psycopg2.extras import execute_values
from datetime import datetime, timezone
import time


def get_db_connection(config):
    """Stellt eine Verbindung zur PostgreSQL-Datenbank her."""
    return psycopg2.connect(**config)


def fetch_smard_timestamps(filter_id, region="DE", resolution="hour"):
    """
    Schritt 1: Welche Zeitbloecke sind bei SMARD verfuegbar?
    Gibt eine Liste von Unix-Timestamps (in Millisekunden) zurueck.
    Jeder Timestamp ist der Beginn eines Datenblocks (typisch: 1 Woche).
    """
    url = (
        f"https://www.smard.de/app/chart_data"
        f"/{filter_id}/{region}/index_{resolution}.json"
    )
    resp = requests.get(url, timeout=30)
    resp.raise_for_status()
    return resp.json().get("timestamps", [])


def fetch_smard_data(filter_id, timestamp_ms, region="DE", resolution="hour"):
    """
    Schritt 2: Hole die tatsaechlichen Daten fuer einen Zeitblock.
    Gibt eine Liste von [timestamp_ms, wert_in_MW] Paaren zurueck.
    """
    url = (
        f"https://www.smard.de/app/chart_data"
        f"/{filter_id}/{region}"
        f"/{filter_id}_{region}_{resolution}_{timestamp_ms}.json"
    )
    resp = requests.get(url, timeout=30)
    resp.raise_for_status()
    return resp.json().get("series", [])


def ms_to_datetime(ms):
    """Wandelt Unix-Millisekunden in Python datetime um."""
    return datetime.fromtimestamp(ms / 1000, tz=timezone.utc)


def fetch_generation_for_period(start_date, end_date, db_config):
    """
    Holt Stromerzeugungsdaten fuer ALLE Energietraeger im Zeitraum
    und schreibt sie in raw.smard_generation.
    """
    from ingestion.config import SMARD_GENERATION_FILTERS

    start_dt = datetime.strptime(start_date, "%Y-%m-%d").replace(tzinfo=timezone.utc)
    end_dt = datetime.strptime(end_date, "%Y-%m-%d").replace(tzinfo=timezone.utc)
    print(f"Hole SMARD-Erzeugungsdaten von {start_date} bis {end_date}...")

    # Sammle alle Datenpunkte: {timestamp: {energietraeger: wert}}
    all_data = {}

    for col_name, filter_id in SMARD_GENERATION_FILTERS.items():
        print(f"  -> {col_name} (Filter {filter_id})...")
        try:
            # Schritt 1: Verfuegbare Zeitbloecke holen
            timestamps = fetch_smard_timestamps(filter_id)

            # Nur Bloecke im gewuenschten Zeitraum
            relevant_ts = [
                ts for ts in timestamps
                if start_dt <= ms_to_datetime(ts) <= end_dt
            ]

            # Schritt 2: Daten pro Block holen
            for ts in relevant_ts:
                series = fetch_smard_data(filter_id, ts)
                for point in series:
                    ts_ms, value = point[0], point[1]
                    if ts_ms not in all_data:
                        all_data[ts_ms] = {}
                    all_data[ts_ms][col_name] = value

                # Kurze Pause damit wir die API nicht ueberlasten
                time.sleep(0.2)

        except Exception as e:
            print(f"  FEHLER bei {col_name}: {e}")

    if not all_data:
        print("Keine Daten erhalten!")
        return 0

    # In die Datenbank schreiben
    conn = get_db_connection(db_config)
    cur = conn.cursor()

    columns = [
        "timestamp", "biomass", "hydro", "wind_offshore", "wind_onshore",
        "solar", "other_renewable", "nuclear", "brown_coal", "hard_coal",
        "natural_gas", "pumped_storage", "other_conv"
    ]

    rows = []
    for ts_ms, values in sorted(all_data.items()):
        dt = ms_to_datetime(ts_ms)
        if start_dt <= dt <= end_dt:
            row = [dt] + [values.get(col, None) for col in columns[1:]]
            rows.append(tuple(row))

    col_str = ", ".join(columns)
    insert_sql = f"INSERT INTO raw.smard_generation ({col_str}) VALUES %s ON CONFLICT DO NOTHING"
    execute_values(cur, insert_sql, rows, page_size=1000)
    conn.commit()

    print(f"  {len(rows)} Zeilen in raw.smard_generation geschrieben.")
    cur.close()
    conn.close()
    return len(rows)


def fetch_prices_for_period(start_date, end_date, db_config):
    """
    Holt Grosshandelspreise (Day-Ahead Spotmarkt) von SMARD
    und schreibt sie in raw.smard_prices.
    """
    start_dt = datetime.strptime(start_date, "%Y-%m-%d").replace(tzinfo=timezone.utc)
    end_dt = datetime.strptime(end_date, "%Y-%m-%d").replace(tzinfo=timezone.utc)
    print(f"Hole SMARD-Preisdaten von {start_date} bis {end_date}...")

    try:
        timestamps = fetch_smard_timestamps(8004)
        relevant_ts = [
            ts for ts in timestamps
            if start_dt <= ms_to_datetime(ts) <= end_dt
        ]
    except Exception as e:
        print(f"FEHLER: {e}")
        return 0

    rows = []
    for ts in relevant_ts:
        try:
            series = fetch_smard_data(8004, ts)
            for point in series:
                ts_ms, value = point[0], point[1]
                dt = ms_to_datetime(ts_ms)
                if start_dt <= dt <= end_dt and value is not None:
                    rows.append((dt, value))
            time.sleep(0.2)
        except Exception as e:
            print(f"  FEHLER: {e}")

    if not rows:
        print("Keine Preisdaten erhalten!")
        return 0

    conn = get_db_connection(db_config)
    cur = conn.cursor()
    execute_values(
        cur,
        "INSERT INTO raw.smard_prices (timestamp, price_eur_mwh) VALUES %s ON CONFLICT DO NOTHING",
        rows,
        page_size=1000,
    )
    conn.commit()
    print(f"  {len(rows)} Zeilen in raw.smard_prices geschrieben.")
    cur.close()
    conn.close()
    return len(rows)


# ─── Direktausfuehrung (einmaliger historischer Load) ───
if __name__ == "__main__":
    # Wenn innerhalb Docker: DB_CONFIG verwenden
    # Wenn lokal: DB_CONFIG_LOCAL verwenden
    try:
        from ingestion.config import DB_CONFIG as cfg
        from ingestion.config import DATE_START, DATE_END
    except ImportError:
        from config import DB_CONFIG_LOCAL as cfg
        from config import DATE_START, DATE_END

    print("=== SMARD Historischer Datenload ===")
    fetch_generation_for_period(DATE_START, DATE_END, cfg)
    fetch_prices_for_period(DATE_START, DATE_END, cfg)
    print("=== FERTIG ===")

