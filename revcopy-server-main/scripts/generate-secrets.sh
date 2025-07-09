#!/bin/bash
# ==============================================================================
# RevCopy Secret Generation Script
# Generates secure secrets for production deployment
# ==============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}"
}

# Generate a random secret of specified length
generate_secret() {
    local length=${1:-32}
    openssl rand -hex "$length"
}

# Generate a random password
generate_password() {
    local length=${1:-24}
    openssl rand -base64 "$length" | tr -d "/+=" | cut -c1-"$length"
}

# Generate JWT secret (must be at least 32 characters)
generate_jwt_secret() {
    generate_secret 32
}

# Update .env file with generated secrets
update_env_file() {
    local env_file=".env"
    
    if [[ ! -f "$env_file" ]]; then
        error "Environment file $env_file not found!"
        exit 1
    fi
    
    log "Generating secure secrets..."
    
    # Generate all secrets
    local api_secret_key
    local postgres_password
    local redis_password
    local grafana_password
    local crawler_api_key
    
    api_secret_key=$(generate_jwt_secret)
    postgres_password=$(generate_password 24)
    redis_password=$(generate_password 20)
    grafana_password=$(generate_password 16)
    crawler_api_key=$(generate_secret 24)
    
    # Create backup of current .env file
    cp "$env_file" "${env_file}.backup.$(date +%Y%m%d_%H%M%S)"
    log "Created backup of .env file"
    
    # Update secrets in .env file
    log "Updating secrets in $env_file..."
    
    # API Secret Key
    if grep -q "^API_SECRET_KEY=" "$env_file"; then
        sed -i.tmp "s/^API_SECRET_KEY=.*/API_SECRET_KEY=$api_secret_key/" "$env_file"
    else
        echo "API_SECRET_KEY=$api_secret_key" >> "$env_file"
    fi
    
    # PostgreSQL Password
    if grep -q "^POSTGRES_PASSWORD=" "$env_file"; then
        sed -i.tmp "s/^POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=$postgres_password/" "$env_file"
    else
        echo "POSTGRES_PASSWORD=$postgres_password" >> "$env_file"
    fi
    
    # Redis Password
    if grep -q "^REDIS_PASSWORD=" "$env_file"; then
        sed -i.tmp "s/^REDIS_PASSWORD=.*/REDIS_PASSWORD=$redis_password/" "$env_file"
    else
        echo "REDIS_PASSWORD=$redis_password" >> "$env_file"
    fi
    
    # Grafana Password
    if grep -q "^GRAFANA_ADMIN_PASSWORD=" "$env_file"; then
        sed -i.tmp "s/^GRAFANA_ADMIN_PASSWORD=.*/GRAFANA_ADMIN_PASSWORD=$grafana_password/" "$env_file"
    else
        echo "GRAFANA_ADMIN_PASSWORD=$grafana_password" >> "$env_file"
    fi
    
    # Crawler API Key
    if grep -q "^AMAZON_CRAWLER_API_KEY=" "$env_file"; then
        sed -i.tmp "s/^AMAZON_CRAWLER_API_KEY=.*/AMAZON_CRAWLER_API_KEY=$crawler_api_key/" "$env_file"
    else
        echo "AMAZON_CRAWLER_API_KEY=$crawler_api_key" >> "$env_file"
    fi
    
    # Clean up temporary files
    rm -f "${env_file}.tmp"
    
    success "Secrets generated and updated in $env_file"
    
    # Display generated secrets (for initial setup)
    echo ""
    echo "===================================================="
    echo "Generated Secrets (SAVE THESE SECURELY!)"
    echo "===================================================="
    echo "API Secret Key: $api_secret_key"
    echo "PostgreSQL Password: $postgres_password"
    echo "Redis Password: $redis_password"
    echo "Grafana Admin Password: $grafana_password"
    echo "Crawler API Key: $crawler_api_key"
    echo "===================================================="
    echo ""
    warning "Make sure to store these secrets securely!"
    warning "The .env file backup was created for safety."
}

# Generate SSL certificate passwords
generate_ssl_secrets() {
    log "Generating SSL certificate passwords..."
    
    local ssl_password
    ssl_password=$(generate_password 20)
    
    # Update SSL password in .env
    if grep -q "^SSL_CERT_PASSWORD=" .env; then
        sed -i.tmp "s/^SSL_CERT_PASSWORD=.*/SSL_CERT_PASSWORD=$ssl_password/" .env
    else
        echo "SSL_CERT_PASSWORD=$ssl_password" >> .env
    fi
    
    success "SSL secrets generated"
    echo "SSL Certificate Password: $ssl_password"
}

# Generate database encryption keys
generate_db_encryption_keys() {
    log "Generating database encryption keys..."
    
    local db_encryption_key
    db_encryption_key=$(generate_secret 32)
    
    # Update database encryption key in .env
    if grep -q "^DB_ENCRYPTION_KEY=" .env; then
        sed -i.tmp "s/^DB_ENCRYPTION_KEY=.*/DB_ENCRYPTION_KEY=$db_encryption_key/" .env
    else
        echo "DB_ENCRYPTION_KEY=$db_encryption_key" >> .env
    fi
    
    success "Database encryption keys generated"
}

# Generate session and CSRF tokens
generate_session_secrets() {
    log "Generating session and CSRF secrets..."
    
    local session_secret
    local csrf_secret
    
    session_secret=$(generate_secret 32)
    csrf_secret=$(generate_secret 32)
    
    # Update session secrets in .env
    if grep -q "^SESSION_SECRET=" .env; then
        sed -i.tmp "s/^SESSION_SECRET=.*/SESSION_SECRET=$session_secret/" .env
    else
        echo "SESSION_SECRET=$session_secret" >> .env
    fi
    
    if grep -q "^CSRF_SECRET=" .env; then
        sed -i.tmp "s/^CSRF_SECRET=.*/CSRF_SECRET=$csrf_secret/" .env
    else
        echo "CSRF_SECRET=$csrf_secret" >> .env
    fi
    
    success "Session secrets generated"
}

# Generate monitoring secrets
generate_monitoring_secrets() {
    log "Generating monitoring secrets..."
    
    local prometheus_token
    local jaeger_secret
    
    prometheus_token=$(generate_secret 24)
    jaeger_secret=$(generate_secret 24)
    
    # Update monitoring secrets in .env
    if grep -q "^PROMETHEUS_AUTH_TOKEN=" .env; then
        sed -i.tmp "s/^PROMETHEUS_AUTH_TOKEN=.*/PROMETHEUS_AUTH_TOKEN=$prometheus_token/" .env
    else
        echo "PROMETHEUS_AUTH_TOKEN=$prometheus_token" >> .env
    fi
    
    if grep -q "^JAEGER_SECRET=" .env; then
        sed -i.tmp "s/^JAEGER_SECRET=.*/JAEGER_SECRET=$jaeger_secret/" .env
    else
        echo "JAEGER_SECRET=$jaeger_secret" >> .env
    fi
    
    success "Monitoring secrets generated"
}

# Validate openssl availability
check_dependencies() {
    if ! command -v openssl >/dev/null 2>&1; then
        error "OpenSSL is required but not installed"
        exit 1
    fi
    
    if ! command -v sed >/dev/null 2>&1; then
        error "sed is required but not installed"
        exit 1
    fi
}

# Main function
main() {
    log "Starting RevCopy secret generation..."
    
    check_dependencies
    update_env_file
    generate_ssl_secrets
    generate_db_encryption_keys
    generate_session_secrets
    generate_monitoring_secrets
    
    # Clean up any remaining temporary files
    rm -f .env.tmp
    
    success "All secrets generated successfully!"
    echo ""
    echo "Next steps:"
    echo "1. Review and configure remaining variables in .env"
    echo "2. Set your domain name: DOMAIN=your-domain.com"
    echo "3. Configure AI service API keys"
    echo "4. Configure email SMTP settings"
    echo "5. Run 'make deploy-production' to start the services"
    echo ""
    warning "Remember to keep the .env file secure and never commit it to version control!"
}

# Run main function
main "$@" 