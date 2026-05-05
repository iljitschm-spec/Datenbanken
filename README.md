# Wetter & Stromerzeugung Pipeline

**Thema:** Zusammenhang zwischen Wettervorhersage und Stromerzeugung
erneuerbarer Energien in Deutschland.

**Team:** Eugen Olariu, Peter Schmid, Maximilian Haag, Marcel Runzer

## Quick Start
```bash
docker compose up -d
docker compose ps

| Service |	URL | Login|
|----|------------------|----|
|Airflow	| http://localhost:8080	| admin / admin |
|Grafana	| http://localhost:3000	| admin / admin |
|PostgreSQL	|localhost:5432	| pipeline/pipeline123 |

## Daten laden (Einmalig)

docker exec -it airflow_scheduler python /opt/airflow/ingestion/smard_client.py
docker exec -it airflow_scheduler python /opt/airflow/ingestion/weather_client.py

