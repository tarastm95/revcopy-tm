#!/bin/bash

# RevCopy Professional Deployment Script
# Follows DevOps best practices and international standards
# Usage: ./scripts/deploy.sh [environment] [version]

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Script configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly LOG_FILE="/var/log/revcopy-deploy.log"
readonly DEPLOYMENT_BASE="/opt/revcopy"
readonly BACKUP_DIR="/opt/revcopy-backups"
readonly MAX_BACKUPS=5

# Default values
ENVIRONMENT="${1:-production}"
VERSION="${2:-latest}"
DRY_RUN="${DRY_RUN:-false}"
FORCE_DEPLOY="${FORCE_DEPLOY:-false}"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Logging functions
log_info() {
    local message="$1"
    echo -e "${BLUE}[INFO]${NC} ${message}" | tee -a "${LOG_FILE}"
}

log_success() {
    local message="$1"
    echo -e "${GREEN}[SUCCESS]${NC} ${message}" | tee -a "${LOG_FILE}"
}

log_warning() {
    local message="$1"
    echo -e "${YELLOW}[WARNING]${NC} ${message}" | tee -a "${LOG_FILE}"
}

log_error() {
    local message="$1"
    echo -e "${RED}[ERROR]${NC} ${message}" | tee -a "${LOG_FILE}"
}

# Error handling
handle_error() {
    local exit_code=$?
    local line_number=$1
    log_error "An error occurred on line ${line_number}. Exit code: ${exit_code}"
    cleanup
    exit ${exit_code}
}

trap 'handle_error ${LINENO}' ERR

# Cleanup function
cleanup() {
    log_info "Performing cleanup..."
    # Remove temporary files, unlock deployment, etc.
    if [[ -f "/tmp/revcopy-deploy.lock" ]]; then
        rm -f "/tmp/revcopy-deploy.lock"
    fi
}

# Validation functions
validate_environment() {
    local env="$1"
    case "${env}" in
        production|staging|development)
            return 0
            ;;
        *)
            log_error "Invalid environment: ${env}. Must be one of: production, staging, development"
            return 1
            ;;
    esac
}

validate_version() {
    local version="$1"
    if [[ ! "${version}" =~ ^[a-zA-Z0-9.-]+$ ]]; then
        log_error "Invalid version format: ${version}"
        return 1
    fi
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if running as appropriate user
    if [[ $EUID -eq 0 && "${ENVIRONMENT}" == "production" ]]; then
        log_error "Do not run production deployments as root"
        return 1
    fi
    
    # Check required tools
    local required_tools=("docker" "docker-compose" "git" "curl" "jq")
    for tool in "${required_tools[@]}"; do
        if ! command -v "${tool}" &> /dev/null; then
            log_error "Required tool not found: ${tool}"
            return 1
        fi
    done
    
    # Check deployment lock
    if [[ -f "/tmp/revcopy-deploy.lock" ]]; then
        local lock_pid
        lock_pid=$(cat "/tmp/revcopy-deploy.lock")
        if kill -0 "${lock_pid}" 2>/dev/null; then
            log_error "Another deployment is in progress (PID: ${lock_pid})"
            return 1
        else
            rm -f "/tmp/revcopy-deploy.lock"
        fi
    fi
    
    # Create deployment lock
    echo $$ > "/tmp/revcopy-deploy.lock"
    
    log_success "Prerequisites check passed"
}

backup_current_deployment() {
    log_info "Creating backup of current deployment..."
    
    local timestamp
    timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_path="${BACKUP_DIR}/${ENVIRONMENT}_${timestamp}"
    
    # Create backup directory
    mkdir -p "${backup_path}"
    
    # Backup current deployment
    if [[ -d "${DEPLOYMENT_BASE}/${ENVIRONMENT}" ]]; then
        cp -r "${DEPLOYMENT_BASE}/${ENVIRONMENT}" "${backup_path}/deployment"
        
        # Backup database
        if docker-compose -f "${DEPLOYMENT_BASE}/${ENVIRONMENT}/docker-compose.yml" ps postgres | grep -q "Up"; then
            local db_backup="${backup_path}/database_${timestamp}.sql"
            docker-compose -f "${DEPLOYMENT_BASE}/${ENVIRONMENT}/docker-compose.yml" exec -T postgres \
                pg_dumpall -U postgres > "${db_backup}"
            log_info "Database backup created: ${db_backup}"
        fi
        
        log_success "Backup created: ${backup_path}"
        echo "${backup_path}" > "/tmp/revcopy-last-backup"
    else
        log_warning "No existing deployment found to backup"
    fi
    
    # Clean old backups
    if [[ -d "${BACKUP_DIR}" ]]; then
        find "${BACKUP_DIR}" -maxdepth 1 -type d -name "${ENVIRONMENT}_*" | \
            sort -r | tail -n +$((MAX_BACKUPS + 1)) | xargs -r rm -rf
    fi
}

fetch_deployment_code() {
    log_info "Fetching deployment code..."
    
    local deployment_dir="${DEPLOYMENT_BASE}/${ENVIRONMENT}"
    local temp_dir="/tmp/revcopy-deploy-${VERSION}"
    
    # Clean temp directory
    rm -rf "${temp_dir}"
    
    # Clone repository
    if [[ "${VERSION}" == "latest" ]]; then
        git clone --depth 1 --branch main "https://github.com/slavamelandovich/revcopy.git" "${temp_dir}"
    else
        git clone --depth 1 --branch "${VERSION}" "https://github.com/slavamelandovich/revcopy.git" "${temp_dir}"
    fi
    
    # Verify code integrity
    if [[ ! -f "${temp_dir}/docker-compose.yml" ]]; then
        log_error "Invalid deployment code: missing docker-compose.yml"
        return 1
    fi
    
    # Create deployment directory
    mkdir -p "${deployment_dir}"
    
    # Copy code to deployment directory
    rsync -av --delete \
        --exclude='.git' \
        --exclude='node_modules' \
        --exclude='__pycache__' \
        --exclude='.env*' \
        "${temp_dir}/" "${deployment_dir}/"
    
    # Clean temp directory
    rm -rf "${temp_dir}"
    
    log_success "Deployment code fetched successfully"
}

setup_environment_config() {
    log_info "Setting up environment configuration..."
    
    local deployment_dir="${DEPLOYMENT_BASE}/${ENVIRONMENT}"
    local env_file="${deployment_dir}/.env"
    
    # Load environment-specific configuration
    case "${ENVIRONMENT}" in
        production)
            setup_production_config "${env_file}"
            ;;
        staging)
            setup_staging_config "${env_file}"
            ;;
        development)
            setup_development_config "${env_file}"
            ;;
    esac
    
    # Validate configuration
    if ! validate_env_file "${env_file}"; then
        log_error "Environment configuration validation failed"
        return 1
    fi
    
    log_success "Environment configuration set up successfully"
}

setup_production_config() {
    local env_file="$1"
    
    cat > "${env_file}" << EOF
# Production Environment Configuration
ENVIRONMENT=production
DEBUG=false

# Database Configuration
POSTGRES_HOST=postgres
POSTGRES_PORT=5432
POSTGRES_DB=${POSTGRES_DB:-revcopy_production}
POSTGRES_USER=${POSTGRES_USER:-revcopy_admin}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:?POSTGRES_PASSWORD is required}

# Redis Configuration
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=${REDIS_PASSWORD:?REDIS_PASSWORD is required}

# Security Keys
SECRET_KEY=${SECRET_KEY:?SECRET_KEY is required}
JWT_SECRET_KEY=${JWT_SECRET_KEY:?JWT_SECRET_KEY is required}
API_SECRET_KEY=${API_SECRET_KEY:?API_SECRET_KEY is required}

# API Keys
DEEPSEEK_API_KEY=${DEEPSEEK_API_KEY:-}
OPENAI_API_KEY=${OPENAI_API_KEY:-}

# Application URLs
BACKEND_URL=http://backend:8000
FRONTEND_URL=https://${DOMAIN:?DOMAIN is required}
ADMIN_URL=https://${DOMAIN}/admin
CRAWLER_URL=http://amazon-crawler:8080

# Monitoring
GRAFANA_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD:?GRAFANA_ADMIN_PASSWORD is required}
GRAFANA_SECRET_KEY=${GRAFANA_SECRET_KEY:?GRAFANA_SECRET_KEY is required}

# Domain
DOMAIN=${DOMAIN}
EOF
}

setup_staging_config() {
    local env_file="$1"
    
    cat > "${env_file}" << EOF
# Staging Environment Configuration
ENVIRONMENT=staging
DEBUG=true

# Database Configuration
POSTGRES_HOST=postgres
POSTGRES_PORT=5432
POSTGRES_DB=${POSTGRES_DB:-revcopy_staging}
POSTGRES_USER=${POSTGRES_USER:-revcopy_staging}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:?POSTGRES_PASSWORD is required}

# Redis Configuration
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=${REDIS_PASSWORD:?REDIS_PASSWORD is required}

# Security Keys (Use different keys for staging)
SECRET_KEY=${SECRET_KEY:?SECRET_KEY is required}
JWT_SECRET_KEY=${JWT_SECRET_KEY:?JWT_SECRET_KEY is required}
API_SECRET_KEY=${API_SECRET_KEY:?API_SECRET_KEY is required}

# API Keys
DEEPSEEK_API_KEY=${DEEPSEEK_API_KEY:-}
OPENAI_API_KEY=${OPENAI_API_KEY:-}

# Application URLs
BACKEND_URL=http://backend:8000
FRONTEND_URL=https://staging.${DOMAIN:?DOMAIN is required}
ADMIN_URL=https://staging.${DOMAIN}/admin
CRAWLER_URL=http://amazon-crawler:8080

# Monitoring
GRAFANA_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD:-admin123}
GRAFANA_SECRET_KEY=${GRAFANA_SECRET_KEY:-staging-secret}

# Domain
DOMAIN=staging.${DOMAIN}
EOF
}

setup_development_config() {
    local env_file="$1"
    
    cat > "${env_file}" << EOF
# Development Environment Configuration
ENVIRONMENT=development
DEBUG=true

# Database Configuration
POSTGRES_HOST=postgres
POSTGRES_PORT=5432
POSTGRES_DB=revcopy_dev
POSTGRES_USER=revcopy_dev
POSTGRES_PASSWORD=dev_password

# Redis Configuration
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=dev_password

# Security Keys (Development only - not secure)
SECRET_KEY=dev-secret-key-not-secure
JWT_SECRET_KEY=dev-jwt-secret-key-not-secure
API_SECRET_KEY=dev-api-secret-key-not-secure

# API Keys
DEEPSEEK_API_KEY=${DEEPSEEK_API_KEY:-}
OPENAI_API_KEY=${OPENAI_API_KEY:-}

# Application URLs
BACKEND_URL=http://backend:8000
FRONTEND_URL=http://localhost:5173
ADMIN_URL=http://localhost:3001
CRAWLER_URL=http://amazon-crawler:8080

# Monitoring
GRAFANA_ADMIN_PASSWORD=admin
GRAFANA_SECRET_KEY=dev-grafana-secret

# Domain
DOMAIN=localhost
EOF
}

validate_env_file() {
    local env_file="$1"
    
    # Check if file exists and is readable
    if [[ ! -r "${env_file}" ]]; then
        log_error "Environment file not readable: ${env_file}"
        return 1
    fi
    
    # Check for required variables in production
    if [[ "${ENVIRONMENT}" == "production" ]]; then
        local required_vars=("POSTGRES_PASSWORD" "REDIS_PASSWORD" "SECRET_KEY" "JWT_SECRET_KEY" "DOMAIN")
        for var in "${required_vars[@]}"; do
            if ! grep -q "^${var}=" "${env_file}" || grep -q "^${var}=$" "${env_file}"; then
                log_error "Required environment variable missing or empty: ${var}"
                return 1
            fi
        done
    fi
    
    return 0
}

deploy_services() {
    log_info "Deploying services..."
    
    local deployment_dir="${DEPLOYMENT_BASE}/${ENVIRONMENT}"
    
    cd "${deployment_dir}"
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "DRY RUN: Would deploy services with docker-compose"
        return 0
    fi
    
    # Pull latest images
    log_info "Pulling latest images..."
    docker-compose pull
    
    # Build and deploy services
    log_info "Building and starting services..."
    docker-compose up -d --build --remove-orphans
    
    # Wait for services to be ready
    log_info "Waiting for services to be ready..."
    sleep 30
    
    log_success "Services deployed successfully"
}

run_health_checks() {
    log_info "Running health checks..."
    
    local deployment_dir="${DEPLOYMENT_BASE}/${ENVIRONMENT}"
    local max_attempts=10
    local wait_time=5
    
    cd "${deployment_dir}"
    
    # Define health check endpoints
    declare -A health_endpoints=(
        ["backend"]="http://localhost:8000/health"
        ["frontend"]="http://localhost:5173/health"
        ["admin"]="http://localhost:3001/health"
    )
    
    for service in "${!health_endpoints[@]}"; do
        local endpoint="${health_endpoints[$service]}"
        local attempts=0
        
        log_info "Checking health of ${service}..."
        
        while [[ ${attempts} -lt ${max_attempts} ]]; do
            if curl -f -s "${endpoint}" > /dev/null; then
                log_success "${service} is healthy"
                break
            else
                ((attempts++))
                if [[ ${attempts} -eq ${max_attempts} ]]; then
                    log_error "${service} health check failed after ${max_attempts} attempts"
                    return 1
                else
                    log_info "Health check attempt ${attempts}/${max_attempts} failed for ${service}, retrying in ${wait_time}s..."
                    sleep ${wait_time}
                fi
            fi
        done
    done
    
    log_success "All health checks passed"
}

run_smoke_tests() {
    log_info "Running smoke tests..."
    
    local deployment_dir="${DEPLOYMENT_BASE}/${ENVIRONMENT}"
    
    cd "${deployment_dir}"
    
    # Test database connectivity
    if ! docker-compose exec -T postgres pg_isready -U postgres > /dev/null; then
        log_error "Database connectivity test failed"
        return 1
    fi
    
    # Test Redis connectivity
    if ! docker-compose exec -T redis redis-cli ping | grep -q "PONG"; then
        log_error "Redis connectivity test failed"
        return 1
    fi
    
    # Test API endpoints
    local backend_url="http://localhost:8000"
    if ! curl -f -s "${backend_url}/health" | grep -q "healthy"; then
        log_error "Backend API test failed"
        return 1
    fi
    
    log_success "All smoke tests passed"
}

rollback_deployment() {
    log_info "Rolling back deployment..."
    
    local last_backup
    if [[ -f "/tmp/revcopy-last-backup" ]]; then
        last_backup=$(cat "/tmp/revcopy-last-backup")
    else
        log_error "No backup information found for rollback"
        return 1
    fi
    
    if [[ ! -d "${last_backup}" ]]; then
        log_error "Backup directory not found: ${last_backup}"
        return 1
    fi
    
    local deployment_dir="${DEPLOYMENT_BASE}/${ENVIRONMENT}"
    
    # Stop current services
    cd "${deployment_dir}"
    docker-compose down
    
    # Restore from backup
    rm -rf "${deployment_dir}"
    cp -r "${last_backup}/deployment" "${deployment_dir}"
    
    # Restore database if available
    if [[ -f "${last_backup}/database_"*.sql ]]; then
        cd "${deployment_dir}"
        docker-compose up -d postgres
        sleep 10
        
        local db_backup
        db_backup=$(find "${last_backup}" -name "database_*.sql" | head -1)
        docker-compose exec -T postgres psql -U postgres < "${db_backup}"
    fi
    
    # Start services
    cd "${deployment_dir}"
    docker-compose up -d
    
    log_success "Rollback completed successfully"
}

show_deployment_status() {
    log_info "Deployment Status for ${ENVIRONMENT}:"
    
    local deployment_dir="${DEPLOYMENT_BASE}/${ENVIRONMENT}"
    
    if [[ -d "${deployment_dir}" ]]; then
        cd "${deployment_dir}"
        
        echo "Services Status:"
        docker-compose ps
        
        echo -e "\nResource Usage:"
        docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"
        
        echo -e "\nService URLs:"
        echo "Frontend: http://localhost:5173"
        echo "Admin: http://localhost:3001"
        echo "Backend API: http://localhost:8000"
        echo "Grafana: http://localhost:3000"
    else
        log_warning "No deployment found for environment: ${ENVIRONMENT}"
    fi
}

# Main deployment function
main() {
    log_info "Starting RevCopy deployment - Environment: ${ENVIRONMENT}, Version: ${VERSION}"
    
    # Validate inputs
    validate_environment "${ENVIRONMENT}"
    validate_version "${VERSION}"
    
    # Check prerequisites
    check_prerequisites
    
    # Show current status
    show_deployment_status
    
    # Create backup
    backup_current_deployment
    
    # Fetch and deploy code
    fetch_deployment_code
    setup_environment_config
    deploy_services
    
    # Verify deployment
    run_health_checks
    run_smoke_tests
    
    # Show final status
    show_deployment_status
    
    log_success "Deployment completed successfully!"
    log_info "Environment: ${ENVIRONMENT}"
    log_info "Version: ${VERSION}"
    log_info "Timestamp: $(date)"
    
    cleanup
}

# Handle script arguments
case "${1:-}" in
    rollback)
        rollback_deployment
        ;;
    status)
        show_deployment_status
        ;;
    *)
        main "$@"
        ;;
esac 