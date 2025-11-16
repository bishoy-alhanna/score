#!/bin/bash

# Quick Fix - Restart Services and Check Health
# Use this when services are not responding

set -e

echo "=========================================="
echo "Restarting All Services"
echo "=========================================="
echo ""

cd ~/score 2>/dev/null || cd /home/bihannaroot/score 2>/dev/null || cd $(dirname "$0")

# Load environment
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

echo "Step 1: Restarting all services..."
docker-compose -f docker-compose.prod.yml restart

echo ""
echo "Step 2: Waiting for services to start (30 seconds)..."
sleep 30

echo ""
echo "Step 3: Checking service health..."
echo ""

# Check each service
services=("postgres" "redis" "auth-service" "api-gateway")

for service in "${services[@]}"; do
    echo "Testing $service..."
    
    case $service in
        "postgres")
            if docker exec score_postgres_prod pg_isready -U postgres > /dev/null 2>&1; then
                echo "  ✅ PostgreSQL is ready"
            else
                echo "  ❌ PostgreSQL is not ready"
            fi
            ;;
        "redis")
            if docker exec score_redis_prod redis-cli ping > /dev/null 2>&1; then
                echo "  ✅ Redis is ready"
            else
                echo "  ❌ Redis is not ready"
            fi
            ;;
        "auth-service")
            if docker exec score_auth_service_prod curl -sf http://localhost:5001/health > /dev/null 2>&1; then
                echo "  ✅ Auth service is healthy"
            else
                echo "  ❌ Auth service is not responding"
                echo "     Logs:"
                docker-compose -f docker-compose.prod.yml logs auth-service --tail=10
            fi
            ;;
        "api-gateway")
            if docker exec score_api_gateway_prod curl -sf http://localhost:5000/health > /dev/null 2>&1; then
                echo "  ✅ API Gateway is healthy"
            else
                echo "  ❌ API Gateway is not responding"
                echo "     Logs:"
                docker-compose -f docker-compose.prod.yml logs api-gateway --tail=10
            fi
            ;;
    esac
    echo ""
done

echo "=========================================="
echo "Step 4: Testing Login Endpoint"
echo "=========================================="
echo ""

# Test the super-admin login endpoint from inside the network
echo "Testing /api/super-admin/login endpoint..."
docker exec score_api_gateway_prod curl -sf -X POST http://localhost:5000/api/super-admin/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test","password":"test"}' 2>&1 || echo "Endpoint test failed (this is expected if credentials are wrong)"

echo ""
echo ""
echo "=========================================="
echo "Service Status Summary"
echo "=========================================="
docker-compose -f docker-compose.prod.yml ps

echo ""
echo "If services are still failing, check detailed logs:"
echo "  docker-compose -f docker-compose.prod.yml logs SERVICE_NAME"
echo ""
