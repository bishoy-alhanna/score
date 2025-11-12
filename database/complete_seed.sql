-- Complete Seed Script with Organizations, Users, and Predefined Categories
-- Run this after database cleanup to populate with test data

BEGIN;

-- Create test organizations
INSERT INTO organizations (id, name, description, is_active, created_at, updated_at)
VALUES 
    ('11111111-1111-1111-1111-111111111111', 'Test Organization', 'Test organization for development', true, NOW(), NOW()),
    ('22222222-2222-2222-2222-222222222222', 'Demo Church', 'Demo church organization', true, NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

-- Create admin users for each organization
-- Note: Password hash is for "Admin@123" - you should change this
INSERT INTO users (id, username, email, password_hash, first_name, last_name, organization_id, role, is_active, created_at, updated_at)
VALUES 
    -- Admin for Test Organization
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 
     'testadmin', 
     'admin@testorg.com',
     'scrypt:32768:8:1$fDjLzQxsS8lMCvjI$5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8',
     'Test', 
     'Admin', 
     '11111111-1111-1111-1111-111111111111', 
     'ADMIN', 
     true,
     NOW(),
     NOW()),
    
    -- Admin for Demo Church
    ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 
     'churchadmin', 
     'admin@demochurch.com',
     'scrypt:32768:8:1$fDjLzQxsS8lMCvjI$5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8',
     'Church', 
     'Admin', 
     '22222222-2222-2222-2222-222222222222', 
     'ADMIN', 
     true,
     NOW(),
     NOW()),
    
    -- Regular user for Test Organization
    ('cccccccc-cccc-cccc-cccc-cccccccccccc', 
     'john', 
     'john@testorg.com',
     'scrypt:32768:8:1$fDjLzQxsS8lMCvjI$5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8',
     'John', 
     'Doe', 
     '11111111-1111-1111-1111-111111111111', 
     'USER', 
     true,
     NOW(),
     NOW()),
    
    -- Regular user for Demo Church
    ('dddddddd-dddd-dddd-dddd-dddddddddddd', 
     'mary', 
     'mary@demochurch.com',
     'scrypt:32768:8:1$fDjLzQxsS8lMCvjI$5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8',
     'Mary', 
     'Smith', 
     '22222222-2222-2222-2222-222222222222', 
     'USER', 
     true,
     NOW(),
     NOW())
ON CONFLICT (id) DO NOTHING;

-- Link users to organizations
INSERT INTO user_organizations (user_id, organization_id, role, joined_at)
VALUES 
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'admin', NOW()),
    ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '22222222-2222-2222-2222-222222222222', 'admin', NOW()),
    ('cccccccc-cccc-cccc-cccc-cccccccccccc', '11111111-1111-1111-1111-111111111111', 'user', NOW()),
    ('dddddddd-dddd-dddd-dddd-dddddddddddd', '22222222-2222-2222-2222-222222222222', 'user', NOW())
ON CONFLICT (user_id, organization_id) DO NOTHING;

-- Create predefined score categories for Test Organization
INSERT INTO score_categories (id, organization_id, name, description, max_score, created_by, is_active, is_predefined, created_at, updated_at)
VALUES 
    -- Arabic Categories (Predefined)
    ('cat11111-1111-1111-1111-111111111111', '11111111-1111-1111-1111-111111111111', 'القداس', 'حضور القداس', 100, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true, true, NOW(), NOW()),
    ('cat11111-1111-1111-1111-111111111112', '11111111-1111-1111-1111-111111111111', 'التناول', 'تناول القربان المقدس', 100, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true, true, NOW(), NOW()),
    ('cat11111-1111-1111-1111-111111111113', '11111111-1111-1111-1111-111111111111', 'الاعتراف', 'سر الاعتراف', 100, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true, true, NOW(), NOW()),
    
    -- English Categories (for reference)
    ('cat11111-1111-1111-1111-111111111114', '11111111-1111-1111-1111-111111111111', 'Mass Attendance', 'Attending church mass', 100, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true, true, NOW(), NOW()),
    ('cat11111-1111-1111-1111-111111111115', '11111111-1111-1111-1111-111111111111', 'Communion', 'Holy communion participation', 100, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true, true, NOW(), NOW()),
    ('cat11111-1111-1111-1111-111111111116', '11111111-1111-1111-1111-111111111111', 'Confession', 'Sacrament of confession', 100, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true, true, NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

-- Create predefined score categories for Demo Church
INSERT INTO score_categories (id, organization_id, name, description, max_score, created_by, is_active, is_predefined, created_at, updated_at)
VALUES 
    -- Arabic Categories (Predefined)
    ('cat22222-2222-2222-2222-222222222221', '22222222-2222-2222-2222-222222222222', 'القداس', 'حضور القداس', 100, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', true, true, NOW(), NOW()),
    ('cat22222-2222-2222-2222-222222222222', '22222222-2222-2222-2222-222222222222', 'التناول', 'تناول القربان المقدس', 100, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', true, true, NOW(), NOW()),
    ('cat22222-2222-2222-2222-222222222223', '22222222-2222-2222-2222-222222222222', 'الاعتراف', 'سر الاعتراف', 100, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', true, true, NOW(), NOW()),
    
    -- English Categories
    ('cat22222-2222-2222-2222-222222222224', '22222222-2222-2222-2222-222222222222', 'Mass Attendance', 'Attending church mass', 100, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', true, true, NOW(), NOW()),
    ('cat22222-2222-2222-2222-222222222225', '22222222-2222-2222-2222-222222222222', 'Communion', 'Holy communion participation', 100, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', true, true, NOW(), NOW()),
    ('cat22222-2222-2222-2222-222222222226', '22222222-2222-2222-2222-222222222222', 'Confession', 'Sacrament of confession', 100, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', true, true, NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

-- Add some sample scores for Test Organization
INSERT INTO scores (id, user_id, organization_id, category_id, points, description, awarded_by, awarded_at, created_at)
VALUES 
    (replace(gen_random_uuid()::varchar, '-', ''), 'cccccccc-cccc-cccc-cccc-cccccccccccc', '11111111-1111-1111-1111-111111111111', 'cat11111-1111-1111-1111-111111111111', 10, 'حضور قداس الاحد', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', NOW() - INTERVAL '1 day', NOW() - INTERVAL '1 day'),
    (replace(gen_random_uuid()::varchar, '-', ''), 'cccccccc-cccc-cccc-cccc-cccccccccccc', '11111111-1111-1111-1111-111111111111', 'cat11111-1111-1111-1111-111111111112', 10, 'تناول', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', NOW() - INTERVAL '1 day', NOW() - INTERVAL '1 day'),
    (replace(gen_random_uuid()::varchar, '-', ''), 'cccccccc-cccc-cccc-cccc-cccccccccccc', '11111111-1111-1111-1111-111111111111', 'cat11111-1111-1111-1111-111111111113', 15, 'اعتراف شهري', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', NOW() - INTERVAL '3 days', NOW() - INTERVAL '3 days')
ON CONFLICT (id) DO NOTHING;

-- Add sample scores for Demo Church
INSERT INTO scores (id, user_id, organization_id, category_id, points, description, awarded_by, awarded_at, created_at)
VALUES 
    (replace(gen_random_uuid()::varchar, '-', ''), 'dddddddd-dddd-dddd-dddd-dddddddddddd', '22222222-2222-2222-2222-222222222222', 'cat22222-2222-2222-2222-222222222221', 10, 'Sunday mass attendance', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', NOW(), NOW()),
    (replace(gen_random_uuid()::varchar, '-', ''), 'dddddddd-dddd-dddd-dddd-dddddddddddd', '22222222-2222-2222-2222-222222222222', 'cat22222-2222-2222-2222-222222222222', 10, 'Holy communion', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

COMMIT;

-- Display summary
SELECT '========================================' as line
UNION ALL SELECT 'SEED DATA LOADED SUCCESSFULLY!'
UNION ALL SELECT '========================================';

SELECT 'Organizations: ' || COUNT(*) as summary FROM organizations;
SELECT 'Users: ' || COUNT(*) as summary FROM users;
SELECT 'Score Categories: ' || COUNT(*) as summary FROM score_categories;
SELECT 'Predefined Categories: ' || COUNT(*) as summary FROM score_categories WHERE is_predefined = true;
SELECT 'Scores: ' || COUNT(*) as summary FROM scores;

SELECT '
========================================
TEST ACCOUNTS
========================================

Organization 1: Test Organization
  Admin Account:
    Username: testadmin
    Password: Admin@123
    Email: admin@testorg.com
  
  User Account:
    Username: john
    Password: Admin@123
    Email: john@testorg.com

Organization 2: Demo Church
  Admin Account:
    Username: churchadmin
    Password: Admin@123
    Email: admin@demochurch.com
  
  User Account:
    Username: mary
    Password: Admin@123
    Email: mary@demochurch.com

Predefined Categories Created:
  - القداس (Mass Attendance)
  - التناول (Communion)
  - الاعتراف (Confession)

Access URLs:
  - Main Site: http://score.al-hanna.com
  - Admin: http://admin.score.al-hanna.com
  - Super Admin: Username: superadmin, Password: SuperBishoy@123!

========================================
' as info;
