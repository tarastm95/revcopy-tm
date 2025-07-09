# 🚀 RevCopy Enterprise Deployment - Quick Start Guide

This guide will help you deploy RevCopy to your production server with enterprise-grade infrastructure.

## 📋 Prerequisites

### Local Machine Requirements
- Python 3.11+
- SSH client
- Git
- Make (GNU Make)

### Server Requirements  
- Ubuntu 20.04+ or Debian 11+ (recommended)
- 4GB+ RAM
- 20GB+ storage
- Root SSH access
- Public IP address

## 🎯 One-Command Complete Setup

For the fastest deployment, run this single command:

```bash
make full-setup SERVER_HOST=37.27.217.240
```

This will:
- Install all CLI dependencies
- Setup the remote server with all required software
- Deploy the complete RevCopy stack
- Configure SSL certificates
- Setup monitoring (Prometheus + Grafana)
- Configure webhook handler for GitOps

## 📚 Step-by-Step Setup

### 1. Clone and Prepare Infrastructure

```bash
# Clone the server infrastructure
git clone https://github.com/Revcopy/revcopy-server.git
cd revcopy-server

# Install CLI dependencies
make install-cli
```

### 2. Setup Remote Server

```bash
# Setup the server (installs Docker, Nginx, security, etc.)
make server-setup SERVER_HOST=37.27.217.240
```

This installs:
- Docker & Docker Compose
- Nginx with reverse proxy
- Python 3.11 & Node.js 18
- UFW firewall with proper rules
- Fail2ban for SSH protection
- SSL tools (Certbot)
- Monitoring tools

### 3. Deploy Application

```bash
# Full deployment with SSL and monitoring
make deploy-remote SERVER_HOST=37.27.217.240
```

### 4. Setup GitOps (Optional)

```bash
# Setup webhook handler for automatic deployments
make setup-webhook SERVER_HOST=37.27.217.240
```

Then configure GitHub webhooks pointing to: `http://37.27.217.240:8080/webhook`

## 🌐 Access Your Application

After deployment, your applications will be available at:

- **Frontend**: https://37.27.217.240/
- **Admin Panel**: https://37.27.217.240/admin
- **Backend API**: https://37.27.217.240/api
- **Crawler API**: https://37.27.217.240/crawler
- **Prometheus**: http://37.27.217.240:9090
- **Grafana**: http://37.27.217.240:3000

## 🛠️ Common Operations

### Health Check
```bash
make server-health SERVER_HOST=37.27.217.240
```

### Update Deployment
```bash
make quick-deploy SERVER_HOST=37.27.217.240
```

### View Logs
```bash
# SSH into server and view logs
ssh root@37.27.217.240
cd /opt/revcopy/revcopy-server
make logs
```

### Create Backup
```bash
make backup-remote SERVER_HOST=37.27.217.240
```

### Troubleshooting
```bash
make troubleshoot SERVER_HOST=37.27.217.240
```

## 🔧 Configuration

### Environment Variables

The deployment creates a production environment file at `/opt/revcopy/revcopy-server/.env.production`.

Key variables to configure:
- Database credentials (auto-generated)
- API keys (DeepSeek, SMTP)
- Domain names
- Security settings

### SSL Configuration

SSL certificates are automatically obtained via Let's Encrypt. To configure for your domain:

1. Point your domain to the server IP
2. Update the environment file with your domain
3. Re-run deployment

## 🔒 Security Features

The deployment includes enterprise-grade security:

- **Firewall**: UFW with restrictive rules
- **SSH Protection**: Fail2ban with automatic IP blocking
- **SSL/TLS**: Let's Encrypt certificates with auto-renewal
- **Container Security**: Non-root users, network isolation
- **Secrets Management**: Encrypted secrets with rotation
- **Security Headers**: Comprehensive HTTP security headers

## 📊 Monitoring & Observability

### Monitoring Stack
- **Prometheus**: Metrics collection and alerting
- **Grafana**: Visualization dashboards
- **Node Exporter**: System metrics
- **Container Metrics**: Docker container monitoring

### Log Management
- Centralized logging with log rotation
- Error tracking and alerting
- Performance monitoring
- Security event logging

## 🔄 GitOps & CI/CD

### GitHub Actions Workflow

The repository includes a professional GitHub Actions workflow:

```yaml
# Located at .github/workflows/deploy-production.yml
# Triggered on push to main branch or manual dispatch
```

Required GitHub Secrets:
- `SERVER_SSH_KEY`: Your SSH private key
- `SLACK_WEBHOOK`: Slack webhook URL (optional)

### Webhook Handler

Automatic deployments on Git push:
- Repository-specific deployment strategies
- Signature verification for security
- Slack notifications on deployment status
- Health checks after deployment

## 🆘 Emergency Procedures

### Emergency Deployment
```bash
make emergency-deploy SERVER_HOST=37.27.217.240
```

### Disaster Recovery
```bash
make disaster-recovery SERVER_HOST=37.27.217.240
```

### Emergency Stop
```bash
# SSH into server
ssh root@37.27.217.240
cd /opt/revcopy/revcopy-server
make emergency-stop
```

## 🎯 Production Checklist

Before going live, ensure:

- [ ] SSL certificates are configured
- [ ] Domain DNS points to server
- [ ] Environment variables are configured
- [ ] SMTP settings are working
- [ ] API keys are added
- [ ] Monitoring is setup
- [ ] Backups are configured
- [ ] Security scan passed
- [ ] Performance tests completed

## 🔍 Troubleshooting Common Issues

### Service Not Starting
```bash
# Check service status
make debug-remote SERVER_HOST=37.27.217.240

# View detailed logs
ssh root@37.27.217.240
cd /opt/revcopy/revcopy-server
docker-compose logs -f <service-name>
```

### Permission Issues
```bash
make fix-permissions SERVER_HOST=37.27.217.240
```

### Network Issues
```bash
# Check firewall status
ssh root@37.27.217.240 'ufw status verbose'

# Test connectivity
make network-test SERVER_HOST=37.27.217.240
```

### Performance Issues
```bash
# Monitor server performance
make performance-monitor SERVER_HOST=37.27.217.240

# Optimize server
make optimize-server SERVER_HOST=37.27.217.240
```

## 🚀 Advanced Features

### Scaling Services
```bash
# Scale backend to 3 replicas
make scale-backend REPLICAS=3

# Scale crawler to 2 replicas
make scale-crawler REPLICAS=2
```

### Development Tunnel
```bash
# Create SSH tunnel for development
make dev-tunnel SERVER_HOST=37.27.217.240
```

### Performance Testing
```bash
make performance-test
```

## 📞 Support

### Get Help
```bash
# Show all available commands
make help

# Show deployment information
make info SERVER_HOST=37.27.217.240

# Complete status check
make status-all SERVER_HOST=37.27.217.240
```

### Log Files
- Installation: `/tmp/revcopy-install.log`
- Deployment: `./deployment.log`
- Webhook: `/opt/revcopy/logs/webhook.log`
- Application: `/opt/revcopy/revcopy-server/logs/`

## 🔗 Repository Structure

The deployment system uses these repositories:

- **revcopy-server**: Infrastructure and deployment automation
- **revcopy-backend**: FastAPI backend application
- **revcopy-frontend**: React frontend application  
- **revcopy-admin**: React admin panel
- **revcopy-crawlers-api**: Go crawler microservice

## 💡 Best Practices

1. **Always test deployments** in staging first
2. **Create backups** before major updates
3. **Monitor resources** regularly
4. **Keep secrets secure** and rotate regularly
5. **Update dependencies** for security patches
6. **Use staging branches** for development
7. **Set up alerts** for critical metrics

---

**🎉 Congratulations!** You now have a professional, enterprise-grade RevCopy deployment with:
- High availability and scalability
- Comprehensive monitoring
- Automated deployments
- Security hardening
- Disaster recovery capabilities

For advanced configuration and customization, refer to the detailed documentation in each repository. 