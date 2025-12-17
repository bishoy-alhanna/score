#!/bin/bash
# Production Server Deployment Script
# Run this on escore.al-hanna.com production server

set -e

echo "=========================================="
echo "Production Server Deployment"
echo "=========================================="

# Navigate to project
cd /home/bihannaroot/newsystem/score

# Step 1: Backup database
echo ""
echo "Step 1: Backing up current database..."
./backup-database.sh

# Step 2: Pull latest code
echo ""
echo "Step 2: Pulling latest code from prod branch..."
git pull origin prod

# Step 3: Apply migrations
echo ""
echo "Step 3: Applying database migrations..."
docker-compose -f docker-compose.prod.yml exec -T postgres \
  psql -U postgres -d saas_platform < apply-production-migrations.sql

echo ""
echo "✓ Migrations applied successfully"

# Step 4: Rebuild services
echo ""
echo "Step 4: Stopping services..."
docker-compose -f docker-compose.prod.yml down

echo ""
echo "Step 5: Building images (this may take 5-10 minutes)..."
docker-compose -f docker-compose.prod.yml build --no-cache

# Step 5: Start services
echo ""
echo "Step 6: Starting services..."
docker-compose -f docker-compose.prod.yml --env-file .env.production up -d

# Step 6: Wait for services
echo ""
echo "Step 7: Waiting for services to start (30 seconds)..."
sleep 30

# Step 7: Check status
echo ""
echo "Step 8: Checking service status..."
docker-compose -f docker-compose.prod.yml ps

echo ""
echo "=========================================="
echo "✓ Deployment Complete!"
echo "=========================================="
echo ""
echo "Next Steps:"
echo "1. Monitor logs: docker-compose -f docker-compose.prod.yml logs -f"
echo "2. Test user dashboard: https://escore.al-hanna.com"
echo "3. Test admin dashboard: https://admin.escore.al-hanna.com"
echo "4. Verify leaderboard shows only active members"
echo ""
echo "If there are any issues, check logs:"
echo "  docker-compose -f docker-compose.prod.yml logs leaderboard-service"
echo "  docker-compose -f docker-compose.prod.yml logs auth-service"
echo ""
