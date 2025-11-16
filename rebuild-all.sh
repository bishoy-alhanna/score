#!/bin/bash

# Complete System Rebuild
# This rebuilds everything from scratch when services are unhealthy

set -e

echo "=========================================="
echo "Complete System Rebuild"
echo "=========================================="
echo ""

cd ~/score 2>/dev/null || cd /home/bihannaroot/score 2>/dev/null || cd $(dirname "$0")

# Load environment
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

echo "Step 1: Stopping all containers..."
docker-compose -f docker-compose.prod.yml down

echo ""
echo "Step 2: Removing old containers and networks..."
docker system prune -f

echo ""
echo "Step 3: Checking disk space..."
df -h | head -5

echo ""
echo "Step 4: Building all services (this may take 10-15 minutes)..."
docker-compose -f docker-compose.prod.yml build --no-cache

echo ""
echo "Step 5: Starting services one by one..."

# Start infrastructure first
echo ""
echo "Starting PostgreSQL..."
docker-compose -f docker-compose.prod.yml up -d postgres
echo "Waiting for PostgreSQL to be ready..."
for i in {1..60}; do
    if docker exec score_postgres_prod pg_isready -U postgres > /dev/null 2>&1; then
        echo "✅ PostgreSQL is ready"
        break
    fi
    if [ $i -eq 60 ]; then
        echo "❌ PostgreSQL failed to start"
        docker-compose -f docker-compose.prod.yml logs postgres --tail=50
        exit 1
    fi
    sleep 2
done

echo ""
echo "Starting Redis..."
docker-compose -f docker-compose.prod.yml up -d redis
echo "Waiting for Redis to be ready..."
for i in {1..30}; do
    if docker exec score_redis_prod redis-cli ping > /dev/null 2>&1; then
        echo "✅ Redis is ready"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "❌ Redis failed to start"
        docker-compose -f docker-compose.prod.yml logs redis --tail=50
        exit 1
    fi
    sleep 2
done

# Start backend services
echo ""
echo "Starting backend services..."
docker-compose -f docker-compose.prod.yml up -d auth-service user-service group-service scoring-service leaderboard-service

echo "Waiting for backend services (30 seconds)..."
sleep 30

# Check backend services
echo ""
echo "Checking auth-service..."
docker-compose -f docker-compose.prod.yml logs auth-service --tail=20

echo ""
echo "Starting API Gateway..."
docker-compose -f docker-compose.prod.yml up -d api-gateway
sleep 10

# Start frontend
echo ""
echo "Starting frontend dashboards..."
docker-compose -f docker-compose.prod.yml up -d admin-dashboard user-dashboard
sleep 10

# Start nginx last
echo ""
echo "Starting nginx..."
docker-compose -f docker-compose.prod.yml up -d nginx
sleep 5

echo ""
echo "=========================================="
echo "Step 6: Checking Final Status"
echo "=========================================="
echo ""
docker-compose -f docker-compose.prod.yml ps

echo ""
echo "Step 7: Testing Critical Services"
echo ""

# Test each service
test_service() {
    local name=$1
    local container=$2
    local cmd=$3
    
    echo -n "Testing $name... "
    if docker exec $container sh -c "$cmd" > /dev/null 2>&1; then
        echo "✅"
        return 0
    else
        echo "❌"
        echo "Logs:"
        docker-compose -f docker-compose.prod.yml logs $name --tail=20
        return 1
    fi
}

test_service "postgres" "score_postgres_prod" "pg_isready -U postgres"
test_service "redis" "score_redis_prod" "redis-cli ping"
test_service "auth-service" "score_auth_service_prod" "curl -f http://localhost:5001/health || true"
test_service "api-gateway" "score_api_gateway_prod" "curl -f http://localhost:5000/health || true"

echo ""
echo "=========================================="
echo "Rebuild Complete!"
echo "=========================================="
echo ""
echo "If services are still unhealthy, check individual logs:"
echo "  docker-compose -f docker-compose.prod.yml logs SERVICE_NAME"
echo ""
echo "Common issues:"
echo "  1. Out of disk space: df -h"
echo "  2. Out of memory: free -h"
echo "  3. Port conflicts: netstat -tlnp"
echo ""
