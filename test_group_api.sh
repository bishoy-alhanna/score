#!/bin/bash

# Test group API with a sample admin token
echo "Testing Group API..."
echo ""

# First, let's login as admin to get a token
echo "1. Logging in as admin..."
LOGIN_RESPONSE=$(curl -s -X POST http://localhost/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@example.com",
    "password": "admin123"
  }')

echo "Login Response:"
echo "$LOGIN_RESPONSE" | jq '.'
echo ""

# Extract token
TOKEN=$(echo "$LOGIN_RESPONSE" | jq -r '.token // empty')

if [ -z "$TOKEN" ]; then
  echo "❌ Failed to get token. Cannot proceed with group API test."
  exit 1
fi

echo "✅ Token obtained"
echo ""

# Test getting groups
echo "2. Testing GET /api/groups..."
GET_RESPONSE=$(curl -s -X GET "http://localhost/api/groups?organization_id=11111111-1111-1111-1111-111111111111" \
  -H "Authorization: Bearer $TOKEN")

echo "GET Groups Response:"
echo "$GET_RESPONSE" | jq '.'
echo ""

# Test getting my groups
echo "3. Testing GET /api/groups/my-groups..."
MY_GROUPS_RESPONSE=$(curl -s -X GET http://localhost/api/groups/my-groups \
  -H "Authorization: Bearer $TOKEN")

echo "My Groups Response:"
echo "$MY_GROUPS_RESPONSE" | jq '.'
echo ""

# Test creating a group
echo "4. Testing POST /api/groups..."
CREATE_RESPONSE=$(curl -s -X POST http://localhost/api/groups/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test Group",
    "description": "A test group"
  }')

echo "Create Group Response:"
echo "$CREATE_RESPONSE" | jq '.'
echo ""

echo "✅ Group API tests complete"
