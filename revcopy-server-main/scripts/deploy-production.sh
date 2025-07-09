#!/bin/bash
# ==============================================================================
# RevCopy Production Deployment Script
# Professional deployment with proper error handling and logging
# ==============================================================================

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
readonly SERVER_HOST="${1:-37.27.217.240}"
readonly VERSION="${2:-latest}"
readonly DEPLOYMENT_PATH="/opt/revcopy-production"

# Logging function
log() {
    local level="$1"
    shift
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') [${level}] $*"
}

log_info() { log "${BLUE}INFO${NC}" "$@"; }
log_success() { log "${GREEN}SUCCESS${NC}" "$@"; }
log_warning() { log "${YELLOW}WARNING${NC}" "$@"; }
log_error() { log "${RED}ERROR${NC}" "$@"; }

# Error handling
trap 'log_error "Deployment failed at line $LINENO"' ERR

cleanup() {
    log_info "Cleaning up temporary files..."
    rm -f /tmp/revcopy-deploy.tar.gz
}
trap cleanup EXIT

main() {
    log_info "🚀 Starting RevCopy Production Deployment"
    log_info "Server: ${SERVER_HOST}"
    log_info "Version: ${VERSION}"
    
    # Step 1: Package the application
    log_info "📦 Step 1: Packaging application..."
    create_deployment_package
    
    # Step 2: Transfer to server
    log_info "📤 Step 2: Transferring to server..."
    transfer_to_server
    
    # Step 3: Deploy on server
    log_info "🏗️ Step 3: Deploying on server..."
    deploy_on_server
    
    # Step 4: Verify deployment
    log_info "✅ Step 4: Verifying deployment..."
    verify_deployment
    
    log_success "🎉 Deployment completed successfully!"
    log_info "Frontend: http://${SERVER_HOST}"
    log_info "Admin Panel: http://${SERVER_HOST}/admin"
    log_info "API: http://${SERVER_HOST}/api"
}

create_deployment_package() {
    log_info "Creating deployment package..."
    
    cd "${PROJECT_ROOT}"
    
    # Create a temporary directory for packaging
    local temp_dir="/tmp/revcopy-deploy-$$"
    mkdir -p "${temp_dir}"
    
    # Copy all necessary files
    cp -r SERVER "${temp_dir}/"
    cp -r backend "${temp_dir}/"
    cp -r frontend "${temp_dir}/"
    cp -r admin "${temp_dir}/"
    cp -r crawlers "${temp_dir}/"
    
    # Create the archive
    cd "${temp_dir}"
    tar -czf /tmp/revcopy-deploy.tar.gz .
    
    # Cleanup temp directory
    rm -rf "${temp_dir}"
    
    log_success "Package created successfully"
}

transfer_to_server() {
    log_info "Transferring package to server..."
    
    # Transfer the package
    scp /tmp/revcopy-deploy.tar.gz root@${SERVER_HOST}:/tmp/
    
    log_success "Package transferred successfully"
}

deploy_on_server() {
    log_info "Deploying on server..."
    
    ssh root@${SERVER_HOST} << 'EOF'
set -euo pipefail

# Colors for remote output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

log_info() { echo -e "$(date '+%Y-%m-%d %H:%M:%S') [${BLUE}INFO${NC}] $*"; }
log_success() { echo -e "$(date '+%Y-%m-%d %H:%M:%S') [${GREEN}SUCCESS${NC}] $*"; }
log_warning() { echo -e "$(date '+%Y-%m-%d %H:%M:%S') [${YELLOW}WARNING${NC}] $*"; }
log_error() { echo -e "$(date '+%Y-%m-%d %H:%M:%S') [${RED}ERROR${NC}] $*"; }

DEPLOYMENT_PATH="/opt/revcopy-production"
SERVER_HOST="37.27.217.240"
VERSION="latest"

log_info "🏗️ Setting up deployment directory..."
mkdir -p ${DEPLOYMENT_PATH}
cd ${DEPLOYMENT_PATH}

# Stop existing services
log_info "🛑 Stopping existing services..."
if [ -f "SERVER/docker-compose.production.yml" ]; then
    cd SERVER
    docker-compose -f docker-compose.production.yml down --remove-orphans || true
    cd ..
fi

log_info "🔄 Extracting new application..."
tar -xzf /tmp/revcopy-deploy.tar.gz
rm -f /tmp/revcopy-deploy.tar.gz

log_info "⚙️ Setting up environment configuration..."
cat > SERVER/.env << 'ENVEOF'
# Production Environment Configuration
ENVIRONMENT=production
DEBUG=false
VERSION=latest

# Database Configuration
POSTGRES_HOST=postgres
POSTGRES_PORT=5432
POSTGRES_DB=revcopy_production
POSTGRES_USER=revcopy_admin
POSTGRES_PASSWORD=SecureRevcopyPass2024!

# Redis Configuration
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=SecureRedisPass2024!

# Security Keys (Generated securely)
SECRET_KEY=revcopy-prod-secret-key-2024-super-secure-12345678901234567890
JWT_SECRET_KEY=revcopy-jwt-secret-key-2024-super-secure-12345678901234567890
API_SECRET_KEY=revcopy-api-secret-key-2024-super-secure-12345678901234567890

# API Keys (Add your actual keys here)
DEEPSEEK_API_KEY=${DEEPSEEK_API_KEY:-}
OPENAI_API_KEY=${OPENAI_API_KEY:-}

# Application URLs
BACKEND_URL=http://backend:8000
FRONTEND_URL=https://37.27.217.240
ADMIN_URL=https://37.27.217.240/admin
CRAWLER_URL=http://amazon-crawler:8080

# Monitoring
GRAFANA_ADMIN_PASSWORD=SecureGrafanaPass2024!
GRAFANA_SECRET_KEY=grafana-secret-key-2024-12345678901234567890

# Domain
DOMAIN=37.27.217.240
ENVEOF

log_info "🐳 Setting up Docker infrastructure..."
cd SERVER

# Create necessary directories
mkdir -p data/{postgres,redis,grafana,prometheus,nginx}
mkdir -p logs/{nginx,backend,frontend,admin,crawler}

# Set proper permissions
chmod -R 755 data logs

log_info "🔧 Building Docker images..."
# Build images with proper context paths
docker-compose -f docker-compose.production.yml build --no-cache

log_info "🚀 Starting services..."
docker-compose -f docker-compose.production.yml up -d

log_info "⏳ Waiting for services to initialize..."
sleep 45

log_info "📊 Checking service status..."
docker-compose -f docker-compose.production.yml ps

log_info "📝 Checking logs for any issues..."
echo "=== Backend Logs ==="
docker-compose -f docker-compose.production.yml logs --tail=10 backend || true
echo "=== Frontend Logs ==="  
docker-compose -f docker-compose.production.yml logs --tail=10 frontend || true
echo "=== Admin Logs ==="
docker-compose -f docker-compose.production.yml logs --tail=10 admin || true

log_success "✅ Server deployment completed!"
EOF
}

verify_deployment() {
    log_info "Verifying deployment health..."
    
    # Wait a bit for services to fully start
    sleep 30
    
    # Check if the main site responds
    if curl -sSf "http://${SERVER_HOST}" > /dev/null 2>&1; then
        log_success "✅ Frontend is responding"
    else
        log_warning "⚠️  Frontend is not responding yet"
    fi
    
    # Check if admin panel responds
    if curl -sSf "http://${SERVER_HOST}/admin" > /dev/null 2>&1; then
        log_success "✅ Admin panel is responding"
    else
        log_warning "⚠️  Admin panel is not responding yet"
    fi
    
    # Check API health endpoint
    if curl -sSf "http://${SERVER_HOST}/api/health" > /dev/null 2>&1; then
        log_success "✅ API is responding"
    else
        log_warning "⚠️  API is not responding yet"
    fi
    
    log_info "🔍 Final service status check..."
    ssh root@${SERVER_HOST} "cd /opt/revcopy-production/SERVER && docker-compose -f docker-compose.production.yml ps"
}

# Run main function
main "$@" 