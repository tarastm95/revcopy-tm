# RevCopy Quick Reference
=======================

## 🚀 Quick Commands

### Deployment
```bash
# Full production deployment
python revcopy-cli.py deploy --server 37.27.217.240 --full --monitoring

# Admin panel only
python revcopy-cli.py admin --deploy --server 37.27.217.240

# Local development
python revcopy-cli.py dev --all
```

### Management
```bash
# Check server status
python revcopy-cli.py status --server 37.27.217.240

# View logs
python revcopy-cli.py logs --server 37.27.217.240 --service backend

# Create backup
python revcopy-cli.py backup --server 37.27.217.240

# Update server
python revcopy-cli.py update --server 37.27.217.240
```

### Database
```bash
# Check database status
python revcopy-cli.py db status --server 37.27.217.240

# Create database backup
python revcopy-cli.py db backup --server 37.27.217.240

# Restore database
python revcopy-cli.py db restore --server 37.27.217.240
```

### Users
```bash
# List users
python revcopy-cli.py users list --server 37.27.217.240

# Create user
python revcopy-cli.py users create --server 37.27.217.240
```

### SSL & Monitoring
```bash
# Configure SSL
python revcopy-cli.py ssl --server 37.27.217.240 --domain yourdomain.com

# Start monitoring
python revcopy-cli.py monitor --server 37.27.217.240
```

## 🔐 Default Credentials

### Admin Panel
- **URL**: http://37.27.217.240:3001
- **Email**: admin@revcopy.com
- **Password**: admin123

### Monitoring
- **Grafana**: http://37.27.217.240:3000 (admin/admin)
- **Prometheus**: http://37.27.217.240:9090

## 📊 Service Ports

| Service | Port | Description |
|---------|------|-------------|
| Frontend | 80/443 | Main application |
| Backend API | 8000 | FastAPI server |
| Admin Panel | 3001 | Admin interface |
| Grafana | 3000 | Monitoring dashboard |
| Prometheus | 9090 | Metrics collection |
| PostgreSQL | 5432 | Database |
| Redis | 6379 | Cache |

## 🚨 Emergency Commands

### Restart Services
```bash
ssh root@37.27.217.240 "cd /opt/revcopy/SERVER && docker-compose restart"
```

### Check Container Status
```bash
ssh root@37.27.217.240 "docker ps"
```

### View Recent Logs
```bash
ssh root@37.27.217.240 "docker logs revcopy-backend --tail 50"
```

### Restore from Backup
```bash
python revcopy-cli.py restore backup_file.tar.gz --server 37.27.217.240
```

## 🔧 Configuration Files

| File | Purpose |
|------|---------|
| `revcopy-cli.py` | Main CLI tool |
| `docker-compose.yml` | Development environment |
| `docker-compose.production.yml` | Production environment |
| `env-template.txt` | Environment variables template |
| `nginx-fix.conf` | Nginx configuration |
| `deploy-admin.sh` | Admin panel deployment |
| `deploy.sh` | Main deployment script |

## 📁 Important Directories

| Directory | Purpose |
|-----------|---------|
| `backups/` | Server backups |
| `configs/` | Service configurations |
| `scripts/` | Deployment scripts |
| `dockerfiles/` | Docker configurations |

## 🆘 Troubleshooting

### Admin Panel White Screen
1. Check if assets load: `curl http://37.27.217.240:3001/assets/`
2. Verify vite config: No base path for standalone deployment
3. Check admin user exists: Use CLI to create admin

### Database Connection Issues
1. Check container status: `docker ps | grep database`
2. Verify environment variables in `.env`
3. Run migrations: `docker exec revcopy-backend alembic upgrade head`

### API Authentication Failures
1. Verify admin credentials
2. Check JWT configuration
3. Ensure CORS settings are correct

## 📞 Support

- **Documentation**: `README_COMPLETE.md`
- **CLI Help**: `python revcopy-cli.py --help`
- **Logs**: Use CLI logs command
- **Monitoring**: Check Grafana dashboard

---

**Last Updated**: July 9, 2025
**Version**: 1.0.0 