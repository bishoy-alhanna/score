#!/bin/bash

# Local Testing Script - Score System
# This script tests the scoring system locally without SSL

echo "========================================="
echo "Score System - Local Testing"
echo "========================================="
echo ""

# Check if services are running
if ! docker-compose ps | grep -q "Up"; then
    echo "⚠️  Docker services not running. Starting..."
    docker-compose up -d
    echo "Waiting for services to start..."
    sleep 10
fi

# Test through docker network directly
echo "Testing API endpoints..."
echo ""

# Test 1: Health Check
echo "1️⃣  Testing API Health..."
HEALTH=$(docker exec saas_api_gateway curl -s http://localhost:5000/health)
echo "Response: $HEALTH"
echo ""

# Test 2: Login
echo "2️⃣  Testing Login..."
LOGIN_RESPONSE=$(docker exec saas_auth_service curl -s -X POST http://localhost:5001/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"password123"}')
echo "Response: $LOGIN_RESPONSE"
echo ""

# Extract token
TOKEN=$(echo $LOGIN_RESPONSE | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

if [ -z "$TOKEN" ]; then
    echo "❌ Login failed - no token received"
    exit 1
fi

echo "✅ Login successful! Token: ${TOKEN:0:20}..."
echo ""

# Test 3: Get Score Categories
echo "3️⃣  Testing Get Score Categories..."
CATEGORIES=$(docker exec saas_api_gateway curl -s -X GET "http://scoring-service:5004/categories" \
  -H "Authorization: Bearer $TOKEN")
echo "Response: $CATEGORIES"
echo ""

# Test 4: Get User Scores
echo "4️⃣  Testing Get Scores..."
SCORES=$(docker exec saas_api_gateway curl -s -X GET "http://scoring-service:5004/" \
  -H "Authorization: Bearer $TOKEN")
echo "Response: $SCORES"
echo ""

# Test 5: Assign Score (Admin only)
echo "5️⃣  Testing Assign Score..."
ASSIGN=$(docker exec saas_api_gateway curl -s -X POST http://scoring-service:5004/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "dddddddd-dddd-dddd-dddd-dddddddddddd",
    "category_id": "c1111111-1111-1111-1111-111111111111",
    "score_value": 75,
    "description": "Test score from local testing"
  }')
echo "Response: $ASSIGN"
echo ""

echo "========================================="
echo "✅ Local Testing Complete!"
echo "========================================="
echo ""
echo "Next steps:"
echo "1. Review the responses above"
echo "2. If all tests passed, push changes to production"
echo "3. Run the same tests on production server"
echo ""
