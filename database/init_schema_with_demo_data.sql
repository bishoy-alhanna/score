-- Complete Database Schema with Demo Data
-- This script creates all tables and populates them with demo data for testing

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Drop existing tables (in correct order to respect foreign keys)
DROP TABLE IF EXISTS score_history CASCADE;
DROP TABLE IF EXISTS scores CASCADE;
DROP TABLE IF EXISTS group_members CASCADE;
DROP TABLE IF EXISTS groups CASCADE;
DROP TABLE IF EXISTS score_categories CASCADE;
DROP TABLE IF EXISTS user_organizations CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS organizations CASCADE;

-- =============================================================================
-- TABLE: organizations
-- =============================================================================
CREATE TABLE organizations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL UNIQUE,
    description TEXT,
    settings JSONB DEFAULT '{}',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================================
-- TABLE: users
-- =============================================================================
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL,
    username VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(255),
    last_name VARCHAR(255),
    role VARCHAR(50) DEFAULT 'user',
    profile_picture_url VARCHAR(500),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE,
    UNIQUE (organization_id, username),
    UNIQUE (organization_id, email)
);

-- =============================================================================
-- TABLE: user_organizations (many-to-many relationship)
-- =============================================================================
CREATE TABLE user_organizations (
    user_id UUID NOT NULL,
    organization_id UUID NOT NULL,
    role VARCHAR(50) DEFAULT 'member',
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, organization_id),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE
);

-- =============================================================================
-- TABLE: groups
-- =============================================================================
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

-- =============================================================================
-- TABLE: group_members
-- =============================================================================
CREATE TABLE group_members (
    group_id UUID NOT NULL,
    user_id UUID NOT NULL,
    role VARCHAR(50) DEFAULT 'member',
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (group_id, user_id),
    FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- =============================================================================
-- TABLE: score_categories
-- =============================================================================
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

-- =============================================================================
-- TABLE: scores
-- =============================================================================
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

-- =============================================================================
-- TABLE: score_history
-- =============================================================================
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

-- =============================================================================
-- INDEXES
-- =============================================================================
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

-- =============================================================================
-- TRIGGERS
-- =============================================================================
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

-- =============================================================================
-- VIEWS
-- =============================================================================
CREATE OR REPLACE VIEW user_total_scores AS
SELECT 
    u.id as user_id,
    u.username,
    u.email,
    u.first_name,
    u.last_name,
    u.organization_id,
    COALESCE(SUM(s.value), 0) as total_score,
    COUNT(DISTINCT s.category_id) as categories_count
FROM users u
LEFT JOIN scores s ON u.id = s.user_id
GROUP BY u.id, u.username, u.email, u.first_name, u.last_name, u.organization_id;

CREATE OR REPLACE VIEW organization_leaderboard AS
SELECT 
    u.organization_id,
    o.name as organization_name,
    u.id as user_id,
    u.username,
    u.first_name,
    u.last_name,
    COALESCE(SUM(s.value), 0) as total_score,
    RANK() OVER (PARTITION BY u.organization_id ORDER BY COALESCE(SUM(s.value), 0) DESC) as rank
FROM users u
JOIN organizations o ON u.organization_id = o.id
LEFT JOIN scores s ON u.id = s.user_id
GROUP BY u.organization_id, o.name, u.id, u.username, u.first_name, u.last_name
ORDER BY u.organization_id, total_score DESC;

CREATE OR REPLACE VIEW category_scores AS
SELECT 
    u.id as user_id,
    u.username,
    u.first_name,
    u.last_name,
    u.organization_id,
    sc.id as category_id,
    sc.name as category_name,
    COALESCE(SUM(s.value), 0) as score
FROM users u
CROSS JOIN score_categories sc
LEFT JOIN scores s ON u.id = s.user_id AND sc.id = s.category_id
WHERE sc.organization_id = u.organization_id
GROUP BY u.id, u.username, u.first_name, u.last_name, u.organization_id, sc.id, sc.name
ORDER BY u.username, sc.name;

-- =============================================================================
-- DEMO DATA
-- =============================================================================

-- Insert Demo Organizations
INSERT INTO organizations (id, name, description) VALUES
    ('11111111-1111-1111-1111-111111111111', 'Demo University', 'Main demonstration university'),
    ('22222222-2222-2222-2222-222222222222', 'Youth Center', 'Community youth organization'),
    ('33333333-3333-3333-3333-333333333333', 'Tech Academy', 'Technology training academy');

-- Insert Demo Users
-- Password for all users: demo123
-- Hash generated with: crypt('demo123', gen_salt('bf'))
INSERT INTO users (id, organization_id, username, email, password_hash, first_name, last_name, role) VALUES
    -- Demo University Users
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'admin', 'admin@demo.com', 
     crypt('admin123', gen_salt('bf')), 'Admin', 'User', 'admin'),
    ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '11111111-1111-1111-1111-111111111111', 'john.doe', 'john.doe@demo.com', 
     crypt('demo123', gen_salt('bf')), 'John', 'Doe', 'user'),
    ('cccccccc-cccc-cccc-cccc-cccccccccccc', '11111111-1111-1111-1111-111111111111', 'jane.smith', 'jane.smith@demo.com', 
     crypt('demo123', gen_salt('bf')), 'Jane', 'Smith', 'user'),
    ('dddddddd-dddd-dddd-dddd-dddddddddddd', '11111111-1111-1111-1111-111111111111', 'bob.wilson', 'bob.wilson@demo.com', 
     crypt('demo123', gen_salt('bf')), 'Bob', 'Wilson', 'user'),
    ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', '11111111-1111-1111-1111-111111111111', 'alice.johnson', 'alice.johnson@demo.com', 
     crypt('demo123', gen_salt('bf')), 'Alice', 'Johnson', 'user'),
    
    -- Youth Center Users
    ('ffffffff-ffff-ffff-ffff-ffffffffffff', '22222222-2222-2222-2222-222222222222', 'youth.admin', 'admin@youth.com', 
     crypt('admin123', gen_salt('bf')), 'Youth', 'Admin', 'admin'),
    ('12121212-1212-1212-1212-121212121212', '22222222-2222-2222-2222-222222222222', 'mike.brown', 'mike@youth.com', 
     crypt('demo123', gen_salt('bf')), 'Mike', 'Brown', 'user'),
    ('13131313-1313-1313-1313-131313131313', '22222222-2222-2222-2222-222222222222', 'sarah.davis', 'sarah@youth.com', 
     crypt('demo123', gen_salt('bf')), 'Sarah', 'Davis', 'user'),
    
    -- Tech Academy Users
    ('14141414-1414-1414-1414-141414141414', '33333333-3333-3333-3333-333333333333', 'tech.admin', 'admin@tech.com', 
     crypt('admin123', gen_salt('bf')), 'Tech', 'Admin', 'admin'),
    ('15151515-1515-1515-1515-151515151515', '33333333-3333-3333-3333-333333333333', 'dev.student', 'dev@tech.com', 
     crypt('demo123', gen_salt('bf')), 'Developer', 'Student', 'user');

-- Link users to organizations
INSERT INTO user_organizations (user_id, organization_id, role) VALUES
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'admin'),
    ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '11111111-1111-1111-1111-111111111111', 'member'),
    ('cccccccc-cccc-cccc-cccc-cccccccccccc', '11111111-1111-1111-1111-111111111111', 'member'),
    ('dddddddd-dddd-dddd-dddd-dddddddddddd', '11111111-1111-1111-1111-111111111111', 'member'),
    ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', '11111111-1111-1111-1111-111111111111', 'member'),
    ('ffffffff-ffff-ffff-ffff-ffffffffffff', '22222222-2222-2222-2222-222222222222', 'admin'),
    ('12121212-1212-1212-1212-121212121212', '22222222-2222-2222-2222-222222222222', 'member'),
    ('13131313-1313-1313-1313-131313131313', '22222222-2222-2222-2222-222222222222', 'member'),
    ('14141414-1414-1414-1414-141414141414', '33333333-3333-3333-3333-333333333333', 'admin'),
    ('15151515-1515-1515-1515-151515151515', '33333333-3333-3333-3333-333333333333', 'member');

-- Insert Score Categories for each organization
INSERT INTO score_categories (organization_id, name, description, max_value) VALUES
    -- Demo University Categories
    ('11111111-1111-1111-1111-111111111111', 'Attendance', 'Points for class attendance', 100),
    ('11111111-1111-1111-1111-111111111111', 'Participation', 'Points for active participation', 100),
    ('11111111-1111-1111-1111-111111111111', 'Leadership', 'Points for leadership activities', 100),
    ('11111111-1111-1111-1111-111111111111', 'Academic Performance', 'Points for academic achievements', 100),
    ('11111111-1111-1111-1111-111111111111', 'Community Service', 'Points for community involvement', 100),
    
    -- Youth Center Categories
    ('22222222-2222-2222-2222-222222222222', 'Attendance', 'Program attendance points', 100),
    ('22222222-2222-2222-2222-222222222222', 'Sports', 'Sports participation points', 100),
    ('22222222-2222-2222-2222-222222222222', 'Volunteer Work', 'Volunteer activity points', 100),
    ('22222222-2222-2222-2222-222222222222', 'Mentorship', 'Mentoring others', 100),
    
    -- Tech Academy Categories
    ('33333333-3333-3333-3333-333333333333', 'Code Quality', 'Quality of submitted code', 100),
    ('33333333-3333-3333-3333-333333333333', 'Project Completion', 'Completed projects', 100),
    ('33333333-3333-3333-3333-333333333333', 'Team Collaboration', 'Working with others', 100),
    ('33333333-3333-3333-3333-333333333333', 'Innovation', 'Creative problem solving', 100);

-- Insert Groups
INSERT INTO groups (organization_id, name, description, created_by) VALUES
    ('11111111-1111-1111-1111-111111111111', 'Freshman Class 2025', 'First year students', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
    ('11111111-1111-1111-1111-111111111111', 'Computer Science Dept', 'CS department students', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
    ('11111111-1111-1111-1111-111111111111', 'Student Council', 'Student leadership group', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
    ('22222222-2222-2222-2222-222222222222', 'Soccer Team', 'Youth soccer team', 'ffffffff-ffff-ffff-ffff-ffffffffffff'),
    ('22222222-2222-2222-2222-222222222222', 'Art Club', 'Creative arts group', 'ffffffff-ffff-ffff-ffff-ffffffffffff'),
    ('33333333-3333-3333-3333-333333333333', 'Web Development', 'Web dev course group', '14141414-1414-1414-1414-141414141414'),
    ('33333333-3333-3333-3333-333333333333', 'Mobile App Development', 'Mobile dev course', '14141414-1414-1414-1414-141414141414');

-- Add users to groups
INSERT INTO group_members (group_id, user_id, role)
SELECT g.id, u.id, 'member'
FROM groups g
CROSS JOIN users u
WHERE g.organization_id = u.organization_id
AND g.name IN ('Freshman Class 2025', 'Computer Science Dept')
AND u.username IN ('john.doe', 'jane.smith', 'bob.wilson');

INSERT INTO group_members (group_id, user_id, role)
SELECT g.id, u.id, 'leader'
FROM groups g
CROSS JOIN users u
WHERE g.organization_id = u.organization_id
AND g.name = 'Student Council'
AND u.username = 'alice.johnson';

-- Insert Sample Scores for Demo University
INSERT INTO scores (user_id, category_id, value, awarded_by, reason)
SELECT 
    u.id,
    sc.id,
    FLOOR(RANDOM() * 50 + 30)::INTEGER, -- Random score between 30-80
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', -- Awarded by admin
    'Demo score for ' || sc.name
FROM users u
CROSS JOIN score_categories sc
WHERE u.organization_id = '11111111-1111-1111-1111-111111111111'
AND sc.organization_id = '11111111-1111-1111-1111-111111111111'
AND u.username IN ('john.doe', 'jane.smith', 'bob.wilson', 'alice.johnson');

-- Give higher scores to some users to create variety
UPDATE scores SET value = value + 20
WHERE user_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'; -- Jane gets bonus

UPDATE scores SET value = value + 30
WHERE user_id = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee'; -- Alice gets more bonus

-- Insert Sample Scores for Youth Center
INSERT INTO scores (user_id, category_id, value, awarded_by, reason)
SELECT 
    u.id,
    sc.id,
    FLOOR(RANDOM() * 40 + 40)::INTEGER,
    'ffffffff-ffff-ffff-ffff-ffffffffffff',
    'Demo score for ' || sc.name
FROM users u
CROSS JOIN score_categories sc
WHERE u.organization_id = '22222222-2222-2222-2222-222222222222'
AND sc.organization_id = '22222222-2222-2222-2222-222222222222'
AND u.username IN ('mike.brown', 'sarah.davis');

-- =============================================================================
-- VERIFICATION QUERIES
-- =============================================================================

-- Show summary
SELECT 
    'Database initialized successfully!' as status;

SELECT 
    'Organizations' as table_name,
    COUNT(*) as count
FROM organizations
UNION ALL
SELECT 'Users', COUNT(*) FROM users
UNION ALL
SELECT 'Groups', COUNT(*) FROM groups
UNION ALL
SELECT 'Score Categories', COUNT(*) FROM score_categories
UNION ALL
SELECT 'Scores', COUNT(*) FROM scores;

-- Show user credentials for testing
SELECT 
    o.name as organization,
    u.username,
    u.email,
    u.role,
    CASE 
        WHEN u.role = 'admin' THEN 'admin123'
        ELSE 'demo123'
    END as password
FROM users u
JOIN organizations o ON u.organization_id = o.id
ORDER BY o.name, u.role DESC, u.username;

-- Show leaderboard for Demo University
SELECT 
    rank,
    username,
    first_name || ' ' || last_name as full_name,
    total_score
FROM organization_leaderboard
WHERE organization_id = '11111111-1111-1111-1111-111111111111'
ORDER BY rank
LIMIT 10;
