#!/bin/bash

# Deploy Manual Score Feature to Production Server
# Run this script AFTER SSH'ing into the production server

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo "Deploying Manual Score Feature to Production"
echo "==========================================${NC}"
echo ""

# Check if we're in the right directory
if [ ! -f "docker-compose.prod.yml" ]; then
    echo -e "${RED}Error: docker-compose.prod.yml not found.${NC}"
    echo "Please navigate to the score directory first:"
    echo "  cd /root/score"
    exit 1
fi

# Step 1: Backup current state
echo -e "${YELLOW}Step 1: Creating backup...${NC}"
BACKUP_DIR="backups/pre-manual-score-$(date +%Y%m%d_%H%M%S)"
mkdir -p $BACKUP_DIR

# Backup database
echo "Backing up database..."
docker exec score_postgres_prod pg_dump -U postgres saas_platform > $BACKUP_DIR/database_backup.sql
echo -e "${GREEN}✓ Database backed up to $BACKUP_DIR/database_backup.sql${NC}"

# Step 2: Pull latest code
echo ""
echo -e "${YELLOW}Step 2: Pulling latest code from GitHub...${NC}"
git fetch origin
git status

# Show what will be pulled
echo ""
echo "Changes to be pulled:"
git log HEAD..origin/prod --oneline --no-decorate | head -10

echo ""
read -p "Pull these changes? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Deployment cancelled."
    exit 0
fi

# Stash any local changes
if ! git diff-index --quiet HEAD --; then
    echo "Stashing local changes..."
    git stash
fi

# Pull latest code
git pull origin prod

# Step 3: Apply database migration
echo ""
echo -e "${YELLOW}Step 3: Applying database migration...${NC}"
echo "Adding manual_score field to groups table..."

docker exec score_postgres_prod psql -U postgres -d saas_platform << 'EOSQL'
-- Add manual_score column if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'groups' AND column_name = 'manual_score'
    ) THEN
        ALTER TABLE groups ADD COLUMN manual_score INTEGER DEFAULT 0;
        RAISE NOTICE 'Added manual_score column to groups table';
    ELSE
        RAISE NOTICE 'manual_score column already exists';
    END IF;
END $$;

-- Verify the column exists
SELECT column_name, data_type, column_default 
FROM information_schema.columns 
WHERE table_name = 'groups' AND column_name = 'manual_score';
EOSQL

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Database migration completed${NC}"
else
    echo -e "${RED}✗ Database migration failed${NC}"
    exit 1
fi

# Step 4: Rebuild updated services
echo ""
echo -e "${YELLOW}Step 4: Rebuilding services...${NC}"
echo "Building: group-service, scoring-service, leaderboard-service"

docker-compose -f docker-compose.prod.yml build --no-cache group-service scoring-service leaderboard-service

if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Build failed${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Services built successfully${NC}"

# Step 5: Restart services with environment file
echo ""
echo -e "${YELLOW}Step 5: Restarting services...${NC}"

# Stop services
docker-compose -f docker-compose.prod.yml stop group-service scoring-service leaderboard-service

# Start services with environment file
docker-compose -f docker-compose.prod.yml --env-file .env.production up -d group-service scoring-service leaderboard-service

echo "Waiting for services to start..."
sleep 15

# Step 6: Verify services are healthy
echo ""
echo -e "${YELLOW}Step 6: Checking service health...${NC}"

# Check group-service
echo -n "Checking group-service... "
if docker exec score_group_service_prod curl -sf http://localhost:5003/health > /dev/null; then
    echo -e "${GREEN}✓ Healthy${NC}"
else
    echo -e "${RED}✗ Unhealthy${NC}"
fi

# Check scoring-service
echo -n "Checking scoring-service... "
if docker exec score_scoring_service_prod curl -sf http://localhost:5004/health > /dev/null; then
    echo -e "${GREEN}✓ Healthy${NC}"
else
    echo -e "${RED}✗ Unhealthy${NC}"
fi

# Check leaderboard-service
echo -n "Checking leaderboard-service... "
if docker exec score_leaderboard_service_prod curl -sf http://localhost:5005/health > /dev/null; then
    echo -e "${GREEN}✓ Healthy${NC}"
else
    echo -e "${RED}✗ Unhealthy${NC}"
fi

# Step 7: Verify JWT configuration
echo ""
echo -e "${YELLOW}Step 7: Verifying JWT configuration...${NC}"

JWT_SECRET=$(docker exec score_leaderboard_service_prod printenv JWT_SECRET_KEY)
if [ -n "$JWT_SECRET" ] && [ "$JWT_SECRET" != "" ]; then
    echo -e "${GREEN}✓ JWT_SECRET_KEY is configured${NC}"
else
    echo -e "${RED}✗ WARNING: JWT_SECRET_KEY is not set properly!${NC}"
    echo "This will cause authentication errors."
fi

# Step 8: Show recent logs
echo ""
echo -e "${YELLOW}Step 8: Checking for errors in logs...${NC}"

echo ""
echo "Last 10 lines from group-service:"
docker logs --tail 10 score_group_service_prod 2>&1 | grep -i "error\|warn\|started" || echo "No errors found"

echo ""
echo "Last 10 lines from scoring-service:"
docker logs --tail 10 score_scoring_service_prod 2>&1 | grep -i "error\|warn\|started" || echo "No errors found"

echo ""
echo "Last 10 lines from leaderboard-service:"
docker logs --tail 10 score_leaderboard_service_prod 2>&1 | grep -i "error\|warn\|started" || echo "No errors found"

# Step 9: Test the new endpoint
echo ""
echo -e "${YELLOW}Step 9: Testing deployment...${NC}"
echo ""
echo "You can test the new features with:"
echo ""
echo "1. Test manual score endpoint:"
echo "   curl -X PUT http://localhost/api/groups/{GROUP_ID}/manual-score \\"
echo "     -H 'Authorization: Bearer YOUR_TOKEN' \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"manual_score\": 100}'"
echo ""
echo "2. Check group total with breakdown:"
echo "   curl http://localhost/api/scores/group/{GROUP_ID}/total?category=general \\"
echo "     -H 'Authorization: Bearer YOUR_TOKEN'"
echo ""

# Summary
echo ""
echo -e "${GREEN}=========================================="
echo "Deployment Complete!"
echo "==========================================${NC}"
echo ""
echo "What was deployed:"
echo "  ✓ Manual score field added to groups table"
echo "  ✓ Group service updated with manual score endpoint"
echo "  ✓ Scoring service updated with aggregation logic"
echo "  ✓ Leaderboard service updated to show combined totals"
echo ""
echo "Formula: Total Group Score = Manual Score + Sum(Member Scores) + Direct Group Scores"
echo ""
echo "Backup location: $BACKUP_DIR"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Test the manual score endpoint"
echo "2. Verify leaderboards show correct totals"
echo "3. Check that member scores are aggregating"
echo ""
echo "To monitor logs continuously:"
echo "  docker-compose -f docker-compose.prod.yml logs -f leaderboard-service"
echo ""
echo "To rollback if needed:"
echo "  docker exec score_postgres_prod psql -U postgres -d saas_platform < $BACKUP_DIR/database_backup.sql"
echo ""
