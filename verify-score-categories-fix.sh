#!/bin/bash

# Verify Score Categories Fix

echo "=========================================="
echo "Score Categories - Service Health Check"
echo "=========================================="
echo ""

echo "1. Checking service health status..."
ssh -o StrictHostKeyChecking=no bihannaroot@escore.al-hanna.com 'docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "scoring|group|leaderboard"'
echo ""

echo "2. Checking scoring service logs..."
ssh -o StrictHostKeyChecking=no bihannaroot@escore.al-hanna.com 'docker logs --tail 5 score_scoring_service_prod 2>&1'
echo ""

echo "3. Verifying score categories in database..."
ssh -o StrictHostKeyChecking=no bihannaroot@escore.al-hanna.com 'docker exec score_postgres_prod psql -U postgres -d saas_platform -c "SELECT COUNT(*) as total_categories, COUNT(*) FILTER (WHERE is_predefined=true) as predefined FROM score_categories;"'
echo ""

echo "4. Checking API Gateway access logs..."
ssh -o StrictHostKeyChecking=no bihannaroot@escore.al-hanna.com 'docker logs --tail 10 score_api_gateway_prod 2>&1 | grep "scores/categories"'
echo ""

echo "=========================================="
echo "Verification Complete"
echo "=========================================="
echo ""
echo "All three services should show '(healthy)' status"
echo "Database should show 5 predefined categories"
echo ""
echo "To test from browser:"
echo "1. Login to https://admin.escore.al-hanna.com"
echo "2. Navigate to Scoring Management tab"
echo "3. You should see the 5 Arabic categories"
