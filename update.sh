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
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')][ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')][SUCCESS]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')][WARNING]${NC} $1"
}

# Function to check if directory exists
check_directory() {
    if [ ! -d "$1" ]; then
        error "Directorio '$1' no existe"
        exit 1
    fi
}

# Function to check if the required environment variables are set
check_env_var() {
    local var_name="$1"
    eval "local value=\${$var_name-}"

    if [ -z "$value" ]; then
        return 1
    fi
    return 0
}

validate_proxy() {
    local proxy="$1"
    local has_error=0

    log "Validando proxy..."

    export http_proxy=$proxy
    export https_proxy=$proxy

    local URL="https://www.bing.com"
    log "Haciendo solicitud a $URL..."
    local HTTP_CODE=$(curl -s --head -o /dev/null -w '%{response_code}' "$URL") || {
        local exit_code=$?
        error "Solicitud falló con código de salida curl $exit_code."
        has_error=1
    }

    # Check the status code
    if [ "$HTTP_CODE" -eq 200 ]; then
        success "Proxy funciona correctamente"
    else
        error "Error de proxy. Código HTTP: $HTTP_CODE"
        has_error=1
    fi

    unset http_proxy
    unset https_proxy

    if [ "$has_error" -eq 1 ]; then
        return 1
    fi
    return 0
}

check_and_prompt_var() {
    local var_name="$1"
    if ! check_env_var "$var_name"; then
        warn "Variable $var_name no está definida o está vacía."
        while true; do
            echo "Elija una opción:"
            echo "  1) Continuar de todos modos"
            echo "  2) Establecer la variable ahora"
            echo "  3) Abortar"
            read -p "Ingrese opción [1-3]: " choice

            case "$choice" in
                1)
                    log "Continuando sin $var_name..."
                    return 0
                    ;;
                2)
                    read -p "Ingrese valor para $var_name: " new_value
                    eval export $var_name=\"$new_value\"
                    success "Variable $var_name establecida"
                    return 0
                    ;;
                3)
                    log "Abortando."
                    return 1
                    ;;
                *)
                    warn "Opción inválida, ingrese 1, 2, o 3"
                    ;;
            esac
        done
    fi
    return 0
}

set_proxy() {
    local proxy="$1"
    log "Configurando proxy Git..."
    git config --global http.proxy $proxy
    git config --global https.proxy $proxy
}

safe_git_unset() {
    local key="$1"
    if git config --global --get "$key" >/dev/null 2>&1; then
        git config --global --unset "$key"
    fi
}

unset_proxy() {
    log "Configurando sin proxy Git..."
    safe_git_unset http.proxy
    safe_git_unset https.proxy
}

# Main execution
main() {
    if ! check_env_var "MOFLOT_DIR"; then
        error "Variable MOFLOT_DIR no está definida o está vacía."
        exit 1
    fi
    if ! check_env_var "GIT_TOKEN"; then
        error "Variable GIT_TOKEN no está definida o está vacía."
        exit 1
    fi

    if ! check_and_prompt_var "PB_PROXY"; then
        exit 1
    fi

    if check_env_var "PB_PROXY"; then
        if ! validate_proxy "$PB_PROXY"; then
            exit 1
        fi
        set_proxy "$PB_PROXY"
    else
        unset_proxy
    fi

    check_directory "$MOFLOT_DIR/deployment"

    log "Descargando actualizaciones..."
    git -C $MOFLOT_DIR/deployment fetch origin
    git -C $MOFLOT_DIR/deployment stash
    git -C $MOFLOT_DIR/deployment checkout -B deploy origin/deploy
    if git -C $MOFLOT_DIR/deployment stash apply; then
        git -C $MOFLOT_DIR/deployment stash drop
    else
        log "Conflicto detectado. Revirtiendo..."
        if git -C $MOFLOT_DIR/deployment merge --abort 2>/dev/null; then
            :
        elif git -C $MOFLOT_DIR/deployment rebase --abort 2>/dev/null; then
            :
        fi
        git -C $MOFLOT_DIR/deployment reset --hard
        error "No se pudieron aplicar los cambios locales automáticamente. Debe aplicar los cambios pendientes manualmente"
        exit 1
    fi

    log "Ejecutando actualizaciones..."
    $MOFLOT_DIR/deployment/update.sh
}

# Run main function
main "$@"
