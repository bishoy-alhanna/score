#!/bin/bash

# Deploy Cities and States Management Feature
# This script applies database migration and rebuilds auth service

set -e

echo "🚀 Deploying Cities and States Management Feature..."

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 1. Apply database migration
echo -e "${YELLOW}Step 1: Applying database migration...${NC}"
ssh bihannaroot@escore.al-hanna.com 'docker exec score_postgres_prod psql -U postgres -d saas_platform' < database/add_cities_states_tables.sql

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Database migration applied successfully${NC}"
else
    echo "❌ Database migration failed"
    exit 1
fi

# 2. Rebuild and deploy auth service
echo -e "${YELLOW}Step 2: Rebuilding and deploying auth service...${NC}"
ssh bihannaroot@escore.al-hanna.com 'cd ~/score && git pull origin prod && docker-compose -f docker-compose.prod.yml build auth-service && docker-compose -f docker-compose.prod.yml --env-file .env.production up -d auth-service'

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Auth service deployed successfully${NC}"
else
    echo "❌ Auth service deployment failed"
    exit 1
fi

# 3. Verify auth service health
echo -e "${YELLOW}Step 3: Verifying auth service health...${NC}"
sleep 5
ssh bihannaroot@escore.al-hanna.com 'curl -s http://localhost:5001/health'

echo -e "\n${GREEN}✅ Deployment completed successfully!${NC}"
echo ""
echo "API Endpoints created:"
echo "  GET    /api/locations/states - Get all states (public)"
echo "  POST   /api/locations/states - Create state (super admin)"
echo "  PUT    /api/locations/states/<id> - Update state (super admin)"
echo "  DELETE /api/locations/states/<id> - Delete state (super admin)"
echo ""
echo "  GET    /api/locations/cities - Get all cities (public)"
echo "  GET    /api/locations/cities?state_id=<id> - Get cities by state"
echo "  POST   /api/locations/cities - Create city (super admin)"
echo "  PUT    /api/locations/cities/<id> - Update city (super admin)"
echo "  DELETE /api/locations/cities/<id> - Delete city (super admin)"
echo ""
echo "Database tables created:"
echo "  - states (with 26 Egyptian governorates)"
echo "  - cities (with sample Cairo cities)"
echo "  - users.city_id and users.state_id fields added"
