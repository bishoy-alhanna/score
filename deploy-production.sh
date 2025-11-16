#!/bin/bash

# Production Deployment Script for SCORE Platform
# This script deploys the SCORE platform to production

set -e  # Exit on any error

echo "=========================================="
echo "SCORE Platform - Production Deployment"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if .env.production exists
if [ ! -f .env.production ]; then
    echo -e "${RED}ERROR: .env.production file not found!${NC}"
    echo "Please create .env.production with your production settings"
    exit 1
fi

# Load production environment variables
echo -e "${GREEN}Loading production environment variables...${NC}"
export $(cat .env.production | grep -v '^#' | xargs)

# Confirm deployment
echo ""
echo -e "${YELLOW}⚠️  WARNING: You are about to deploy to PRODUCTION!${NC}"
echo "Domain: ${DOMAIN_NAME}"
echo "Admin Subdomain: ${ADMIN_SUBDOMAIN}"
echo ""
read -p "Are you sure you want to continue? (yes/no): " -r
echo
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Deployment cancelled."
    exit 0
fi

# Pull latest code
echo ""
echo -e "${GREEN}Step 1: Pulling latest code from prod branch...${NC}"
git pull origin prod

# Stop existing containers
echo ""
echo -e "${GREEN}Step 2: Stopping existing containers...${NC}"
docker-compose -f docker-compose.prod.yml down

# Build images
echo ""
echo -e "${GREEN}Step 3: Building Docker images...${NC}"
docker-compose -f docker-compose.prod.yml build --no-cache

# Start services
echo ""
echo -e "${GREEN}Step 4: Starting services...${NC}"
docker-compose -f docker-compose.prod.yml up -d

# Wait for services to be healthy
echo ""
echo -e "${GREEN}Step 5: Waiting for services to be healthy...${NC}"
echo "This may take a few minutes..."
sleep 30

# Check service health
echo ""
echo -e "${GREEN}Step 6: Checking service health...${NC}"
docker-compose -f docker-compose.prod.yml ps

# Show logs
echo ""
echo -e "${GREEN}Step 7: Showing recent logs...${NC}"
docker-compose -f docker-compose.prod.yml logs --tail=50

echo ""
echo -e "${GREEN}=========================================="
echo "✅ Production deployment complete!"
echo "==========================================${NC}"
echo ""
echo "Access your application at:"
echo "  - User Dashboard: https://${DOMAIN_NAME}"
echo "  - Admin Dashboard: https://${ADMIN_SUBDOMAIN}"
echo ""
echo "To view logs: docker-compose -f docker-compose.prod.yml logs -f"
echo "To stop: docker-compose -f docker-compose.prod.yml down"
echo ""
