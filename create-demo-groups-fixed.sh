#!/bin/bash

echo "Creating demo groups for organization: شباب ٢٠٢٦"

ssh bihannaroot@escore.al-hanna.com 'docker exec score_postgres_prod psql -U postgres -d saas_platform' <<'EOF'
-- Get organization ID
DO $$
DECLARE
    org_id UUID;
BEGIN
    SELECT id INTO org_id FROM organizations WHERE name='شباب ٢٠٢٦' LIMIT 1;
    
    -- Group 1: Youth Group
    INSERT INTO groups (id, organization_id, name, description, is_active, created_at, updated_at)
    VALUES (
        gen_random_uuid(),
        org_id,
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
        org_id,
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
        org_id,
        'فريق التسبيح',
        'فريق التسبيح والموسيقى',
        true,
        NOW(),
        NOW()
    );
    
    RAISE NOTICE 'Created 3 demo groups for organization %', org_id;
END $$;

-- Show results
SELECT 
    id, 
    name, 
    description,
    created_at
FROM groups 
WHERE organization_id = (SELECT id FROM organizations WHERE name='شباب ٢٠٢٦')
ORDER BY created_at DESC;

SELECT COUNT(*) as total_groups FROM groups WHERE organization_id = (SELECT id FROM organizations WHERE name='شباب ٢٠٢٦');
EOF

echo ""
echo "✅ Demo groups created successfully!"
