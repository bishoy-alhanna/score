#!/bin/bash

# Test Super Admin Login
# This script tests the super admin login from multiple angles

set -e

echo "=========================================="
echo "Testing Super Admin Login"
echo "=========================================="
echo ""

# Load environment
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

SUPER_ADMIN_USERNAME=${SUPER_ADMIN_USERNAME:-admin}
SUPER_ADMIN_PASSWORD=${SUPER_ADMIN_PASSWORD:-SuperBishoy@2024!}

echo "Testing with credentials:"
echo "  Username: $SUPER_ADMIN_USERNAME"
echo "  Password: $SUPER_ADMIN_PASSWORD"
echo ""

# Test 1: Check if user exists
echo "Test 1: Checking if user exists in database..."
USER_CHECK=$(docker exec -i score_postgres_prod psql -U postgres -d saas_platform -t << EOF
SELECT username, email, is_super_admin, is_active 
FROM users 
WHERE username = '$SUPER_ADMIN_USERNAME';
EOF
)

if [ -z "$USER_CHECK" ]; then
    echo "❌ User '$SUPER_ADMIN_USERNAME' not found in database!"
    echo ""
    echo "Run this to create the user:"
    echo "  ./fix-admin-password.sh"
    exit 1
else
    echo "✅ User found: $USER_CHECK"
fi
echo ""

# Test 2: Test from inside Docker network (HTTP)
echo "Test 2: Testing login from inside Docker network (HTTP)..."
RESULT=$(docker exec score_api_gateway_prod curl -s -w "\n%{http_code}" -X POST http://localhost:5000/api/super-admin/login \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"$SUPER_ADMIN_USERNAME\",\"password\":\"$SUPER_ADMIN_PASSWORD\"}")

HTTP_CODE=$(echo "$RESULT" | tail -n1)
RESPONSE=$(echo "$RESULT" | head -n-1)

echo "HTTP Status: $HTTP_CODE"
echo "Response: $RESPONSE"

if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ Login successful from inside Docker!"
elif [ "$HTTP_CODE" = "401" ]; then
    echo "❌ Login failed: Invalid credentials"
    echo ""
    echo "The password hash doesn't match. Run:"
    echo "  ./fix-admin-password.sh"
    exit 1
else
    echo "⚠️  Unexpected response: $HTTP_CODE"
fi
echo ""

# Test 3: Test from nginx (HTTPS)
echo "Test 3: Testing login through nginx (HTTPS)..."
RESULT=$(curl -k -s -w "\n%{http_code}" -X POST https://localhost/api/super-admin/login \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"$SUPER_ADMIN_USERNAME\",\"password\":\"$SUPER_ADMIN_PASSWORD\"}")

HTTP_CODE=$(echo "$RESULT" | tail -n1)
RESPONSE=$(echo "$RESULT" | head -n-1)

echo "HTTP Status: $HTTP_CODE"
echo "Response: $RESPONSE"

if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ Login successful through nginx!"
    
    # Extract token
    TOKEN=$(echo "$RESPONSE" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
    if [ -n "$TOKEN" ]; then
        echo ""
        echo "🎉 Login token received!"
        echo "Token preview: ${TOKEN:0:50}..."
    fi
elif [ "$HTTP_CODE" = "401" ]; then
    echo "❌ Login failed through nginx: Invalid credentials"
else
    echo "⚠️  Unexpected response: $HTTP_CODE"
fi
echo ""

# Test 4: Test from external domain
echo "Test 4: Testing login from external domain..."
RESULT=$(curl -k -s -w "\n%{http_code}" -X POST https://admin.escore.al-hanna.com/api/super-admin/login \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"$SUPER_ADMIN_USERNAME\",\"password\":\"$SUPER_ADMIN_PASSWORD\"}")

HTTP_CODE=$(echo "$RESULT" | tail -n1)
RESPONSE=$(echo "$RESULT" | head -n-1)

echo "HTTP Status: $HTTP_CODE"

if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ Login successful from external domain!"
    echo ""
    echo "=========================================="
    echo "🎉 ALL TESTS PASSED!"
    echo "=========================================="
    echo ""
    echo "You can now login at:"
    echo "  🌐 https://admin.escore.al-hanna.com"
    echo "  👤 Username: $SUPER_ADMIN_USERNAME"
    echo "  🔑 Password: $SUPER_ADMIN_PASSWORD"
    echo ""
elif [ "$HTTP_CODE" = "401" ]; then
    echo "❌ Login failed from external domain"
    echo ""
    echo "Internal tests passed but external failed."
    echo "This might be a DNS or SSL issue."
else
    echo "⚠️  Status: $HTTP_CODE"
    echo "Response: $RESPONSE"
fi
echo ""
