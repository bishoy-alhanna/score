#!/bin/bash

# Test Join Request Flow After Registration

API_URL="https://escore.al-hanna.com"
ORG_NAME="شباب ٢٠٢٦"  # Existing organization name from logs

echo "=========================================="
echo "Testing Join Request Flow"
echo "=========================================="
echo ""

# Generate unique username for test
TIMESTAMP=$(date +%s)
TEST_USERNAME="testuser${TIMESTAMP}"
TEST_EMAIL="testuser${TIMESTAMP}@test.com"

echo "Step 1: Register new user with organization request"
echo "Username: $TEST_USERNAME"
echo "Organization: $ORG_NAME"
echo ""

REGISTER_RESPONSE=$(curl -s -X POST "${API_URL}/api/auth/register" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "'${TEST_USERNAME}'",
    "email": "'${TEST_EMAIL}'",
    "password": "TestPassword123!",
    "first_name": "Test",
    "last_name": "User",
    "organization_name": "'${ORG_NAME}'"
  }')

echo "Registration Response:"
echo "$REGISTER_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$REGISTER_RESPONSE"
echo ""

# Check if join request was created
if echo "$REGISTER_RESPONSE" | grep -q "join_request_submitted"; then
    echo "✅ Join request was created during registration!"
    echo ""
    
    echo "Step 2: Check if organization admin can see the join request"
    echo "(Check admin dashboard for pending join requests)"
    echo ""
    
else
    echo "❌ Join request was NOT created during registration"
    echo ""
fi

echo "=========================================="
echo "Test Complete"
echo "=========================================="
