#!/bin/bash
TIMESTAMP=$(date +%s)
curl -s -X POST "http://localhost/api/auth/register" \
  -H "Content-Type: application/json" \
  -d "{
    \"username\": \"testuser${TIMESTAMP}\",
    \"email\": \"testuser${TIMESTAMP}@test.com\",
    \"password\": \"TestPassword123!\",
    \"first_name\": \"Test\",
    \"last_name\": \"User\",
    \"organization_name\": \"شباب ٢٠٢٦\"
  }" | python3 -m json.tool 2>/dev/null || echo "Failed"
