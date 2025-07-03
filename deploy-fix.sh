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

# Function to pull Docker images
pull_docker_images() {
    log "Extrayendo imágenes de Docker..."

    local images=(
        "node:22.11"
        "postgres:17"
        "nginx:alpine"
        "php:8.2-apache"
        "redis:8.0"
        "composer:2.8"
    )

    for image in "${images[@]}"; do
        log "Extrayendo $image..."
        if docker pull "$image"; then
            success "$image extraída con éxito"
        else
            error "No se pudo extraer $image"
            exit 1
        fi
    done
}

remove_dangling_docker_images() {
    local ids="$(docker images --filter "dangling=true" --no-trunc -q)"
    if [ -n "$ids" ]; then
        echo "Eliminando las siguientes imágenes colgantes:"
        echo "$ids"
        docker rmi $ids
    else
        echo "No hay imágenes colgantes para eliminar"
    fi
}

# Main execution
main() {
    check_env_var MOFLOT_DIR
    check_env_var PB_PROXY
    check_env_var GIT_TOKEN
    
    # Validate proxy setting
    validate_proxy
    
    log "Configurando proxy..."
    export http_proxy=$PB_PROXY
    export https_proxy=$PB_PROXY
    export no_proxy="localhost,127.0.0.1"

    git config --global http.proxy $PB_PROXY
    git config --global https.proxy $PB_PROXY

    # Validate all directories exist
    check_directory "$MOFLOT_DIR/web"
    check_directory "$MOFLOT_DIR/api"
    check_directory "$MOFLOT_DIR/async"
    check_directory "$MOFLOT_DIR/deployment"
    
    cd $MOFLOT_DIR
    
    log "Actualizando repositorios Git..."
    git -C $MOFLOT_DIR/web remote set-url origin https://ofigueroa-andinas:$GIT_TOKEN@github.com/ofigueroa-andinas/petroboscan-moflot-web.git
    git -C $MOFLOT_DIR/api remote set-url origin https://ofigueroa-andinas:$GIT_TOKEN@github.com/ofigueroa-andinas/petroboscan-moflot-api.git
    git -C $MOFLOT_DIR/async remote set-url origin https://ofigueroa-andinas:$GIT_TOKEN@github.com/ofigueroa-andinas/petroboscan-moflot-async.git
    git -C $MOFLOT_DIR/deployment remote set-url origin https://ofigueroa-andinas:$GIT_TOKEN@github.com/ofigueroa-andinas/petroboscan-moflot-deploy.git

    git -C $MOFLOT_DIR/web stash clear
    git -C $MOFLOT_DIR/api stash clear
    git -C $MOFLOT_DIR/async stash clear
    git -C $MOFLOT_DIR/deployment stash clear

    git -C $MOFLOT_DIR/api reset --hard HEAD
    git -C $MOFLOT_DIR/api pull

    git -C $MOFLOT_DIR/deployment fetch origin
    git -C $MOFLOT_DIR/deployment reset --hard HEAD
    git -C $MOFLOT_DIR/deployment checkout -B deploy origin/deploy

    log "Iniciando proceso de despliegue..."
    
    # Store original directory
    ORIGINAL_DIR=$(pwd)
    
    cd $MOFLOT_DIR/deployment
    
    log "Eliminar contenedores e imágenes Docker antes de recrear..."
    docker compose down -v listener
    remove_dangling_docker_images

    # Pull Docker images
    pull_docker_images
    
    log "Reiniciando Docker..."
    systemctl restart docker

    log "Compilando contenedores de Docker..."
    docker compose build backend listener

    log "Iniciando servicios de Docker 1/2..."
    docker compose up -d postgres redis backend frontend

    log "Estableciendo clave de aplicación..."
    docker compose exec -u root backend chown -R www-data:www-data /var/www/html
    docker compose exec backend php artisan key:generate
    
    log "Ejecutando migraciones de base de datos..."
    docker compose exec backend php artisan migrate:fresh

    log "Poblando la base de datos..."
    docker compose exec backend php artisan app:import-legacy-data
    
    log "Iniciando servicios de Docker 2/2..."
    docker compose up -d emitter processor listener

    success "¡Proceso de despliegue completado con éxito!"

    log "Servicios:"
    docker compose ps

    log "Efectuando limpieza adicional..."
    [ -d "/home/web" ] && rm -rf /home/web
    [ -d "/home/api" ] && rm -rf /home/api
    [ -d "/home/async" ] && rm -rf /home/async
    [ -d "/home/deployment" ] && rm -rf /home/deployment
    [ -d "/home/Archive" ] && rm -rf /home/Archive

    success "¡Proceso de despliegue completado con éxito!"

    cd $ORIGINAL_DIR
}

# Run main function
main "$@"
