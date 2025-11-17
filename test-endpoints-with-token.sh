#!/bin/bash

TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoiMWZiODhjMzgtMmM5YS00ZmMyLWJjMzItNjhhMjcyZDJjNjBmIiwidXNlcm5hbWUiOiJ0ZXN0dXNlcjEyMyIsImVtYWlsIjoidGVzdHVzZXIxMjNAZXhhbXBsZS5jb20iLCJyb2xlIjoiVVNFUiIsIm9yZ2FuaXphdGlvbl9pZCI6IjIzMzllOGM0LWRiZTUtNGQ2MC05ODI4LTJlMTI5Mzc0YjE1YiIsImV4cCI6MTc2MzUwMTQwOCwiaWF0IjoxNzYzNDE1MDA4fQ.bqdtPsvkB0IfgqyOsYN8NUSpMZ6r_r7zlQgUZ8ZqeyM"

echo "=== Testing Groups Endpoint ==="
ssh bihannaroot@escore.al-hanna.com "docker exec score_api_gateway_prod curl -s -X GET http://group-service:5003/groups/ -H 'Authorization: Bearer $TOKEN'" | python3 -m json.tool

echo ""
echo "=== Testing Scores Endpoint ==="
ssh bihannaroot@escore.al-hanna.com "docker exec score_api_gateway_prod curl -s -X GET http://scoring-service:5004/scores/ -H 'Authorization: Bearer $TOKEN'" | python3 -m json.tool

echo ""
echo "=== Testing Score Categories Endpoint ==="
ssh bihannaroot@escore.al-hanna.com "docker exec score_api_gateway_prod curl -s -X GET http://scoring-service:5004/scores/categories -H 'Authorization: Bearer $TOKEN'" | python3 -m json.tool
