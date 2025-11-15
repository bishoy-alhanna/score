#!/bin/bash

# ULTIMATE FIX - Run this on production to solve the loading screen issue
# This stops everything, rebuilds everything, and starts fresh

echo "=========================================="
echo "🚨 ULTIMATE FIX FOR LOADING SCREEN"
echo "=========================================="
echo ""
echo "This will:"
echo "  - Stop all containers"
echo "  - Pull latest code"  
echo "  - Rebuild ALL containers from scratch"
echo "  - Start everything fresh"
echo "  - Test the deployment"
echo ""
echo "⏱️  Estimated time: 5-10 minutes"
echo "💾  No data will be lost (database persists)"
echo ""

read -p "Ready to fix? Type 'FIX' to continue: " CONFIRM

if [ "$CONFIRM" != "FIX" ]; then
    echo "Cancelled. Nothing changed."
    exit 0
fi

set -e  # Exit on any error

echo ""
echo "Step 1/6: Stopping all containers..."
docker-compose down

echo ""
echo "Step 2/6: Pulling latest code from GitHub..."
git pull

echo ""
echo "Step 3/6: Removing old Docker images..."
docker-compose rm -f

echo ""
echo "Step 4/6: Building ALL containers from scratch..."
echo "(This takes a few minutes - be patient!)"
docker-compose build --no-cache

echo ""
echo "Step 5/6: Starting all services..."
docker-compose up -d

echo ""
echo "Step 6/6: Waiting for services to start..."
for i in {1..30}; do
    echo -n "."
    sleep 1
done
echo ""

echo ""
echo "=========================================="
echo "✅ DEPLOYMENT COMPLETE!"
echo "=========================================="
echo ""

# Show status
echo "Container Status:"
docker-compose ps

echo ""
echo "=========================================="
echo "🧪 TESTING"
echo "=========================================="
echo ""

# Test API
echo "Testing API Gateway..."
if curl -s http://localhost:5000/health | grep -q "healthy"; then
    echo "✅ API Gateway is healthy"
else
    echo "❌ API Gateway not responding"
fi

# Test database
echo "Testing database..."
if docker exec saas_postgres pg_isready -U postgres > /dev/null 2>&1; then
    echo "✅ Database is healthy"
else
    echo "❌ Database not responding"
fi

echo ""
echo "=========================================="
echo "🌐 YOUR SITE IS READY"
echo "=========================================="
echo ""
echo "Visit: https://escore.al-hanna.com/admin/"
echo ""
echo "🎯 What should happen:"
echo "  1. Page loads"
echo "  2. You see 'Loading...' for UP TO 5 seconds"
echo "  3. Login form appears"
echo "  4. You can login with: admin / password123"
echo ""
echo "If still showing loading:"
echo "  1. Visit: https://escore.al-hanna.com/debug.html"
echo "  2. Click 'Clear Storage'"
echo "  3. Go back to /admin/"
echo ""
echo "📊 For detailed testing:"
echo "  ./scripts/test-platform-docker.sh"
echo ""
echo "📖 For troubleshooting:"
echo "  cat LOADING_SCREEN_TROUBLESHOOTING.md"
echo ""
echo "=========================================="
echo "✨ DONE!"
echo "=========================================="
