#!/bin/bash

# Debug Auth Service
# This script shows detailed information about why auth-service is failing

set -e

echo "=========================================="
echo "Debugging Auth Service"
echo "=========================================="
echo ""

cd ~/score 2>/dev/null || cd /home/bihannaroot/score 2>/dev/null || cd $(dirname "$0")

# Load environment
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

echo "Step 1: Checking if auth-service container exists..."
if docker ps -a | grep -q score_auth_service_prod; then
    echo "✅ Container exists"
    
    echo ""
    echo "Step 2: Checking container status..."
    docker ps -a | grep score_auth_service_prod
    
    echo ""
    echo "Step 3: Full logs from auth-service..."
    docker logs score_auth_service_prod --tail=100
    
    echo ""
    echo "Step 4: Checking environment variables in container..."
    docker exec score_auth_service_prod env | grep -E "(DATABASE_URL|JWT_SECRET|SECRET_KEY|FLASK)" || echo "Environment variables not accessible"
    
else
    echo "❌ Container does not exist"
    echo "Building and starting auth-service..."
    docker-compose -f docker-compose.prod.yml up -d auth-service
    sleep 5
    docker logs score_auth_service_prod --tail=50
fi

echo ""
echo "Step 5: Testing database connection from auth-service..."
docker exec score_auth_service_prod sh -c 'python3 -c "
import os
import psycopg2
try:
    conn = psycopg2.connect(os.environ.get(\"DATABASE_URL\"))
    print(\"✅ Database connection successful\")
    conn.close()
except Exception as e:
    print(f\"❌ Database connection failed: {e}\")
"' 2>&1 || echo "Failed to test database connection"

echo ""
echo "Step 6: Checking if port 5001 is listening..."
docker exec score_auth_service_prod sh -c 'netstat -tlnp 2>/dev/null | grep 5001' || echo "Port 5001 not listening"

echo ""
echo "=========================================="
echo "Diagnostic Summary"
echo "=========================================="
echo ""
echo "Check the logs above for errors. Common issues:"
echo ""
echo "1. Database connection errors:"
echo "   - Check DATABASE_URL is correct"
echo "   - Ensure postgres container is running"
echo ""
echo "2. Missing dependencies:"
echo "   - Check if requirements.txt is complete"
echo "   - Rebuild container: docker-compose -f docker-compose.prod.yml build auth-service"
echo ""
echo "3. Python errors:"
echo "   - Check for import errors or syntax errors in logs"
echo ""
echo "4. Port already in use:"
echo "   - Another process might be using port 5001"
echo ""
