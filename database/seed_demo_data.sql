-- Demo Data Initialization Script
-- This script creates demo data for first-time setup
-- Can be deleted by super admin after login

BEGIN;

-- Create a flag table to track demo data
CREATE TABLE IF NOT EXISTS system_flags (
    key VARCHAR(100) PRIMARY KEY,
    value BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Check if demo data already exists
DO $$
DECLARE
    demo_exists BOOLEAN;
BEGIN
    -- Check if demo data flag exists
    SELECT value INTO demo_exists FROM system_flags WHERE key = 'demo_data_loaded';
    
    -- Only proceed if demo data hasn't been loaded
    IF demo_exists IS NULL OR demo_exists = false THEN
        
        -- Create demo organization
        INSERT INTO organizations (id, name, description, is_active, created_at, updated_at)
        VALUES 
            ('demo1111-1111-1111-1111-111111111111'::uuid, 'Demo Organization', 'This is a demo organization with sample data. You can delete this after exploring the platform.', true, NOW(), NOW())
        ON CONFLICT (id) DO NOTHING;

        -- Create demo admin user (Password: Demo@123)
        INSERT INTO users (id, username, email, password_hash, first_name, last_name, organization_id, role, is_active, created_at, updated_at)
        VALUES 
            ('demoadm1-1111-1111-1111-111111111111', 
             'demoadmin', 
             'demo.admin@example.com',
             'scrypt:32768:8:1$fDjLzQxsS8lMCvjI$5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8',
             'Demo', 
             'Admin', 
             'demo1111-1111-1111-1111-111111111111', 
             'ADMIN', 
             true,
             NOW(),
             NOW())
        ON CONFLICT (id) DO NOTHING;

        -- Create demo users
        INSERT INTO users (id, username, email, password_hash, first_name, last_name, organization_id, role, is_active, created_at, updated_at)
        VALUES 
            ('demouser-1111-1111-1111-111111111111', 
             'john.demo', 
             'john.demo@example.com',
             'scrypt:32768:8:1$fDjLzQxsS8lMCvjI$5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8',
             'John', 
             'Doe', 
             'demo1111-1111-1111-1111-111111111111', 
             'USER', 
             true,
             NOW(),
             NOW()),
            ('demouser-2222-2222-2222-222222222222', 
             'jane.demo', 
             'jane.demo@example.com',
             'scrypt:32768:8:1$fDjLzQxsS8lMCvjI$5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8',
             'Jane', 
             'Smith', 
             'demo1111-1111-1111-1111-111111111111', 
             'USER', 
             true,
             NOW(),
             NOW()),
            ('demouser-3333-3333-3333-333333333333', 
             'mike.demo', 
             'mike.demo@example.com',
             'scrypt:32768:8:1$fDjLzQxsS8lMCvjI$5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8',
             'Mike', 
             'Johnson', 
             'demo1111-1111-1111-1111-111111111111', 
             'USER', 
             true,
             NOW(),
             NOW())
        ON CONFLICT (id) DO NOTHING;

        -- Link users to organization
        INSERT INTO user_organizations (user_id, organization_id, role, joined_at)
        VALUES 
            ('demoadm1-1111-1111-1111-111111111111', 'demo1111-1111-1111-1111-111111111111', 'admin', NOW()),
            ('demouser-1111-1111-1111-111111111111', 'demo1111-1111-1111-1111-111111111111', 'user', NOW()),
            ('demouser-2222-2222-2222-222222222222', 'demo1111-1111-1111-1111-111111111111', 'user', NOW()),
            ('demouser-3333-3333-3333-333333333333', 'demo1111-1111-1111-1111-111111111111', 'user', NOW())
        ON CONFLICT (user_id, organization_id) DO NOTHING;

        -- Create predefined score categories (Arabic)
        INSERT INTO score_categories (id, organization_id, name, description, max_score, created_by, is_active, is_predefined, created_at, updated_at)
        VALUES 
            ('democat1-1111-1111-1111-111111111111', 'demo1111-1111-1111-1111-111111111111', 'القداس', 'حضور القداس الإلهي', 100, 'demoadm1-1111-1111-1111-111111111111', true, true, NOW(), NOW()),
            ('democat2-2222-2222-2222-222222222222', 'demo1111-1111-1111-1111-111111111111', 'التناول', 'تناول القربان المقدس', 100, 'demoadm1-1111-1111-1111-111111111111', true, true, NOW(), NOW()),
            ('democat3-3333-3333-3333-333333333333', 'demo1111-1111-1111-1111-111111111111', 'الاعتراف', 'سر الاعتراف', 100, 'demoadm1-1111-1111-1111-111111111111', true, true, NOW(), NOW()),
            ('democat4-4444-4444-4444-444444444444', 'demo1111-1111-1111-1111-111111111111', 'خدمة', 'الخدمة الكنسية', 100, 'demoadm1-1111-1111-1111-111111111111', true, true, NOW(), NOW()),
            ('democat5-5555-5555-5555-555555555555', 'demo1111-1111-1111-1111-111111111111', 'حفظ الكتاب المقدس', 'حفظ آيات من الكتاب المقدس', 100, 'demoadm1-1111-1111-1111-111111111111', true, true, NOW(), NOW())
        ON CONFLICT (id) DO NOTHING;

        -- Create demo group
        INSERT INTO groups (id, organization_id, name, description, created_by, created_at, updated_at)
        VALUES 
            ('demogrp1-1111-1111-1111-111111111111', 
             'demo1111-1111-1111-1111-111111111111', 
             'Youth Group', 
             'Demo youth group for young members',
             'demoadm1-1111-1111-1111-111111111111',
             NOW(), 
             NOW())
        ON CONFLICT (id) DO NOTHING;

        -- Add members to demo group
        INSERT INTO group_members (group_id, user_id, joined_at)
        VALUES 
            ('demogrp1-1111-1111-1111-111111111111', 'demouser-1111-1111-1111-111111111111', NOW()),
            ('demogrp1-1111-1111-1111-111111111111', 'demouser-2222-2222-2222-222222222222', NOW())
        ON CONFLICT (group_id, user_id) DO NOTHING;

        -- Add sample scores with varied dates
        INSERT INTO scores (id, user_id, organization_id, category_id, points, description, awarded_by, awarded_at, created_at)
        VALUES 
            -- John's scores
            (replace(gen_random_uuid()::varchar, '-', ''), 'demouser-1111-1111-1111-111111111111', 'demo1111-1111-1111-1111-111111111111', 'democat1-1111-1111-1111-111111111111', 10, 'حضور قداس الأحد', 'demoadm1-1111-1111-1111-111111111111', NOW() - INTERVAL '7 days', NOW() - INTERVAL '7 days'),
            (replace(gen_random_uuid()::varchar, '-', ''), 'demouser-1111-1111-1111-111111111111', 'demo1111-1111-1111-1111-111111111111', 'democat2-2222-2222-2222-222222222222', 10, 'تناول', 'demoadm1-1111-1111-1111-111111111111', NOW() - INTERVAL '7 days', NOW() - INTERVAL '7 days'),
            (replace(gen_random_uuid()::varchar, '-', ''), 'demouser-1111-1111-1111-111111111111', 'demo1111-1111-1111-1111-111111111111', 'democat1-1111-1111-1111-111111111111', 10, 'حضور قداس الأحد', 'demoadm1-1111-1111-1111-111111111111', NOW() - INTERVAL '3 days', NOW() - INTERVAL '3 days'),
            (replace(gen_random_uuid()::varchar, '-', ''), 'demouser-1111-1111-1111-111111111111', 'demo1111-1111-1111-1111-111111111111', 'democat4-4444-4444-4444-444444444444', 15, 'خدمة الأطفال', 'demoadm1-1111-1111-1111-111111111111', NOW() - INTERVAL '2 days', NOW() - INTERVAL '2 days'),
            (replace(gen_random_uuid()::varchar, '-', ''), 'demouser-1111-1111-1111-111111111111', 'demo1111-1111-1111-1111-111111111111', 'democat5-5555-5555-5555-555555555555', 20, 'حفظ مزمور 23', 'demoadm1-1111-1111-1111-111111111111', NOW() - INTERVAL '1 day', NOW() - INTERVAL '1 day'),
            
            -- Jane's scores
            (replace(gen_random_uuid()::varchar, '-', ''), 'demouser-2222-2222-2222-222222222222', 'demo1111-1111-1111-1111-111111111111', 'democat1-1111-1111-1111-111111111111', 10, 'حضور قداس الأحد', 'demoadm1-1111-1111-1111-111111111111', NOW() - INTERVAL '7 days', NOW() - INTERVAL '7 days'),
            (replace(gen_random_uuid()::varchar, '-', ''), 'demouser-2222-2222-2222-222222222222', 'demo1111-1111-1111-1111-111111111111', 'democat2-2222-2222-2222-222222222222', 10, 'تناول', 'demoadm1-1111-1111-1111-111111111111', NOW() - INTERVAL '7 days', NOW() - INTERVAL '7 days'),
            (replace(gen_random_uuid()::varchar, '-', ''), 'demouser-2222-2222-2222-222222222222', 'demo1111-1111-1111-1111-111111111111', 'democat3-3333-3333-3333-333333333333', 15, 'اعتراف شهري', 'demoadm1-1111-1111-1111-111111111111', NOW() - INTERVAL '5 days', NOW() - INTERVAL '5 days'),
            (replace(gen_random_uuid()::varchar, '-', ''), 'demouser-2222-2222-2222-222222222222', 'demo1111-1111-1111-1111-111111111111', 'democat1-1111-1111-1111-111111111111', 10, 'حضور قداس الأحد', 'demoadm1-1111-1111-1111-111111111111', NOW() - INTERVAL '3 days', NOW() - INTERVAL '3 days'),
            (replace(gen_random_uuid()::varchar, '-', ''), 'demouser-2222-2222-2222-222222222222', 'demo1111-1111-1111-1111-111111111111', 'democat4-4444-4444-4444-444444444444', 20, 'ترتيل في الكورال', 'demoadm1-1111-1111-1111-111111111111', NOW() - INTERVAL '1 day', NOW() - INTERVAL '1 day'),
            
            -- Mike's scores
            (replace(gen_random_uuid()::varchar, '-', ''), 'demouser-3333-3333-3333-333333333333', 'demo1111-1111-1111-1111-111111111111', 'democat1-1111-1111-1111-111111111111', 10, 'حضور قداس الأحد', 'demoadm1-1111-1111-1111-111111111111', NOW() - INTERVAL '7 days', NOW() - INTERVAL '7 days'),
            (replace(gen_random_uuid()::varchar, '-', ''), 'demouser-3333-3333-3333-333333333333', 'demo1111-1111-1111-1111-111111111111', 'democat2-2222-2222-2222-222222222222', 10, 'تناول', 'demoadm1-1111-1111-1111-111111111111', NOW() - INTERVAL '7 days', NOW() - INTERVAL '7 days'),
            (replace(gen_random_uuid()::varchar, '-', ''), 'demouser-3333-3333-3333-333333333333', 'demo1111-1111-1111-1111-111111111111', 'democat5-5555-5555-5555-555555555555', 25, 'حفظ مزمور 91', 'demoadm1-1111-1111-1111-111111111111', NOW() - INTERVAL '4 days', NOW() - INTERVAL '4 days'),
            (replace(gen_random_uuid()::varchar, '-', ''), 'demouser-3333-3333-3333-333333333333', 'demo1111-1111-1111-1111-111111111111', 'democat1-1111-1111-1111-111111111111', 10, 'حضور قداس الأحد', 'demoadm1-1111-1111-1111-111111111111', NOW() - INTERVAL '3 days', NOW() - INTERVAL '3 days')
        ON CONFLICT (id) DO NOTHING;

        -- Set the demo data flag
        INSERT INTO system_flags (key, value, created_at, updated_at)
        VALUES ('demo_data_loaded', true, NOW(), NOW())
        ON CONFLICT (key) DO UPDATE SET value = true, updated_at = NOW();

        RAISE NOTICE 'Demo data has been successfully created!';
    ELSE
        RAISE NOTICE 'Demo data already exists. Skipping...';
    END IF;
END $$;

COMMIT;

-- Display summary
SELECT '========================================' as info
UNION ALL SELECT 'DEMO DATA CREATED SUCCESSFULLY!'
UNION ALL SELECT '========================================'
UNION ALL SELECT ''
UNION ALL SELECT 'Demo Organization: Demo Organization'
UNION ALL SELECT 'Demo Admin: demoadmin / Demo@123'
UNION ALL SELECT 'Demo Users: john.demo, jane.demo, mike.demo / Demo@123'
UNION ALL SELECT ''
UNION ALL SELECT 'Predefined Categories:'
UNION ALL SELECT '  - القداس (Mass)'
UNION ALL SELECT '  - التناول (Communion)'
UNION ALL SELECT '  - الاعتراف (Confession)'
UNION ALL SELECT '  - خدمة (Service)'
UNION ALL SELECT '  - حفظ الكتاب المقدس (Scripture Memorization)'
UNION ALL SELECT ''
UNION ALL SELECT 'Access: http://score.al-hanna.com'
UNION ALL SELECT 'Super Admin can delete demo data after login'
UNION ALL SELECT '========================================';
