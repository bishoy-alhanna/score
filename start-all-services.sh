#!/bin/bash

# Start All Production Services
# This ensures all services are running and healthy

set -e

echo "=========================================="
echo "Starting All Production Services"
echo "=========================================="
echo ""

cd ~/score 2>/dev/null || cd /home/bihannaroot/score 2>/dev/null || cd $(dirname "$0")

# Load environment
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

echo "Step 1: Checking current status..."
docker-compose -f docker-compose.prod.yml ps

echo ""
echo "Step 2: Starting all services..."
docker-compose -f docker-compose.prod.yml up -d

echo ""
echo "Step 3: Waiting for services to start (30 seconds)..."
sleep 30

echo ""
echo "Step 4: Checking service health..."
echo ""

# Function to check service health
check_service() {
    local service=$1
    local container=$2
    local health_cmd=$3
    
    echo -n "Checking $service... "
    if docker exec $container sh -c "$health_cmd" > /dev/null 2>&1; then
        echo "✅ Healthy"
        return 0
    else
        echo "❌ Not healthy"
        return 1
    fi
}

# Check critical services
check_service "PostgreSQL" "score_postgres_prod" "pg_isready -U postgres"
check_service "Redis" "score_redis_prod" "redis-cli ping"
check_service "Auth Service" "score_auth_service_prod" "curl -sf http://localhost:5001/health"
check_service "API Gateway" "score_api_gateway_prod" "curl -sf http://localhost:5000/health"
check_service "User Service" "score_user_service_prod" "curl -sf http://localhost:5002/health"
check_service "Group Service" "score_group_service_prod" "curl -sf http://localhost:5003/health"
check_service "Admin Dashboard" "score_admin_dashboard_prod" "curl -sf http://localhost:3000"
check_service "User Dashboard" "score_user_dashboard_prod" "curl -sf http://localhost:3001"
check_service "Nginx" "score_nginx_prod" "curl -sf http://localhost/health"

echo ""
echo "Step 5: Final status..."
docker-compose -f docker-compose.prod.yml ps

echo ""
echo "=========================================="
echo "Services Started!"
echo "=========================================="
echo ""
echo "Your sites should be accessible at:"
echo "  🌐 User Dashboard:  https://escore.al-hanna.com"
echo "  🔧 Admin Dashboard: https://admin.escore.al-hanna.com"
echo ""
echo "If any service is unhealthy, check logs:"
echo "  docker-compose -f docker-compose.prod.yml logs SERVICE_NAME"
echo ""
