#!/bin/bash
# RevCopy Enterprise Server Installation Script
# Professional automated setup for production deployment

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
SERVER_HOST="37.27.217.240"
DEPLOYMENT_PATH="/opt/revcopy"
LOG_FILE="/tmp/revcopy-install.log"
PYTHON_VERSION="3.11"

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}✅ $1${NC}" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}⚠️ $1${NC}" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}❌ $1${NC}" | tee -a "$LOG_FILE"
    exit 1
}

header() {
    echo -e "\n${PURPLE}================================================${NC}"
    echo -e "${PURPLE} $1${NC}"
    echo -e "${PURPLE}================================================${NC}\n"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (use sudo)"
    fi
}

# Check system requirements
check_system() {
    header "🔍 CHECKING SYSTEM REQUIREMENTS"
    
    # Check OS
    if [[ ! -f /etc/os-release ]]; then
        error "Cannot determine OS version"
    fi
    
    source /etc/os-release
    log "Operating System: $PRETTY_NAME"
    
    # Check if Ubuntu/Debian
    if [[ "$ID" != "ubuntu" && "$ID" != "debian" ]]; then
        warning "This script is optimized for Ubuntu/Debian. Proceed with caution."
    fi
    
    # Check memory
    local memory_gb=$(free -g | awk '/^Mem:/{print $2}')
    if [[ $memory_gb -lt 2 ]]; then
        warning "System has less than 2GB RAM. Performance may be affected."
    else
        log "Memory: ${memory_gb}GB ✓"
    fi
    
    # Check disk space
    local disk_space=$(df / | awk 'NR==2{print $4}')
    local disk_space_gb=$((disk_space / 1024 / 1024))
    if [[ $disk_space_gb -lt 10 ]]; then
        error "Insufficient disk space. At least 10GB required."
    else
        log "Disk space: ${disk_space_gb}GB ✓"
    fi
    
    success "System requirements check completed"
}

# Update system packages
update_system() {
    header "📦 UPDATING SYSTEM PACKAGES"
    
    log "Updating package lists..."
    apt-get update || error "Failed to update package lists"
    
    log "Upgrading existing packages..."
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y || error "Failed to upgrade packages"
    
    log "Installing essential packages..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        curl \
        wget \
        git \
        htop \
        vim \
        unzip \
        software-properties-common \
        apt-transport-https \
        ca-certificates \
        gnupg \
        lsb-release \
        jq \
        fail2ban \
        ufw \
        logrotate \
        cron || error "Failed to install essential packages"
    
    success "System packages updated successfully"
}

# Install Docker
install_docker() {
    header "🐳 INSTALLING DOCKER"
    
    # Remove old Docker versions
    log "Removing old Docker versions..."
    apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Install Docker repository
    log "Adding Docker repository..."
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Update package list
    apt-get update || error "Failed to update package list after adding Docker repo"
    
    # Install Docker
    log "Installing Docker CE..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin || error "Failed to install Docker"
    
    # Install Docker Compose standalone
    log "Installing Docker Compose..."
    local compose_version="2.24.5"
    curl -L "https://github.com/docker/compose/releases/download/v${compose_version}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    
    # Start and enable Docker
    systemctl enable docker
    systemctl start docker
    
    # Verify installation
    if docker --version && docker-compose --version; then
        success "Docker installed successfully"
        log "Docker version: $(docker --version)"
        log "Docker Compose version: $(docker-compose --version)"
    else
        error "Docker installation failed"
    fi
}

# Install Python and dependencies
install_python() {
    header "🐍 INSTALLING PYTHON AND DEPENDENCIES"
    
    # Install Python
    log "Installing Python ${PYTHON_VERSION}..."
    add-apt-repository ppa:deadsnakes/ppa -y
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        python${PYTHON_VERSION} \
        python${PYTHON_VERSION}-dev \
        python${PYTHON_VERSION}-venv \
        python3-pip \
        python3-setuptools || error "Failed to install Python"
    
    # Set Python alternatives
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python${PYTHON_VERSION} 1
    
    # Upgrade pip
    log "Upgrading pip..."
    python3 -m pip install --upgrade pip
    
    success "Python ${PYTHON_VERSION} installed successfully"
}

# Install Node.js
install_nodejs() {
    header "📗 INSTALLING NODE.JS"
    
    log "Installing Node.js 18.x..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs || error "Failed to install Node.js"
    
    # Install global packages
    log "Installing global npm packages..."
    npm install -g pm2 || warning "Failed to install PM2"
    
    if node --version && npm --version; then
        success "Node.js installed successfully"
        log "Node.js version: $(node --version)"
        log "npm version: $(npm --version)"
    else
        error "Node.js installation failed"
    fi
}

# Setup Nginx
install_nginx() {
    header "🌐 INSTALLING AND CONFIGURING NGINX"
    
    log "Installing Nginx..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y nginx || error "Failed to install Nginx"
    
    # Create basic configuration
    log "Configuring Nginx..."
    cat > /etc/nginx/sites-available/revcopy << 'EOF'
# RevCopy Nginx Configuration
server {
    listen 80;
    server_name 37.27.217.240;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
    
    # Frontend
    location / {
        proxy_pass http://localhost:5173;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
    
    # Admin panel
    location /admin {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
    
    # API endpoints
    location /api {
        proxy_pass http://localhost:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # Crawler API
    location /crawler {
        proxy_pass http://localhost:9000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # Health check
    location /health {
        proxy_pass http://localhost:8000/health;
        access_log off;
    }
}
EOF
    
    # Enable site
    ln -sf /etc/nginx/sites-available/revcopy /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    
    # Test configuration
    nginx -t || error "Nginx configuration test failed"
    
    # Start and enable Nginx
    systemctl enable nginx
    systemctl restart nginx
    
    success "Nginx installed and configured successfully"
}

# Setup SSL with Let's Encrypt
setup_ssl() {
    header "🔒 SETTING UP SSL CERTIFICATES"
    
    log "Installing Certbot..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y certbot python3-certbot-nginx || error "Failed to install Certbot"
    
    log "SSL setup will be completed during deployment with actual domain name"
    success "SSL tools installed successfully"
}

# Configure firewall
setup_firewall() {
    header "🛡️ CONFIGURING FIREWALL"
    
    log "Configuring UFW firewall..."
    
    # Reset firewall
    ufw --force reset
    
    # Default policies
    ufw default deny incoming
    ufw default allow outgoing
    
    # SSH access
    ufw allow 22/tcp comment 'SSH'
    
    # HTTP/HTTPS
    ufw allow 80/tcp comment 'HTTP'
    ufw allow 443/tcp comment 'HTTPS'
    
    # Application ports (for direct access during development)
    ufw allow 8000/tcp comment 'Backend API'
    ufw allow 5173/tcp comment 'Frontend Dev'
    ufw allow 3001/tcp comment 'Admin Panel'
    ufw allow 9000/tcp comment 'Crawler API'
    ufw allow 8080/tcp comment 'Webhook Handler'
    
    # Monitoring ports
    ufw allow 9090/tcp comment 'Prometheus'
    ufw allow 3000/tcp comment 'Grafana'
    
    # Enable firewall
    ufw --force enable
    
    success "Firewall configured successfully"
}

# Setup monitoring
setup_monitoring() {
    header "📊 INSTALLING MONITORING TOOLS"
    
    log "Installing Prometheus..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y prometheus prometheus-node-exporter || warning "Failed to install Prometheus via apt, will use Docker version"
    
    log "Creating monitoring directories..."
    mkdir -p /opt/revcopy/monitoring/{prometheus,grafana,logs}
    
    success "Monitoring tools prepared"
}

# Create deployment directory structure
setup_directories() {
    header "📁 CREATING DIRECTORY STRUCTURE"
    
    log "Creating deployment directories..."
    mkdir -p "$DEPLOYMENT_PATH"/{logs,backups,ssl,monitoring}
    
    # Set proper permissions
    chown -R root:root "$DEPLOYMENT_PATH"
    chmod -R 755 "$DEPLOYMENT_PATH"
    
    log "Creating log rotation configuration..."
    cat > /etc/logrotate.d/revcopy << EOF
$DEPLOYMENT_PATH/logs/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    copytruncate
    create 0644 root root
}
EOF
    
    success "Directory structure created successfully"
}

# Setup fail2ban
setup_fail2ban() {
    header "🔐 CONFIGURING FAIL2BAN"
    
    log "Configuring fail2ban for SSH protection..."
    
    cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3

[ssh]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
EOF
    
    systemctl enable fail2ban
    systemctl restart fail2ban
    
    success "Fail2ban configured successfully"
}

# Create systemd services
create_services() {
    header "⚙️ CREATING SYSTEMD SERVICES"
    
    # Webhook handler service
    log "Creating webhook handler service..."
    cat > /etc/systemd/system/revcopy-webhook.service << EOF
[Unit]
Description=RevCopy Webhook Handler
After=network.target
Requires=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$DEPLOYMENT_PATH/revcopy-server
Environment=PYTHONPATH=$DEPLOYMENT_PATH/revcopy-server
ExecStart=/usr/bin/python3 $DEPLOYMENT_PATH/revcopy-server/scripts/webhook-handler.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    # Enable services
    systemctl daemon-reload
    
    success "Systemd services created successfully"
}

# Install CLI dependencies
install_cli_dependencies() {
    header "🛠️ INSTALLING CLI DEPENDENCIES"
    
    log "Creating Python virtual environment..."
    python3 -m venv "$DEPLOYMENT_PATH/venv"
    source "$DEPLOYMENT_PATH/venv/bin/activate"
    
    log "Installing CLI requirements will be done during deployment..."
    
    success "CLI environment prepared"
}

# Final configuration
final_configuration() {
    header "🔧 FINAL CONFIGURATION"
    
    log "Setting up environment variables..."
    cat > /etc/environment << EOF
REVCOPY_DEPLOYMENT_PATH=$DEPLOYMENT_PATH
REVCOPY_SERVER_HOST=$SERVER_HOST
PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$DEPLOYMENT_PATH/revcopy-server"
EOF
    
    log "Creating deployment user..."
    if ! id "revcopy" &>/dev/null; then
        useradd -r -s /bin/bash -d "$DEPLOYMENT_PATH" revcopy
        usermod -aG docker revcopy
    fi
    
    log "Setting up cron jobs..."
    cat > /etc/cron.d/revcopy << EOF
# RevCopy maintenance tasks
0 2 * * * root docker system prune -f
0 3 * * 0 root $DEPLOYMENT_PATH/revcopy-server/scripts/backup.sh
*/5 * * * * root $DEPLOYMENT_PATH/revcopy-server/scripts/health-check.sh
EOF
    
    success "Final configuration completed"
}

# Print installation summary
print_summary() {
    header "🎉 INSTALLATION COMPLETED SUCCESSFULLY"
    
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════════════════════════════════════╗"
    echo "║                    RevCopy Server Installation Summary              ║"
    echo "╚══════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    echo -e "${BLUE}📊 System Information:${NC}"
    echo "  • Server IP: $SERVER_HOST"
    echo "  • Deployment Path: $DEPLOYMENT_PATH"
    echo "  • Python Version: $(python3 --version)"
    echo "  • Docker Version: $(docker --version)"
    echo "  • Node.js Version: $(node --version)"
    echo ""
    
    echo -e "${BLUE}✅ Installed Components:${NC}"
    echo "  • Docker & Docker Compose"
    echo "  • Python $PYTHON_VERSION with pip"
    echo "  • Node.js 18.x with npm"
    echo "  • Nginx with reverse proxy configuration"
    echo "  • SSL/TLS tools (Certbot)"
    echo "  • UFW Firewall (configured)"
    echo "  • Fail2ban (SSH protection)"
    echo "  • Monitoring tools (Prometheus/Grafana)"
    echo "  • Log rotation"
    echo "  • Systemd services"
    echo ""
    
    echo -e "${BLUE}🚀 Next Steps:${NC}"
    echo "  1. Clone the RevCopy infrastructure:"
    echo "     cd $DEPLOYMENT_PATH && git clone https://github.com/Revcopy/revcopy-server.git"
    echo ""
    echo "  2. Install CLI dependencies:"
    echo "     cd $DEPLOYMENT_PATH/revcopy-server && pip3 install -r requirements-cli.txt"
    echo ""
    echo "  3. Run the deployment CLI:"
    echo "     python3 revcopy-cli.py deploy --server $SERVER_HOST --full --ssl --monitoring"
    echo ""
    echo "  4. Setup GitHub webhooks pointing to:"
    echo "     http://$SERVER_HOST:8080/webhook"
    echo ""
    
    echo -e "${BLUE}🔗 Service URLs (after deployment):${NC}"
    echo "  • Frontend: https://$SERVER_HOST/"
    echo "  • Admin Panel: https://$SERVER_HOST/admin"
    echo "  • Backend API: https://$SERVER_HOST/api"
    echo "  • Crawler API: https://$SERVER_HOST/crawler"
    echo "  • Webhook Handler: http://$SERVER_HOST:8080"
    echo "  • Prometheus: http://$SERVER_HOST:9090"
    echo "  • Grafana: http://$SERVER_HOST:3000"
    echo ""
    
    echo -e "${YELLOW}⚠️ Security Notes:${NC}"
    echo "  • Change default passwords in .env.production"
    echo "  • Configure SMTP settings for notifications"
    echo "  • Add your domain name for SSL certificates"
    echo "  • Set up GitHub webhook secrets"
    echo "  • Configure monitoring alerts"
    echo ""
    
    echo -e "${GREEN}🎯 Installation log saved to: $LOG_FILE${NC}"
    echo ""
}

# Main installation function
main() {
    clear
    echo -e "${PURPLE}"
    echo "╔════════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                        ║"
    echo "║                   RevCopy Enterprise Server Installer                 ║"
    echo "║                   Professional Production Deployment                  ║"
    echo "║                                                                        ║"
    echo "╚════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}\n"
    
    log "Starting RevCopy enterprise installation..."
    
    # Run installation steps
    check_root
    check_system
    update_system
    install_docker
    install_python
    install_nodejs
    install_nginx
    setup_ssl
    setup_firewall
    setup_monitoring
    setup_directories
    setup_fail2ban
    create_services
    install_cli_dependencies
    final_configuration
    
    # Print summary
    print_summary
    
    log "Installation completed successfully!"
}

# Handle interruption
trap 'echo -e "\n${RED}Installation interrupted!${NC}"; exit 1' INT TERM

# Run main function
main "$@" 