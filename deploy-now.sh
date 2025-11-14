#!/bin/bash

# COMPLETE PRODUCTION DEPLOYMENT
# Run this on production server to fix the loading screen issue

set -e

echo "=========================================="
echo "🚀 COMPLETE PRODUCTION DEPLOYMENT"
echo "=========================================="
echo ""
echo "This will:"
echo "  1. Pull latest code changes"
echo "  2. Rebuild frontend with 5-second timeout fix"
echo "  3. Rebuild backend with Gunicorn WSGI server"
echo "  4. Restart all services"
echo "  5. Verify deployment"
echo ""

read -p "Continue? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo "Deployment cancelled"
    exit 0
fi

echo ""
echo "Step 1: Pulling latest changes from GitHub..."
git pull

echo ""
echo "Step 2: Building frontend containers (this fixes the loading screen)..."
docker-compose build admin-dashboard user-dashboard nginx

echo ""
echo "Step 3: Building backend containers (this adds Gunicorn)..."
docker-compose build api-gateway auth-service user-service group-service scoring-service leaderboard-service

echo ""
echo "Step 4: Restarting all services..."
docker-compose up -d

echo ""
echo "Step 5: Waiting for services to start..."
sleep 15

echo ""
echo "Step 6: Checking container status..."
docker-compose ps

echo ""
echo "=========================================="
echo "✅ DEPLOYMENT COMPLETE!"
echo "=========================================="
echo ""
echo "🌐 Your site is now available at:"
echo "   Admin:  https://escore.al-hanna.com/admin/"
echo "   User:   https://escore.al-hanna.com/"
echo "   Clear:  https://escore.al-hanna.com/clear-cache.html"
echo ""
echo "🔧 What was deployed:"
echo "   ✓ Frontend with 5-second loading timeout"
echo "   ✓ Backend with Gunicorn WSGI server"
echo "   ✓ Cache clearing page"
echo ""
echo "📝 Next steps:"
echo "   1. Visit: https://escore.al-hanna.com/clear-cache.html"
echo "   2. Wait for 'Cache cleared successfully!'"
echo "   3. Visit: https://escore.al-hanna.com/admin/"
echo "   4. Login should appear within 5 seconds"
echo ""
echo "If still showing loading:"
echo "   - Press Ctrl+Shift+R (hard refresh)"
echo "   - Or clear browser cache manually"
echo ""
echo "🧪 Test with:"
echo "   ./scripts/test-platform-docker.sh"
echo ""
