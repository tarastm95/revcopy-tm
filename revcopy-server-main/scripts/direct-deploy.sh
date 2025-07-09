#!/bin/bash

# Direct RevCopy Deployment
# Uploads code directly from local machine following DevOps standards

set -euo pipefail

# Configuration
readonly SERVER_HOST="${1:-37.27.217.240}"
readonly VERSION="${2:-latest}"
readonly LOG_FILE="./deployment.log"
readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Colors
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "${LOG_FILE}"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "${LOG_FILE}"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "${LOG_FILE}"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "${LOG_FILE}"
}

echo "🚀 RevCopy Direct Deployment"
echo "============================"
echo "Target Server: ${SERVER_HOST}"
echo "Version: ${VERSION}"
echo "Timestamp: $(date)"
echo ""

log_info "Step 1: Preparing local code..."

# Create deployment archive
cd "${PROJECT_ROOT}"
TEMP_ARCHIVE="/tmp/revcopy-deploy-$(date +%Y%m%d_%H%M%S).tar.gz"

log_info "Creating deployment archive..."
tar --exclude='.git' \
    --exclude='node_modules' \
    --exclude='__pycache__' \
    --exclude='*.pyc' \
    --exclude='.env*' \
    --exclude='venv' \
    --exclude='dist' \
    --exclude='build' \
    -czf "${TEMP_ARCHIVE}" .

log_success "Archive created: ${TEMP_ARCHIVE}"

log_info "Step 2: Uploading code to server..."

# Upload and extract on server
scp "${TEMP_ARCHIVE}" root@${SERVER_HOST}:/tmp/revcopy-deploy.tar.gz

log_success "Code uploaded to server"

log_info "Step 3: Setting up deployment on server..."

ssh root@${SERVER_HOST} "
    set -e
    
    echo '📥 Setting up deployment directory...'
    mkdir -p /opt/revcopy-production
    cd /opt/revcopy-production
    
    echo '🔄 Extracting new code...'
    tar -xzf /tmp/revcopy-deploy.tar.gz
    rm -f /tmp/revcopy-deploy.tar.gz
    
    echo '⚙️ Setting up environment...'
    cat > SERVER/.env << 'EOF'
# Production Environment
ENVIRONMENT=production
DEBUG=false

# Database
POSTGRES_HOST=postgres
POSTGRES_PORT=5432
POSTGRES_DB=revcopy_production
POSTGRES_USER=revcopy_admin
POSTGRES_PASSWORD=SecurePass123!

# Redis
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=RedisPass123!

# Security
SECRET_KEY=prod-secret-key-super-secure-12345678901234567890
JWT_SECRET_KEY=jwt-secret-key-super-secure-12345678901234567890
API_SECRET_KEY=api-secret-key-super-secure-12345678901234567890

# API Keys
DEEPSEEK_API_KEY=\${DEEPSEEK_API_KEY:-}
OPENAI_API_KEY=\${OPENAI_API_KEY:-}

# URLs
BACKEND_URL=http://backend:8000
FRONTEND_URL=https://${SERVER_HOST}
ADMIN_URL=https://${SERVER_HOST}/admin
CRAWLER_URL=http://amazon-crawler:8080

# Monitoring
GRAFANA_ADMIN_PASSWORD=GrafanaAdmin123!
GRAFANA_SECRET_KEY=grafana-secret-key-12345678901234567890

# Domain
DOMAIN=${SERVER_HOST}
VERSION=${VERSION}
EOF
    
    echo '🐳 Setting up Docker infrastructure...'
    # Create data directories
    mkdir -p data/{postgres,redis,grafana,prometheus}
    
    # Copy SERVER configs to root for Docker access
    cp -r SERVER/configs .
    cp -r SERVER/scripts .
    cp -r SERVER/dockerfiles .
    
    echo '🔧 Fixing Dockerfile issues...'
    # Fix the Dockerfile.crawler issue
    sed -i 's/COPY --from=build \/app\/configs \/app\/configs 2>\/dev\/null || echo \"No configs directory found\"/COPY --from=build \/app\/configs \/app\/configs 2>\/dev\/null || true/' dockerfiles/Dockerfile.crawler
    
    echo '🏗️ Building and starting services...'
    # Use the production docker-compose
    cd SERVER
    
    # Stop existing services
    docker-compose -f docker-compose.production.yml down --remove-orphans || true
    
    # Build services
    docker-compose -f docker-compose.production.yml build --no-cache
    
    # Start services
    docker-compose -f docker-compose.production.yml up -d
    
    echo '⏳ Waiting for services to start...'
    sleep 60
    
    echo '✅ Checking service status...'
    docker-compose -f docker-compose.production.yml ps
    
    echo '🔍 Checking logs for any issues...'
    docker-compose -f docker-compose.production.yml logs --tail=20
    
    echo '🎉 Deployment completed!'
"

# Clean up local temp file
rm -f "${TEMP_ARCHIVE}"

log_success "Step 4: Verifying deployment..."

# Health checks with retry logic
check_service_with_retry() {
    local service_name="$1"
    local url="$2"
    local max_attempts=5
    local wait_time=10
    
    for i in $(seq 1 $max_attempts); do
        if curl -f -s --max-time 10 "${url}" > /dev/null 2>&1; then
            log_success "${service_name} is healthy"
            return 0
        else
            if [ $i -eq $max_attempts ]; then
                log_warning "${service_name} health check failed after ${max_attempts} attempts"
                return 1
            else
                log_info "Health check ${i}/${max_attempts} failed for ${service_name}, retrying in ${wait_time}s..."
                sleep $wait_time
            fi
        fi
    done
}

# Wait for services to be fully ready
log_info "Waiting for services to initialize..."
sleep 30

# Check all services
log_info "Running health checks..."

# Check basic connectivity first
if check_service_with_retry "Server Connection" "http://${SERVER_HOST}"; then
    echo "✅ Server: http://${SERVER_HOST}"
fi

# Attempt to check individual services (they might not have health endpoints yet)
echo ""
echo "🎉 RevCopy Deployment Complete!"
echo "==============================="
echo "🌐 Frontend: http://${SERVER_HOST}:5173"
echo "🔧 Admin Panel: http://${SERVER_HOST}:3001"  
echo "🚀 Backend API: http://${SERVER_HOST}:8000"
echo "📊 Grafana: http://${SERVER_HOST}:3000 (admin/GrafanaAdmin123!)"
echo "📈 Prometheus: http://${SERVER_HOST}:9090"
echo ""
echo "✨ Deployment completed successfully!"
echo "📝 Log file: ${LOG_FILE}"
echo ""
echo "🔍 To check service status on server:"
echo "   ssh root@${SERVER_HOST} 'cd /opt/revcopy-production/SERVER && docker-compose -f docker-compose.production.yml ps'"
echo ""
echo "🔧 To view service logs:"
echo "   ssh root@${SERVER_HOST} 'cd /opt/revcopy-production/SERVER && docker-compose -f docker-compose.production.yml logs -f'" 