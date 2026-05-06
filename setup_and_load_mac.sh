#!/bin/zsh
# =============================================
# Wetter & Strom Pipeline - Setup & Data Load
# =============================================
# macOS Version (zsh-kompatibel)
#
# Nutzung:
#   Terminal:  chmod +x setup_and_load_mac.sh && ./setup_and_load_mac.sh
#   oder:     zsh setup_and_load_mac.sh
# =============================================

# --- Farben fuer Terminal-Ausgabe ---
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo ""
    echo "${BLUE}========================================${NC}"
    echo "${BLUE}  $1${NC}"
    echo "${BLUE}========================================${NC}"
    echo ""
}

print_step()    { echo "${YELLOW}[SCHRITT]${NC} $1" }
print_success() { echo "${GREEN}[OK]${NC} $1" }
print_error()   { echo "${RED}[FEHLER]${NC} $1" }
print_info()    { echo "${BLUE}[INFO]${NC} $1" }

STEPS_OK=0
STEPS_FAIL=0
FAILED_STEPS=()


# =============================================
# SCHRITT 1: Docker Compose starten
# =============================================
print_header "SCHRITT 1/6: Docker Infrastruktur starten"

print_step "Starte Docker Compose..."
docker compose up -d 2>&1

if [[ $? -ne 0 ]]; then
    print_error "Docker Compose konnte nicht gestartet werden!"
    print_error "Ist Docker Desktop gestartet?"
    print_error "Bist du im richtigen Ordner (wo docker-compose.yml liegt)?"
    exit 1
fi
print_success "Docker Compose gestartet"


# =============================================
# SCHRITT 2: Warten bis Datenbank bereit ist
# =============================================
print_header "SCHRITT 2/6: Warte auf Datenbank..."
print_step "Pruefe ob PostgreSQL bereit ist..."
MAX_RETRIES=30
RETRY=0
while [[ $RETRY -lt $MAX_RETRIES ]]; do
    docker exec wetter_strom_db pg_isready -U pipeline -d wetter_strom > /dev/null 2>&1
    if [[ $? -eq 0 ]]; then
        print_success "PostgreSQL ist bereit!"
        break
    fi
    RETRY=$((RETRY + 1))
    echo "  Warte... (Versuch $RETRY/$MAX_RETRIES)"
    sleep 2
done

if [[ $RETRY -eq $MAX_RETRIES ]]; then
    print_error "PostgreSQL ist nach $MAX_RETRIES Versuchen nicht bereit!"
    print_error "Pruefe: docker logs wetter_strom_db"
    exit 1
fi

print_step "Pruefe ob Tabellen erstellt wurden..."
TABLE_COUNT=$(docker exec wetter_strom_db psql -U pipeline -d wetter_strom -t -c \
    "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'raw';" 2>/dev/null | tr -d ' ')

if [[ "$TABLE_COUNT" -ge 3 ]] 2>/dev/null; then
    print_success "Alle $TABLE_COUNT Tabellen im Schema 'raw' gefunden"
    STEPS_OK=$((STEPS_OK + 1))
else
    print_error "Tabellen nicht gefunden! (Gefunden: $TABLE_COUNT)"
    print_error "Pruefe: docker logs wetter_strom_db"
    STEPS_FAIL=$((STEPS_FAIL + 1))
    FAILED_STEPS+=("Tabellen erstellen")
    exit 1
fi


# =============================================
# SCHRITT 3: Warten bis Airflow bereit ist
# =============================================
print_header "SCHRITT 3/6: Warte auf Airflow..."

print_step "Warte bis Airflow Scheduler laeuft..."
MAX_RETRIES=60
RETRY=0
while [[ $RETRY -lt $MAX_RETRIES ]]; do
    SCHEDULER_STATUS=$(docker inspect -f '{{.State.Running}}' airflow_scheduler 2>/dev/null)
    if [[ "$SCHEDULER_STATUS" == "true" ]]; then
        print_success "Airflow Scheduler laeuft!"
        break
    fi
    RETRY=$((RETRY + 1))
    echo "  Warte auf Airflow... (Versuch $RETRY/$MAX_RETRIES)"
    sleep 5
done
if [[ $RETRY -eq $MAX_RETRIES ]]; then
    print_error "Airflow Scheduler ist nicht bereit!"
    print_error "Pruefe: docker logs airflow_init"
    print_error "Pruefe: docker logs airflow_scheduler"
    print_error ""
    print_error "Haeufige Ursache: Berechtigungsproblem im logs/ Ordner."
    print_error "Loesung: Fuege 'user: \"0:0\"' zu den Airflow-Services in docker-compose.yml hinzu."
    exit 1
fi

print_step "Warte 30 Sekunden damit Airflow Python-Pakete installiert..."
sleep 30
print_success "Airflow ist bereit!"
STEPS_OK=$((STEPS_OK + 1))


# =============================================
# SCHRITT 4: Wetterdaten laden
# =============================================
print_header "SCHRITT 4/6: Wetterdaten laden (Open-Meteo)"

print_info "Das dauert ca. 1-2 Minuten..."
print_info "7 Staedte x 2 Jahre stuendliche Daten"
echo ""

docker exec airflow_scheduler python /opt/airflow/ingestion/weather_client.py 2>&1
WEATHER_EXIT=$?

if [[ $WEATHER_EXIT -eq 0 ]]; then
    WEATHER_COUNT=$(docker exec wetter_strom_db psql -U pipeline -d wetter_strom -t -c \
        "SELECT COUNT(*) FROM raw.weather_hourly;" 2>/dev/null | tr -d ' ')

    if [[ "$WEATHER_COUNT" -gt 0 ]] 2>/dev/null; then
        print_success "Wetterdaten geladen: $WEATHER_COUNT Zeilen"
        STEPS_OK=$((STEPS_OK + 1))

        echo ""
        print_info "Vorschau der Wetterdaten:"
        docker exec wetter_strom_db psql -U pipeline -d wetter_strom -c \
            "SELECT timestamp, region_name, temperature_2m, windspeed_100m, shortwave_radiation FROM raw.weather_hourly ORDER BY timestamp LIMIT 3;"
        echo ""
        print_info "Geladene Regionen:"
        docker exec wetter_strom_db psql -U pipeline -d wetter_strom -c \
            "SELECT region_name, COUNT(*) as zeilen FROM raw.weather_hourly GROUP BY region_name ORDER BY region_name;"
    else
        print_error "Wetterdaten: Tabelle ist leer!"
        STEPS_FAIL=$((STEPS_FAIL + 1))
        FAILED_STEPS+=("Wetterdaten laden")
    fi
else
    print_error "Wetterdaten laden fehlgeschlagen! (Exit Code: $WEATHER_EXIT)"
    print_error "Pruefe: docker logs airflow_scheduler"
    STEPS_FAIL=$((STEPS_FAIL + 1))
    FAILED_STEPS+=("Wetterdaten laden")
fi


# =============================================
# SCHRITT 5: SMARD-Daten laden
# =============================================
print_header "SCHRITT 5/6: Stromdaten laden (SMARD)"

print_info "Das dauert ca. 10-20 Minuten!"
print_info "12 Energietraeger + Preise fuer 2 Jahre"
print_info "Bitte Geduld - das Skript laeuft noch!"
echo ""

docker exec airflow_scheduler python /opt/airflow/ingestion/smard_client.py 2>&1
SMARD_EXIT=$?

if [[ $SMARD_EXIT -eq 0 ]]; then
    GEN_COUNT=$(docker exec wetter_strom_db psql -U pipeline -d wetter_strom -t -c \
        "SELECT COUNT(*) FROM raw.smard_generation;" 2>/dev/null | tr -d ' ')

    PRICE_COUNT=$(docker exec wetter_strom_db psql -U pipeline -d wetter_strom -t -c \
        "SELECT COUNT(*) FROM raw.smard_prices;" 2>/dev/null | tr -d ' ')

    if [[ "$GEN_COUNT" -gt 0 ]] 2>/dev/null; then
        print_success "Erzeugungsdaten geladen: $GEN_COUNT Zeilen"
        STEPS_OK=$((STEPS_OK + 1))
        echo ""
        print_info "Vorschau der Erzeugungsdaten:"
        docker exec wetter_strom_db psql -U pipeline -d wetter_strom -c \
            "SELECT timestamp, wind_onshore, wind_offshore, solar FROM raw.smard_generation ORDER BY timestamp LIMIT 3;"
    else
        print_error "Erzeugungsdaten: Tabelle ist leer!"
        STEPS_FAIL=$((STEPS_FAIL + 1))
        FAILED_STEPS+=("Erzeugungsdaten laden")
    fi

    if [[ "$PRICE_COUNT" -gt 0 ]] 2>/dev/null; then
        print_success "Preisdaten geladen: $PRICE_COUNT Zeilen"
        STEPS_OK=$((STEPS_OK + 1))

        echo ""
        print_info "Vorschau der Preisdaten:"
        docker exec wetter_strom_db psql -U pipeline -d wetter_strom -c \
            "SELECT timestamp, price_eur_mwh FROM raw.smard_prices ORDER BY timestamp LIMIT 3;"
    else
        print_error "Preisdaten: Tabelle ist leer!"
        STEPS_FAIL=$((STEPS_FAIL + 1))
        FAILED_STEPS+=("Preisdaten laden")
    fi
else
    print_error "SMARD-Daten laden fehlgeschlagen! (Exit Code: $SMARD_EXIT)"
    print_error "Pruefe: docker logs airflow_scheduler"
    STEPS_FAIL=$((STEPS_FAIL + 1))
    FAILED_STEPS+=("SMARD-Daten laden")
fi


# =============================================
# SCHRITT 6: Zusammenfassung
# =============================================
print_header "SCHRITT 6/6: Zusammenfassung"

print_info "Datenbestand in der Datenbank:"
docker exec wetter_strom_db psql -U pipeline -d wetter_strom -c \
    "SELECT
        (SELECT COUNT(*) FROM raw.weather_hourly)   AS wetter_zeilen,
        (SELECT COUNT(*) FROM raw.smard_generation)  AS erzeugungs_zeilen,
        (SELECT COUNT(*) FROM raw.smard_prices)      AS preis_zeilen;"
echo ""
echo "${BLUE}========================================${NC}"
echo "${BLUE}  ERGEBNIS${NC}"
echo "${BLUE}========================================${NC}"
echo ""
echo "  Erfolgreich:     ${GREEN}$STEPS_OK${NC}"
echo "  Fehlgeschlagen:  ${RED}$STEPS_FAIL${NC}"

if [[ $STEPS_FAIL -gt 0 ]]; then
    echo ""
    echo "${RED}Fehlgeschlagene Schritte:${NC}"
    for step in "${FAILED_STEPS[@]}"; do
        echo "  - $step"
    done
    echo ""
    print_info "Tipps zur Fehlerbehebung:"
    print_info "  docker logs airflow_scheduler    (Airflow-Fehler)"
    print_info "  docker logs wetter_strom_db      (Datenbank-Fehler)"
    print_info "  docker compose ps                (Service-Status)"
fi

if [[ $STEPS_FAIL -eq 0 ]]; then
    echo ""
    echo "${GREEN}Alles erfolgreich! Die Pipeline ist bereit.${NC}"
    echo ""
    print_info "Naechste Schritte:"
    print_info "  1. Airflow UI:  http://localhost:8080  (admin/admin)"
    print_info "  2. Grafana:     http://localhost:3000  (admin/admin)"
    print_info "  3. SQL Shell:   docker exec -it wetter_strom_db psql -U pipeline -d wetter_strom"
    echo ""
    print_info "Docker stoppen (Daten bleiben erhalten):"
    print_info "  docker compose down"
fi

echo ""
