#!/bin/bash

set -e

SERVER_IP="$1"
BRANCH="${2:-main}"

if [ -z "$SERVER_IP" ]; then
    echo "Usage: $0 <server_ip> [branch]"
    echo "Example: $0 37.27.217.240 main"
    exit 1
fi

echo "🚀 Starting deployment to $SERVER_IP..."

# Function to run commands on server
run_on_server() {
    ssh root@$SERVER_IP "$1"
}

echo "📥 Pulling latest changes from git..."
run_on_server "cd /opt/revcopy-simple && git pull origin $BRANCH"

echo "📦 Updating submodules..."
run_on_server "cd /opt/revcopy-simple && git submodule update --init --recursive"

echo "🛠️ Building and deploying containers..."
run_on_server "cd /opt/revcopy-simple && docker-compose build --no-cache frontend backend"

echo "🔄 Restarting services..."
run_on_server "cd /opt/revcopy-simple && docker-compose down && docker-compose up -d"

echo "⏰ Waiting for services to be ready..."
sleep 15

echo "🩺 Checking service health..."
if curl -s "http://$SERVER_IP/health" | grep -q "healthy"; then
    echo "✅ Frontend is healthy"
else
    echo "❌ Frontend health check failed"
fi

if curl -s "http://$SERVER_IP:8000/health" | grep -q "healthy"; then
    echo "✅ Backend API is healthy"
else
    echo "❌ Backend API health check failed"
fi

echo "🎉 Deployment completed!"
echo "🌐 Frontend: http://$SERVER_IP"
echo "🔌 Backend API: http://$SERVER_IP:8000" 