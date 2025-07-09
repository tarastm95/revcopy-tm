# RevCopy Enterprise Server Infrastructure

🚀 **Enterprise-Grade Production Infrastructure**

This directory contains production-ready Docker orchestration and infrastructure configurations for the RevCopy platform, designed for enterprise deployment with high availability, security, and scalability.

## 🏗️ Architecture Overview

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Load Balancer │────│   API Gateway   │────│   Microservices │
│     (Nginx)     │    │    (Traefik)    │    │   Architecture  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Frontend      │    │   Backend API   │    │   Amazon        │
│   (React SPA)   │    │   (FastAPI)     │    │   Crawler (Go)  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Admin Panel   │    │   PostgreSQL    │    │     Redis       │
│   (React SPA)   │    │   (Database)    │    │    (Cache)      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 📦 Services

### Core Application Services
- **Frontend**: React TypeScript SPA (Port: 3000)
- **Admin Panel**: React TypeScript Admin Interface (Port: 3001)
- **Backend API**: FastAPI Python Application (Port: 8000)
- **Amazon Crawler**: Go Microservice (Port: 8080)

### Infrastructure Services
- **PostgreSQL**: Primary Database (Port: 5432)
- **Redis**: Cache & Session Store (Port: 6379)
- **Nginx**: Load Balancer & Reverse Proxy (Ports: 80, 443)
- **Traefik**: API Gateway & SSL Management (Port: 80, 443, 8080)

### Monitoring & Observability
- **Prometheus**: Metrics Collection (Port: 9090)
- **Grafana**: Monitoring Dashboard (Port: 3000)
- **Jaeger**: Distributed Tracing (Port: 16686)
- **ELK Stack**: Centralized Logging

## 🚀 Quick Start

### Prerequisites
- Docker Engine 24.0+
- Docker Compose 2.20+
- Minimum 8GB RAM, 4 CPU cores
- 50GB available disk space

### 1. Environment Setup
```bash
# Clone and navigate to server directory
cd SERVER

# Copy environment template
cp .env.example .env

# Generate secure secrets
./scripts/generate-secrets.sh

# Configure your environment variables
nano .env
```

### 2. SSL Certificate Setup
```bash
# For production with real domain
./scripts/setup-ssl.sh your-domain.com

# For local development
./scripts/setup-local-ssl.sh
```

### 3. Deploy Stack
```bash
# Production deployment
make deploy-production

# Development deployment
make deploy-development

# Monitor deployment
make logs
make status
```

## 📋 Environment Configuration

### Required Environment Variables
```bash
# Application
ENVIRONMENT=production
DOMAIN=your-domain.com
API_SECRET_KEY=<generated-secret>

# Database
POSTGRES_DB=revcopy_prod
POSTGRES_USER=revcopy_user
POSTGRES_PASSWORD=<secure-password>

# Redis
REDIS_PASSWORD=<secure-password>

# AI Services
OPENAI_API_KEY=<your-openai-key>
DEEPSEEK_API_KEY=<your-deepseek-key>

# Monitoring
GRAFANA_ADMIN_PASSWORD=<secure-password>
PROMETHEUS_RETENTION=30d
```

## 🔒 Security Features

### Application Security
- **HTTPS Only**: Automatic SSL/TLS with Let's Encrypt
- **Rate Limiting**: Per-IP and per-endpoint limits
- **Authentication**: JWT with secure secrets
- **Input Validation**: Comprehensive request validation
- **CORS Protection**: Configured for production domains

### Infrastructure Security
- **Network Isolation**: Internal Docker networks
- **Secret Management**: Docker secrets for sensitive data
- **Security Headers**: HSTS, CSP, X-Frame-Options
- **Container Security**: Non-root users, read-only filesystems
- **Database Security**: Encrypted connections, user isolation

## 📊 Monitoring & Alerting

### Health Checks
- Application health endpoints
- Database connectivity checks
- Redis availability monitoring
- External service health validation

### Metrics Collection
- Application performance metrics
- System resource monitoring
- Business KPI tracking
- Error rate and latency monitoring

### Alerting Rules
- High error rates (>5%)
- Response time degradation (>2s)
- Database connection issues
- High memory/CPU usage (>80%)
- SSL certificate expiration

## 📈 Scaling Configuration

### Horizontal Scaling
```bash
# Scale specific services
docker-compose up -d --scale backend=3
docker-compose up -d --scale crawler=2

# Auto-scaling with Docker Swarm
docker stack deploy -c docker-stack.yml revcopy
```

### Load Balancing
- **Nginx**: Layer 7 load balancing
- **Traefik**: Dynamic service discovery
- **Health Checks**: Automatic failover
- **Session Affinity**: Redis-based session storage

## 🔄 Backup & Recovery

### Automated Backups
```bash
# Database backups (daily)
./scripts/backup-database.sh

# File system backups
./scripts/backup-volumes.sh

# Configuration backups
./scripts/backup-configs.sh
```

### Disaster Recovery
```bash
# Restore from backup
./scripts/restore-database.sh backup-file.sql
./scripts/restore-volumes.sh backup-date

# Full system recovery
make restore-production BACKUP_DATE=2024-01-15
```

## 🚧 Maintenance

### Updates
```bash
# Update application images
make update-images

# Update infrastructure
make update-infrastructure

# Rolling updates (zero downtime)
make rolling-update
```

### Database Migrations
```bash
# Run pending migrations
make migrate-database

# Rollback migrations
make rollback-database VERSION=previous
```

## 📞 Support

### Logs
```bash
# View all logs
make logs

# Service-specific logs
make logs-backend
make logs-frontend
make logs-database

# Error logs only
make logs-errors
```

### Debugging
```bash
# Service status
make status

# Resource usage
make resources

# Network connectivity
make network-test

# Performance testing
make performance-test
```

## 🏷️ Versions

- **Application Version**: 1.0.0
- **Infrastructure Version**: 1.0.0
- **Docker Compose Version**: 3.8
- **Last Updated**: January 2025

---

**Built with ❤️ for Enterprise Production Deployment** 