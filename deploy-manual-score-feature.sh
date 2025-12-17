#!/bin/bash

# Deploy Manual Score Feature to Production
# This script deploys the group manual score feature with member aggregation

set -e  # Exit on any error

echo "======================================"
echo "Deploying Manual Score Feature"
echo "======================================"
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if we're in the right directory
if [ ! -f "docker-compose.prod.yml" ]; then
    echo -e "${RED}Error: docker-compose.prod.yml not found. Please run from the score directory.${NC}"
    exit 1
fi

# Check if .env.production exists
if [ ! -f ".env.production" ]; then
    echo -e "${RED}Error: .env.production not found.${NC}"
    exit 1
fi

echo -e "${YELLOW}Step 1: Building updated services...${NC}"
echo "Building group-service, scoring-service, and leaderboard-service..."
docker-compose -f docker-compose.prod.yml build group-service scoring-service leaderboard-service

echo ""
echo -e "${YELLOW}Step 2: Applying database migration...${NC}"
echo "Adding manual_score field to groups table..."

# Apply migration
docker exec score_postgres_prod psql -U postgres -d saas_platform << 'EOF'
-- Add manual_score column if it doesn't exist
ALTER TABLE groups ADD COLUMN IF NOT EXISTS manual_score INTEGER DEFAULT 0;

-- Verify the column was added
\d groups
EOF

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Database migration applied successfully${NC}"
else
    echo -e "${RED}✗ Database migration failed${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}Step 3: Restarting services with updated code...${NC}"

# Restart services with environment file
docker-compose -f docker-compose.prod.yml --env-file .env.production up -d group-service scoring-service leaderboard-service

echo ""
echo -e "${YELLOW}Step 4: Waiting for services to be healthy...${NC}"
sleep 10

# Check service health
echo "Checking group-service..."
GROUP_HEALTH=$(docker exec score_group_service_prod curl -s http://localhost:5003/health || echo "FAILED")
if [[ "$GROUP_HEALTH" == *"healthy"* ]] || [[ "$GROUP_HEALTH" == *"ok"* ]]; then
    echo -e "${GREEN}✓ Group service is healthy${NC}"
else
    echo -e "${RED}✗ Group service health check failed${NC}"
fi

echo "Checking scoring-service..."
SCORING_HEALTH=$(docker exec score_scoring_service_prod curl -s http://localhost:5004/health || echo "FAILED")
if [[ "$SCORING_HEALTH" == *"healthy"* ]] || [[ "$SCORING_HEALTH" == *"ok"* ]]; then
    echo -e "${GREEN}✓ Scoring service is healthy${NC}"
else
    echo -e "${RED}✗ Scoring service health check failed${NC}"
fi

echo "Checking leaderboard-service..."
LEADERBOARD_HEALTH=$(docker exec score_leaderboard_service_prod curl -s http://localhost:5005/health || echo "FAILED")
if [[ "$LEADERBOARD_HEALTH" == *"healthy"* ]] || [[ "$LEADERBOARD_HEALTH" == *"ok"* ]]; then
    echo -e "${GREEN}✓ Leaderboard service is healthy${NC}"
else
    echo -e "${RED}✗ Leaderboard service health check failed${NC}"
fi

echo ""
echo -e "${YELLOW}Step 5: Verifying JWT configuration...${NC}"

# Check JWT secret is set
JWT_SECRET=$(docker exec score_leaderboard_service_prod printenv JWT_SECRET_KEY)
if [ -n "$JWT_SECRET" ] && [ "$JWT_SECRET" != "" ]; then
    echo -e "${GREEN}✓ JWT_SECRET_KEY is configured${NC}"
else
    echo -e "${RED}✗ JWT_SECRET_KEY is not set!${NC}"
    echo "This will cause authentication errors."
fi

echo ""
echo -e "${GREEN}======================================"
echo "Deployment Complete!"
echo "======================================${NC}"
echo ""
echo "New Features Available:"
echo "  ✓ Manual group scores (PUT /groups/{id}/manual-score)"
echo "  ✓ Automatic member score aggregation"
echo "  ✓ Combined total in leaderboards"
echo "  ✓ Score breakdown endpoint (GET /scores/group/{id}/total)"
echo ""
echo "Formula: Total Group Score = Manual Score + Sum(Member Scores) + Direct Group Scores"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Test the manual score endpoint"
echo "2. Verify leaderboards show correct totals"
echo "3. Check that member scores are aggregating"
echo ""
echo "To view logs:"
echo "  docker logs -f score_group_service_prod"
echo "  docker logs -f score_scoring_service_prod"
echo "  docker logs -f score_leaderboard_service_prod"
echo ""
