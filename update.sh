#!/bin/bash

set -e  # Exit on any error
set -u  # Exit on undefined variables

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to check if directory exists
check_directory() {
    if [ ! -d "$1" ]; then
        error "El directorio '$1' no existe"
        exit 1
    fi
}

# Function to check if the required environment variables are set
check_env_var() {
    local var_name="$1"
    local var_value="${!var_name}"
    
    if [ -z "$var_name" ]; then
        echo "Usage: check_env_var VARIABLE_NAME" >&2
        exit 2
    fi

    if [ -z "$var_value" ]; then
        echo "Error: La variable de entorno '$var_name' no está definida o está vacía." >&2
        exit 1
    fi
}

validate_proxy() {
    log "Validando proxy..."
    
    export http_proxy=$PB_PROXY
    export https_proxy=$PB_PROXY
    
    URL="https://www.google.com"
    HTTP_CODE=$(curl -s --head -o /dev/null -w '%{response_code}' "$URL") || {
        exit_code=$?
        echo "La solicitud a $URL falló (código de salida curl $exit_code)"
        exit $exit_code
    }

    # Check the status code
    if [ "$HTTP_CODE" -eq 200 ]; then
        echo "Proxy funciona correctamente"
    else
        echo "Error de proxy. Código de estado HTTP: $HTTP_CODE"
        exit 1
    fi
}

# Main execution
main() {
    local use_proxy="true"
    
    check_env_var MOFLOT_DIR
    check_env_var GIT_TOKEN
    if [ "$use_proxy" = "true" ]; then
        check_env_var PB_PROXY
    
        # Validate proxy setting
        validate_proxy
        
        log "Configurando proxy..."
        export http_proxy=$PB_PROXY
        export https_proxy=$PB_PROXY
        export no_proxy="localhost,127.0.0.1"

        git config --global http.proxy $http_proxy
        git config --global https.proxy $https_proxy
        
        npm config set proxy $http_proxy
        npm config set https-proxy $https_proxy
    fi

    # Validate all directories exist
    check_directory "$MOFLOT_DIR/web"
    check_directory "$MOFLOT_DIR/api"
    check_directory "$MOFLOT_DIR/async"
    check_directory "$MOFLOT_DIR/deployment"
    
    # Store original directory
    ORIGINAL_DIR=$(pwd)
    
    cd $MOFLOT_DIR
    
    log "Efectuando limpieza adicional..."
    [ -d "/home/web" ] && rm -rf /home/web
    [ -d "/home/api" ] && rm -rf /home/api
    [ -d "/home/async" ] && rm -rf /home/async
    [ -d "/home/deployment" ] && rm -rf /home/deployment
    [ -d "/home/Archive" ] && rm -rf /home/Archive
    [ -d "/home/moflot-test" ] && rm -rf /home/moflot-test
    
    log "Actualizando repositorios Git..."
    git -C $MOFLOT_DIR/web pull

    log "Iniciando actualización..."
    
    cd $MOFLOT_DIR/web
    npm run build
    
    cd $MOFLOT_DIR/deployment
    
    log "Reiniciando servicios de Docker..."
    docker compose up -d --force-recreate frontend

    success "¡Proceso de actualización completado con éxito!"

    log "Servicios:"
    docker compose ps

    cd $ORIGINAL_DIR
}

# Run main function
main "$@"
