#!/bin/bash

# Fix API Gateway and Auth Service Issues
# This script diagnoses and fixes common issues with API gateway and auth service

set -e

echo "=========================================="
echo "Fixing API Gateway and Auth Service"
echo "=========================================="
echo ""

cd ~/score 2>/dev/null || cd /home/bihannaroot/score 2>/dev/null || cd $(dirname "$0")

# Load environment
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

echo "Step 1: Checking current status..."
docker-compose -f docker-compose.prod.yml ps | grep -E "(api-gateway|auth-service|postgres|redis)"

echo ""
echo "Step 2: Checking API Gateway logs for errors..."
docker-compose -f docker-compose.prod.yml logs api-gateway --tail=50

echo ""
echo "Step 3: Stopping problematic services..."
docker-compose -f docker-compose.prod.yml stop api-gateway auth-service

echo ""
echo "Step 4: Ensuring dependencies are healthy..."

# Wait for postgres
echo "Waiting for PostgreSQL..."
for i in {1..30}; do
    if docker exec score_postgres_prod pg_isready -U postgres > /dev/null 2>&1; then
        echo "✅ PostgreSQL is ready"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "❌ PostgreSQL timeout - restarting..."
        docker-compose -f docker-compose.prod.yml restart postgres
        sleep 10
    fi
    sleep 1
done

# Wait for redis
echo "Waiting for Redis..."
for i in {1..30}; do
    if docker exec score_redis_prod redis-cli ping > /dev/null 2>&1; then
        echo "✅ Redis is ready"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "❌ Redis timeout - restarting..."
        docker-compose -f docker-compose.prod.yml restart redis
        sleep 10
    fi
    sleep 1
done

echo ""
echo "Step 5: Starting auth-service..."
docker-compose -f docker-compose.prod.yml up -d auth-service

echo "Waiting for auth-service to be healthy..."
sleep 10

for i in {1..30}; do
    if docker exec score_auth_service_prod curl -sf http://localhost:5001/health > /dev/null 2>&1; then
        echo "✅ Auth service is healthy"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "❌ Auth service not responding"
        echo "Logs:"
        docker-compose -f docker-compose.prod.yml logs auth-service --tail=30
        exit 1
    fi
    sleep 2
done

echo ""
echo "Step 6: Starting API gateway..."
docker-compose -f docker-compose.prod.yml up -d api-gateway

echo "Waiting for API gateway to be healthy..."
sleep 10

for i in {1..30}; do
    if docker exec score_api_gateway_prod curl -sf http://localhost:5000/health > /dev/null 2>&1; then
        echo "✅ API Gateway is healthy"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "❌ API Gateway not responding"
        echo "Logs:"
        docker-compose -f docker-compose.prod.yml logs api-gateway --tail=30
        exit 1
    fi
    sleep 2
done

echo ""
echo "Step 7: Testing login endpoint..."

# Test login endpoint
TEST_RESULT=$(docker exec score_api_gateway_prod curl -s -w "\n%{http_code}" -X POST http://localhost:5000/api/super-admin/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"SuperBishoy@2024!"}')

HTTP_CODE=$(echo "$TEST_RESULT" | tail -n1)
RESPONSE=$(echo "$TEST_RESULT" | head -n-1)

echo "HTTP Status: $HTTP_CODE"
echo "Response: $RESPONSE"

if [ "$HTTP_CODE" = "200" ]; then
    echo ""
    echo "✅ Login endpoint is working!"
    echo ""
    echo "=========================================="
    echo "🎉 SUCCESS! Everything is working!"
    echo "=========================================="
    echo ""
    echo "You can now login at:"
    echo "  https://admin.escore.al-hanna.com"
    echo "  Username: admin"
    echo "  Password: SuperBishoy@2024!"
    echo ""
elif [ "$HTTP_CODE" = "401" ]; then
    echo ""
    echo "⚠️  Login endpoint is responding but credentials may be wrong"
    echo "   Run: ./update-admin-password.sh"
    echo ""
else
    echo ""
    echo "❌ Login endpoint returned unexpected status: $HTTP_CODE"
    echo ""
fi

echo ""
echo "Final status:"
docker-compose -f docker-compose.prod.yml ps | grep -E "(api-gateway|auth-service)"
