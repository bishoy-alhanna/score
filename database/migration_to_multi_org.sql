-- Migration script from single-org to multi-org schema
-- Run this AFTER creating the new schema tables

-- Step 1: Migrate existing users to the new structure
INSERT INTO user_organizations (user_id, organization_id, role, department, title, is_active, joined_at)
SELECT 
    id as user_id,
    organization_id,
    role,
    department,
    CASE 
        WHEN role = 'ORG_ADMIN' THEN 'Administrator'
        ELSE 'Member'
    END as title,
    is_active,
    created_at as joined_at
FROM users 
WHERE organization_id IS NOT NULL;

-- Step 2: Update users table to remove organization-specific fields
-- (This will be done by replacing the old users table with the new one)

-- Step 3: Verify migration
SELECT 
    u.username,
    u.email,
    o.name as organization_name,
    uo.role,
    uo.joined_at
FROM users u
JOIN user_organizations uo ON u.id = uo.user_id
JOIN organizations o ON uo.organization_id = o.id
WHERE uo.is_active = true
ORDER BY o.name, u.username;

-- Step 4: Clean up old constraints that may conflict
-- ALTER TABLE users DROP CONSTRAINT IF EXISTS unique_username_per_org;
-- ALTER TABLE users DROP CONSTRAINT IF EXISTS unique_email_per_org;

-- Add some sample join requests for testing
-- INSERT INTO organization_join_requests (user_id, organization_id, requested_role, message, status)
-- VALUES 
-- (
--     (SELECT id FROM users WHERE username = 'testuser' LIMIT 1),
--     (SELECT id FROM organizations WHERE name = 'Demo Organization' LIMIT 1),
--     'USER',
--     'I would like to join this organization to participate in the scoring system.',
--     'PENDING'
-- );

-- Example organization invitation
-- INSERT INTO organization_invitations (
--     organization_id, 
--     invited_by, 
--     email, 
--     role, 
--     message, 
--     token, 
--     expires_at, 
--     status
-- ) VALUES (
--     (SELECT id FROM organizations WHERE name = 'Demo Organization' LIMIT 1),
--     (SELECT id FROM users WHERE role = 'ORG_ADMIN' LIMIT 1),
--     'newuser@example.com',
--     'USER',
--     'Welcome to our organization!',
--     'sample_invitation_token_123',
--     NOW() + INTERVAL '7 days',
--     'PENDING'
-- );