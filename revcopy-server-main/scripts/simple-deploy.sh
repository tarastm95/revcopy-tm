#!/bin/bash
# Simple RevCopy Deployment - Get the site working fast

set -e

SERVER_HOST="${1:-37.27.217.240}"

echo "🚀 Starting Simple RevCopy Deployment to ${SERVER_HOST}"

# Create a basic deployment package
echo "📦 Creating deployment package..."
cd ..
tar --exclude='node_modules' --exclude='.git' --exclude='__pycache__' \
    --exclude='*.pyc' --exclude='.env' --exclude='venv' \
    -czf /tmp/revcopy-simple.tar.gz .

echo "📤 Transferring to server..."
scp /tmp/revcopy-simple.tar.gz root@${SERVER_HOST}:/tmp/

echo "🛠️ Deploying on server..."
ssh root@${SERVER_HOST} << 'EOF'
# Set up deployment directory
mkdir -p /opt/revcopy-simple
cd /opt/revcopy-simple

# Extract files
tar -xzf /tmp/revcopy-simple.tar.gz
rm /tmp/revcopy-simple.tar.gz

# Install Docker if not present
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com | sh
    systemctl start docker
    systemctl enable docker
fi

# Install Docker Compose if not present
if ! command -v docker-compose &> /dev/null; then
    echo "Installing Docker Compose..."
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
fi

# Create a simple environment file
cat > .env << 'ENVEOF'
ENVIRONMENT=production
DEBUG=false

# Database
POSTGRES_HOST=postgres
POSTGRES_PORT=5432
POSTGRES_DB=revcopy_production
POSTGRES_USER=revcopy_admin
POSTGRES_PASSWORD=SecureRevcopyPass2024!

# Redis
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=SecureRedisPass2024!

# Security
SECRET_KEY=revcopy-prod-secret-key-2024-super-secure-12345678901234567890
JWT_SECRET_KEY=revcopy-jwt-secret-key-2024-super-secure-12345678901234567890
API_SECRET_KEY=revcopy-api-secret-key-2024-super-secure-12345678901234567890

# API Keys
DEEPSEEK_API_KEY=${DEEPSEEK_API_KEY:-}
OPENAI_API_KEY=${OPENAI_API_KEY:-}

# URLs
BACKEND_URL=http://backend:8000
FRONTEND_URL=http://37.27.217.240
ADMIN_URL=http://37.27.217.240/admin
CRAWLER_URL=http://amazon-crawler:8080

DOMAIN=37.27.217.240
VERSION=latest
ENVEOF

# Create a simple docker-compose file for just the basics
cat > docker-compose.simple.yml << 'DOCKEREOF'
version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    container_name: revcopy-postgres
    restart: unless-stopped
    environment:
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 30s
      timeout: 10s
      retries: 3

  redis:
    image: redis:7-alpine
    container_name: revcopy-redis
    restart: unless-stopped
    command: redis-server --requirepass ${REDIS_PASSWORD}
    ports:
      - "6379:6379"
    healthcheck:
      test: ["CMD", "redis-cli", "--no-auth-warning", "-a", "${REDIS_PASSWORD}", "ping"]
      interval: 30s
      timeout: 10s
      retries: 3

  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile
    container_name: revcopy-backend
    restart: unless-stopped
    environment:
      - ENVIRONMENT=${ENVIRONMENT}
      - DEBUG=${DEBUG}
      - POSTGRES_HOST=postgres
      - POSTGRES_PORT=5432
      - POSTGRES_DB=${POSTGRES_DB}
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
      - REDIS_HOST=redis
      - REDIS_PORT=6379
      - REDIS_PASSWORD=${REDIS_PASSWORD}
      - SECRET_KEY=${SECRET_KEY}
      - JWT_SECRET_KEY=${JWT_SECRET_KEY}
      - API_SECRET_KEY=${API_SECRET_KEY}
      - DEEPSEEK_API_KEY=${DEEPSEEK_API_KEY}
      - OPENAI_API_KEY=${OPENAI_API_KEY}
    ports:
      - "8000:8000"
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

  nginx:
    image: nginx:alpine
    container_name: revcopy-nginx
    restart: unless-stopped
    ports:
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
    depends_on:
      - backend

volumes:
  postgres_data:
DOCKEREOF

# Create a simple nginx config
cat > nginx.conf << 'NGINXEOF'
events {
    worker_connections 1024;
}

http {
    upstream backend {
        server backend:8000;
    }

    server {
        listen 80;
        server_name _;

        location / {
            return 200 'RevCopy is running! Backend: http://37.27.217.240:8000';
            add_header Content-Type text/plain;
        }

        location /api/ {
            proxy_pass http://backend/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        location /health {
            proxy_pass http://backend/health;
            proxy_set_header Host $host;
        }
    }
}
NGINXEOF

# Stop any existing services
docker-compose -f docker-compose.simple.yml down --remove-orphans || true

# Start the basic services
echo "Starting basic services..."
docker-compose -f docker-compose.simple.yml up -d

echo "Waiting for services to start..."
sleep 30

echo "Checking status..."
docker-compose -f docker-compose.simple.yml ps

echo "Deployment completed!"
echo "Site should be available at: http://37.27.217.240"
echo "Backend health: http://37.27.217.240:8000/health"
EOF

echo "✅ Deployment completed!"
echo "🌐 Check: http://${SERVER_HOST}"
echo "🔧 Backend: http://${SERVER_HOST}:8000" 