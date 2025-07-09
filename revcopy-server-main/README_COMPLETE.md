# RevCopy Server - Complete Documentation
=====================================

## 📋 Overview

RevCopy is a comprehensive content generation platform with the following components:

- **Frontend**: React-based user interface (Port 5173)
- **Backend**: FastAPI-based API server (Port 8000)
- **Admin Panel**: React-based admin interface (Port 3001)
- **Database**: PostgreSQL with async support
- **Cache**: Redis for session and data caching
- **Monitoring**: Grafana + Prometheus stack
- **Crawlers**: Amazon product crawler (Go)

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Frontend      │    │   Admin Panel   │    │   Backend API   │
│   (React)       │    │   (React)       │    │   (FastAPI)     │
│   Port: 5173    │    │   Port: 3001    │    │   Port: 8000    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │   Nginx Proxy   │
                    │   Port: 80/443  │
                    └─────────────────┘
                                 │
         ┌───────────────────────┼───────────────────────┐
         │                       │                       │
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   PostgreSQL    │    │     Redis       │    │   Monitoring    │
│   Database      │    │     Cache       │    │   Stack         │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 🚀 Quick Start

### 1. Local Development

```bash
# Start all services locally
python SERVER/revcopy-cli.py dev --all

# Or start individual services
cd backend && python run.py          # Backend API
cd frontend && npm run dev           # Frontend
cd admin && npm run dev --port 3001  # Admin Panel
```

### 2. Production Deployment

```bash
# Full deployment with monitoring
python SERVER/revcopy-cli.py deploy --server 37.27.217.240 --full --monitoring

# Admin panel only
python SERVER/revcopy-cli.py admin --deploy --server 37.27.217.240

# Check server status
python SERVER/revcopy-cli.py status --server 37.27.217.240
```

## 📁 Project Structure

```
revcopy/
├── SERVER/                          # Server management files
│   ├── revcopy-cli.py              # Complete CLI tool
│   ├── deploy-admin.sh             # Admin panel deployment
│   ├── deploy.sh                   # Main deployment script
│   ├── docker-compose.yml          # Development environment
│   ├── docker-compose.production.yml # Production environment
│   ├── configs/                    # Service configurations
│   ├── scripts/                    # Deployment scripts
│   ├── dockerfiles/                # Docker configurations
│   └── README_COMPLETE.md          # This documentation
├── backend/                         # FastAPI backend
│   ├── app/                        # Application code
│   ├── alembic/                    # Database migrations
│   ├── requirements.txt            # Python dependencies
│   └── run.py                      # Development server
├── frontend/                       # React frontend
│   ├── src/                        # Source code
│   ├── package.json               # Dependencies
│   └── vite.config.ts             # Build configuration
├── admin/                          # React admin panel
│   ├── src/                        # Source code
│   ├── package.json               # Dependencies
│   └── vite.config.ts             # Build configuration
└── crawlers/                       # Web crawlers
    └── amazon/                     # Amazon crawler (Go)
```

## 🛠️ CLI Tool Usage

The `revcopy-cli.py` tool provides comprehensive server management:

### Deployment Commands

```bash
# Full production deployment
python revcopy-cli.py deploy --server 37.27.217.240 --full --ssl --monitoring

# Admin panel deployment only
python revcopy-cli.py admin --deploy --server 37.27.217.240

# Local development
python revcopy-cli.py dev --all
```

### Management Commands

```bash
# Check server status
python revcopy-cli.py status --server 37.27.217.240

# View logs
python revcopy-cli.py logs --server 37.27.217.240 --service backend

# Create backup
python revcopy-cli.py backup --server 37.27.217.240

# Update server
python revcopy-cli.py update --server 37.27.217.240

# Start monitoring
python revcopy-cli.py monitor --server 37.27.217.240

# Configure SSL
python revcopy-cli.py ssl --server 37.27.217.240 --domain yourdomain.com
```

### Database Management

```bash
# Check database status
python revcopy-cli.py db status --server 37.27.217.240

# Create database backup
python revcopy-cli.py db backup --server 37.27.217.240

# Restore database
python revcopy-cli.py db restore --server 37.27.217.240
```

### User Management

```bash
# List users
python revcopy-cli.py users list --server 37.27.217.240

# Create user
python revcopy-cli.py users create --server 37.27.217.240
```

## 🔧 Configuration

### Environment Variables

Create `.env` file in the project root:

```bash
# Database
POSTGRES_USER=postgres
POSTGRES_PASSWORD=your_password
POSTGRES_DB=revcopy

# Redis
REDIS_PASSWORD=your_redis_password

# API
API_SECRET_KEY=your_secret_key
DOMAIN=yourdomain.com

# AI Providers
OPENAI_API_KEY=your_openai_key
DEEPSEEK_API_KEY=your_deepseek_key

# Monitoring
GRAFANA_ADMIN_PASSWORD=your_grafana_password
```

### CLI Configuration

The CLI tool creates `cli-config.json` automatically:

```json
{
  "default_server": "37.27.217.240",
  "default_user": "root",
  "admin_port": 3001,
  "backend_port": 8000,
  "frontend_port": 5173,
  "database": {
    "host": "localhost",
    "port": 5432,
    "name": "revcopy",
    "user": "postgres"
  },
  "monitoring": {
    "grafana_port": 3000,
    "prometheus_port": 9090
  }
}
```

## 🐳 Docker Services

### Development Environment

```bash
cd SERVER
docker-compose up -d
```

Services:
- `revcopy-backend`: FastAPI backend
- `revcopy-frontend`: React frontend
- `revcopy-admin`: React admin panel
- `revcopy-database`: PostgreSQL database
- `revcopy-redis`: Redis cache
- `revcopy-nginx`: Nginx reverse proxy

### Production Environment

```bash
cd SERVER
docker-compose -f docker-compose.production.yml up -d
```

Additional services:
- `revcopy-grafana`: Monitoring dashboard
- `revcopy-prometheus`: Metrics collection
- `revcopy-amazon-crawler`: Amazon product crawler

## 🔐 Security

### Default Admin Credentials

After deployment, the default admin user is created:

- **Email**: `admin@revcopy.com`
- **Password**: `admin123`

⚠️ **Important**: Change the default password after first login!

### SSL Configuration

For production, configure SSL certificates:

```bash
python revcopy-cli.py ssl --server 37.27.217.240 --domain yourdomain.com
```

This will:
1. Install Certbot
2. Obtain Let's Encrypt certificates
3. Configure Nginx for HTTPS
4. Set up automatic renewal

## 📊 Monitoring

### Grafana Dashboard

Access: `http://yourdomain.com:3000`
- Default credentials: `admin/admin`
- Pre-configured dashboards for:
  - System metrics
  - Application performance
  - Database statistics
  - API usage

### Prometheus Metrics

Access: `http://yourdomain.com:9090`
- Collects metrics from all services
- Stores time-series data
- Provides alerting capabilities

## 🔄 Backup & Recovery

### Create Backup

```bash
python revcopy-cli.py backup --server 37.27.217.240
```

This creates:
- Complete project backup
- Database dump
- Configuration files

### Restore Backup

```bash
python revcopy-cli.py restore backup_file.tar.gz --server 37.27.217.240
```

## 🚨 Troubleshooting

### Common Issues

1. **Admin panel white screen**
   - Check if assets are loading correctly
   - Verify vite config base path
   - Ensure admin user exists

2. **Database connection errors**
   - Check PostgreSQL container status
   - Verify environment variables
   - Run database migrations

3. **API authentication failures**
   - Verify admin user credentials
   - Check JWT token configuration
   - Ensure proper CORS settings

### Logs

View service logs:

```bash
# All services
python revcopy-cli.py logs --server 37.27.217.240

# Specific service
python revcopy-cli.py logs --server 37.27.217.240 --service backend
```

### Health Checks

```bash
# Check all services
python revcopy-cli.py status --server 37.27.217.240

# Manual health checks
curl http://yourdomain.com/api/health
curl http://yourdomain.com:3001
```

## 📈 Performance Optimization

### Database Optimization

1. **Indexes**: Ensure proper indexes on frequently queried columns
2. **Connection Pooling**: Configure PostgreSQL connection limits
3. **Query Optimization**: Monitor slow queries in Grafana

### Caching Strategy

1. **Redis**: Cache frequently accessed data
2. **API Responses**: Cache expensive API calls
3. **Static Assets**: Configure proper cache headers

### Load Balancing

For high-traffic deployments:
1. Use multiple backend instances
2. Configure Nginx load balancing
3. Implement horizontal scaling

## 🔄 Updates & Maintenance

### Update Server

```bash
python revcopy-cli.py update --server 37.27.217.240
```

This will:
1. Pull latest code from Git
2. Rebuild Docker containers
3. Restart services
4. Run database migrations

### Regular Maintenance

1. **Weekly**:
   - Check system resources
   - Review error logs
   - Update security patches

2. **Monthly**:
   - Database optimization
   - Backup verification
   - Performance review

3. **Quarterly**:
   - SSL certificate renewal
   - Dependency updates
   - Security audit

## 📞 Support

### Getting Help

1. Check this documentation
2. Review server logs
3. Check monitoring dashboards
4. Contact system administrator

### Emergency Procedures

1. **Service Down**: Restart containers
2. **Database Issues**: Restore from backup
3. **Security Breach**: Rotate all credentials
4. **Performance Issues**: Scale resources

## 📝 Changelog

### Version 1.0.0
- Complete server setup
- CLI management tool
- Admin panel integration
- Monitoring stack
- SSL configuration
- Backup/restore functionality

## 🤝 Contributing

1. Follow the established project structure
2. Use the CLI tool for deployments
3. Document all changes
4. Test thoroughly before deployment
5. Update this documentation

---

**Last Updated**: July 9, 2025
**Version**: 1.0.0
**Maintainer**: RevCopy Development Team 