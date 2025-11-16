#!/bin/bash

# Check and Fix Production Services
# This script checks all services and attempts to fix issues

set -e

echo "=========================================="
echo "Checking Production Services Status"
echo "=========================================="
echo ""

cd ~/score 2>/dev/null || cd /home/bihannaroot/score 2>/dev/null || cd $(dirname "$0")

# Load environment
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

echo "1. Checking Docker Compose services..."
docker-compose -f docker-compose.prod.yml ps

echo ""
echo "2. Checking which services are unhealthy..."
docker-compose -f docker-compose.prod.yml ps | grep -E "(Exit|unhealthy)" || echo "All services appear healthy"

echo ""
echo "3. Checking recent logs for errors..."
echo ""
echo "=== Auth Service Logs ==="
docker-compose -f docker-compose.prod.yml logs auth-service --tail=20 2>&1 || echo "Auth service not running"

echo ""
echo "=== Postgres Logs ==="
docker-compose -f docker-compose.prod.yml logs postgres --tail=20 2>&1 || echo "Postgres not running"

echo ""
echo "=========================================="
echo "Service Health Summary"
echo "=========================================="

# Check each critical service
services=("postgres" "redis" "auth-service" "user-service" "group-service" "api-gateway" "admin-dashboard" "user-dashboard" "nginx")

for service in "${services[@]}"; do
    container_name="score_${service//-/_}_prod"
    if docker ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
        status=$(docker inspect --format='{{.State.Health.Status}}' $container_name 2>/dev/null || echo "no healthcheck")
        echo "✅ $service: Running ($status)"
    else
        echo "❌ $service: Not running"
    fi
done

echo ""
echo "=========================================="
echo "Recommended Actions"
echo "=========================================="
echo ""
echo "If services are not running, try:"
echo "  1. docker-compose -f docker-compose.prod.yml down"
echo "  2. docker-compose -f docker-compose.prod.yml up -d"
echo ""
echo "If auth-service is failing, check database connection:"
echo "  docker-compose -f docker-compose.prod.yml logs auth-service"
echo ""
echo "To restart a specific service:"
echo "  docker-compose -f docker-compose.prod.yml restart SERVICE_NAME"
echo ""
