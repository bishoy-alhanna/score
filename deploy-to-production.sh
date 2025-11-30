#!/bin/bash

# Production Deployment - Quick Start
# This script guides you through deploying to production

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo "SCORE Platform - Production Deployment"
echo "==========================================${NC}"
echo ""

# Step 1: Check current branch
echo -e "${YELLOW}Step 1: Checking current branch...${NC}"
CURRENT_BRANCH=$(git branch --show-current)
echo "Current branch: ${CURRENT_BRANCH}"

if [ "$CURRENT_BRANCH" != "pre-prod-dev" ]; then
    echo -e "${RED}WARNING: You should be on pre-prod-dev branch${NC}"
    read -p "Continue anyway? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        exit 0
    fi
fi

# Step 2: Check for uncommitted changes
echo ""
echo -e "${YELLOW}Step 2: Checking for uncommitted changes...${NC}"
if ! git diff-index --quiet HEAD --; then
    echo -e "${RED}ERROR: You have uncommitted changes${NC}"
    git status --short
    echo ""
    echo "Please commit or stash your changes before deploying."
    exit 1
else
    echo -e "${GREEN}✓ No uncommitted changes${NC}"
fi

# Step 3: Confirm deployment plan
echo ""
echo -e "${YELLOW}Step 3: Deployment Plan${NC}"
echo "---------------------------------------"
echo "1. Merge pre-prod-dev → prod branch"
echo "2. Push to remote repository"
echo "3. SSH to production server"
echo "4. Backup production database"
echo "5. Apply database migrations"
echo "6. Pull latest code"
echo "7. Rebuild and restart services"
echo "8. Verify deployment"
echo "---------------------------------------"
echo ""

read -p "Ready to proceed? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Deployment cancelled."
    exit 0
fi

# Step 4: Merge to prod branch
echo ""
echo -e "${YELLOW}Step 4: Merging to prod branch...${NC}"
git checkout prod
git merge pre-prod-dev

echo ""
echo -e "${GREEN}✓ Merged successfully${NC}"

# Step 5: Push to remote
echo ""
echo -e "${YELLOW}Step 5: Pushing to remote...${NC}"
git push origin prod

echo ""
echo -e "${GREEN}✓ Pushed to remote${NC}"

# Step 6: Generate deployment commands
echo ""
echo -e "${YELLOW}Step 6: Production Server Commands${NC}"
echo "---------------------------------------"
echo "Copy and run these commands on your production server:"
echo ""
echo -e "${BLUE}# 1. SSH to production server${NC}"
echo "ssh root@escore.al-hanna.com"
echo ""
echo -e "${BLUE}# 2. Navigate to project directory${NC}"
echo "cd /root/score"
echo ""
echo -e "${BLUE}# 3. Backup current database${NC}"
echo "./backup-database.sh"
echo ""
echo -e "${BLUE}# 4. Pull latest code${NC}"
echo "git pull origin prod"
echo ""
echo -e "${BLUE}# 5. Apply database migrations${NC}"
echo "docker-compose -f docker-compose.prod.yml exec -T postgres psql -U postgres -d saas_platform < apply-production-migrations.sql"
echo ""
echo -e "${BLUE}# 6. Rebuild and restart services${NC}"
echo "docker-compose -f docker-compose.prod.yml down"
echo "docker-compose -f docker-compose.prod.yml build --no-cache"
echo "docker-compose -f docker-compose.prod.yml --env-file .env.production up -d"
echo ""
echo -e "${BLUE}# 7. Check service status${NC}"
echo "docker-compose -f docker-compose.prod.yml ps"
echo ""
echo -e "${BLUE}# 8. Monitor logs${NC}"
echo "docker-compose -f docker-compose.prod.yml logs -f leaderboard-service"
echo "---------------------------------------"
echo ""

# Create a deployment script file
echo ""
echo -e "${YELLOW}Creating production-deploy-server.sh...${NC}"
cat > production-deploy-server.sh << 'EOF'
#!/bin/bash
# Run this script on the production server

set -e

echo "=========================================="
echo "Production Server Deployment"
echo "=========================================="

# Navigate to project
cd /root/score

# Backup database
echo ""
echo "Step 1: Backing up database..."
./backup-database.sh

# Pull latest code
echo ""
echo "Step 2: Pulling latest code..."
git pull origin prod

# Apply migrations
echo ""
echo "Step 3: Applying database migrations..."
docker-compose -f docker-compose.prod.yml exec -T postgres psql -U postgres -d saas_platform < apply-production-migrations.sql

# Rebuild services
echo ""
echo "Step 4: Rebuilding services..."
docker-compose -f docker-compose.prod.yml down
docker-compose -f docker-compose.prod.yml build --no-cache

# Start services
echo ""
echo "Step 5: Starting services..."
docker-compose -f docker-compose.prod.yml --env-file .env.production up -d

# Wait for services
echo ""
echo "Step 6: Waiting for services to start..."
sleep 30

# Check status
echo ""
echo "Step 7: Checking service status..."
docker-compose -f docker-compose.prod.yml ps

echo ""
echo "=========================================="
echo "✓ Deployment Complete!"
echo "=========================================="
echo ""
echo "Next Steps:"
echo "1. Check logs: docker-compose -f docker-compose.prod.yml logs -f"
echo "2. Test user dashboard: https://escore.al-hanna.com"
echo "3. Test admin dashboard: https://admin.escore.al-hanna.com"
echo "4. Verify leaderboard shows only active members"
echo ""
EOF

chmod +x production-deploy-server.sh

echo -e "${GREEN}✓ Created production-deploy-server.sh${NC}"
echo ""
echo -e "${YELLOW}Instructions:${NC}"
echo "1. Copy production-deploy-server.sh to your production server"
echo "2. Run it on the server: ./production-deploy-server.sh"
echo ""
echo -e "${GREEN}Or copy the commands above and run them manually${NC}"
echo ""

# Switch back to pre-prod-dev
echo -e "${YELLOW}Switching back to pre-prod-dev branch...${NC}"
git checkout pre-prod-dev

echo ""
echo -e "${GREEN}=========================================="
echo "✓ Local deployment preparation complete!"
echo "==========================================${NC}"
echo ""
echo -e "${YELLOW}Next: Deploy on production server${NC}"
echo ""
