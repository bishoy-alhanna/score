#!/bin/bash

echo "Creating demo data for Score system..."

# Get organization ID
ORG_ID=$(ssh bihannaroot@escore.al-hanna.com 'docker exec score_postgres_prod psql -U postgres -d saas_platform -t -c "SELECT id FROM organizations WHERE name='\''شباب ٢٠٢٦'\'' LIMIT 1;"' | tr -d ' ')

echo "Organization ID: $ORG_ID"

# Get admin user ID
ADMIN_ID=$(ssh bihannaroot@escore.al-hanna.com 'docker exec score_postgres_prod psql -U postgres -d saas_platform -t -c "SELECT user_id FROM user_organizations WHERE organization_id='\''$ORG_ID'\'' AND role='\''ORG_ADMIN'\'' LIMIT 1;"' | tr -d ' ')

echo "Admin ID: $ADMIN_ID"

# Create 3 demo groups
echo ""
echo "Creating demo groups..."
ssh bihannaroot@escore.al-hanna.com 'docker exec score_postgres_prod psql -U postgres -d saas_platform' <<EOF
-- Group 1: Youth Group
INSERT INTO groups (id, organization_id, name, description, is_active, created_at, updated_at)
VALUES (
    gen_random_uuid(),
    '$ORG_ID',
    'مجموعة الشباب',
    'مجموعة الشباب الرئيسية',
    true,
    NOW(),
    NOW()
);

-- Group 2: Service Team
INSERT INTO groups (id, organization_id, name, description, is_active, created_at, updated_at)
VALUES (
    gen_random_uuid(),
    '$ORG_ID',
    'فريق الخدمة',
    'فريق خدمة الكنيسة',
    true,
    NOW(),
    NOW()
);

-- Group 3: Worship Team  
INSERT INTO groups (id, organization_id, name, description, is_active, created_at, updated_at)
VALUES (
    gen_random_uuid(),
    '$ORG_ID',
    'فريق التسبيح',
    'فريق التسبيح والموسيقى',
    true,
    NOW(),
    NOW()
);

SELECT COUNT(*) as group_count FROM groups WHERE organization_id='$ORG_ID';
EOF

echo ""
echo "Demo data created successfully!"
echo ""
echo "Summary:"
ssh bihannaroot@escore.al-hanna.com 'docker exec score_postgres_prod psql -U postgres -d saas_platform -c "SELECT COUNT(*) as total_groups FROM groups WHERE organization_id='\''$ORG_ID'\'';"'
ssh bihannaroot@escore.al-hanna.com 'docker exec score_postgres_prod psql -U postgres -d saas_platform -c "SELECT id, name, description FROM groups WHERE organization_id='\''$ORG_ID'\'';"'

echo ""
echo "✅ Demo groups created! Users can now:"
echo "   1. Join groups"
echo "   2. Submit scores for activities"
echo "   3. View leaderboards"
