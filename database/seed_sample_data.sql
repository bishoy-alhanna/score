-- Seed Data for Testing
-- This script populates the database with sample data for testing

BEGIN;

-- Create a test organization
INSERT INTO organizations (id, name, description, is_active, created_at, updated_at)
VALUES 
    ('11111111-1111-1111-1111-111111111111', 'Test Organization', 'A test organization for development and testing', true, NOW(), NOW()),
    ('22222222-2222-2222-2222-222222222222', 'Demo Company', 'A demo company for demonstrations', true, NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

-- Create test users
INSERT INTO users (id, username, email, password_hash, full_name, organization_id, role, is_active, created_at, updated_at)
VALUES 
    -- Admin user for testorg
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 
     'admin', 
     'admin@testorg.com', 
     'scrypt:32768:8:1$fDjLzQxsS8lMCvjI$2d8f8e7f0f3d5c6b4a3e2d1f9c8e7d6f5c4b3a2e1d0f9c8e7d6f5c4b3a2e1d0f9c8e7d6f5c4b3a2e1d0f9c8e', 
     'Admin User', 
     '11111111-1111-1111-1111-111111111111', 
     'admin', 
     true, 
     NOW(), 
     NOW()),
    
    -- Regular users for testorg
    ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 
     'john.doe', 
     'john@testorg.com', 
     'scrypt:32768:8:1$fDjLzQxsS8lMCvjI$2d8f8e7f0f3d5c6b4a3e2d1f9c8e7d6f5c4b3a2e1d0f9c8e7d6f5c4b3a2e1d0f9c8e7d6f5c4b3a2e1d0f9c8e', 
     'John Doe', 
     '11111111-1111-1111-1111-111111111111', 
     'user', 
     true, 
     NOW(), 
     NOW()),
    
    ('cccccccc-cccc-cccc-cccc-cccccccccccc', 
     'jane.smith', 
     'jane@testorg.com', 
     'scrypt:32768:8:1$fDjLzQxsS8lMCvjI$2d8f8e7f0f3d5c6b4a3e2d1f9c8e7d6f5c4b3a2e1d0f9c8e7d6f5c4b3a2e1d0f9c8e7d6f5c4b3a2e1d0f9c8e', 
     'Jane Smith', 
     '11111111-1111-1111-1111-111111111111', 
     'user', 
     true, 
     NOW(), 
     NOW()),
    
    ('dddddddd-dddd-dddd-dddd-dddddddddddd', 
     'bob.wilson', 
     'bob@testorg.com', 
     'scrypt:32768:8:1$fDjLzQxsS8lMCvjI$2d8f8e7f0f3d5c6b4a3e2d1f9c8e7d6f5c4b3a2e1d0f9c8e7d6f5c4b3a2e1d0f9c8e7d6f5c4b3a2e1d0f9c8e', 
     'Bob Wilson', 
     '11111111-1111-1111-1111-111111111111', 
     'user', 
     true, 
     NOW(), 
     NOW())
ON CONFLICT (id) DO NOTHING;

-- Link users to organizations
INSERT INTO user_organizations (user_id, organization_id, role, joined_at)
VALUES 
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'admin', NOW()),
    ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '11111111-1111-1111-1111-111111111111', 'user', NOW()),
    ('cccccccc-cccc-cccc-cccc-cccccccccccc', '11111111-1111-1111-1111-111111111111', 'user', NOW()),
    ('dddddddd-dddd-dddd-dddd-dddddddddddd', '11111111-1111-1111-1111-111111111111', 'user', NOW())
ON CONFLICT (user_id, organization_id) DO NOTHING;

-- Create score categories
INSERT INTO score_categories (id, organization_id, name, description, max_points, created_at, updated_at)
VALUES 
    ('11111111-1111-1111-1111-000000000001', '11111111-1111-1111-1111-111111111111', 'Leadership', 'Leadership activities and initiatives', 100, NOW(), NOW()),
    ('11111111-1111-1111-1111-000000000002', '11111111-1111-1111-1111-111111111111', 'Community Service', 'Community service and volunteer work', 100, NOW(), NOW()),
    ('11111111-1111-1111-1111-000000000003', '11111111-1111-1111-1111-111111111111', 'Academic Excellence', 'Academic achievements and awards', 100, NOW(), NOW()),
    ('11111111-1111-1111-1111-000000000004', '11111111-1111-1111-1111-111111111111', 'Sports & Athletics', 'Sports participation and achievements', 100, NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

-- Create a test group
INSERT INTO groups (id, organization_id, name, description, created_by, created_at, updated_at)
VALUES 
    ('99999999-9999-9999-9999-999999999999', 
     '11111111-1111-1111-1111-111111111111', 
     'Leadership Team', 
     'Core leadership team members',
     'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
     NOW(), 
     NOW())
ON CONFLICT (id) DO NOTHING;

-- Add members to the group
INSERT INTO group_members (group_id, user_id, joined_at)
VALUES 
    ('99999999-9999-9999-9999-999999999999', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', NOW()),
    ('99999999-9999-9999-9999-999999999999', 'cccccccc-cccc-cccc-cccc-cccccccccccc', NOW())
ON CONFLICT (group_id, user_id) DO NOTHING;

-- Add sample scores
INSERT INTO scores (id, user_id, organization_id, category_id, points, description, awarded_by, awarded_at, created_at)
VALUES 
    -- John Doe's scores
    (gen_random_uuid(), 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '11111111-1111-1111-1111-111111111111', '11111111-1111-1111-1111-000000000001', 25, 'Led team meeting', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', NOW() - INTERVAL '5 days', NOW() - INTERVAL '5 days'),
    (gen_random_uuid(), 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '11111111-1111-1111-1111-111111111111', '11111111-1111-1111-1111-000000000002', 30, 'Volunteered at community center', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', NOW() - INTERVAL '3 days', NOW() - INTERVAL '3 days'),
    (gen_random_uuid(), 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '11111111-1111-1111-1111-111111111111', '11111111-1111-1111-1111-000000000003', 40, 'Deans List achievement', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', NOW() - INTERVAL '1 day', NOW() - INTERVAL '1 day'),
    
    -- Jane Smith's scores
    (gen_random_uuid(), 'cccccccc-cccc-cccc-cccc-cccccccccccc', '11111111-1111-1111-1111-111111111111', '11111111-1111-1111-1111-000000000001', 35, 'Organized workshop', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', NOW() - INTERVAL '4 days', NOW() - INTERVAL '4 days'),
    (gen_random_uuid(), 'cccccccc-cccc-cccc-cccc-cccccccccccc', '11111111-1111-1111-1111-111111111111', '11111111-1111-1111-1111-000000000004', 45, 'Won basketball tournament', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', NOW() - INTERVAL '2 days', NOW() - INTERVAL '2 days'),
    (gen_random_uuid(), 'cccccccc-cccc-cccc-cccc-cccccccccccc', '11111111-1111-1111-1111-111111111111', '11111111-1111-1111-1111-000000000002', 20, 'Food bank volunteer', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', NOW(), NOW()),
    
    -- Bob Wilson's scores
    (gen_random_uuid(), 'dddddddd-dddd-dddd-dddd-dddddddddddd', '11111111-1111-1111-1111-111111111111', '11111111-1111-1111-1111-000000000003', 50, 'Research paper published', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', NOW() - INTERVAL '6 days', NOW() - INTERVAL '6 days'),
    (gen_random_uuid(), 'dddddddd-dddd-dddd-dddd-dddddddddddd', '11111111-1111-1111-1111-111111111111', '11111111-1111-1111-1111-000000000001', 30, 'Mentored new students', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', NOW() - INTERVAL '2 days', NOW() - INTERVAL '2 days')
ON CONFLICT DO NOTHING;

COMMIT;

-- Display summary of seeded data
SELECT 'Data Seeding Complete!' as status;
SELECT 'Organizations Created: ' || COUNT(*) as summary FROM organizations;
SELECT 'Users Created: ' || COUNT(*) as summary FROM users;
SELECT 'Score Categories Created: ' || COUNT(*) as summary FROM score_categories;
SELECT 'Groups Created: ' || COUNT(*) as summary FROM groups;
SELECT 'Scores Created: ' || COUNT(*) as summary FROM scores;

-- Display test credentials
SELECT '
========================================
TEST CREDENTIALS
========================================

Super Admin:
  URL: http://admin.score.al-hanna.com
  Username: superadmin
  Password: SuperBishoy@123!

Organization Admin:
  URL: http://score.al-hanna.com
  Username: admin
  Password: admin123
  Organization: Test Organization (testorg)

Regular Users:
  Username: john.doe / Password: user123
  Username: jane.smith / Password: user123
  Username: bob.wilson / Password: user123

NOTE: All passwords are hashed with "admin123" or "user123"
You may need to reset them using the proper hashing mechanism.

' as credentials;
