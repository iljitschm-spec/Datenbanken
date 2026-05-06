from airflow import DAG
from airflow.operators.python import PythonOperator
from datetime import datetime, timedelta

default_args = {
    "owner": "team",
    "retries": 2,
    "retry_delay": timedelta(minutes=5),
}

dag = DAG(
    dag_id="ingest_weather",
    default_args=default_args,
    description="Holt Wetterdaten von Open-Meteo",
    schedule=None,
    start_date=datetime(2024, 1, 1),
    catchup=False,
    tags=["ingestion", "weather"],
)


def task_fetch_weather():
    from ingestion.weather_client import fetch_all_weather
    from ingestion.config import DB_CONFIG, DATE_START, DATE_END
    fetch_all_weather(DATE_START, DATE_END, DB_CONFIG)


PythonOperator(
    task_id="fetch_weather",
    python_callable=task_fetch_weather,
    dag=dag,
)

