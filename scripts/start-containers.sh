#!/bin/bash

# Quick fix script for starting missing containers on production

echo "=========================================="
echo "🔧 Starting Missing Containers"
echo "=========================================="
echo ""

cd /root/score

echo "1. Checking current container status..."
docker-compose ps
echo ""

echo "2. Starting all containers..."
docker-compose up -d
echo ""

echo "3. Waiting for containers to start..."
sleep 10
echo ""

echo "4. Checking container status again..."
docker-compose ps
echo ""

echo "5. Checking for any errors in API Gateway..."
docker-compose logs api-gateway --tail 30
echo ""

echo "=========================================="
echo "✅ Container startup complete"
echo "=========================================="
echo ""
echo "Run the test again:"
echo "  ./scripts/test-platform-docker.sh"
