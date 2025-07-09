#!/bin/bash

# RevCopy Admin Panel Deployment Script
# Deploys admin panel as a separate service on port 3001

set -e

SERVER_IP="37.27.217.240"
ADMIN_PORT="3001"
SERVICE_NAME="revcopy-admin"

echo "🚀 Deploying RevCopy Admin Panel..."

# Build admin panel locally
echo "📦 Building admin panel..."
cd admin
npm run build
cd ..

# Package the build
echo "📋 Creating deployment package..."
tar czf admin-deploy.tar.gz -C admin/dist .

# Upload to server
echo "📤 Uploading to server..."
scp admin-deploy.tar.gz root@${SERVER_IP}:/tmp/

# Deploy on server
echo "🔧 Deploying on server..."
ssh root@${SERVER_IP} << 'EOF'
# Create admin directory
mkdir -p /opt/revcopy-admin
cd /opt/revcopy-admin

# Extract new build
tar xzf /tmp/admin-deploy.tar.gz
rm /tmp/admin-deploy.tar.gz

# Create nginx config for React Router
cat > nginx.conf << 'NGINX_EOF'
server {
    listen 80;
    server_name _;
    root /usr/share/nginx/html;
    index index.html;

    # React Router support
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Static assets caching
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
NGINX_EOF

# Stop existing admin container
docker rm -f revcopy-admin 2>/dev/null || true

# Start new admin container
docker run -d \
  --name revcopy-admin \
  --restart unless-stopped \
  -p 3001:80 \
  -v $(pwd):/usr/share/nginx/html:ro \
  -v $(pwd)/nginx.conf:/etc/nginx/conf.d/default.conf:ro \
  nginx:alpine

echo "✅ Admin panel deployed on port 3001"
EOF

echo "🎉 Deployment complete!"
echo "📍 Admin panel available at: http://${SERVER_IP}:${ADMIN_PORT}"
echo "🔗 Direct access: http://${SERVER_IP}:${ADMIN_PORT}"

# Cleanup
rm admin-deploy.tar.gz

echo "✨ Done!" 