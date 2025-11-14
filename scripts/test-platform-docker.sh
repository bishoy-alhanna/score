#!/bin/bash

# Production Platform Test Script
# Tests the Score platform using Docker containers

set -e

echo "=========================================="
echo "🧪 Score Platform Production Test"
echo "=========================================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
success() {
    echo -e "${GREEN}✓${NC} $1"
}

error() {
    echo -e "${RED}✗${NC} $1"
}

warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Check if docker-compose is available
if ! command -v docker-compose &> /dev/null; then
    error "docker-compose not found. Please install Docker Compose."
    exit 1
fi

# Test 1: Check if containers are running
echo "1. Checking Docker containers..."
REQUIRED_CONTAINERS=(
    "saas_postgres"
    "saas_redis"
    "saas_nginx"
    "api-gateway"
)

for container in "${REQUIRED_CONTAINERS[@]}"; do
    if docker ps --format '{{.Names}}' | grep -q "$container"; then
        success "$container is running"
    else
        error "$container is not running"
        echo ""
        echo "Start containers with: docker-compose up -d"
        exit 1
    fi
done
echo ""

# Test 2: Database connection
echo "2. Testing database connection..."
if docker exec saas_postgres pg_isready -U postgres > /dev/null 2>&1; then
    success "PostgreSQL connection successful"
    
    # Check database exists
    if docker exec saas_postgres psql -U postgres -lqt | cut -d \| -f 1 | grep -qw saas_platform; then
        success "Database 'saas_platform' exists"
    else
        error "Database 'saas_platform' not found"
        echo "Run: ./scripts/reset-database.sh"
        exit 1
    fi
else
    error "PostgreSQL connection failed"
    exit 1
fi
echo ""

# Test 3: Check database tables
echo "3. Checking database schema..."
REQUIRED_TABLES=(
    "users"
    "organizations"
    "user_organizations"
    "score_categories"
    "scores"
    "score_aggregates"
)

for table in "${REQUIRED_TABLES[@]}"; do
    if docker exec saas_postgres psql -U postgres -d saas_platform -c "\dt" | grep -q "$table"; then
        success "Table '$table' exists"
    else
        error "Table '$table' not found"
    fi
done
echo ""

# Test 4: Redis connection
echo "4. Testing Redis connection..."
if docker exec saas_redis redis-cli ping | grep -q PONG; then
    success "Redis connection successful"
else
    error "Redis connection failed"
    exit 1
fi
echo ""

# Test 5: Check demo data
echo "5. Checking demo data..."
USER_COUNT=$(docker exec saas_postgres psql -U postgres -d saas_platform -tAc "SELECT COUNT(*) FROM users;")
ORG_COUNT=$(docker exec saas_postgres psql -U postgres -d saas_platform -tAc "SELECT COUNT(*) FROM organizations;")
CATEGORY_COUNT=$(docker exec saas_postgres psql -U postgres -d saas_platform -tAc "SELECT COUNT(*) FROM score_categories;")

echo "  Users: $USER_COUNT"
echo "  Organizations: $ORG_COUNT"
echo "  Score Categories: $CATEGORY_COUNT"

if [ "$USER_COUNT" -gt 0 ] && [ "$ORG_COUNT" -gt 0 ]; then
    success "Demo data loaded"
else
    warning "No demo data found"
    echo "  Run: ./scripts/reset-database.sh to load demo data"
fi
echo ""

# Test 6: Nginx health check
echo "6. Testing Nginx..."
if docker exec saas_nginx nginx -t > /dev/null 2>&1; then
    success "Nginx configuration valid"
else
    error "Nginx configuration has errors"
    docker exec saas_nginx nginx -t
    exit 1
fi

# Test HTTP health endpoint
if docker exec saas_nginx wget -q -O- http://localhost/health 2>/dev/null | grep -q "healthy"; then
    success "Nginx health endpoint responding"
else
    warning "Nginx health endpoint not responding"
fi
echo ""

# Test 7: API Gateway health
echo "7. Testing API Gateway..."
if docker exec api-gateway curl -s http://localhost:5000/api/health | grep -q "healthy"; then
    success "API Gateway health check passed"
else
    error "API Gateway health check failed"
    echo "Logs:"
    docker logs api-gateway --tail 20
fi
echo ""

# Test 8: External HTTPS access (if in production)
echo "8. Testing external access..."
DOMAIN="escore.al-hanna.com"

if curl -k -s -o /dev/null -w "%{http_code}" https://$DOMAIN/health 2>/dev/null | grep -q "200"; then
    success "HTTPS health endpoint accessible: https://$DOMAIN/health"
else
    warning "HTTPS health endpoint not accessible (might be local environment)"
fi

if curl -k -s -o /dev/null -w "%{http_code}" https://$DOMAIN/api/health 2>/dev/null | grep -q "200"; then
    success "API Gateway accessible: https://$DOMAIN/api/health"
else
    warning "API Gateway not accessible externally (might be local environment)"
fi
echo ""

# Test 9: Check SSL certificates (if in production)
echo "9. Checking SSL certificates..."
if [ -d "/etc/letsencrypt/live/$DOMAIN" ]; then
    success "SSL certificates found"
    
    # Check expiry
    CERT_FILE="/etc/letsencrypt/live/$DOMAIN/cert.pem"
    if [ -f "$CERT_FILE" ]; then
        EXPIRY=$(openssl x509 -enddate -noout -in "$CERT_FILE" | cut -d= -f2)
        echo "  Expires: $EXPIRY"
    fi
else
    warning "SSL certificates not found (local environment or not configured)"
    echo "  Run: sudo ./scripts/setup-ssl.sh to set up SSL"
fi
echo ""

# Test 10: Test login functionality
echo "10. Testing authentication..."
LOGIN_RESPONSE=$(docker exec api-gateway curl -s -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "admin",
    "password": "password123",
    "organization_name": "Tech Corp"
  }' 2>/dev/null)

if echo "$LOGIN_RESPONSE" | grep -q "token"; then
    success "Authentication working (admin login successful)"
    TOKEN=$(echo "$LOGIN_RESPONSE" | grep -o '"token":"[^"]*"' | sed 's/"token":"\([^"]*\)"/\1/')
    echo "  Token: ${TOKEN:0:30}..."
else
    warning "Authentication test failed (demo user might not exist)"
    echo "  Response: $LOGIN_RESPONSE"
    echo "  Run: ./scripts/reset-database.sh to load demo users"
fi
echo ""

# Test 11: Frontend containers
echo "11. Checking frontend containers..."
if docker ps --format '{{.Names}}' | grep -q "admin-dashboard"; then
    success "Admin Dashboard container running"
else
    warning "Admin Dashboard container not running"
fi

if docker ps --format '{{.Names}}' | grep -q "user-dashboard"; then
    success "User Dashboard container running"
else
    warning "User Dashboard container not running"
fi
echo ""

# Summary
echo "=========================================="
echo "📊 Test Summary"
echo "=========================================="
echo ""
echo "Core Services:"
success "PostgreSQL: Running"
success "Redis: Running"
success "Nginx: Running"
success "API Gateway: Running"
echo ""

echo "Access URLs:"
echo "  🌐 Admin Dashboard: https://$DOMAIN/admin/"
echo "  🌐 User Dashboard:  https://$DOMAIN/"
echo "  🔧 API Gateway:     https://$DOMAIN/api/"
echo "  🧹 Clear Cache:     https://$DOMAIN/clear-cache.html"
echo ""

echo "Demo Credentials:"
echo "  👤 Super Admin: admin / password123"
echo "  👤 Org Admin:   john.admin / password123"
echo "  👤 User:        john.doe / password123"
echo ""

echo "=========================================="
success "Platform test completed!"
echo "=========================================="
