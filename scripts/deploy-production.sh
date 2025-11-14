#!/bin/bash

# Production Deployment Script
# This script deploys the latest changes to production including the loading screen fix

set -e  # Exit on error

echo "========================================"
echo "🚀 Score Platform Production Deployment"
echo "========================================"
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}This will deploy to: escore.al-hanna.com${NC}"
echo ""
read -p "Continue with production deployment? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Deployment cancelled."
    exit 0
fi

echo ""
echo "📡 Connecting to production server..."
ssh bihannaroot@escore.al-hanna.com << 'ENDSSH'

set -e

echo ""
echo "📂 Navigating to project directory..."
cd score

echo ""
echo "🔄 Pulling latest changes from git..."
git pull

echo ""
echo "🛠️  Building frontend containers with loading fix..."
docker-compose build admin-dashboard user-dashboard

echo ""
echo "🔧 Building nginx with cache clearing page..."
docker-compose build nginx

echo ""
echo "🔄 Restarting containers..."
docker-compose up -d

echo ""
echo "⏳ Waiting for containers to be ready..."
sleep 10

echo ""
echo "🔍 Checking container status..."
docker-compose ps

echo ""
echo "✅ Deployment complete!"
echo ""
echo "🌐 Access your site:"
echo "   - Admin: https://escore.al-hanna.com/admin/"
echo "   - User:  https://escore.al-hanna.com/"
echo "   - Clear Cache: https://escore.al-hanna.com/clear-cache.html"
echo ""
echo "📝 The 5-second loading timeout is now active!"
echo "   If you still see loading, visit the clear-cache page."

ENDSSH

echo ""
echo -e "${GREEN}========================================"
echo "✅ Production Deployment Successful!"
echo -e "========================================${NC}"
echo ""
echo "Next steps:"
echo "1. Visit https://escore.al-hanna.com/admin/"
echo "2. If you see loading screen, visit: https://escore.al-hanna.com/clear-cache.html"
echo "3. Login should appear within 5 seconds max"
echo ""
