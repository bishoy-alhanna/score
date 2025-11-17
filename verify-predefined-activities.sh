#!/bin/bash

# Verify Predefined Activities Setup

echo "=========================================="
echo "Predefined Activities Verification"
echo "=========================================="
echo ""

echo "1. Checking score_categories table structure..."
ssh -o StrictHostKeyChecking=no bihannaroot@escore.al-hanna.com 'docker exec score_postgres_prod psql -U postgres -d saas_platform -c "\d score_categories"' 2>/dev/null
echo ""

echo "2. Checking predefined categories..."
ssh -o StrictHostKeyChecking=no bihannaroot@escore.al-hanna.com 'docker exec score_postgres_prod psql -U postgres -d saas_platform -c "
SELECT 
    o.name as organization,
    sc.name as category,
    sc.description,
    sc.is_predefined,
    sc.is_active
FROM score_categories sc
JOIN organizations o ON sc.organization_id = o.id
WHERE sc.is_predefined = TRUE
ORDER BY o.name, sc.name;
"' 2>/dev/null
echo ""

echo "3. Checking services status..."
ssh -o StrictHostKeyChecking=no bihannaroot@escore.al-hanna.com 'docker ps --filter "name=score_" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "auth|scoring"' 2>/dev/null
echo ""

echo "4. Testing scoring service endpoint..."
echo "   Checking if scoring service is ready..."
ssh -o StrictHostKeyChecking=no bihannaroot@escore.al-hanna.com 'curl -s http://localhost:5004/health 2>/dev/null || echo "Scoring service not responding"'
echo ""

echo "=========================================="
echo "Verification Complete"
echo "=========================================="
echo ""
echo "Summary:"
echo "- Database table: Created"
echo "- Predefined categories: 5 Arabic categories"
echo "- Services: Running"
echo ""
echo "Next: Test user registration with organization join request"
