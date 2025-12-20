#!/bin/bash

echo "=================================================="
echo "Applying manual_score Migration to Production"
echo "=================================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Step 1: Check current database state
echo -e "${YELLOW}Step 1: Checking current database state...${NC}"
docker exec score_postgres_prod psql -U postgres -d saas_platform -c "SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'groups' AND column_name = 'manual_score';"

echo ""
echo -e "${YELLOW}Step 2: Applying migration - Adding manual_score column...${NC}"
docker exec score_postgres_prod psql -U postgres -d saas_platform -c "ALTER TABLE groups ADD COLUMN IF NOT EXISTS manual_score INTEGER DEFAULT 0;"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Migration applied successfully${NC}"
else
    echo -e "${RED}✗ Migration failed${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}Step 3: Verifying migration...${NC}"
docker exec score_postgres_prod psql -U postgres -d saas_platform -c "SELECT column_name, data_type, column_default FROM information_schema.columns WHERE table_name = 'groups' AND column_name = 'manual_score';"

echo ""
echo -e "${YELLOW}Step 4: Checking groups table structure...${NC}"
docker exec score_postgres_prod psql -U postgres -d saas_platform -c "SELECT COUNT(*) as total_groups, COUNT(manual_score) as groups_with_manual_score FROM groups;"

echo ""
echo -e "${YELLOW}Step 5: Restarting affected services...${NC}"
echo "Restarting group-service..."
docker restart score_group_service_prod
sleep 3

echo "Restarting leaderboard-service..."
docker restart score_leaderboard_service_prod
sleep 3

echo "Restarting scoring-service..."
docker restart score_scoring_service_prod
sleep 3

echo "Restarting api-gateway..."
docker restart score_api_gateway_prod
sleep 3

echo ""
echo -e "${YELLOW}Step 6: Checking service health...${NC}"
sleep 5

echo "Group Service:"
docker logs --tail 5 score_group_service_prod 2>&1 | grep -E "Listening|ERROR|started"

echo ""
echo "Leaderboard Service:"
docker logs --tail 5 score_leaderboard_service_prod 2>&1 | grep -E "Listening|ERROR|started"

echo ""
echo "Scoring Service:"
docker logs --tail 5 score_scoring_service_prod 2>&1 | grep -E "Listening|ERROR|started"

echo ""
echo -e "${YELLOW}Step 7: Testing API endpoints...${NC}"
echo "Testing group service health:"
curl -s http://localhost:5003/health

echo ""
echo ""
echo "Testing leaderboard service health:"
curl -s http://localhost:5005/health

echo ""
echo ""
echo -e "${GREEN}=================================================="
echo "Migration Complete!"
echo "==================================================${NC}"
echo ""
echo "Next steps:"
echo "1. Test the admin portal - try to load groups"
echo "2. Test the user portal - check if errors are gone"
echo "3. Test manual score endpoint with:"
echo "   curl -X PUT http://localhost:5003/groups/{GROUP_ID}/manual-score \\"
echo "     -H 'Authorization: Bearer YOUR_TOKEN' \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"manual_score\": 50}'"
