#!/bin/bash

echo "Creating 3 demo groups for organization: شباب ٢٠٢٦"

ssh bihannaroot@escore.al-hanna.com 'docker exec score_postgres_prod psql -U postgres -d saas_platform' <<'EOF'
DO $$
DECLARE
    org_id UUID;
    creator_id UUID;
BEGIN
    -- Get organization ID
    SELECT id INTO org_id FROM organizations WHERE name='شباب ٢٠٢٦' LIMIT 1;
    
    -- Get a user from this organization to use as creator
    SELECT user_id INTO creator_id 
    FROM user_organizations 
    WHERE organization_id = org_id 
    LIMIT 1;
    
    -- Group 1: Youth Group
    INSERT INTO groups (id, organization_id, name, description, created_by, is_active, created_at, updated_at)
    VALUES (
        gen_random_uuid(),
        org_id,
        'مجموعة الشباب',
        'مجموعة الشباب الرئيسية',
        creator_id,
        true,
        NOW(),
        NOW()
    );
    
    -- Group 2: Service Team
    INSERT INTO groups (id, organization_id, name, description, created_by, is_active, created_at, updated_at)
    VALUES (
        gen_random_uuid(),
        org_id,
        'فريق الخدمة',
        'فريق خدمة الكنيسة',
        creator_id,
        true,
        NOW(),
        NOW()
    );
    
    -- Group 3: Worship Team  
    INSERT INTO groups (id, organization_id, name, description, created_by, is_active, created_at, updated_at)
    VALUES (
        gen_random_uuid(),
        org_id,
        'فريق التسبيح',
        'فريق التسبيح والموسيقى',
        creator_id,
        true,
        NOW(),
        NOW()
    );
    
    RAISE NOTICE 'Created 3 demo groups for organization % by user %', org_id, creator_id;
END $$;

-- Show results
SELECT 
    name, 
    description,
    (SELECT username FROM users WHERE id = created_by) as created_by_username,
    created_at
FROM groups 
WHERE organization_id = (SELECT id FROM organizations WHERE name='شباب ٢٠٢٦')
ORDER BY created_at DESC;

SELECT COUNT(*) as total_groups FROM groups;
EOF

echo ""
echo "✅ Demo groups created successfully!"
echo "   Users can now test the groups feature."
