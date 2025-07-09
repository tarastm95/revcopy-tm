#!/bin/bash
# ==============================================================================
# RevCopy SSL Setup Script
# Automated SSL certificate management with Let's Encrypt
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

# Load environment variables
load_env() {
    if [[ -f ".env" ]]; then
        source .env
        log "Environment variables loaded"
    else
        error ".env file not found! Please run 'make init' first."
        exit 1
    fi
}

# Validate domain configuration
validate_domain() {
    if [[ -z "${DOMAIN:-}" ]] || [[ "$DOMAIN" == "your-domain.com" ]]; then
        error "Please configure your domain in the .env file"
        exit 1
    fi
    
    log "Domain configured: $DOMAIN"
}

# Check DNS resolution
check_dns() {
    log "Checking DNS resolution for $DOMAIN..."
    
    local domain_ip
    domain_ip=$(dig +short "$DOMAIN" 2>/dev/null || echo "")
    
    if [[ -z "$domain_ip" ]]; then
        error "Domain $DOMAIN does not resolve to an IP address"
        exit 1
    fi
    
    success "Domain resolves to: $domain_ip"
}

# Create necessary directories
create_directories() {
    log "Creating SSL directories..."
    
    mkdir -p configs/nginx/ssl
    mkdir -p letsencrypt/live
    mkdir -p letsencrypt/archive
    mkdir -p webroot/.well-known/acme-challenge
    
    success "SSL directories created"
}

# Generate self-signed certificates for initial setup
generate_self_signed() {
    log "Generating self-signed certificates for initial setup..."
    
    local ssl_dir="configs/nginx/ssl"
    
    # Generate private key
    openssl genrsa -out "$ssl_dir/privkey.pem" 2048
    
    # Generate certificate
    openssl req -new -x509 -key "$ssl_dir/privkey.pem" \
        -out "$ssl_dir/fullchain.pem" \
        -days 30 \
        -subj "/C=US/ST=State/L=City/O=Organization/CN=$DOMAIN"
    
    # Create dhparam
    openssl dhparam -out "$ssl_dir/dhparam.pem" 2048
    
    success "Self-signed certificates generated"
}

# Setup Let's Encrypt certificates
setup_letsencrypt() {
    log "Setting up Let's Encrypt certificates..."
    
    # Start nginx for ACME challenge
    docker-compose up -d nginx
    sleep 10
    
    # Request certificate
    local staging_flag=""
    if [[ "${LETSENCRYPT_STAGING:-false}" == "true" ]]; then
        staging_flag="--staging"
        warning "Using Let's Encrypt staging environment"
    fi
    
    docker run --rm \
        -v "$(pwd)/letsencrypt:/etc/letsencrypt" \
        -v "$(pwd)/webroot:/var/www/certbot" \
        certbot/certbot certonly \
        --webroot \
        --webroot-path=/var/www/certbot \
        --email "${LETSENCRYPT_EMAIL:-admin@$DOMAIN}" \
        --agree-tos \
        --no-eff-email \
        $staging_flag \
        -d "$DOMAIN"
    
    if [[ $? -eq 0 ]]; then
        success "Let's Encrypt certificate obtained successfully"
        
        # Copy certificates to nginx ssl directory
        cp "letsencrypt/live/$DOMAIN/fullchain.pem" configs/nginx/ssl/
        cp "letsencrypt/live/$DOMAIN/privkey.pem" configs/nginx/ssl/
        
        # Generate dhparam if not exists
        if [[ ! -f "configs/nginx/ssl/dhparam.pem" ]]; then
            openssl dhparam -out configs/nginx/ssl/dhparam.pem 2048
        fi
        
        # Reload nginx
        docker-compose exec nginx nginx -s reload
        
        success "SSL certificates installed and nginx reloaded"
    else
        error "Failed to obtain Let's Encrypt certificate"
        return 1
    fi
}

# Setup SSL renewal
setup_renewal() {
    log "Setting up SSL certificate renewal..."
    
    # Create renewal script
    cat > scripts/renew-ssl.sh << 'EOF'
#!/bin/bash
# SSL Certificate Renewal Script

set -euo pipefail

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

log "Starting SSL certificate renewal..."

# Renew certificates
docker run --rm \
    -v "$(pwd)/letsencrypt:/etc/letsencrypt" \
    -v "$(pwd)/webroot:/var/www/certbot" \
    certbot/certbot renew --quiet

# Check if renewal was successful
if [[ $? -eq 0 ]]; then
    log "Certificate renewal completed"
    
    # Copy renewed certificates
    if [[ -f "letsencrypt/live/$DOMAIN/fullchain.pem" ]]; then
        cp "letsencrypt/live/$DOMAIN/fullchain.pem" configs/nginx/ssl/
        cp "letsencrypt/live/$DOMAIN/privkey.pem" configs/nginx/ssl/
        
        # Reload nginx
        docker-compose exec nginx nginx -s reload
        log "Nginx reloaded with new certificates"
    fi
else
    log "Certificate renewal failed"
    exit 1
fi
EOF
    
    chmod +x scripts/renew-ssl.sh
    
    success "SSL renewal script created"
}

# Setup nginx SSL configuration
setup_nginx_ssl() {
    log "Setting up nginx SSL configuration..."
    
    # Create SSL nginx configuration
    mkdir -p configs/nginx/sites
    
    cat > configs/nginx/sites/ssl.conf << EOF
# SSL Configuration for $DOMAIN

server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN;
    
    # ACME challenge location
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }
    
    # Redirect all other traffic to HTTPS
    location / {
        return 301 https://\$server_name\$request_uri;
    }
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name $DOMAIN;
    
    # SSL Configuration
    ssl_certificate /etc/nginx/ssl/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/privkey.pem;
    ssl_dhparam /etc/nginx/ssl/dhparam.pem;
    
    # SSL Security Settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # Security Headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options DENY always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    
    # Frontend Application
    location / {
        proxy_pass http://frontend;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    # API Backend
    location /api/ {
        proxy_pass http://backend:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    # Admin Panel
    location /admin/ {
        proxy_pass http://admin;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
    
    success "Nginx SSL configuration created"
}

# Test SSL configuration
test_ssl() {
    log "Testing SSL configuration..."
    
    # Test nginx configuration
    if docker-compose exec nginx nginx -t; then
        success "Nginx configuration test passed"
    else
        error "Nginx configuration test failed"
        return 1
    fi
    
    # Test SSL certificate
    if openssl x509 -in configs/nginx/ssl/fullchain.pem -text -noout >/dev/null 2>&1; then
        success "SSL certificate is valid"
    else
        error "SSL certificate is invalid"
        return 1
    fi
}

# Main function
main() {
    local domain_arg="${1:-}"
    
    echo "=================================================================="
    echo "                    RevCopy SSL Setup"
    echo "=================================================================="
    
    # If domain provided as argument, update .env file
    if [[ -n "$domain_arg" ]]; then
        if [[ -f ".env" ]]; then
            sed -i.bak "s/^DOMAIN=.*/DOMAIN=$domain_arg/" .env
            log "Domain updated to: $domain_arg"
        else
            error ".env file not found"
            exit 1
        fi
    fi
    
    load_env
    validate_domain
    check_dns
    create_directories
    setup_nginx_ssl
    
    # Choose SSL setup method
    echo ""
    echo "Choose SSL setup method:"
    echo "1) Let's Encrypt (recommended for production)"
    echo "2) Self-signed certificates (for testing)"
    echo ""
    read -p "Enter choice [1-2]: " choice
    
    case $choice in
        1)
            setup_letsencrypt
            setup_renewal
            ;;
        2)
            generate_self_signed
            warning "Self-signed certificates are not suitable for production!"
            ;;
        *)
            error "Invalid choice"
            exit 1
            ;;
    esac
    
    test_ssl
    
    success "SSL setup completed successfully!"
    echo ""
    echo "Next steps:"
    echo "1. Restart nginx: docker-compose restart nginx"
    echo "2. Test your domain: https://$DOMAIN"
    echo "3. Set up automatic renewal (cron job recommended)"
    echo ""
    echo "For automatic renewal, add to crontab:"
    echo "0 2 * * * cd $(pwd) && ./scripts/renew-ssl.sh"
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [domain] [options]"
        echo ""
        echo "Arguments:"
        echo "  domain          Domain name to setup SSL for"
        echo ""
        echo "Options:"
        echo "  --help, -h      Show this help message"
        echo ""
        echo "Examples:"
        echo "  $0                     # Use domain from .env file"
        echo "  $0 example.com         # Setup SSL for example.com"
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac 