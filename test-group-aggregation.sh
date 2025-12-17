#!/bin/bash

# Script to test the group member score aggregation feature

echo "=========================================="
echo "Testing Group Member Score Aggregation"
echo "=========================================="
echo ""

GROUP_ID="7d800f80-95f3-4398-8c4a-ec410f095447"

echo "1. Checking current member scores..."
docker exec -it score_postgres_prod psql -U postgres -d saas_platform -c "
SELECT 
    u.username,
    COUNT(*) as score_entries,
    SUM(s.score_value) as total_score
FROM scores s
JOIN users u ON s.user_id = u.id
WHERE s.user_id IN (
    SELECT user_id FROM group_members 
    WHERE group_id = '$GROUP_ID'
)
GROUP BY u.username
ORDER BY total_score DESC;
"

echo ""
echo "2. Total across ALL members and ALL categories..."
docker exec -it score_postgres_prod psql -U postgres -d saas_platform -c "
SELECT 
    COUNT(DISTINCT s.user_id) as members_with_scores,
    SUM(s.score_value) as total_member_scores
FROM scores s
WHERE s.user_id IN (
    SELECT user_id FROM group_members 
    WHERE group_id = '$GROUP_ID'
);
"

echo ""
echo "3. Checking group manual score..."
docker exec -it score_postgres_prod psql -U postgres -d saas_platform -c "
SELECT name, manual_score FROM groups WHERE id = '$GROUP_ID';
"

echo ""
echo "4. Checking current group aggregate..."
docker exec -it score_postgres_prod psql -U postgres -d saas_platform -c "
SELECT 
    category,
    total_score,
    score_count,
    last_updated
FROM score_aggregates 
WHERE group_id = '$GROUP_ID'
ORDER BY category;
"

echo ""
echo "5. To test the feature:"
echo "   - Go to admin dashboard"
echo "   - Assign a score to any member of 'فريق الخدمة'"
echo "   - Run this script again to see the group aggregate update!"
echo ""
echo "   Or use the API:"
echo "   curl -X POST http://localhost/api/scores \\"
echo "     -H 'Authorization: Bearer YOUR_TOKEN' \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"user_id\": \"fd0444af-6d38-469f-8355-cb87f441eafa\", \"score_value\": 10, \"category\": \"general\"}'"
echo ""
