#!/bin/bash

# Test login and check token payload
echo "Testing login and token payload..."

# Login as a test user
LOGIN_RESPONSE=$(ssh bihannaroot@escore.al-hanna.com 'docker exec score_api_gateway_prod curl -s -X POST http://auth-service:5001/auth/login -H "Content-Type: application/json" -d "{\"username\":\"test1@hotmail.com\",\"password\":\"Test@12345\",\"organization_name\":\"شباب ٢٠٢٦\"}"')

echo "Login Response:"
echo "$LOGIN_RESPONSE" | python3 -m json.tool

# Extract token
TOKEN=$(echo "$LOGIN_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('token', ''))" 2>/dev/null)

if [ -z "$TOKEN" ]; then
    echo "❌ Failed to get token"
    exit 1
fi

echo ""
echo "Token obtained: ${TOKEN:0:50}..."
echo ""

# Decode token (base64 decode the payload part)
echo "Decoding token payload..."
PAYLOAD=$(echo "$TOKEN" | cut -d. -f2)
# Add padding if needed
PADDED_PAYLOAD="${PAYLOAD}$(printf '=%.0s' {1..4})"
echo "$PADDED_PAYLOAD" | base64 -d 2>/dev/null | python3 -m json.tool

echo ""
echo "Testing groups endpoint..."
ssh bihannaroot@escore.al-hanna.com "docker exec score_api_gateway_prod curl -s -X GET http://group-service:5003/groups/ -H 'Authorization: Bearer $TOKEN'" | python3 -m json.tool

echo ""
echo "Testing scores endpoint..."
ssh bihannaroot@escore.al-hanna.com "docker exec score_api_gateway_prod curl -s -X GET http://scoring-service:5004/scores/ -H 'Authorization: Bearer $TOKEN'" | python3 -m json.tool
