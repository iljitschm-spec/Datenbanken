from airflow import DAG
from airflow.operators.python import PythonOperator
from datetime import datetime, timedelta

default_args = {
    "owner": "team",
    "retries": 2,
    "retry_delay": timedelta(minutes=5),
}

dag = DAG(
    dag_id="ingest_smard",
    default_args=default_args,
    description="Holt Stromerzeugung und Preise von SMARD",
    # schedule=None bedeutet: laeuft NUR manuell per Klick
    schedule=None,
    start_date=datetime(2024, 1, 1),
    catchup=False,
    tags=["ingestion", "smard"],
)


def task_fetch_generation():
    from ingestion.smard_client import fetch_generation_for_period
    from ingestion.config import DB_CONFIG, DATE_START, DATE_END
    fetch_generation_for_period(DATE_START, DATE_END, DB_CONFIG)


def task_fetch_prices():
    from ingestion.smard_client import fetch_prices_for_period
    from ingestion.config import DB_CONFIG, DATE_START, DATE_END
    fetch_prices_for_period(DATE_START, DATE_END, DB_CONFIG)


t1 = PythonOperator(
    task_id="fetch_generation",
    python_callable=task_fetch_generation,
    dag=dag,
)
t2 = PythonOperator(
    task_id="fetch_prices",
    python_callable=task_fetch_prices,
    dag=dag,
)

# Beide Aufgaben laufen unabhaengig voneinander (parallel)
[t1, t2]

