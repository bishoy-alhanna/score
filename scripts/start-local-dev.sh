#!/bin/bash

# Local Development Startup Script

echo "=========================================="
echo "🚀 Starting Score Platform - LOCAL DEV"
echo "=========================================="
echo ""

# Check if .env.local exists
if [ ! -f .env.local ]; then
    echo "Creating .env.local from template..."
    cp .env.development .env.local
    echo "✓ Created .env.local"
fi

echo "Starting local development environment..."
echo ""

# Stop any existing containers
echo "1. Stopping any existing containers..."
docker-compose -f docker-compose.dev.yml down

echo ""
echo "2. Building containers..."
docker-compose -f docker-compose.dev.yml build

echo ""
echo "3. Starting services..."
docker-compose -f docker-compose.dev.yml up -d

echo ""
echo "4. Waiting for services to start..."
sleep 15

echo ""
echo "5. Checking container status..."
docker-compose -f docker-compose.dev.yml ps

echo ""
echo "=========================================="
echo "✅ LOCAL DEVELOPMENT READY!"
echo "=========================================="
echo ""
echo "🌐 Access your application:"
echo "   Admin Dashboard:  http://localhost/admin/"
echo "   User Dashboard:   http://localhost/"
echo "   API Gateway:      http://localhost/api/health"
echo "   Debug Tools:      http://localhost/debug.html"
echo "   Clear Cache:      http://localhost/clear-cache.html"
echo ""
echo "🗄️  Database:"
echo "   Host: localhost"
echo "   Port: 5432"
echo "   User: postgres"
echo "   Pass: password"
echo "   DB:   saas_platform"
echo ""
echo "📊 View logs:"
echo "   All:          docker-compose -f docker-compose.dev.yml logs -f"
echo "   Nginx:        docker-compose -f docker-compose.dev.yml logs -f nginx"
echo "   API Gateway:  docker-compose -f docker-compose.dev.yml logs -f api-gateway"
echo "   Database:     docker-compose -f docker-compose.dev.yml logs -f postgres"
echo ""
echo "🛑 Stop services:"
echo "   docker-compose -f docker-compose.dev.yml down"
echo ""
echo "🔄 Restart service:"
echo "   docker-compose -f docker-compose.dev.yml restart <service-name>"
echo ""
echo "🧪 Test platform:"
echo "   ./scripts/test-local-platform.sh"
echo ""
