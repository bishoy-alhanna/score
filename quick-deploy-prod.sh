#!/bin/bash

# Quick Deploy Script for Production Server
# Copy this script to the server and run it

set -e

echo "=========================================="
echo "Deploying Manual Score Feature Updates"
echo "=========================================="

# Navigate to project directory
cd /home/bihannaroot/score || cd ~/score || cd /root/score

echo ""
echo "Step 1: Pulling latest code..."
git fetch origin
git pull origin prod

echo ""
echo "Step 2: Checking database migration..."
docker exec score_postgres_prod psql -U postgres -d saas_platform -c "SELECT column_name FROM information_schema.columns WHERE table_name = 'groups' AND column_name = 'manual_score';" | grep manual_score && echo "✓ manual_score column exists" || {
    echo "Adding manual_score column..."
    docker exec score_postgres_prod psql -U postgres -d saas_platform -c "ALTER TABLE groups ADD COLUMN manual_score INTEGER DEFAULT 0;"
}

echo ""
echo "Step 3: Rebuilding services..."
docker-compose -f docker-compose.prod.yml build --no-cache leaderboard-service scoring-service group-service

echo ""
echo "Step 4: Restarting services..."
docker-compose -f docker-compose.prod.yml --env-file .env.production up -d leaderboard-service scoring-service group-service

echo ""
echo "Step 5: Waiting for services to start..."
sleep 10

echo ""
echo "Step 6: Checking service health..."
docker ps | grep score_ | grep -E "leaderboard|scoring|group"

echo ""
echo "Step 7: Checking logs for errors..."
echo ""
echo "Leaderboard service logs:"
docker logs --tail 20 score_leaderboard_service_prod 2>&1 | grep -i "error\|started\|listening" || echo "No critical errors"

echo ""
echo "=========================================="
echo "Deployment Complete!"
echo "=========================================="
echo ""
echo "Test the leaderboard now and check if it shows correct scores."
echo ""
echo "To monitor logs:"
echo "  docker logs -f score_leaderboard_service_prod"
echo ""
