# 🚀 RevCopy Production Deployment Guide

## Overview

This guide provides step-by-step instructions for deploying RevCopy in a production environment using Docker and enterprise-grade infrastructure.

## 📋 Prerequisites

### System Requirements
- **OS**: Ubuntu 20.04+ / CentOS 8+ / RHEL 8+
- **CPU**: Minimum 4 cores, Recommended 8+ cores
- **RAM**: Minimum 8GB, Recommended 16GB+
- **Storage**: Minimum 100GB SSD, Recommended 500GB+ SSD
- **Network**: Public IP address and domain name

### Required Software
```bash
# Docker Engine 24.0+
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# Docker Compose 2.20+
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Additional utilities
sudo apt update
sudo apt install -y make curl wget git openssl
```

## 🔧 Quick Start Deployment

### 1. Clone and Setup
```bash
# Clone the repository
git clone <repository-url>
cd revcopy/SERVER

# Initialize the environment
make init
```

### 2. Configure Environment
```bash
# Edit environment variables
nano .env

# Required configurations:
DOMAIN=your-domain.com
LETSENCRYPT_EMAIL=admin@your-domain.com
OPENAI_API_KEY=sk-your-openai-key
DEEPSEEK_API_KEY=your-deepseek-key
```

### 3. Generate Secrets
```bash
# Generate secure secrets
make secrets
```

### 4. Setup SSL (Production)
```bash
# Setup SSL certificates
make ssl-setup
# OR
./scripts/setup-ssl.sh your-domain.com
```

### 5. Deploy
```bash
# Deploy production stack
make production-deploy
```

### 6. Verify Deployment
```bash
# Check service health
make health-check

# View service status
make status

# Check logs
make logs
```

## 🔒 Security Configuration

### SSL/TLS Setup
```bash
# For production with Let's Encrypt
./scripts/setup-ssl.sh your-domain.com

# For development with self-signed certificates
./scripts/setup-ssl.sh --self-signed
```

### Firewall Configuration
```bash
# Allow necessary ports
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS
sudo ufw enable
```

### Security Headers
The deployment includes comprehensive security headers:
- HSTS (HTTP Strict Transport Security)
- CSP (Content Security Policy)
- X-Frame-Options
- X-Content-Type-Options
- X-XSS-Protection

## 📊 Monitoring & Observability

### Built-in Monitoring Services
- **Prometheus**: Metrics collection (http://localhost:9090)
- **Grafana**: Dashboards (http://localhost:3000)
- **cAdvisor**: Container metrics
- **Node Exporter**: System metrics

### Access Monitoring
```bash
# Grafana credentials (after deployment)
Username: admin
Password: [Check GRAFANA_ADMIN_PASSWORD in .env]
```

### Health Monitoring
```bash
# Automated health checks
make health-check

# Continuous monitoring
watch -n 30 'make health-check --quiet'
```

## 🔄 Backup & Recovery

### Database Backup
```bash
# Manual backup
make db-backup

# Automated backup (add to crontab)
0 2 * * * cd /path/to/revcopy/SERVER && make db-backup
```

### Full System Backup
```bash
# Backup everything
make backup-all

# Restore from backup
make restore-production BACKUP_DATE=2024-01-15
```

## 📈 Scaling Configuration

### Horizontal Scaling
```bash
# Scale backend services
make scale-backend REPLICAS=3

# Scale crawler services
make scale-crawler REPLICAS=2
```

### Resource Limits
Adjust in `.env`:
```bash
# Memory limits (in bytes)
BACKEND_MEMORY_LIMIT=4294967296   # 4GB
FRONTEND_MEMORY_LIMIT=1073741824  # 1GB

# CPU limits (in cores)
BACKEND_CPU_LIMIT=2.0
FRONTEND_CPU_LIMIT=1.0
```

## 🔧 Maintenance

### Update Applications
```bash
# Update all images
make update-images

# Rolling update (zero downtime)
make rolling-update
```

### Database Migrations
```bash
# Run migrations
make db-migrate

# Rollback if needed
make db-rollback VERSION=previous
```

### Clean Up
```bash
# Clean unused resources
make clean

# Deep clean (WARNING: removes all data)
make clean-all
```

## 🚨 Troubleshooting

### Common Issues

#### Services Won't Start
```bash
# Check container status
make ps

# Check logs for errors
make logs-errors

# Restart specific service
docker-compose restart backend
```

#### Database Connection Issues
```bash
# Check database status
make logs-database

# Test database connectivity
docker exec revcopy-postgres pg_isready

# Reset database password
./scripts/generate-secrets.sh
make restart
```

#### SSL Certificate Issues
```bash
# Check certificate status
openssl x509 -in configs/nginx/ssl/fullchain.pem -text -noout

# Renew certificates
make ssl-renew

# Setup SSL again
./scripts/setup-ssl.sh
```

#### High Resource Usage
```bash
# Check resource usage
make resources

# Scale down if needed
docker-compose scale backend=1

# Clean up resources
make clean
```

### Log Locations
- **Application Logs**: `logs/`
- **Nginx Logs**: `/var/log/nginx/`
- **Container Logs**: `docker-compose logs [service]`

### Support Commands
```bash
# Full system status
make status

# Network connectivity test
make network-test

# Performance test
make performance-test

# Configuration validation
make config-validate
```

## 🌐 DNS Configuration

### Required DNS Records
```
# A Record
your-domain.com.    IN    A    YOUR_SERVER_IP

# Optional CNAME for admin
admin.your-domain.com.    IN    CNAME    your-domain.com.

# Optional WWW redirect
www.your-domain.com.    IN    CNAME    your-domain.com.
```

## 📱 API Endpoints

After deployment, the following endpoints will be available:

### Frontend
- **Main App**: `https://your-domain.com`
- **Health Check**: `https://your-domain.com/health`

### Backend API
- **API Base**: `https://your-domain.com/api/v1/`
- **Documentation**: `https://your-domain.com/docs`
- **Health Check**: `https://your-domain.com/api/v1/health`

### Admin Panel
- **Admin Interface**: `https://your-domain.com/admin/`
- **Health Check**: `https://your-domain.com/admin/health`

## 🔐 Environment Variables Reference

### Essential Variables
```bash
# Application
ENVIRONMENT=production
DOMAIN=your-domain.com
API_SECRET_KEY=<generated-automatically>

# Database
POSTGRES_DB=revcopy_prod
POSTGRES_USER=revcopy_user
POSTGRES_PASSWORD=<generated-automatically>

# AI Services
OPENAI_API_KEY=sk-your-openai-key
DEEPSEEK_API_KEY=your-deepseek-key

# SSL
LETSENCRYPT_EMAIL=admin@your-domain.com
```

### Optional Variables
```bash
# Monitoring
SENTRY_DSN=https://your-sentry-dsn
GRAFANA_ADMIN_PASSWORD=<generated-automatically>

# Email
SMTP_HOST=smtp.gmail.com
SMTP_USERNAME=your-email@gmail.com
SMTP_PASSWORD=your-app-password
```

## 📞 Support & Maintenance

### Regular Maintenance Tasks

#### Daily
- Monitor system resources
- Check error logs
- Verify backup completion

#### Weekly
- Update security patches
- Review performance metrics
- Clean up old logs and backups

#### Monthly
- Update Docker images
- Review and rotate secrets
- Test backup restoration
- Performance optimization review

### Emergency Procedures

#### Emergency Stop
```bash
make emergency-stop
```

#### Emergency Restart
```bash
make emergency-restart
```

#### Rollback Deployment
```bash
# Stop current deployment
make down

# Restore from backup
make restore-production BACKUP_DATE=stable-date

# Start services
make start
```

## 📚 Additional Resources

- [Docker Documentation](https://docs.docker.com/)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [Nginx Configuration Guide](https://nginx.org/en/docs/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [Redis Documentation](https://redis.io/documentation)

---

**Built with ❤️ for Enterprise Production Deployment**

For support, please contact the development team or create an issue in the repository. 