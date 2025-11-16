#!/bin/bash

# Deploy Fixes Script for Old Branch
# This script rebuilds and deploys all services with the production fixes

set -e

echo "🔧 Deploying Production Fixes..."
echo "================================="

# Change to script directory
cd "$(dirname "$0")"

echo "📍 Working directory: $(pwd)"

echo ""
echo "Step 1: Stopping all containers..."
docker-compose down

echo ""
echo "Step 2: Building backend services with Gunicorn and wget..."
docker-compose build --no-cache \
    auth-service \
    user-service \
    group-service \
    scoring-service \
    leaderboard-service

echo ""
echo "Step 3: Building nginx with fixed configuration..."
docker-compose build --no-cache nginx

echo ""
echo "Step 4: Starting all services..."
docker-compose up -d

echo ""
echo "Step 5: Waiting for services to initialize..."
sleep 30

echo ""
echo "Step 6: Checking service status..."
docker-compose ps

echo ""
echo "Step 7: Testing backend health endpoints..."
echo "Auth Service:"
docker exec saas_auth_service wget --spider -q http://localhost:5001/health && echo "✅ Healthy" || echo "❌ Unhealthy"

echo "User Service:"
docker exec saas_user_service wget --spider -q http://localhost:5002/health && echo "✅ Healthy" || echo "❌ Unhealthy"

echo "Group Service:"
docker exec saas_group_service wget --spider -q http://localhost:5003/health && echo "✅ Healthy" || echo "❌ Unhealthy"

echo "Scoring Service:"
docker exec saas_scoring_service wget --spider -q http://localhost:5004/health && echo "✅ Healthy" || echo "❌ Unhealthy"

echo "Leaderboard Service:"
docker exec saas_leaderboard_service wget --spider -q http://localhost:5005/health && echo "✅ Healthy" || echo "❌ Unhealthy"

echo ""
echo "Step 8: Checking for Gunicorn (should see gunicorn, not Flask dev server)..."
docker exec saas_auth_service ps aux | grep -E "gunicorn|python" | grep -v grep

echo ""
echo "================================="
echo "✅ Deployment Complete!"
echo "================================="
echo ""
echo "Access your application at:"
echo "  - Admin: http://admin.score.al-hanna.com"
echo "  - User:  http://score.al-hanna.com"
echo ""
echo "All services should now be running with:"
echo "  ✅ Gunicorn production server"
echo "  ✅ wget-based health checks"
echo "  ✅ Fixed nginx configuration"
echo "  ✅ No deprecated docker-compose version warning"
