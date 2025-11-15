#!/bin/bash

# Local Platform Test Script

echo "=========================================="
echo "🧪 Testing Local Development Platform"
echo "=========================================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

success() {
    echo -e "${GREEN}✓${NC} $1"
}

error() {
    echo -e "${RED}✗${NC} $1"
}

# Test 1: Check containers
echo "1. Checking Docker containers..."
REQUIRED_CONTAINERS=(
    "score_postgres_dev"
    "score_redis_dev"
    "score_nginx_dev"
    "score_api_gateway_dev"
    "score_admin_dashboard_dev"
    "score_user_dashboard_dev"
)

for container in "${REQUIRED_CONTAINERS[@]}"; do
    if docker ps --format '{{.Names}}' | grep -q "$container"; then
        success "$container is running"
    else
        error "$container is NOT running"
    fi
done
echo ""

# Test 2: Database
echo "2. Testing database..."
if docker exec score_postgres_dev pg_isready -U postgres > /dev/null 2>&1; then
    success "PostgreSQL is ready"
    
    # Check if database has data
    USER_COUNT=$(docker exec score_postgres_dev psql -U postgres -d saas_platform -tAc "SELECT COUNT(*) FROM users;" 2>/dev/null || echo "0")
    if [ "$USER_COUNT" -gt 0 ]; then
        success "Database has $USER_COUNT users"
    else
        error "Database is empty - run ./scripts/reset-database.sh"
    fi
else
    error "PostgreSQL is not ready"
fi
echo ""

# Test 3: Redis
echo "3. Testing Redis..."
if docker exec score_redis_dev redis-cli ping | grep -q PONG; then
    success "Redis is responding"
else
    error "Redis is not responding"
fi
echo ""

# Test 4: Nginx
echo "4. Testing Nginx..."
if curl -s http://localhost/health | grep -q "healthy"; then
    success "Nginx health check passed"
else
    error "Nginx health check failed"
fi
echo ""

# Test 5: API Gateway
echo "5. Testing API Gateway..."
API_RESPONSE=$(curl -s http://localhost/api/health)
if echo "$API_RESPONSE" | grep -q "healthy"; then
    success "API Gateway is healthy"
    echo "   Response: $API_RESPONSE"
else
    error "API Gateway health check failed"
fi
echo ""

# Test 6: Frontend
echo "6. Testing Frontend..."
if curl -s -o /dev/null -w "%{http_code}" http://localhost/admin/ | grep -q "200"; then
    success "Admin dashboard accessible"
else
    error "Admin dashboard not accessible"
fi

if curl -s -o /dev/null -w "%{http_code}" http://localhost/ | grep -q "200"; then
    success "User dashboard accessible"
else
    error "User dashboard not accessible"
fi
echo ""

# Test 7: Debug tools
echo "7. Testing Debug Tools..."
if curl -s -o /dev/null -w "%{http_code}" http://localhost/debug.html | grep -q "200"; then
    success "Debug page accessible"
else
    error "Debug page not accessible"
fi

if curl -s -o /dev/null -w "%{http_code}" http://localhost/clear-cache.html | grep -q "200"; then
    success "Cache clearing page accessible"
else
    error "Cache clearing page not accessible"
fi
echo ""

echo "=========================================="
echo "📊 Test Summary"
echo "=========================================="
echo ""
echo "Access URLs:"
echo "  Admin:  http://localhost/admin/"
echo "  User:   http://localhost/"
echo "  Debug:  http://localhost/debug.html"
echo "  API:    http://localhost/api/health"
echo ""
echo "Demo Credentials:"
echo "  Username: admin"
echo "  Password: password123"
echo ""
echo "View Logs:"
echo "  docker-compose -f docker-compose.dev.yml logs -f"
echo ""
