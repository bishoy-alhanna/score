#!/bin/bash

# Create Predefined Categories for Existing Organizations

echo "=========================================="
echo "Creating Predefined Score Categories"
echo "=========================================="
echo ""

ssh -o StrictHostKeyChecking=no bihannaroot@escore.al-hanna.com 'docker exec -i score_postgres_prod psql -U postgres -d saas_platform' << 'EOSQL'

-- Create predefined categories for all organizations
DO $$ 
DECLARE
    org_record RECORD;
    admin_id UUID;
    cat_exists BOOLEAN;
BEGIN
    -- Loop through all organizations
    FOR org_record IN SELECT id, name FROM organizations WHERE is_active = TRUE
    LOOP
        RAISE NOTICE 'Processing organization: % (ID: %)', org_record.name, org_record.id;
        
        -- Get an admin user for this organization (or any user)
        SELECT u.id INTO admin_id
        FROM users u
        JOIN user_organizations uo ON u.id = uo.user_id
        WHERE uo.organization_id = org_record.id
          AND uo.is_active = TRUE
        LIMIT 1;
        
        IF admin_id IS NULL THEN
            RAISE NOTICE 'No admin found for organization %, skipping', org_record.name;
            CONTINUE;
        END IF;
        
        -- Create القداس (Mass Attendance)
        SELECT EXISTS(SELECT 1 FROM score_categories WHERE name = 'القداس' AND organization_id = org_record.id) INTO cat_exists;
        IF NOT cat_exists THEN
            INSERT INTO score_categories (organization_id, name, description, max_score, created_by, is_predefined, is_active)
            VALUES (org_record.id, 'القداس', 'حضور القداس الإلهي', 100, admin_id, TRUE, TRUE);
            RAISE NOTICE '  ✓ Created: القداس';
        END IF;
        
        -- Create التناول (Holy Communion)
        SELECT EXISTS(SELECT 1 FROM score_categories WHERE name = 'التناول' AND organization_id = org_record.id) INTO cat_exists;
        IF NOT cat_exists THEN
            INSERT INTO score_categories (organization_id, name, description, max_score, created_by, is_predefined, is_active)
            VALUES (org_record.id, 'التناول', 'تناول القربان المقدس', 100, admin_id, TRUE, TRUE);
            RAISE NOTICE '  ✓ Created: التناول';
        END IF;
        
        -- Create الاعتراف (Confession)
        SELECT EXISTS(SELECT 1 FROM score_categories WHERE name = 'الاعتراف' AND organization_id = org_record.id) INTO cat_exists;
        IF NOT cat_exists THEN
            INSERT INTO score_categories (organization_id, name, description, max_score, created_by, is_predefined, is_active)
            VALUES (org_record.id, 'الاعتراف', 'سر الاعتراف', 100, admin_id, TRUE, TRUE);
            RAISE NOTICE '  ✓ Created: الاعتراف';
        END IF;
        
        -- Create الخدمة (Service)
        SELECT EXISTS(SELECT 1 FROM score_categories WHERE name = 'الخدمة' AND organization_id = org_record.id) INTO cat_exists;
        IF NOT cat_exists THEN
            INSERT INTO score_categories (organization_id, name, description, max_score, created_by, is_predefined, is_active)
            VALUES (org_record.id, 'الخدمة', 'الخدمة الكنسية', 100, admin_id, TRUE, TRUE);
            RAISE NOTICE '  ✓ Created: الخدمة';
        END IF;
        
        -- Create حفظ الكتاب (Scripture Memorization)
        SELECT EXISTS(SELECT 1 FROM score_categories WHERE name = 'حفظ الكتاب' AND organization_id = org_record.id) INTO cat_exists;
        IF NOT cat_exists THEN
            INSERT INTO score_categories (organization_id, name, description, max_score, created_by, is_predefined, is_active)
            VALUES (org_record.id, 'حفظ الكتاب', 'حفظ آيات من الكتاب المقدس', 100, admin_id, TRUE, TRUE);
            RAISE NOTICE '  ✓ Created: حفظ الكتاب';
        END IF;
        
    END LOOP;
END $$;

-- Show summary
\echo ''
\echo '=========================================='
\echo 'Summary of Created Categories'
\echo '=========================================='

SELECT 
    o.name as organization,
    COUNT(*) as total_categories,
    SUM(CASE WHEN sc.is_predefined THEN 1 ELSE 0 END) as predefined_categories
FROM score_categories sc
JOIN organizations o ON sc.organization_id = o.id
GROUP BY o.name;

\echo ''
\echo 'Predefined Categories by Organization:'
SELECT 
    o.name as organization,
    sc.name as category_name,
    sc.description
FROM score_categories sc
JOIN organizations o ON sc.organization_id = o.id
WHERE sc.is_predefined = TRUE
ORDER BY o.name, sc.name;

EOSQL

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Predefined categories created successfully"
else
    echo ""
    echo "❌ Failed to create predefined categories"
    exit 1
fi
