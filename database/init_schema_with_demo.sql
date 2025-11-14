-- Complete Database Schema with Demo Data
-- This script drops and recreates the entire database

-- Drop existing tables (if they exist)
DROP TABLE IF EXISTS score_history CASCADE;
DROP TABLE IF EXISTS scores CASCADE;
DROP TABLE IF EXISTS group_members CASCADE;
DROP TABLE IF EXISTS groups CASCADE;
DROP TABLE IF EXISTS score_categories CASCADE;
DROP TABLE IF EXISTS user_organizations CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS organizations CASCADE;

-- Drop existing views
DROP VIEW IF EXISTS user_total_scores CASCADE;
DROP VIEW IF EXISTS organization_leaderboard CASCADE;
DROP VIEW IF EXISTS category_scores CASCADE;

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================
-- TABLE: organizations
-- ============================================
CREATE TABLE organizations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL UNIQUE,
    description TEXT,
    settings JSONB DEFAULT '{}',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- TABLE: users
-- ============================================
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL,
    username VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(255),
    last_name VARCHAR(255),
    profile_picture_url VARCHAR(500),
    role VARCHAR(50) DEFAULT 'user',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE,
    UNIQUE (organization_id, username),
    UNIQUE (organization_id, email)
);

-- ============================================
-- TABLE: user_organizations (many-to-many)
-- ============================================
CREATE TABLE user_organizations (
    user_id UUID NOT NULL,
    organization_id UUID NOT NULL,
    role VARCHAR(50) DEFAULT 'member',
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, organization_id),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE
);

-- ============================================
-- TABLE: groups
-- ============================================
CREATE TABLE groups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    created_by UUID,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE,
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL,
    UNIQUE (organization_id, name)
);

-- ============================================
-- TABLE: group_members
-- ============================================
CREATE TABLE group_members (
    group_id UUID NOT NULL,
    user_id UUID NOT NULL,
    role VARCHAR(50) DEFAULT 'member',
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (group_id, user_id),
    FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- ============================================
-- TABLE: score_categories
-- ============================================
CREATE TABLE score_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    max_value INTEGER,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE,
    UNIQUE (organization_id, name)
);

-- ============================================
-- TABLE: scores
-- ============================================
CREATE TABLE scores (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    category_id UUID NOT NULL,
    value INTEGER NOT NULL DEFAULT 0,
    awarded_by UUID,
    reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (category_id) REFERENCES score_categories(id) ON DELETE CASCADE,
    FOREIGN KEY (awarded_by) REFERENCES users(id) ON DELETE SET NULL
);

-- ============================================
-- TABLE: score_history
-- ============================================
CREATE TABLE score_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    category_id UUID NOT NULL,
    old_value INTEGER NOT NULL,
    new_value INTEGER NOT NULL,
    change_value INTEGER NOT NULL,
    changed_by UUID,
    reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (category_id) REFERENCES score_categories(id) ON DELETE CASCADE,
    FOREIGN KEY (changed_by) REFERENCES users(id) ON DELETE SET NULL
);

-- ============================================
-- INDEXES
-- ============================================
CREATE INDEX idx_users_organization_id ON users(organization_id);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_user_organizations_user_id ON user_organizations(user_id);
CREATE INDEX idx_user_organizations_organization_id ON user_organizations(organization_id);
CREATE INDEX idx_groups_organization_id ON groups(organization_id);
CREATE INDEX idx_group_members_user_id ON group_members(user_id);
CREATE INDEX idx_group_members_group_id ON group_members(group_id);
CREATE INDEX idx_scores_user_id ON scores(user_id);
CREATE INDEX idx_scores_category_id ON scores(category_id);
CREATE INDEX idx_score_categories_organization_id ON score_categories(organization_id);
CREATE INDEX idx_score_history_user_id ON score_history(user_id);
CREATE INDEX idx_score_history_category_id ON score_history(category_id);

-- ============================================
-- TRIGGERS
-- ============================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_organizations_updated_at BEFORE UPDATE ON organizations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_groups_updated_at BEFORE UPDATE ON groups
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_score_categories_updated_at BEFORE UPDATE ON score_categories
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_scores_updated_at BEFORE UPDATE ON scores
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- VIEWS
-- ============================================
CREATE VIEW user_total_scores AS
SELECT 
    u.id as user_id,
    u.username,
    u.email,
    u.first_name,
    u.last_name,
    u.organization_id,
    o.name as organization_name,
    COALESCE(SUM(s.value), 0) as total_score,
    COUNT(DISTINCT s.category_id) as categories_count
FROM users u
JOIN organizations o ON u.organization_id = o.id
LEFT JOIN scores s ON u.id = s.user_id
GROUP BY u.id, u.username, u.email, u.first_name, u.last_name, u.organization_id, o.name;

CREATE VIEW organization_leaderboard AS
SELECT 
    u.organization_id,
    o.name as organization_name,
    u.id as user_id,
    u.username,
    u.first_name,
    u.last_name,
    u.profile_picture_url,
    COALESCE(SUM(s.value), 0) as total_score,
    RANK() OVER (PARTITION BY u.organization_id ORDER BY COALESCE(SUM(s.value), 0) DESC) as rank
FROM users u
JOIN organizations o ON u.organization_id = o.id
LEFT JOIN scores s ON u.id = s.user_id
WHERE u.is_active = true
GROUP BY u.organization_id, o.name, u.id, u.username, u.first_name, u.last_name, u.profile_picture_url
ORDER BY u.organization_id, total_score DESC;

CREATE VIEW category_scores AS
SELECT 
    u.id as user_id,
    u.username,
    u.first_name,
    u.last_name,
    u.organization_id,
    sc.id as category_id,
    sc.name as category_name,
    COALESCE(SUM(s.value), 0) as score,
    sc.max_value
FROM users u
CROSS JOIN score_categories sc
LEFT JOIN scores s ON u.id = s.user_id AND sc.id = s.category_id
WHERE sc.organization_id = u.organization_id AND u.is_active = true
GROUP BY u.id, u.username, u.first_name, u.last_name, u.organization_id, sc.id, sc.name, sc.max_value
ORDER BY u.username, sc.name;

-- ============================================
-- DEMO DATA
-- ============================================

-- Insert Demo Organizations
INSERT INTO organizations (id, name, description) VALUES
('11111111-1111-1111-1111-111111111111', 'Default Organization', 'Default organization for the platform'),
('22222222-2222-2222-2222-222222222222', 'Youth Academy', 'Youth development and training organization'),
('33333333-3333-3333-3333-333333333333', 'Tech University', 'Technology and innovation university');

-- Insert Demo Users (password for all: admin123)
-- Hash generated using: crypt('admin123', gen_salt('bf'))
INSERT INTO users (id, organization_id, username, email, password_hash, first_name, last_name, role) VALUES
-- Default Organization Users
('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'admin', 'admin@score.com', crypt('admin123', gen_salt('bf')), 'Admin', 'User', 'admin'),
('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '11111111-1111-1111-1111-111111111111', 'john.doe', 'john.doe@score.com', crypt('admin123', gen_salt('bf')), 'John', 'Doe', 'user'),
('cccccccc-cccc-cccc-cccc-cccccccccccc', '11111111-1111-1111-1111-111111111111', 'jane.smith', 'jane.smith@score.com', crypt('admin123', gen_salt('bf')), 'Jane', 'Smith', 'user'),

-- Youth Academy Users
('dddddddd-dddd-dddd-dddd-dddddddddddd', '22222222-2222-2222-2222-222222222222', 'coach.mike', 'mike@youth.com', crypt('admin123', gen_salt('bf')), 'Mike', 'Johnson', 'admin'),
('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', '22222222-2222-2222-2222-222222222222', 'student.alice', 'alice@youth.com', crypt('admin123', gen_salt('bf')), 'Alice', 'Williams', 'user'),
('ffffffff-ffff-ffff-ffff-ffffffffffff', '22222222-2222-2222-2222-222222222222', 'student.bob', 'bob@youth.com', crypt('admin123', gen_salt('bf')), 'Bob', 'Brown', 'user'),
('10101010-1010-1010-1010-101010101010', '22222222-2222-2222-2222-222222222222', 'student.carol', 'carol@youth.com', crypt('admin123', gen_salt('bf')), 'Carol', 'Davis', 'user'),

-- Tech University Users
('20202020-2020-2020-2020-202020202020', '33333333-3333-3333-3333-333333333333', 'prof.smith', 'smith@tech.edu', crypt('admin123', gen_salt('bf')), 'Professor', 'Smith', 'admin'),
('30303030-3030-3030-3030-303030303030', '33333333-3333-3333-3333-333333333333', 'david.lee', 'david@tech.edu', crypt('admin123', gen_salt('bf')), 'David', 'Lee', 'user'),
('40404040-4040-4040-4040-404040404040', '33333333-3333-3333-3333-333333333333', 'emma.wilson', 'emma@tech.edu', crypt('admin123', gen_salt('bf')), 'Emma', 'Wilson', 'user');

-- Insert User Organizations (many-to-many relationships)
INSERT INTO user_organizations (user_id, organization_id, role) VALUES
-- Default Organization
('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'admin'),
('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '11111111-1111-1111-1111-111111111111', 'member'),
('cccccccc-cccc-cccc-cccc-cccccccccccc', '11111111-1111-1111-1111-111111111111', 'member'),
-- Youth Academy
('dddddddd-dddd-dddd-dddd-dddddddddddd', '22222222-2222-2222-2222-222222222222', 'admin'),
('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', '22222222-2222-2222-2222-222222222222', 'member'),
('ffffffff-ffff-ffff-ffff-ffffffffffff', '22222222-2222-2222-2222-222222222222', 'member'),
('10101010-1010-1010-1010-101010101010', '22222222-2222-2222-2222-222222222222', 'member'),
-- Tech University
('20202020-2020-2020-2020-202020202020', '33333333-3333-3333-3333-333333333333', 'admin'),
('30303030-3030-3030-3030-303030303030', '33333333-3333-3333-3333-333333333333', 'member'),
('40404040-4040-4040-4040-404040404040', '33333333-3333-3333-3333-333333333333', 'member');

-- Insert Score Categories for each organization
INSERT INTO score_categories (organization_id, name, description, max_value) VALUES
-- Default Organization Categories
('11111111-1111-1111-1111-111111111111', 'Attendance', 'Points for attendance and punctuality', 100),
('11111111-1111-1111-1111-111111111111', 'Participation', 'Points for class/event participation', 100),
('11111111-1111-1111-1111-111111111111', 'Leadership', 'Points for leadership activities', 100),
('11111111-1111-1111-1111-111111111111', 'Academic', 'Points for academic achievements', 100),
('11111111-1111-1111-1111-111111111111', 'Community Service', 'Points for community service', 100),

-- Youth Academy Categories
('22222222-2222-2222-2222-222222222222', 'Training Attendance', 'Attendance at training sessions', 100),
('22222222-2222-2222-2222-222222222222', 'Performance', 'Performance in competitions', 150),
('22222222-2222-2222-2222-222222222222', 'Teamwork', 'Teamwork and collaboration', 100),
('22222222-2222-2222-2222-222222222222', 'Discipline', 'Discipline and behavior', 100),
('22222222-2222-2222-2222-222222222222', 'Improvement', 'Personal improvement and growth', 100),

-- Tech University Categories
('33333333-3333-3333-3333-333333333333', 'Academic Performance', 'GPA and test scores', 200),
('33333333-3333-3333-3333-333333333333', 'Projects', 'Project completion and quality', 150),
('33333333-3333-3333-3333-333333333333', 'Research', 'Research contributions', 150),
('33333333-3333-3333-3333-333333333333', 'Collaboration', 'Team collaboration', 100),
('33333333-3333-3333-3333-333333333333', 'Innovation', 'Innovative solutions', 100);

-- Insert Demo Groups
INSERT INTO groups (id, organization_id, name, description, created_by) VALUES
-- Default Organization Groups
('50505050-5050-5050-5050-505050505050', '11111111-1111-1111-1111-111111111111', 'Team Alpha', 'First team group', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
('60606060-6060-6060-6060-606060606060', '11111111-1111-1111-1111-111111111111', 'Team Beta', 'Second team group', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),

-- Youth Academy Groups
('70707070-7070-7070-7070-707070707070', '22222222-2222-2222-2222-222222222222', 'Junior Squad', 'Junior training squad', 'dddddddd-dddd-dddd-dddd-dddddddddddd'),
('80808080-8080-8080-8080-808080808080', '22222222-2222-2222-2222-222222222222', 'Senior Squad', 'Senior training squad', 'dddddddd-dddd-dddd-dddd-dddddddddddd'),

-- Tech University Groups
('90909090-9090-9090-9090-909090909090', '33333333-3333-3333-3333-333333333333', 'CS Department', 'Computer Science students', '20202020-2020-2020-2020-202020202020'),
('a0a0a0a0-a0a0-a0a0-a0a0-a0a0a0a0a0a0', '33333333-3333-3333-3333-333333333333', 'Engineering Club', 'Engineering innovation club', '20202020-2020-2020-2020-202020202020');

-- Insert Group Members
INSERT INTO group_members (group_id, user_id, role) VALUES
-- Team Alpha members
('50505050-5050-5050-5050-505050505050', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'member'),
('50505050-5050-5050-5050-505050505050', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'member'),

-- Junior Squad members
('70707070-7070-7070-7070-707070707070', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'member'),
('70707070-7070-7070-7070-707070707070', 'ffffffff-ffff-ffff-ffff-ffffffffffff', 'leader'),

-- Senior Squad members
('80808080-8080-8080-8080-808080808080', '10101010-1010-1010-1010-101010101010', 'member'),

-- CS Department members
('90909090-9090-9090-9090-909090909090', '30303030-3030-3030-3030-303030303030', 'member'),
('90909090-9090-9090-9090-909090909090', '40404040-4040-4040-4040-404040404040', 'member');

-- Insert Demo Scores
-- We'll add scores to make the leaderboard interesting
INSERT INTO scores (user_id, category_id, value, awarded_by, reason)
SELECT 
    u.id,
    sc.id,
    (RANDOM() * 50 + 20)::INTEGER, -- Random score between 20-70
    (SELECT id FROM users WHERE role = 'admin' AND organization_id = u.organization_id LIMIT 1),
    'Demo score for testing'
FROM users u
CROSS JOIN score_categories sc
WHERE u.organization_id = sc.organization_id 
    AND u.role = 'user'
    AND RANDOM() > 0.3; -- Only add scores for ~70% of user-category combinations

-- Add some specific high scores for leaderboard demo
DO $$
DECLARE
    attendance_cat UUID;
    performance_cat UUID;
    alice_id UUID := 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee';
    bob_id UUID := 'ffffffff-ffff-ffff-ffff-ffffffffffff';
    admin_id UUID;
BEGIN
    -- Get category IDs
    SELECT id INTO attendance_cat FROM score_categories 
    WHERE name = 'Training Attendance' AND organization_id = '22222222-2222-2222-2222-222222222222';
    
    SELECT id INTO performance_cat FROM score_categories 
    WHERE name = 'Performance' AND organization_id = '22222222-2222-2222-2222-222222222222';
    
    SELECT id INTO admin_id FROM users 
    WHERE role = 'admin' AND organization_id = '22222222-2222-2222-2222-222222222222';
    
    -- Give Alice high scores
    INSERT INTO scores (user_id, category_id, value, awarded_by, reason) VALUES
    (alice_id, attendance_cat, 95, admin_id, 'Perfect attendance record'),
    (alice_id, performance_cat, 140, admin_id, 'Excellent performance in championships');
    
    -- Give Bob good scores
    INSERT INTO scores (user_id, category_id, value, awarded_by, reason) VALUES
    (bob_id, attendance_cat, 85, admin_id, 'Great attendance'),
    (bob_id, performance_cat, 120, admin_id, 'Strong performance');
END $$;

-- ============================================
-- VERIFICATION QUERIES
-- ============================================

-- Show organizations
SELECT '=== ORGANIZATIONS ===' as info;
SELECT id, name, description, is_active FROM organizations ORDER BY name;

-- Show users count per organization
SELECT '=== USERS PER ORGANIZATION ===' as info;
SELECT 
    o.name as organization,
    COUNT(u.id) as user_count,
    COUNT(CASE WHEN u.role = 'admin' THEN 1 END) as admin_count
FROM organizations o
LEFT JOIN users u ON o.id = u.organization_id
GROUP BY o.id, o.name
ORDER BY o.name;

-- Show score categories per organization
SELECT '=== SCORE CATEGORIES ===' as info;
SELECT 
    o.name as organization,
    sc.name as category,
    sc.max_value
FROM score_categories sc
JOIN organizations o ON sc.organization_id = o.id
ORDER BY o.name, sc.name;

-- Show top 5 users from leaderboard
SELECT '=== TOP 5 LEADERBOARD (Sample) ===' as info;
SELECT 
    organization_name,
    username,
    first_name,
    last_name,
    total_score,
    rank
FROM organization_leaderboard
WHERE rank <= 5
ORDER BY organization_name, rank;

-- Summary
SELECT '=== DATABASE SUMMARY ===' as info;
SELECT 
    (SELECT COUNT(*) FROM organizations) as total_organizations,
    (SELECT COUNT(*) FROM users) as total_users,
    (SELECT COUNT(*) FROM groups) as total_groups,
    (SELECT COUNT(*) FROM score_categories) as total_categories,
    (SELECT COUNT(*) FROM scores) as total_scores;
