#!/bin/bash

# RevCopy Health Check Script
# Comprehensive monitoring for all services

set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_FILE="/var/log/revcopy-health.log"
readonly ALERT_WEBHOOK="${ALERT_WEBHOOK:-}"
readonly CHECK_INTERVAL="${CHECK_INTERVAL:-30}"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Service configurations
declare -A SERVICES=(
    ["backend"]="http://localhost:8000/health"
    ["frontend"]="http://localhost:5173/health"
    ["admin"]="http://localhost:3001/health"
    ["postgres"]="localhost:5432"
    ["redis"]="localhost:6379"
    ["grafana"]="http://localhost:3000/api/health"
    ["prometheus"]="http://localhost:9090/-/healthy"
)

# Logging functions
log_with_timestamp() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}" | tee -a "${LOG_FILE}"
}

log_info() {
    log_with_timestamp "INFO" "$1"
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    log_with_timestamp "SUCCESS" "$1"
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    log_with_timestamp "WARNING" "$1"
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    log_with_timestamp "ERROR" "$1"
    echo -e "${RED}[ERROR]${NC} $1"
}

# Health check functions
check_http_service() {
    local service_name="$1"
    local url="$2"
    local timeout="${3:-10}"
    
    if curl -f -s --max-time "${timeout}" "${url}" > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

check_postgres() {
    if command -v pg_isready >/dev/null 2>&1; then
        pg_isready -h localhost -p 5432 -U postgres >/dev/null 2>&1
    else
        nc -z localhost 5432 >/dev/null 2>&1
    fi
}

check_redis() {
    if command -v redis-cli >/dev/null 2>&1; then
        redis-cli -h localhost -p 6379 ping | grep -q "PONG" >/dev/null 2>&1
    else
        nc -z localhost 6379 >/dev/null 2>&1
    fi
}

check_docker_service() {
    local service_name="$1"
    local container_name="$2"
    
    if docker ps --filter "name=${container_name}" --filter "status=running" | grep -q "${container_name}"; then
        return 0
    else
        return 1
    fi
}

check_disk_space() {
    local threshold="${1:-85}"
    local usage
    usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    
    if [[ ${usage} -gt ${threshold} ]]; then
        log_warning "Disk usage is ${usage}% (threshold: ${threshold}%)"
        return 1
    else
        return 0
    fi
}

check_memory_usage() {
    local threshold="${1:-85}"
    local usage
    usage=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
    
    if [[ ${usage} -gt ${threshold} ]]; then
        log_warning "Memory usage is ${usage}% (threshold: ${threshold}%)"
        return 1
    else
        return 0
    fi
}

check_system_load() {
    local threshold="${1:-5.0}"
    local load
    load=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    
    if (( $(echo "${load} > ${threshold}" | bc -l) )); then
        log_warning "System load is ${load} (threshold: ${threshold})"
        return 1
    else
        return 0
    fi
}

send_alert() {
    local service="$1"
    local status="$2"
    local message="$3"
    
    if [[ -n "${ALERT_WEBHOOK}" ]]; then
        local payload
        payload=$(cat <<EOF
{
    "service": "${service}",
    "status": "${status}",
    "message": "${message}",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "environment": "${ENVIRONMENT:-production}"
}
EOF
        )
        
        curl -s -X POST -H "Content-Type: application/json" \
            -d "${payload}" "${ALERT_WEBHOOK}" >/dev/null 2>&1 || true
    fi
}

check_service_health() {
    local service="$1"
    local endpoint="$2"
    local status=0
    
    case "${service}" in
        backend|frontend|admin|grafana|prometheus)
            if check_http_service "${service}" "${endpoint}"; then
                log_success "${service} is healthy"
            else
                log_error "${service} health check failed"
                send_alert "${service}" "unhealthy" "HTTP health check failed for ${endpoint}"
                status=1
            fi
            ;;
        postgres)
            if check_postgres; then
                log_success "PostgreSQL is healthy"
            else
                log_error "PostgreSQL health check failed"
                send_alert "postgres" "unhealthy" "PostgreSQL connection failed"
                status=1
            fi
            ;;
        redis)
            if check_redis; then
                log_success "Redis is healthy"
            else
                log_error "Redis health check failed"
                send_alert "redis" "unhealthy" "Redis connection failed"
                status=1
            fi
            ;;
    esac
    
    return ${status}
}

check_all_services() {
    log_info "Running comprehensive health checks..."
    local overall_status=0
    
    # Check each service
    for service in "${!SERVICES[@]}"; do
        if ! check_service_health "${service}" "${SERVICES[$service]}"; then
            overall_status=1
        fi
    done
    
    # Check system resources
    log_info "Checking system resources..."
    
    if ! check_disk_space 85; then
        overall_status=1
    fi
    
    if ! check_memory_usage 85; then
        overall_status=1
    fi
    
    if ! check_system_load 5.0; then
        overall_status=1
    fi
    
    # Check Docker containers
    log_info "Checking Docker containers..."
    local containers=("revcopy-backend" "revcopy-frontend" "revcopy-admin" "revcopy-postgres" "revcopy-redis")
    
    for container in "${containers[@]}"; do
        if check_docker_service "${container}" "${container}"; then
            log_success "Container ${container} is running"
        else
            log_warning "Container ${container} is not running"
            # Don't fail overall status for optional containers
        fi
    done
    
    return ${overall_status}
}

generate_health_report() {
    local output_file="${1:-/tmp/revcopy-health-report.json}"
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    log_info "Generating health report..."
    
    cat > "${output_file}" <<EOF
{
    "timestamp": "${timestamp}",
    "environment": "${ENVIRONMENT:-production}",
    "overall_status": "$(check_all_services >/dev/null 2>&1 && echo "healthy" || echo "unhealthy")",
    "services": {
EOF
    
    local first=true
    for service in "${!SERVICES[@]}"; do
        if [[ "${first}" == "false" ]]; then
            echo "," >> "${output_file}"
        fi
        first=false
        
        local status="unhealthy"
        if check_service_health "${service}" "${SERVICES[$service]}" >/dev/null 2>&1; then
            status="healthy"
        fi
        
        cat >> "${output_file}" <<EOF
        "${service}": {
            "status": "${status}",
            "endpoint": "${SERVICES[$service]}",
            "last_check": "${timestamp}"
        }
EOF
    done
    
    cat >> "${output_file}" <<EOF
    },
    "system": {
        "disk_usage": "$(df / | awk 'NR==2 {print $5}')",
        "memory_usage": "$(free | awk 'NR==2{printf "%.0f%%", $3*100/$2}')",
        "load_average": "$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')",
        "uptime": "$(uptime -p)"
    }
}
EOF
    
    log_success "Health report generated: ${output_file}"
}

monitor_continuously() {
    log_info "Starting continuous monitoring (interval: ${CHECK_INTERVAL}s)"
    
    while true; do
        if ! check_all_services; then
            log_error "Health check failed at $(date)"
        else
            log_success "All services healthy at $(date)"
        fi
        
        # Generate periodic report
        generate_health_report "/var/log/revcopy-health-$(date +%Y%m%d).json"
        
        sleep "${CHECK_INTERVAL}"
    done
}

show_service_status() {
    echo "RevCopy Service Status"
    echo "====================="
    echo
    
    for service in "${!SERVICES[@]}"; do
        printf "%-12s: " "${service}"
        if check_service_health "${service}" "${SERVICES[$service]}" >/dev/null 2>&1; then
            echo -e "${GREEN}HEALTHY${NC}"
        else
            echo -e "${RED}UNHEALTHY${NC}"
        fi
    done
    
    echo
    echo "System Resources"
    echo "================"
    echo "Disk Usage:    $(df / | awk 'NR==2 {print $5}')"
    echo "Memory Usage:  $(free | awk 'NR==2{printf "%.0f%%", $3*100/$2}')"
    echo "Load Average:  $(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')"
    echo "Uptime:        $(uptime -p)"
}

# Main function
main() {
    case "${1:-check}" in
        check)
            check_all_services
            ;;
        status)
            show_service_status
            ;;
        report)
            generate_health_report "${2:-/tmp/revcopy-health-report.json}"
            ;;
        monitor)
            monitor_continuously
            ;;
        *)
            echo "Usage: $0 {check|status|report|monitor}"
            echo
            echo "Commands:"
            echo "  check    - Run health checks once"
            echo "  status   - Show current service status"
            echo "  report   - Generate JSON health report"
            echo "  monitor  - Run continuous monitoring"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@" 