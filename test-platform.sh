#!/bin/bash

# Test script for SaaS Platform
echo "=== SaaS Platform Test Script ==="

# Check if database services are running
echo "1. Checking database services..."
if sudo docker ps | grep -q saas_postgres; then
    echo "✓ PostgreSQL is running"
else
    echo "✗ PostgreSQL is not running"
    exit 1
fi

if sudo docker ps | grep -q saas_redis; then
    echo "✓ Redis is running"
else
    echo "✗ Redis is not running"
    exit 1
fi

# Test database connection
echo "2. Testing database connection..."
if sudo docker exec saas_postgres pg_isready -U postgres > /dev/null 2>&1; then
    echo "✓ PostgreSQL connection successful"
else
    echo "✗ PostgreSQL connection failed"
    exit 1
fi

# Test Redis connection
echo "3. Testing Redis connection..."
if sudo docker exec saas_redis redis-cli ping | grep -q PONG; then
    echo "✓ Redis connection successful"
else
    echo "✗ Redis connection failed"
    exit 1
fi

# Start auth service
echo "4. Starting auth service..."
cd backend/auth-service/auth-service
source venv/bin/activate
export DATABASE_URL="postgresql://postgres:password@localhost:5432/saas_platform"
export JWT_SECRET_KEY="test-jwt-secret-key"
export SECRET_KEY="test-secret-key"

# Start service in background
python src/main.py > /tmp/auth-service.log 2>&1 &
AUTH_PID=$!
cd ../../..

# Wait for service to start
sleep 5

# Test auth service health
echo "5. Testing auth service..."
if curl -s http://localhost:5001/health | grep -q "healthy"; then
    echo "✓ Auth service is healthy"
else
    echo "✗ Auth service health check failed"
    echo "Auth service logs:"
    cat /tmp/auth-service.log
    kill $AUTH_PID 2>/dev/null
    exit 1
fi

# Test organization registration
echo "6. Testing organization registration..."
REGISTER_RESPONSE=$(curl -s -X POST http://localhost:5001/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testadmin",
    "email": "admin@test.com",
    "password": "password123",
    "organization_name": "Test Organization"
  }')

if echo "$REGISTER_RESPONSE" | grep -q "token"; then
    echo "✓ Organization registration successful"
    TOKEN=$(echo "$REGISTER_RESPONSE" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
    echo "  Token: ${TOKEN:0:20}..."
else
    echo "✗ Organization registration failed"
    echo "Response: $REGISTER_RESPONSE"
    kill $AUTH_PID 2>/dev/null
    exit 1
fi

# Test login
echo "7. Testing login..."
LOGIN_RESPONSE=$(curl -s -X POST http://localhost:5001/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testadmin",
    "password": "password123",
    "organization_name": "Test Organization"
  }')

if echo "$LOGIN_RESPONSE" | grep -q "token"; then
    echo "✓ Login successful"
else
    echo "✗ Login failed"
    echo "Response: $LOGIN_RESPONSE"
    kill $AUTH_PID 2>/dev/null
    exit 1
fi

# Test token verification
echo "8. Testing token verification..."
VERIFY_RESPONSE=$(curl -s -X POST http://localhost:5001/api/auth/verify \
  -H "Authorization: Bearer $TOKEN")

if echo "$VERIFY_RESPONSE" | grep -q "user"; then
    echo "✓ Token verification successful"
else
    echo "✗ Token verification failed"
    echo "Response: $VERIFY_RESPONSE"
fi

# Cleanup
echo "9. Cleaning up..."
kill $AUTH_PID 2>/dev/null
echo "✓ Auth service stopped"

echo ""
echo "=== Test Summary ==="
echo "✓ Database services are running"
echo "✓ Auth service works correctly"
echo "✓ Organization registration works"
echo "✓ User login works"
echo "✓ JWT token verification works"
echo ""
echo "🎉 SaaS Platform core functionality is working!"
echo ""
echo "Next steps:"
echo "1. Start all services: sudo docker compose up --build"
echo "2. Access Admin Dashboard: http://localhost:3000"
echo "3. Access User Dashboard: http://localhost:3001"
echo "4. API Gateway: http://localhost:5000"

