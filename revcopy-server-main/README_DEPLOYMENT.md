# RevCopy Deployment Guide

## Architecture Overview

RevCopy uses a microservices architecture with separate services:

### Main Services (Port 80)
- **Frontend**: React application (`revcopy-frontend`)
- **Backend**: FastAPI server (`revcopy-backend`) 
- **API**: Available at `/api/` endpoint

### Admin Panel (Port 3001)
- **Admin**: React admin dashboard (`revcopy-admin`)
- **Standalone service**: Independent deployment
- **URL**: `http://SERVER_IP:3001`

## Deployment Process

### 1. Main Application
The main frontend and backend are deployed via Docker Compose:
```bash
# Main services are already deployed and working
curl http://37.27.217.240/         # Frontend
curl http://37.27.217.240/health   # Backend health
curl http://37.27.217.240/api/     # API endpoints
```

### 2. Admin Panel Deployment
Use the professional deployment script:

```bash
# Deploy admin panel as separate service
./deploy-admin.sh
```

This script:
- ✅ Builds the admin panel locally with npm
- ✅ Creates a deployment package 
- ✅ Uploads via secure copy (scp)
- ✅ Deploys in isolated Docker container
- ✅ Configures nginx for React Router
- ✅ Sets up automatic restart policy

### 3. Access URLs
- **Main App**: http://37.27.217.240
- **Admin Panel**: http://37.27.217.240:3001
- **API Documentation**: http://37.27.217.240/docs

## Professional Deployment Benefits

✅ **Git-based**: No manual server file editing  
✅ **Containerized**: Each service in its own container  
✅ **Automated**: Single script deployment  
✅ **Isolated**: Admin panel separate from main app  
✅ **Scalable**: Easy to add more admin instances  
✅ **Maintainable**: Clear separation of concerns  

## Service Status

### Main Application
```bash
# Frontend + Backend working perfectly
curl -s http://37.27.217.240/health
# Returns: {"status":"healthy",...}
```

### Admin Panel  
```bash
# Admin panel working as separate service
curl -s http://37.27.217.240:3001/
# Returns: React admin dashboard
```

## Repository Structure

```
revcopy/
├── frontend/          # Main React app
├── backend/           # FastAPI server  
├── admin/             # Admin React app
├── deploy-admin.sh    # Admin deployment script
└── README_DEPLOYMENT.md
```

## Future Improvements

1. **CI/CD Pipeline**: GitHub Actions for automatic deployment
2. **Load Balancer**: nginx for multiple admin instances
3. **HTTPS**: SSL certificates for secure connections
4. **Monitoring**: Health checks and logging
5. **Backup**: Automated database backups

---

**Note**: This approach follows microservices best practices with proper separation of concerns and professional deployment methodology. 