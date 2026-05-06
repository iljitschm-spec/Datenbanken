# =============================================
# Wetter & Strom Pipeline - Setup & Data Load
# =============================================
# Windows PowerShell Version
#
# Nutzung:
#   PowerShell:  .\setup_and_load_windows.ps1
#
# Falls Ausfuehrung blockiert:
#   Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
# =============================================

$ErrorActionPreference = "Stop"

function Print-Header($msg) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Blue
    Write-Host "  $msg" -ForegroundColor Blue
    Write-Host "========================================" -ForegroundColor Blue
    Write-Host ""
}
function Print-Step($msg)    { Write-Host "[SCHRITT] $msg" -ForegroundColor Yellow }
function Print-Success($msg) { Write-Host "[OK] $msg" -ForegroundColor Green }
function Print-Error($msg)   { Write-Host "[FEHLER] $msg" -ForegroundColor Red }
function Print-Info($msg)    { Write-Host "[INFO] $msg" -ForegroundColor Cyan }

$StepsOK   = 0
$StepsFail = 0
$FailedSteps = @()

# =============================================
# SCHRITT 1: Docker Compose starten
# =============================================
Print-Header "SCHRITT 1/6: Docker Infrastruktur starten"
Print-Step "Starte Docker Compose..."

docker compose up -d 2>&1 | Write-Host
if ($LASTEXITCODE -ne 0) {
    Print-Error "Docker Compose konnte nicht gestartet werden!"
    Print-Error "Ist Docker Desktop gestartet?"
    Print-Error "Bist du im richtigen Ordner (wo docker-compose.yml liegt)?"
    exit 1
}
Print-Success "Docker Compose gestartet"

# =============================================
# SCHRITT 2: Warten bis Datenbank bereit ist
# =============================================
Print-Header "SCHRITT 2/6: Warte auf Datenbank..."
Print-Step "Pruefe ob PostgreSQL bereit ist..."

$MaxRetries = 30
$Retry = 0
while ($Retry -lt $MaxRetries) {
    docker exec wetter_strom_db pg_isready -U pipeline -d wetter_strom 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Print-Success "PostgreSQL ist bereit!"
        break
    }
    $Retry++
    Write-Host "  Warte... (Versuch $Retry/$MaxRetries)"
    Start-Sleep -Seconds 2
}
if ($Retry -eq $MaxRetries) {
    Print-Error "PostgreSQL ist nach $MaxRetries Versuchen nicht bereit!"
    Print-Error "Pruefe: docker logs wetter_strom_db"
    exit 1
}

Print-Step "Pruefe ob Tabellen erstellt wurden..."
$TableCount = (docker exec wetter_strom_db psql -U pipeline -d wetter_strom -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'raw';" 2>$null).Trim()

if ([int]$TableCount -ge 3) {
    Print-Success "Alle $TableCount Tabellen im Schema 'raw' gefunden"
    $StepsOK++
} else {
    Print-Error "Tabellen nicht gefunden! (Gefunden: $TableCount)"
    Print-Error "Pruefe: docker logs wetter_strom_db"
    $StepsFail++
    $FailedSteps += "Tabellen erstellen"
    exit 1
}

# =============================================
# SCHRITT 3: Warten bis Airflow bereit ist
# =============================================
Print-Header "SCHRITT 3/6: Warte auf Airflow..."
Print-Step "Warte bis Airflow Scheduler laeuft..."

$MaxRetries = 60
$Retry = 0
while ($Retry -lt $MaxRetries) {
    $Status = docker inspect -f '{{.State.Running}}' airflow_scheduler 2>$null
    if ($Status -eq "true") {
        Print-Success "Airflow Scheduler laeuft!"
        break
    }
    $Retry++
    Write-Host "  Warte auf Airflow... (Versuch $Retry/$MaxRetries)"
    Start-Sleep -Seconds 5
}
if ($Retry -eq $MaxRetries) {
    Print-Error "Airflow Scheduler ist nicht bereit!"
    Print-Error "Pruefe: docker logs airflow_init"
    Print-Error "Pruefe: docker logs airflow_scheduler"
    Print-Error ""
    Print-Error "Haeufige Ursache: Berechtigungsproblem im logs/ Ordner."
    exit 1
}

Print-Step "Warte 30 Sekunden damit Airflow Python-Pakete installiert..."
Start-Sleep -Seconds 30
Print-Success "Airflow ist bereit!"
$StepsOK++

# =============================================
# SCHRITT 4: Wetterdaten laden
# =============================================
Print-Header "SCHRITT 4/6: Wetterdaten laden (Open-Meteo)"
Print-Info "Das dauert ca. 1-2 Minuten..."
Print-Info "7 Staedte x 2 Jahre stuendliche Daten"
Write-Host ""

docker exec airflow_scheduler python /opt/airflow/ingestion/weather_client.py 2>&1 | Write-Host
$WeatherExit = $LASTEXITCODE

if ($WeatherExit -eq 0) {
    $WeatherCount = (docker exec wetter_strom_db psql -U pipeline -d wetter_strom -t -c "SELECT COUNT(*) FROM raw.weather_hourly;" 2>$null).Trim()

    if ([int]$WeatherCount -gt 0) {
        Print-Success "Wetterdaten geladen: $WeatherCount Zeilen"
        $StepsOK++
        Write-Host ""
        Print-Info "Vorschau der Wetterdaten:"
        docker exec wetter_strom_db psql -U pipeline -d wetter_strom -c "SELECT timestamp, region_name, temperature_2m, windspeed_100m, shortwave_radiation FROM raw.weather_hourly ORDER BY timestamp LIMIT 3;"
        Write-Host ""
        Print-Info "Geladene Regionen:"
        docker exec wetter_strom_db psql -U pipeline -d wetter_strom -c "SELECT region_name, COUNT(*) as zeilen FROM raw.weather_hourly GROUP BY region_name ORDER BY region_name;"
    } else {
        Print-Error "Wetterdaten: Tabelle ist leer!"
        $StepsFail++
        $FailedSteps += "Wetterdaten laden"
    }
} else {
    Print-Error "Wetterdaten laden fehlgeschlagen! (Exit Code: $WeatherExit)"
    Print-Error "Pruefe: docker logs airflow_scheduler"
    $StepsFail++
    $FailedSteps += "Wetterdaten laden"
}

# =============================================
# SCHRITT 5: SMARD-Daten laden
# =============================================
Print-Header "SCHRITT 5/6: Stromdaten laden (SMARD)"
Print-Info "Das dauert ca. 10-20 Minuten!"
Print-Info "12 Energietraeger + Preise fuer 2 Jahre"
Print-Info "Bitte Geduld - das Skript laeuft noch!"
Write-Host ""

docker exec airflow_scheduler python /opt/airflow/ingestion/smard_client.py 2>&1 | Write-Host
$SmardExit = $LASTEXITCODE

if ($SmardExit -eq 0) {
    $GenCount = (docker exec wetter_strom_db psql -U pipeline -d wetter_strom -t -c "SELECT COUNT(*) FROM raw.smard_generation;" 2>$null).Trim()
    $PriceCount = (docker exec wetter_strom_db psql -U pipeline -d wetter_strom -t -c "SELECT COUNT(*) FROM raw.smard_prices;" 2>$null).Trim()

    if ([int]$GenCount -gt 0) {
        Print-Success "Erzeugungsdaten geladen: $GenCount Zeilen"
        $StepsOK++
        Write-Host ""
        Print-Info "Vorschau der Erzeugungsdaten:"
        docker exec wetter_strom_db psql -U pipeline -d wetter_strom -c "SELECT timestamp, wind_onshore, wind_offshore, solar FROM raw.smard_generation ORDER BY timestamp LIMIT 3;"
    } else {
        Print-Error "Erzeugungsdaten: Tabelle ist leer!"
        $StepsFail++
        $FailedSteps += "Erzeugungsdaten laden"
    }

    if ([int]$PriceCount -gt 0) {
        Print-Success "Preisdaten geladen: $PriceCount Zeilen"
        $StepsOK++
        Write-Host ""
        Print-Info "Vorschau der Preisdaten:"
        docker exec wetter_strom_db psql -U pipeline -d wetter_strom -c "SELECT timestamp, price_eur_mwh FROM raw.smard_prices ORDER BY timestamp LIMIT 3;"
    } else {
        Print-Error "Preisdaten: Tabelle ist leer!"
        $StepsFail++
        $FailedSteps += "Preisdaten laden"
    }
} else {
    Print-Error "SMARD-Daten laden fehlgeschlagen! (Exit Code: $SmardExit)"
    Print-Error "Pruefe: docker logs airflow_scheduler"
    $StepsFail++
    $FailedSteps += "SMARD-Daten laden"
}

# =============================================
# SCHRITT 6: Zusammenfassung
# =============================================
Print-Header "SCHRITT 6/6: Zusammenfassung"

Print-Info "Datenbestand in der Datenbank:"
docker exec wetter_strom_db psql -U pipeline -d wetter_strom -c "SELECT (SELECT COUNT(*) FROM raw.weather_hourly) AS wetter_zeilen, (SELECT COUNT(*) FROM raw.smard_generation) AS erzeugungs_zeilen, (SELECT COUNT(*) FROM raw.smard_prices) AS preis_zeilen;"

Write-Host ""
Write-Host "========================================" -ForegroundColor Blue
Write-Host "  ERGEBNIS" -ForegroundColor Blue
Write-Host "========================================" -ForegroundColor Blue
Write-Host ""
Write-Host "  Erfolgreich:     $StepsOK" -ForegroundColor Green
Write-Host "  Fehlgeschlagen:  $StepsFail" -ForegroundColor Red

if ($StepsFail -gt 0) {
    Write-Host ""
    Write-Host "Fehlgeschlagene Schritte:" -ForegroundColor Red
    foreach ($step in $FailedSteps) {
        Write-Host "  - $step" -ForegroundColor Red
    }
    Write-Host ""
    Print-Info "Tipps zur Fehlerbehebung:"
    Print-Info "  docker logs airflow_scheduler    (Airflow-Fehler)"
    Print-Info "  docker logs wetter_strom_db      (Datenbank-Fehler)"
    Print-Info "  docker compose ps                (Service-Status)"
}

if ($StepsFail -eq 0) {
    Write-Host ""
    Write-Host "Alles erfolgreich! Die Pipeline ist bereit." -ForegroundColor Green
    Write-Host ""
    Print-Info "Naechste Schritte:"
    Print-Info "  1. Airflow UI:  http://localhost:8080  (admin/admin)"
    Print-Info "  2. Grafana:     http://localhost:3000  (admin/admin)"
    Print-Info "  3. SQL Shell:   docker exec -it wetter_strom_db psql -U pipeline -d wetter_strom"
    Write-Host ""
    Print-Info "Docker stoppen (Daten bleiben erhalten):"
    Print-Info "  docker compose down"
}

Write-Host ""

